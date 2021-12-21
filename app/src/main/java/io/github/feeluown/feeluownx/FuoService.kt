package io.github.feeluown.feeluownx

import android.app.Service
import android.content.Intent
import android.os.IBinder
import android.util.Log
import android.widget.Toast
import com.chaquo.python.PyObject
import com.chaquo.python.Python
import com.chaquo.python.android.AndroidPlatform
import java.util.concurrent.ExecutorService
import java.util.concurrent.Executors
import java.util.concurrent.Future

class FuoService : Service() {
    companion object {
        private val executor: ExecutorService = Executors.newSingleThreadExecutor()
        const val TAG = "FuoService"
        lateinit var pythonInstance: Python
        lateinit var task: Future<*>
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        task = executor.submit {
            startPython()
            start()
        }
        Toast.makeText(this, "FeelUOwn running in background", Toast.LENGTH_SHORT).show()
        return super.onStartCommand(intent, flags, startId)
    }

    override fun onBind(intent: Intent): IBinder {
        TODO("Return the communication channel to the service.")
    }

    private fun startPython() {
        if (!Python.isStarted()) {
            Python.start(AndroidPlatform(this))
        }
        pythonInstance = Python.getInstance()
    }

    private fun start() {
        pythonInstance.getModule("sys")["argv"]?.asList()?.add(PyObject.fromJava("-nw"))
        pythonInstance.getModule("sys")["argv"]?.asList()?.add(PyObject.fromJava("-d"))
        pythonInstance.getModule("feeluown.__main__").callAttr("main")
    }

    override fun onDestroy() {
        super.onDestroy()
        try {
            task.cancel(true)
            Toast.makeText(this, "Stopping FeelUOwn service", Toast.LENGTH_SHORT).show()
        } catch (e: Exception) {
            Log.e(TAG, "onDestroy: ", e)
        }
    }
}