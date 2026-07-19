package com.vitalyart.aulaf75maxdriver

import android.content.Context
import android.hardware.usb.UsbConstants
import android.hardware.usb.UsbDevice
import android.hardware.usb.UsbInterface
import android.hardware.usb.UsbManager
import java.util.Date
import kotlin.math.min

class AndroidAulaBackend(private val context: Context) {
    private val usbManager = context.getSystemService(UsbManager::class.java)

    fun scanEndpoints(): List<HIDEndpointInfo> {
        return usbManager.deviceList.values
            .filter { isAulaDevice(it) }
            .flatMap { device ->
                val product = device.productName ?: productName(device.vendorId, device.productId)
                val transport = "usbHost"
                if (device.interfaceCount == 0) {
                    listOf(
                        HIDEndpointInfo(
                            id = device.deviceName,
                            vendorID = device.vendorId,
                            productID = device.productId,
                            usagePage = 0,
                            usage = 0,
                            maxInputReportSize = 64,
                            maxOutputReportSize = 64,
                            maxFeatureReportSize = 64,
                            product = product,
                            transport = transport
                        )
                    )
                } else {
                    (0 until device.interfaceCount).map { index ->
                        val usbInterface = device.getInterface(index)
                        val inputSize = endpointSize(usbInterface, UsbConstants.USB_DIR_IN)
                        val outputSize = endpointSize(usbInterface, UsbConstants.USB_DIR_OUT)
                        HIDEndpointInfo(
                            id = "${device.deviceName}:$index",
                            vendorID = device.vendorId,
                            productID = device.productId,
                            usagePage = if (device.vendorId == AulaConstants.wiredVendorID) {
                                AulaConstants.wiredCommandUsagePage
                            } else {
                                AulaConstants.wirelessCommandUsagePage
                            },
                            usage = 0,
                            maxInputReportSize = inputSize,
                            maxOutputReportSize = outputSize,
                            maxFeatureReportSize = maxOf(64, inputSize, outputSize),
                            product = product,
                            transport = transport
                        )
                    }
                }
            }
            .sortedWith(compareBy<HIDEndpointInfo> { it.vendorID }.thenBy { it.productID }.thenBy { it.id })
    }

    fun syncTime(date: Date = Date()) {
        openWiredCommandSession().use { session ->
            commandExchange(session, AulaWiredPackets.packet(0x04, 0x18))
            val prepare = AulaWiredPackets.packet(0x04, 0x28).apply {
                this[8] = 0x01.toByte()
            }
            commandExchange(session, prepare)
            commandExchange(session, AulaWiredPackets.timePayload(date = date))
            commandExchange(session, AulaWiredPackets.packet(0x04, 0x02))
        }
    }

    fun uploadDisplayStream(
        stream: ByteArray,
        slot: Int,
        progress: (DisplayUploadProgress) -> Unit
    ) {
        if (slot !in 1..255) {
            throw AulaError.InvalidSlot
        }

        openWiredCommandSession().use { commandSession ->
            openWiredDisplaySession().use { displaySession ->
                val chunkCount = (stream.size + AulaConstants.chunkLength - 1) / AulaConstants.chunkLength
                if (chunkCount > 0xffff) {
                    throw AulaError.ImageTooLarge("$chunkCount chunks exceeds UInt16 metadata")
                }

                commandExchange(commandSession, AulaWiredPackets.packet(0x04, 0x18))

                val metadata = AulaWiredPackets.packet(0x04, 0x72).apply {
                    this[2] = slot.toByte()
                    this[8] = (chunkCount and 0xff).toByte()
                    this[9] = ((chunkCount shr 8) and 0xff).toByte()
                }
                commandExchange(commandSession, metadata)
                displaySession.readInputReport(AulaConstants.ackLength, 150)

                for (chunkIndex in 0 until chunkCount) {
                    val offset = chunkIndex * AulaConstants.chunkLength
                    val chunk = stream.copyOfRange(offset, min(offset + AulaConstants.chunkLength, stream.size))
                    val padded = if (chunk.size == AulaConstants.chunkLength) {
                        chunk
                    } else {
                        chunk + ByteArray(AulaConstants.chunkLength - chunk.size)
                    }
                    sendOutputReport(displaySession, padded, "display chunk ${chunkIndex + 1}/$chunkCount")
                    displaySession.readInputReport(AulaConstants.ackLength, 350)
                    progress(DisplayUploadProgress(chunkIndex + 1, chunkCount))
                }

                commandExchange(commandSession, AulaWiredPackets.packet(0x04, 0x02))
            }
        }
    }

