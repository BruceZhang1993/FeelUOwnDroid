package io.github.feeluown.feeluownx

import android.app.Service
import android.content.Intent
import android.os.IBinder
import android.util.Log
import com.chaquo.python.PyObject
import com.chaquo.python.Python
import com.chaquo.python.android.AndroidPlatform

class FuoService : Service() {
    companion object {
        lateinit var pythonInstance: Python
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        startPython()
        start()
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
}