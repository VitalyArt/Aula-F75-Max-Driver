package com.vitalyart.aulaf75maxdriver

import android.content.Context
import android.hardware.usb.UsbConstants
import android.hardware.usb.UsbDevice
import android.hardware.usb.UsbDeviceConnection
import android.hardware.usb.UsbInterface
import android.hardware.usb.UsbManager
import java.io.Closeable

private const val HID_SET_REPORT = 0x09
private const val HID_GET_REPORT = 0x01
private const val HID_REPORT_TYPE_INPUT = 0x01
private const val HID_REPORT_TYPE_OUTPUT = 0x02
private const val HID_REPORT_TYPE_FEATURE = 0x03
private const val USB_RECIP_INTERFACE = 0x01

class UsbHidSession private constructor(
    private val connection: UsbDeviceConnection,
    private val hidInterface: UsbInterface
) : Closeable {
    companion object {
        fun open(
            context: Context,
            vendorId: Int,
            productId: Int,
            label: String,
            interfacePredicate: (UsbInterface) -> Boolean = { true }
        ): UsbHidSession {
            val usbManager = context.getSystemService(UsbManager::class.java)
            val device = usbManager.deviceList.values.firstOrNull {
                it.vendorId == vendorId && it.productId == productId
            } ?: throw AulaError.DeviceNotFound()

            if (!usbManager.hasPermission(device)) {
                throw AulaError.OpenFailed("USB permission is missing for $label.")
            }

            val connection = usbManager.openDevice(device)
                ?: throw AulaError.OpenFailed("Failed to open USB device for $label.")

            val hidInterface = selectHidInterface(device, interfacePredicate)
            if (!connection.claimInterface(hidInterface, true)) {
                connection.close()
                throw AulaError.OpenFailed("Failed to claim USB interface ${hidInterface.id} for $label.")
            }

            return UsbHidSession(connection, hidInterface)
        }

        fun openFirst(
            context: Context,
            predicate: (UsbDevice) -> Boolean,
            label: String
        ): UsbHidSession {
            val usbManager = context.getSystemService(UsbManager::class.java)
            val device = usbManager.deviceList.values.firstOrNull(predicate)
                ?: throw AulaError.DeviceNotFound()

            if (!usbManager.hasPermission(device)) {
                throw AulaError.OpenFailed("USB permission is missing for $label.")
            }

            val connection = usbManager.openDevice(device)
                ?: throw AulaError.OpenFailed("Failed to open USB device for $label.")

            val hidInterface = selectHidInterface(device, { true })
            if (!connection.claimInterface(hidInterface, true)) {
                connection.close()
                throw AulaError.OpenFailed("Failed to claim USB interface ${hidInterface.id} for $label.")
            }

            return UsbHidSession(connection, hidInterface)
        }

        private fun selectHidInterface(
            device: UsbDevice,
            interfacePredicate: (UsbInterface) -> Boolean
        ): UsbInterface {
            for (index in 0 until device.interfaceCount) {
                val candidate = device.getInterface(index)
                if (candidate.interfaceClass == UsbConstants.USB_CLASS_HID && interfacePredicate(candidate)) {
                    return candidate
                }
            }
            for (index in 0 until device.interfaceCount) {
                val candidate = device.getInterface(index)
                if (candidate.interfaceClass == UsbConstants.USB_CLASS_HID) {
                    return candidate
                }
            }
            return device.getInterface(0)
        }
    }

    val interfaceId: Int
        get() = hidInterface.id

    fun sendOutputReport(report: ByteArray, reportId: Int = 0): Int {
        return sendReport(HID_REPORT_TYPE_OUTPUT, reportId, report)
    }

    fun sendFeatureReport(report: ByteArray, reportId: Int = 0): Int {
        return sendReport(HID_REPORT_TYPE_FEATURE, reportId, report)
    }

    fun readInputReport(length: Int, timeoutMillis: Int): ByteArray? {
        return readReport(HID_REPORT_TYPE_INPUT, 0, length, timeoutMillis)
    }

    fun readFeatureReport(length: Int, timeoutMillis: Int): ByteArray? {
        return readReport(HID_REPORT_TYPE_FEATURE, 0, length, timeoutMillis)
    }

    private fun sendReport(reportType: Int, reportId: Int, bytes: ByteArray): Int {
        val result = controlTransfer(
            UsbConstants.USB_DIR_OUT,
            HID_SET_REPORT,
            reportType,
            reportId,
            bytes,
            bytes.size,
            1_000
        )

        if (result >= 0 && result != bytes.size) {
            throw AulaError.HidFailed("SET_REPORT", result)
        }

        if (result >= 0) {
            return result
        }

        if (reportId == 0) {
            val prefixed = ByteArray(bytes.size + 1)
            System.arraycopy(bytes, 0, prefixed, 1, bytes.size)
            val fallback = controlTransfer(
                UsbConstants.USB_DIR_OUT,
                HID_SET_REPORT,
                reportType,
                reportId,
                prefixed,
                prefixed.size,
                1_000
            )
            if (fallback < 0) {
                throw AulaError.HidFailed("SET_REPORT", fallback)
            }
            return fallback
        }

        throw AulaError.HidFailed("SET_REPORT", result)
    }

    private fun readReport(reportType: Int, reportId: Int, length: Int, timeoutMillis: Int): ByteArray? {
        val buffer = ByteArray(length.coerceAtLeast(0))
        if (buffer.isEmpty()) {
            return buffer
        }

        val result = controlTransfer(
            UsbConstants.USB_DIR_IN,
            HID_GET_REPORT,
            reportType,
            reportId,
            buffer,
            buffer.size,
            timeoutMillis
        )
        if (result < 0) {
            return null
        }
        return buffer.copyOf(result)
    }

    private fun controlTransfer(
        direction: Int,
        request: Int,
        reportType: Int,
        reportId: Int,
        buffer: ByteArray,
        length: Int,
        timeoutMillis: Int
    ): Int {
        val requestType = direction or UsbConstants.USB_TYPE_CLASS or USB_RECIP_INTERFACE
        val value = (reportType shl 8) or (reportId and 0xff)
        return connection.controlTransfer(
            requestType,
            request,
            value,
            hidInterface.id,
            buffer,
            length,
            timeoutMillis
        )
    }

    override fun close() {
        connection.releaseInterface(hidInterface)
        connection.close()
    }
}

private fun ByteArray.isEmpty(): Boolean = size == 0