    fun factoryReset(progress: (String) -> Unit) {
        openWiredCommandSession().use { session ->
            progress("Clearing display memory")
            commandExchange(session, AulaWiredPackets.packet(0x04, 0x19))
            val clearSlots = AulaWiredPackets.packet(0x04, 0x15).apply { this[8] = 0x08.toByte() }
            commandExchange(session, clearSlots)
            sendZeroPages(session, 8)
            commandExchange(session, AulaWiredPackets.packet(0x04, 0x02))

            progress("Resetting keymap and macro data")
            commandExchange(session, AulaWiredPackets.packet(0x04, 0x18))
            val keymap = AulaWiredPackets.packet(0x04, 0x11).apply { this[8] = 0x09.toByte() }
            commandExchange(session, keymap)
            sendZeroPages(session, 9)
            commandExchange(session, AulaWiredPackets.packet(0x04, 0x02))
            commandExchange(session, AulaWiredPackets.packet(0x04, 0xf0))

            progress("Resetting lighting data")
            commandExchange(session, AulaWiredPackets.packet(0x04, 0x18))
            val lighting = AulaWiredPackets.packet(0x04, 0x27).apply { this[8] = 0x09.toByte() }
            commandExchange(session, lighting)
            sendZeroPages(session, 9)
            commandExchange(session, AulaWiredPackets.packet(0x04, 0x02))
            commandExchange(session, AulaWiredPackets.packet(0x04, 0xf0))

            progress("Sending reset footer")
            commandExchange(session, AulaWiredPackets.packet(0x04, 0x18))
            val resetPayloadHeader = AulaWiredPackets.packet(0x04, 0x13).apply { this[8] = 0x01.toByte() }
            commandExchange(session, resetPayloadHeader)

            val resetPayload = ByteArray(AulaConstants.commandLength).apply {
                this[0] = 0x0b.toByte()
                this[1] = 0xff.toByte()
                this[8] = 0x01.toByte()
                this[9] = 0x05.toByte()
                this[10] = 0x03.toByte()
                this[14] = 0xaa.toByte()
                this[15] = 0x55.toByte()
            }
            commandExchange(session, resetPayload)
            commandExchange(session, AulaWiredPackets.packet(0x04, 0x02))
            commandExchange(session, AulaWiredPackets.packet(0x04, 0xf0))

            progress("Resetting display config")
            commandExchange(session, AulaWiredPackets.packet(0x04, 0x18))
            val displayReset = AulaWiredPackets.packet(0x04, 0x17).apply {
                this[2] = 0x01.toByte()
                this[8] = 0x01.toByte()
            }
            commandExchange(session, displayReset)

            val displayConfig = ByteArray(AulaConstants.commandLength).apply {
                this[0] = 0x00.toByte()
                this[1] = 0x01.toByte()
                this[6] = 0x02.toByte()
                this[8] = 0x02.toByte()
            }
            commandExchange(session, displayConfig)
            commandExchange(session, AulaWiredPackets.packet(0x04, 0x02))
        }
    }

    fun queryBattery(): Int? {
        openDongleSession().use { session ->
            val lengths = listOf(64, 33, 32)
            for (length in lengths) {
                sendOutputReport(session, AulaWirelessReports.batteryQuery(includeReportID = false, length = length), "battery query")
                readBatteryPercent(session.readInputReport(512, 250))?.let { return it }

                sendOutputReport(session, AulaWirelessReports.batteryQuery(includeReportID = true, length = length), "battery query")
                readBatteryPercent(session.readInputReport(512, 250))?.let { return it }
            }
            return null
        }
    }

    fun applyRGB(mode: Int, brightness: Int, speed: Int, direction: Int, colorful: Boolean, color: Int) {
        openDongleSession().use { session ->
            sendOutputReport(session, AulaWirelessReports.rgbCommitReport(), "RGB commit")
            Thread.sleep(50)
            sendOutputReport(
                session,
                AulaWirelessReports.rgbLEDReport(
                    mode = mode.coerceIn(0, 31),
                    brightness = brightness.coerceIn(1, 5),
                    speed = speed.coerceIn(1, 5),
                    direction = direction.coerceIn(0, 3),
                    colorful = if (colorful) 1 else 0,
                    color = color.coerceIn(0, 0xffffff)
                ),
                "RGB LED"
            )
        }
    }

    fun applyPerformance(level: Int, sleepTime: Int) {
        openDongleSession().use { session ->
            sendOutputReport(
                session,
                AulaWirelessReports.keyResponseReport(
                    responseLevel = level.coerceIn(1, 5),
                    fnSwitch = 1,
                    sleepTime = sleepTime.coerceIn(0, 3)
                ),
                "performance"
            )
        }
    }

