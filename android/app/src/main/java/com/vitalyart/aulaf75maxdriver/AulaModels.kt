package com.vitalyart.aulaf75maxdriver

import androidx.compose.ui.graphics.Color
import java.util.Calendar
import java.util.Date
import java.util.Locale

object AulaConstants {
    const val wiredVendorID = 0x0c45
    const val wiredProductID = 0x800a
    const val dongleVendorID = 0x05ac
    const val dongleProductID = 0x024f

    const val wiredCommandUsagePage = 0xff13
    const val wiredRawUsagePage = 0xff68
    const val wirelessCommandUsagePage = 0xff59
    const val wirelessRawUsagePage = 0xff60
    const val commandUsagePage = wiredCommandUsagePage
    const val rawUsagePage = wiredRawUsagePage
    const val vendorUsage = 0x61

    const val commandLength = 64
    const val ackLength = 128
    const val displayWidth = 128
    const val displayHeight = 128
    const val headerLength = 256
    const val frameBytes = displayWidth * displayHeight * 2
    const val chunkLength = 4096
    const val maxFrames = 255
}

sealed class AulaError(message: String) : Exception(message) {
    class DeviceNotFound : AulaError("Aula F75 Max device was not found.")
    class EndpointNotFound(endpoint: String) : AulaError("Required HID endpoint was not found: $endpoint.")
    class OpenFailed(detail: String) : AulaError("Failed to open HID device: $detail.")
    class HidFailed(operation: String, code: Int) : AulaError("$operation failed with HID status $code.")
    class ImageLoadFailed(detail: String) : AulaError("Failed to load image: $detail.")
    class ImageTooLarge(detail: String) : AulaError("Image payload is too large: $detail.")
    object InvalidSlot : AulaError("Slot must be between 1 and 255.")
    object Cancelled : AulaError("Operation cancelled.")
}

data class HIDEndpointInfo(
    val id: String,
    val vendorID: Int,
    val productID: Int,
    val usagePage: Int,
    val usage: Int,
    val maxInputReportSize: Int,
    val maxOutputReportSize: Int,
    val maxFeatureReportSize: Int,
    val product: String,
    val transport: String
) {
    val role: String
        get() {
            if (vendorID == AulaConstants.dongleVendorID && productID == AulaConstants.dongleProductID) {
                return if (maxOutputReportSize >= AulaConstants.commandLength && maxInputReportSize >= AulaConstants.commandLength) {
                    "2.4G command"
                } else {
                    "2.4G raw"
                }
            }
            if (maxOutputReportSize >= AulaConstants.chunkLength) {
                return "Wired display"
            }
            if (maxFeatureReportSize >= AulaConstants.commandLength || maxOutputReportSize >= AulaConstants.commandLength) {
                return "Wired command"
            }
            return "HID"
        }

    val summary: String
        get() = String.format(
            Locale.US,
            "%s usagePage=0x%04x in=%d out=%d feature=%d",
            role,
            usagePage,
            maxInputReportSize,
            maxOutputReportSize,
            maxFeatureReportSize
        )
}

data class DisplayUploadProgress(
    val sentChunks: Int,
    val totalChunks: Int
) {
    val fraction: Double
        get() = if (totalChunks <= 0) 0.0 else sentChunks.toDouble() / totalChunks.toDouble()
}

enum class ScreenFitMode(val title: String) {
    CONTAIN("Fit"),
    COVER("Fill"),
    STRETCH("Stretch")
}

data class EncodedDisplayStream(
    val data: ByteArray,
    val frameCount: Int,
    val chunkCount: Int
)

object AulaChecksum {
    fun apply(bytes: ByteArray, checksumIndex: Int) {
        if (checksumIndex !in bytes.indices) {
            return
        }
        bytes[checksumIndex] = 0
        var sum = 0
        for (byte in bytes) {
            sum = (sum + (byte.toInt() and 0xff)) and 0xff
        }
        bytes[checksumIndex] = sum.toByte()
    }
}

object AulaWiredPackets {
    fun packet(first: Int, second: Int): ByteArray = ByteArray(AulaConstants.commandLength).apply {
        this[0] = first.toByte()
        this[1] = second.toByte()
    }

