package com.hannesrueger.network_barcode_scanner

import android.os.Build
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

private const val METHOD_CHANNEL = "network_barcode_scanner/scanner"
private const val SCAN_CHANNEL = "network_barcode_scanner/scanner/scans"

class MainActivity : FlutterActivity() {

    private var scanReceiver: ScanReceiver? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        val receiver = ScanReceiver(applicationContext)
        scanReceiver = receiver

        val messenger = flutterEngine.dartExecutor.binaryMessenger
        EventChannel(messenger, SCAN_CHANNEL).setStreamHandler(receiver.scanStream)

        MethodChannel(messenger, METHOD_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "configure" -> {
                    receiver.configure(
                        call.argument<List<String>>("actions").orEmpty(),
                        call.argument<List<String>>("extraKeys").orEmpty(),
                    )
                    result.success(null)
                }

                "stop" -> {
                    receiver.unregister()
                    result.success(null)
                }

                // Used to recognise PDA models known to ship a scan engine.
                "deviceInfo" -> result.success(
                    mapOf(
                        "manufacturer" to Build.MANUFACTURER,
                        "brand" to Build.BRAND,
                        "model" to Build.MODEL,
                    )
                )

                else -> result.notImplemented()
            }
        }
    }

    override fun onDestroy() {
        scanReceiver?.unregister()
        scanReceiver = null
        super.onDestroy()
    }
}
