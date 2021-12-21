package io.github.feeluown.feeluownx

import android.util.Log
import java.net.ConnectException
import java.net.InetAddress
import java.net.InetSocketAddress
import java.net.Socket
import java.nio.channels.SocketChannel
import java.util.concurrent.Executor
import java.util.concurrent.ExecutorService
import java.util.concurrent.Executors

/**
 * @author zhangyao
 */
class FuoClient(private val host: String, private val port: Int) {
    private var socket: Socket? = null

    companion object {
        const val TAG = "FuoClient"
        val instance = FuoClient("127.0.0.1", 23333)
    }

    fun runCheckConnection(callback: (Boolean) -> Unit) {
        val executor: ExecutorService = Executors.newSingleThreadExecutor()
        executor.execute {
            val ok = checkConnection()
            callback(ok)
            Log.i(TAG, "checkConnection: $ok")
        }
    }

    private fun checkConnection(): Boolean {
        val ok = InetAddress.getByName(host).isReachable(3)
        var portOk = false
        try {
            SocketChannel.open(InetSocketAddress(host, port)).use {
                if (it != null && it.isOpen) {
                    portOk = true
                }
            }
        } catch (e: ConnectException) {
            Log.i(TAG, "checkConnection: ", e)
        }
        return ok && portOk
    }
}