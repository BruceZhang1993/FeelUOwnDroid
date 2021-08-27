LOCAL_PATH := $(call my-dir)

ifeq ($(TARGET_ARCH_ABI),arm64-v8a)
PREFIX = $(PREFIX64)
endif
ifeq ($(TARGET_ARCH_ABI),x86_64)
PREFIX = $(PREFIX_X64)
endif
ifeq ($(TARGET_ARCH_ABI),x86)
PREFIX = $(PREFIX_X86)
endif

include $(CLEAR_VARS)

LOCAL_MODULE := libmpv
LOCAL_SRC_FILES := $(PREFIX)/lib/libmpv.so
LOCAL_EXPORT_C_INCLUDES := $(PREFIX)/include

include $(PREBUILT_SHARED_LIBRARY)
