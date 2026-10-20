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
    private val hidInterface: UsbInterface,
    private val useInterruptReports: Boolean = false,
    private val inputReportSize: Int = 0
) : Closeable {
    companion object {
        fun open(
            context: Context,
            vendorId: Int,
            productId: Int,
            label: String,
            interfacePredicate: (UsbInterface) -> Boolean = { true },
            requiredUsagePage: Int? = null
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

            val selected = try {
                if (requiredUsagePage == null) selectHidInterface(device, interfacePredicate) to HidReportInfo()
                else {
                    val observed = mutableListOf<String>()
                    var match: Pair<UsbInterface, HidReportInfo>? = null
                    for (index in 0 until device.interfaceCount) {
                        val candidate = device.getInterface(index)
                        if (candidate.interfaceClass != UsbConstants.USB_CLASS_HID) continue
                        val info = readReportInfo(connection, candidate,
                            allowInputOnlyVendor = vendorId == AulaConstants.wiredVendorID && productId == AulaConstants.wiredProductID)
                        val description = "${candidate.id}:${info.usagePages.map { "0x%04x".format(it) }}"
                        observed.add(description)
                        android.util.Log.d("AulaUSB", "Interface $description input=${info.inputBytes} output=${info.outputBytes} feature=${info.featureBytes}")
                        if (requiredUsagePage in info.usagePages && interfacePredicate(candidate)) {
                            match = candidate to info
                            break // Do not claim/release another channel which is already in use.
                        }
                    }
                    match ?: throw AulaError.EndpointNotFound("$label usagePage=0x%04x; interfaces=%s".format(requiredUsagePage, observed.joinToString()))
                }
            } catch (error: Throwable) {
                connection.close()
                throw error
            }
            val hidInterface = selected.first
            android.util.Log.d("AulaUSB", "Opening $label on interface ${hidInterface.id}")
            if (!connection.claimInterface(hidInterface, true)) {
                connection.close()
                throw AulaError.OpenFailed("Failed to claim USB interface ${hidInterface.id} for $label.")
            }

            return UsbHidSession(connection, hidInterface,
                useInterruptReports = requiredUsagePage == AulaConstants.wirelessRawUsagePage || requiredUsagePage == AulaConstants.wiredRawUsagePage,
                inputReportSize = selected.second.inputBytes)
        }

        /** GET_DESCRIPTOR(Report), addressed to this interface, before sending any vendor commands. */
        private fun readReportInfo(connection: UsbDeviceConnection, usbInterface: UsbInterface,
            allowInputOnlyVendor: Boolean = false): HidReportInfo {
            // Android usbfs requires claiming an interface for interface-recipient requests.
            // Never detach boot keyboard/mouse interfaces merely to inspect descriptors.
            val vendorChannel = usbInterface.interfaceSubclass == 0 &&
                (allowInputOnlyVendor || (0 until usbInterface.endpointCount).any {
                    usbInterface.getEndpoint(it).direction == UsbConstants.USB_DIR_OUT
                })
            if (!connection.claimInterface(usbInterface, vendorChannel)) return HidReportInfo()
            return try {
                val buffer = ByteArray(4096)
                val count = connection.controlTransfer(
                    UsbConstants.USB_DIR_IN or UsbConstants.USB_TYPE_STANDARD or USB_RECIP_INTERFACE,
                    0x06, 0x2200, usbInterface.id, buffer, buffer.size, 1000
                )
                android.util.Log.d("AulaUSB", "Report descriptor interface ${usbInterface.id}: $count bytes")
                if (count > 0) HidReportDescriptor.parse(buffer.copyOf(count)) else HidReportInfo()
            } finally {
                connection.releaseInterface(usbInterface)
            }
        }

        fun reportInfoByInterface(context: Context, device: UsbDevice): Map<Int, HidReportInfo> {
            val manager = context.getSystemService(UsbManager::class.java)
            if (!manager.hasPermission(device)) return emptyMap()
            val connection = manager.openDevice(device) ?: return emptyMap()
            return try {
                (0 until device.interfaceCount).map { device.getInterface(it) }
                    .filter { it.interfaceClass == UsbConstants.USB_CLASS_HID }
                    .associate { it.id to readReportInfo(connection, it,
                        allowInputOnlyVendor = device.vendorId == AulaConstants.wiredVendorID && device.productId == AulaConstants.wiredProductID) }
            } finally {
                connection.close()
            }
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
        val output = if (useInterruptReports) interruptEndpoint(UsbConstants.USB_DIR_OUT) else null
        if (output != null) {
            val payload = if (reportId == 0) report else byteArrayOf(reportId.toByte()) + report
            val count = connection.bulkTransfer(output, payload, payload.size, 1000)
            android.util.Log.d("AulaUSB", "Interrupt OUT interface ${hidInterface.id} endpoint ${output.address}: $count/${payload.size} bytes")
            if (count != payload.size) throw AulaError.HidFailed("interrupt OUT", count)
            return count
        }
        return sendReport(HID_REPORT_TYPE_OUTPUT, reportId, report)
    }

    fun sendFeatureReport(report: ByteArray, reportId: Int = 0): Int {
        return sendReport(HID_REPORT_TYPE_FEATURE, reportId, report)
    }

    fun readInputReport(length: Int, timeoutMillis: Int): ByteArray? {
        val input = if (useInterruptReports) interruptEndpoint(UsbConstants.USB_DIR_IN) else null
        if (input != null) {
            val reportLength = if (inputReportSize > 0) inputReportSize else input.maxPacketSize
            val buffer = ByteArray(minOf(length, reportLength))
            val count = connection.bulkTransfer(input, buffer, buffer.size, timeoutMillis)
            return if (count > 0) buffer.copyOf(count) else null
        }
        return readReport(HID_REPORT_TYPE_INPUT, 0, length, timeoutMillis)
    }

    fun readFeatureReport(length: Int, timeoutMillis: Int): ByteArray? {
        return readReport(HID_REPORT_TYPE_FEATURE, 0, length, timeoutMillis)
    }

    private fun interruptEndpoint(direction: Int): android.hardware.usb.UsbEndpoint? =
        (0 until hidInterface.endpointCount).map { hidInterface.getEndpoint(it) }.firstOrNull {
            it.direction == direction && it.type == UsbConstants.USB_ENDPOINT_XFER_INT
        }

    // Android's USBDEVFS_BULK path also handles interrupt endpoints synchronously.
    // Avoid closing queued UsbRequests on timeout: a later requestWait can reap freed native state.

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

        android.util.Log.d("AulaUSB", "SET_REPORT interface ${hidInterface.id} type=$reportType length=${bytes.size}: $result")
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