    fun setGameMode(enabled: Boolean, level: Int, sleepTime: Int) {
        openDongleSession().use { session ->
            val value = if (enabled) 1 else 0
            sendOutputReport(
                session,
                AulaWirelessReports.gameModeReport(
                    responseLevel = level.coerceIn(1, 5),
                    fnSwitch = 1,
                    sleepTime = sleepTime.coerceIn(0, 3),
                    gameMode = value,
                    disableAltTab = value,
                    disableAltF4 = value,
                    disableWin = value
                ),
                "game mode"
            )
        }
    }

    private fun openWiredCommandSession(): UsbHidSession {
        return UsbHidSession.open(
            context = context,
            vendorId = AulaConstants.wiredVendorID,
            productId = AulaConstants.wiredProductID,
            label = "wired keyboard command endpoint",
            interfacePredicate = { usbInterface ->
                val outputSize = endpointSize(usbInterface, UsbConstants.USB_DIR_OUT)
                outputSize in 1 until AulaConstants.chunkLength
            }
        )
    }

    private fun openWiredDisplaySession(): UsbHidSession {
        return UsbHidSession.open(
            context = context,
            vendorId = AulaConstants.wiredVendorID,
            productId = AulaConstants.wiredProductID,
            label = "wired keyboard display endpoint",
            interfacePredicate = { usbInterface ->
                val inputSize = endpointSize(usbInterface, UsbConstants.USB_DIR_IN)
                val outputSize = endpointSize(usbInterface, UsbConstants.USB_DIR_OUT)
                outputSize >= AulaConstants.chunkLength || inputSize >= AulaConstants.ackLength
            }
        )
    }

    private fun openDongleSession(): UsbHidSession {
        return UsbHidSession.open(
            context = context,
            vendorId = AulaConstants.dongleVendorID,
            productId = AulaConstants.dongleProductID,
            label = "2.4G receiver",
            interfacePredicate = { usbInterface ->
                endpointSize(usbInterface, UsbConstants.USB_DIR_OUT) in 1 until AulaConstants.chunkLength
            }
        )
    }

    private fun commandExchange(session: UsbHidSession, packet: ByteArray) {
        sendFeatureReport(session, packet, "SET_REPORT")
        session.readFeatureReport(AulaConstants.commandLength, 100)
    }

    private fun sendZeroPages(session: UsbHidSession, count: Int) {
        if (count <= 0) {
            return
        }
        val zero = ByteArray(AulaConstants.commandLength)
        repeat(count - 1) {
            sendFeatureReport(session, zero, "zero page")
            Thread.sleep(40)
        }
        commandExchange(session, zero)
    }

    private fun sendOutputReport(session: UsbHidSession, bytes: ByteArray, operation: String) {
        val written = session.sendOutputReport(bytes)
        if (written < 0) {
            throw AulaError.HidFailed(operation, written)
        }
    }

    private fun sendFeatureReport(session: UsbHidSession, bytes: ByteArray, operation: String) {
        val written = session.sendFeatureReport(bytes)
        if (written < 0) {
            throw AulaError.HidFailed(operation, written)
        }
    }

    private fun readBatteryPercent(report: ByteArray?): Int? {
        if (report == null || report.size < 4) {
            return null
        }
        if (report[0] == 0x20.toByte() && report[1] == 0x01.toByte()) {
            val percent = report.getOrNull(3)?.toInt()?.and(0xff) ?: return null
            if (percent in 1..100) {
                return percent
            }
        }
        if (report.size >= 5 && report[1] == 0x20.toByte() && report[2] == 0x01.toByte()) {
            val percent = report.getOrNull(4)?.toInt()?.and(0xff) ?: return null
            if (percent in 1..100) {
                return percent
            }
        }
        return null
    }

    private fun isAulaDevice(device: UsbDevice): Boolean {
        return (device.vendorId == AulaConstants.wiredVendorID && device.productId == AulaConstants.wiredProductID) ||
            (device.vendorId == AulaConstants.dongleVendorID && device.productId == AulaConstants.dongleProductID)
    }

    private fun endpointSize(usbInterface: UsbInterface, direction: Int): Int {
        var size = 0
        for (index in 0 until usbInterface.endpointCount) {
            val endpoint = usbInterface.getEndpoint(index)
            if (endpoint.direction == direction) {
                size = maxOf(size, endpoint.maxPacketSize)
            }
        }
        return size
    }

    private fun productName(vendorID: Int, productID: Int): String {
        if (vendorID == AulaConstants.dongleVendorID && productID == AulaConstants.dongleProductID) {
            return "Aula F75 Max 2.4G"
        }
        return "Aula F75 Max"
    }
}