    fun timePayload(date: Date = Date(), calendar: Calendar = Calendar.getInstance()): ByteArray {
        val parts = calendar.apply { time = date }.let {
            arrayOf(
                it.get(Calendar.MONTH) + 1,
                it.get(Calendar.DAY_OF_MONTH),
                it.get(Calendar.HOUR_OF_DAY),
                it.get(Calendar.MINUTE),
                it.get(Calendar.SECOND),
                it.get(Calendar.DAY_OF_WEEK)
            )
        }
        return ByteArray(AulaConstants.commandLength).apply {
            this[0] = 0x00.toByte()
            this[1] = 0x01.toByte()
            this[2] = 0x5a.toByte()
            this[3] = 0x1a.toByte()
            this[4] = parts[0].toByte()
            this[5] = parts[1].toByte()
            this[6] = parts[2].toByte()
            this[7] = parts[3].toByte()
            this[8] = parts[4].toByte()
            this[10] = ((parts[5] - 1).coerceAtLeast(0)).toByte()
            this[62] = 0xaa.toByte()
            this[63] = 0x55.toByte()
        }
    }
}

object AulaWirelessReports {
    fun rgbCommitReport(): ByteArray = ByteArray(32).apply {
        this[0] = 0x0f.toByte()
        AulaChecksum.apply(this, 31)
    }

    fun rgbLEDReport(
        mode: Int,
        brightness: Int,
        speed: Int,
        direction: Int,
        colorful: Int,
        color: Int
    ): ByteArray = ByteArray(32).apply {
        this[0] = 0x05.toByte()
        this[1] = 0x10.toByte()
        this[2] = 0x00.toByte()
        this[3] = mode.toByte()
        if (mode != 0) {
            this[4] = (color and 0xff).toByte()
            this[5] = ((color shr 8) and 0xff).toByte()
            this[6] = ((color shr 16) and 0xff).toByte()
            this[11] = colorful.toByte()
            this[12] = brightness.toByte()
            this[13] = speed.toByte()
            this[14] = direction.toByte()
        }
        this[17] = 0xaa.toByte()
        this[18] = 0x55.toByte()
        AulaChecksum.apply(this, 31)
    }

    fun keyResponseReport(responseLevel: Int, fnSwitch: Int, sleepTime: Int): ByteArray = ByteArray(32).apply {
        this[0] = 0x07.toByte()
        this[1] = 0x10.toByte()
        this[2] = 0x00.toByte()
        this[3] = 0x00.toByte()
        this[4] = 0x01.toByte()
        this[5] = 0x01.toByte()
        this[6] = 0x01.toByte()
        this[7] = 0x01.toByte()
        this[8] = fnSwitch.toByte()
        this[9] = sleepTime.toByte()
        this[11] = responseLevel.toByte()
        this[17] = 0xaa.toByte()
        this[18] = 0x55.toByte()
        AulaChecksum.apply(this, 31)
    }

    fun gameModeReport(
        responseLevel: Int,
        fnSwitch: Int,
        sleepTime: Int,
        gameMode: Int,
        disableAltTab: Int,
        disableAltF4: Int,
        disableWin: Int
    ): ByteArray = keyResponseReport(responseLevel, fnSwitch, sleepTime).apply {
        this[12] = gameMode.toByte()
        this[13] = disableAltTab.toByte()
        this[14] = disableAltF4.toByte()
        this[15] = disableWin.toByte()
        AulaChecksum.apply(this, 31)
    }

    fun batteryQuery(includeReportID: Boolean, length: Int): ByteArray {
        val payload = ByteArray(length.coerceAtLeast(0))
        if (payload.isEmpty()) {
            return payload
        }

        if (includeReportID) {
            payload[0] = 0x00.toByte()
            if (payload.size > 1) {
                payload[1] = 0x20.toByte()
            }
            if (payload.size > 2) {
                payload[2] = 0x01.toByte()
            }
        } else {
            payload[0] = 0x20.toByte()
            if (payload.size > 1) {
                payload[1] = 0x01.toByte()
            }
        }

        AulaChecksum.apply(payload, if (includeReportID) 32 else 31)
        return payload
    }
}

fun screenFitModeTitle(mode: ScreenFitMode): String = mode.title

fun rgbColorToInt(color: Color): Int {
    val red = (color.red * 255.0f).toInt().coerceIn(0, 255)
    val green = (color.green * 255.0f).toInt().coerceIn(0, 255)
    val blue = (color.blue * 255.0f).toInt().coerceIn(0, 255)
    return (red shl 16) or (green shl 8) or blue
}

fun intToColor(value: Int): Color {
    val red = ((value shr 16) and 0xff) / 255.0f
    val green = ((value shr 8) and 0xff) / 255.0f
    val blue = (value and 0xff) / 255.0f
    return Color(red, green, blue)
}
