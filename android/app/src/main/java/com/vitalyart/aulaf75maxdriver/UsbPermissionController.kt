package com.vitalyart.aulaf75maxdriver

import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.hardware.usb.UsbDevice
import android.hardware.usb.UsbManager
import java.io.Closeable
import androidx.core.content.ContextCompat

class UsbPermissionController(
    private val context: Context,
    private val onPermissionResult: () -> Unit
) : Closeable {
    private val usbManager = context.getSystemService(UsbManager::class.java)
    private val action = "${context.packageName}.USB_PERMISSION"
    private val permissionIntent = PendingIntent.getBroadcast(
        context,
        0,
        Intent(action),
        PendingIntent.FLAG_IMMUTABLE
    )
    private val receiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context?, intent: Intent?) {
            if (intent?.action == action) {
                onPermissionResult()
            }
        }
    }

    init {
        ContextCompat.registerReceiver(
            context,
            receiver,
            IntentFilter(action),
            ContextCompat.RECEIVER_NOT_EXPORTED
        )
    }

    fun hasPermissionForAnyAulaDevice(): Boolean {
        return usbManager.deviceList.values.any { isAulaDevice(it) && usbManager.hasPermission(it) }
    }

    fun requestPermissionForFirstAulaDevice(): Boolean {
        val device = usbManager.deviceList.values.firstOrNull { isAulaDevice(it) && !usbManager.hasPermission(it) }
            ?: return false
        usbManager.requestPermission(device, permissionIntent)
        return true
    }

    fun hasPermissionFor(device: UsbDevice): Boolean {
        return usbManager.hasPermission(device)
    }

    override fun close() {
        runCatching {
            context.unregisterReceiver(receiver)
        }
    }

    private fun isAulaDevice(device: UsbDevice): Boolean {
        return (device.vendorId == AulaConstants.wiredVendorID && device.productId == AulaConstants.wiredProductID) ||
            (device.vendorId == AulaConstants.dongleVendorID && device.productId == AulaConstants.dongleProductID)
    }
}
