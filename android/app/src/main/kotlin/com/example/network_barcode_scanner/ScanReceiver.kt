package com.hannesrueger.network_barcode_scanner

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.os.Build
import io.flutter.plugin.common.EventChannel

/**
 * Bridges a PDA's built-in barcode engine into Dart.
 *
 * Rugged Android handhelds (the Chainway C90 and the ODM siblings it is resold
 * as) ship a vendor scanner service that can emit each decode as a broadcast
 * Intent. The action string and the extra key holding the text differ by
 * vendor and firmware, so both are supplied from Dart when registering.
 */
class ScanReceiver(private val context: Context) {

    val scanStream = object : EventChannel.StreamHandler {
        override fun onListen(arguments: Any?, events: EventChannel.EventSink) {
            scanSink = events
        }

        override fun onCancel(arguments: Any?) {
            scanSink = null
        }
    }

    private var scanSink: EventChannel.EventSink? = null
    private var extraKeys: List<String> = emptyList()
    private var registered = false

    private val receiver = object : BroadcastReceiver() {
        override fun onReceive(ctx: Context?, intent: Intent?) {
            if (intent == null) return

            // Chainway reports failed decodes on the same action with an empty
            // payload and SCAN_STATE=failed; an empty payload is skipped below.
            val barcode = extraKeys
                .firstNotNullOfOrNull { key -> intent.getStringExtra(key)?.takeIf { it.isNotBlank() } }
                // Some firmwares put the payload in a byte array rather than a string.
                ?: extraKeys.firstNotNullOfOrNull { key ->
                    intent.getByteArrayExtra(key)?.toString(Charsets.UTF_8)?.takeIf { it.isNotBlank() }
                }

            if (barcode != null) scanSink?.success(barcode.trim())
        }
    }

    /** (Re)register for the given actions. Safe to call repeatedly. */
    fun configure(actions: List<String>, extraKeys: List<String>) {
        this.extraKeys = extraKeys
        unregister()
        if (actions.isEmpty()) return

        val filter = IntentFilter().apply { actions.forEach { addAction(it) } }
        // The broadcast comes from another app on the device, so the receiver
        // has to be exported on Android 13+.
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            context.registerReceiver(receiver, filter, Context.RECEIVER_EXPORTED)
        } else {
            @Suppress("UnspecifiedRegisterReceiverFlag")
            context.registerReceiver(receiver, filter)
        }
        registered = true
    }

    fun unregister() {
        if (!registered) return
        runCatching { context.unregisterReceiver(receiver) }
        registered = false
    }
}
