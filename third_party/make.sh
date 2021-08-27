#!/usr/bin/env bash
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"

clean() {
  rm -vrf "$SCRIPT_DIR"/build
  rm -vrf "$SCRIPT_DIR"/prefix
}

setup() {
  unset CC CXX CPATH LIBRARY_PATH C_INCLUDE_PATH CPLUS_INCLUDE_PATH

  apilvl=23
  # ndk_triple: what the toolchain actually is
  # cc_triple: what Google pretends the toolchain is
  if [ "$1" == "arm" ]; then
    export ndk_suffix=
    export ndk_triple=arm-linux-androideabi
    cc_triple=armv7a-linux-androideabi$apilvl
    prefix_name=armv7l
  elif [ "$1" == "arm64" ]; then
    export ndk_suffix=-arm64
    export ndk_triple=aarch64-linux-android
    cc_triple=$ndk_triple$apilvl
    prefix_name=arm64
  elif [ "$1" == "x86" ]; then
    export ndk_suffix=-x86
    export ndk_triple=i686-linux-android
    cc_triple=$ndk_triple$apilvl
    prefix_name=x86
  elif [ "$1" == "x86_64" ]; then
    export ndk_suffix=-x64
    export ndk_triple=x86_64-linux-android
    cc_triple=$ndk_triple$apilvl
    prefix_name=x86_64
  else
    echo "Invalid architecture"
    exit 1
  fi

  export CC="$NDK/toolchains/llvm/prebuilt/linux-x86_64/bin/$cc_triple-clang"
  export CXX="$NDK/toolchains/llvm/prebuilt/linux-x86_64/bin/$cc_triple-clang++"

  ndk_suffix="_$1"

  os=linux
  [[ "$OSTYPE" == "darwin"* ]] && os=mac
  export os
  if [ "$os" == "mac" ]; then
    [ -z "$cores" ] && cores=$(sysctl -n hw.ncpu)
    # shellcheck disable=SC2155
    export INSTALL=$(which ginstall)
    export SED=gsed
  else
    [ -z "$cores" ] && cores=$(grep -c ^processor /proc/cpuinfo)
  fi
  cores=${cores:-4}

  crossfile_dir="$SCRIPT_DIR/prefix/$prefix_name"
  mkdir -p "$crossfile_dir"

  cat > "$crossfile_dir/crossfile.txt" << CROSSFILE
[binaries]
c = '$CC'
cpp = '$CXX'
ar = '$NDK/toolchains/llvm/prebuilt/linux-x86_64/bin/$ndk_triple-ar'
strip = '$NDK/toolchains/llvm/prebuilt/linux-x86_64/bin/$ndk_triple-strip'
pkgconfig = 'pkg-config'
[host_machine]
system = 'linux'
cpu_family = '$NDK/toolchains/llvm/prebuilt/linux-x86_64/bin/${ndk_triple%%-*}'
cpu = '${CC%%-*}'
endian = 'little'
CROSSFILE
}

build_dav1d() {
  if [ -z "$NDK" ]
  then
        echo "\$NDK is not set"
        exit 1
  fi

  setup "$1"

  mkdir -p "$SCRIPT_DIR"/build
  [ ! -d "$SCRIPT_DIR"/build/dav1d ] && cp -r "$SCRIPT_DIR"/dav1d "$SCRIPT_DIR"/build/dav1d
  cd "$SCRIPT_DIR"/build/dav1d || exit

  unset CC CXX

  build="_build$ndk_suffix"
  prefix_dir="$(pwd)/../../prefix/$prefix_name"

  meson "$build" \
  	--buildtype release --cross-file "$prefix_dir"/crossfile.txt \
  	--default-library static -Denable_tests=false

  ninja -C "$build" -j"$cores"
  DESTDIR="$prefix_dir" ninja -C "$build" install
}

build_ffmpeg() {
  if [ -z "$NDK" ]
  then
        echo "\$NDK is not set"
        exit 1
  fi

  setup "$1"

  mkdir -p "$SCRIPT_DIR"/build
  [ ! -d "$SCRIPT_DIR"/build/ffmpeg ] && cp -r "$SCRIPT_DIR"/ffmpeg "$SCRIPT_DIR"/build/ffmpeg
  cd "$SCRIPT_DIR"/build/ffmpeg || exit

  mkdir -p "_build$ndk_suffix"
  cd "_build$ndk_suffix" || exit

  cpu=armv7-a
  [[ "$ndk_triple" == "aarch64"* ]] && cpu=armv8-a
  [[ "$ndk_triple" == "x86_64"* ]] && cpu=generic
  [[ "$ndk_triple" == "i686"* ]] && cpu="i686 --disable-asm"

  cpuflags=
  [[ "$ndk_triple" == "arm"* ]] && cpuflags="$cpuflags -mfpu=neon -mcpu=cortex-a8"

  prefix_dir="$(pwd)/../../../prefix/$prefix_name"

  cross_prefix="$NDK/toolchains/llvm/prebuilt/linux-x86_64/bin/$ndk_triple-"

  ../configure \
  	--target-os=android --enable-cross-compile --cross-prefix="$cross_prefix" --cc="$CC" \
  	--arch=${ndk_triple%%-*} --cpu="$cpu" --enable-{jni,mediacodec,mbedtls,libdav1d} \
  	--extra-cflags="-I$prefix_dir/usr/local/include $cpuflags" --extra-ldflags="-L$prefix_dir/usr/local/lib" \
  	--disable-static --enable-shared --enable-{gpl,version3} \
  	--pkg-config=pkg-config --disable-{stripping,doc,programs} \
  	--disable-{muxers,encoders,devices} --enable-encoder=mjpeg,png

  make -j"$cores"
  make DESTDIR="$prefix_dir" install
}

build_mpv() {
  if [ -z "$NDK" ]
  then
        echo "\$NDK is not set"
        exit 1
  fi

  setup "$1"

  mkdir -p "$SCRIPT_DIR"/build
  [ ! -d "$SCRIPT_DIR"/build/mpv ] && cp -r "$SCRIPT_DIR"/mpv "$SCRIPT_DIR"/build/mpv
  cd "$SCRIPT_DIR"/build/mpv || exit
  [ -f waf ] || ./bootstrap.py

  PKG_CONFIG="pkg-config --static" \
  ./waf configure \
  	--disable-iconv --lua=52 \
  	--enable-libmpv-shared \
  	--disable-manpage-build \
  	-o "$(pwd)/_build$ndk_suffix"

  ./waf build -j"$cores"
  ./waf install --destdir="$(pwd)/../prefix/$prefix_name"
}

usage() {
  echo "Usage: make.sh [target]"
  echo "Targets: clean, build"
  exit 0
}

case "$1" in
  clean)
    clean
    ;;
  build)
    build_dav1d "arm64" || exit 1
    build_ffmpeg "arm64" || exit 1
    build_mpv "arm64" || exit 1
    # build_mpv "x86"
    # build_mpv "x86_64"
    ;;
  *)
    usage
    ;;
esac

exit 0
