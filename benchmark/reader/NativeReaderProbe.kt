// Copied only into exported benchmark APKs. No production receiver/channel.
package BENCHMARK_PACKAGE

import android.Manifest
import android.app.Activity
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.os.Build
import android.os.Process
import android.os.SystemClock
import android.os.Trace
import android.view.KeyEvent
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel

class NativeReaderProbe(private val activity: Activity, messenger: BinaryMessenger) {
    private val channel = MethodChannel(messenger, "reader/benchmark")
    private val keys = ArrayList<List<Long>>()
    private var capturing = false
    private var closed = false
    private var cpuStart = 0L
    private val receiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context, intent: Intent) {
            val args = HashMap<String, Any?>()
            intent.extras?.keySet()?.forEach { args[it] = intent.extras?.get(it) }
            channel.invokeMethod("command", args)
        }
    }

    init {
        channel.setMethodCallHandler { call, result ->
            when (call.method) {
                "clock" -> result.success(mapOf("monoNs" to System.nanoTime(), "elapsedNs" to SystemClock.elapsedRealtimeNanos(), "uptimeMs" to SystemClock.uptimeMillis()))
                "capture" -> {
                    keys.clear()
                    cpuStart = Process.getElapsedCpuTime()
                    capturing = true
                    result.success(null)
                }
                "stop" -> {
                    capturing = false
                    result.success(mapOf("keys" to keys.toList(), "cpuTimeMs" to (Process.getElapsedCpuTime() - cpuStart), "columns" to listOf("monoNs", "elapsedNs", "uptimeMs", "eventTimeMs", "downTimeMs", "keyCode", "repeatCount")))
                }
                else -> result.notImplemented()
            }
        }
        val filter = IntentFilter(activity.packageName + ".READER_BENCH")
        if (Build.VERSION.SDK_INT >= 33) {
            activity.registerReceiver(receiver, filter, Manifest.permission.DUMP, null, Context.RECEIVER_EXPORTED)
        } else {
            activity.registerReceiver(receiver, filter, Manifest.permission.DUMP, null)
        }
    }

    fun key(keyCode: Int, event: KeyEvent?) {
        if (!capturing || event == null || keyCode !in listOf(KeyEvent.KEYCODE_VOLUME_DOWN, KeyEvent.KEYCODE_VOLUME_UP)) return
        if (keys.size >= 10000) return
        Trace.beginSection("ReaderBench.volume.${event.repeatCount}")
        keys.add(listOf(System.nanoTime(), SystemClock.elapsedRealtimeNanos(), SystemClock.uptimeMillis(), event.eventTime, event.downTime, keyCode.toLong(), event.repeatCount.toLong()))
        Trace.endSection()
    }

    fun close() {
        if (closed) return
        closed = true
        capturing = false
        activity.unregisterReceiver(receiver)
        channel.setMethodCallHandler(null)
    }
}
