package com.vitalyart.aulaf75maxdriver

import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class AulaModelsTest {
    @Test
    fun `rgb commit report is sized and checksummed`() {
        val report = AulaWirelessReports.rgbCommitReport()

        assertEquals(32, report.size)
        assertTrue(report[0] == 0x0f.toByte())
        assertTrue(report[31] != 0.toByte())
    }

    @Test
    fun `battery query uses expected header`() {
        val payload = AulaWirelessReports.batteryQuery(includeReportID = false, length = 64)

        assertEquals(64, payload.size)
        assertEquals(0x20.toByte(), payload[0])
        assertEquals(0x01.toByte(), payload[1])
    }

    @Test
    fun `time payload ends with footer bytes`() {
        val payload = AulaWiredPackets.timePayload()

        assertEquals(64, payload.size)
        assertEquals(0xaa.toByte(), payload[62])
        assertEquals(0x55.toByte(), payload[63])
    }

    @Test
    fun `wired high bandwidth endpoint is detected as display`() {
        val endpoint = HIDEndpointInfo(
            id = "wired-display",
            vendorID = AulaConstants.wiredVendorID,
            productID = AulaConstants.wiredProductID,
            usagePage = AulaConstants.wiredRawUsagePage,
            usage = 0,
            maxInputReportSize = AulaConstants.ackLength,
            maxOutputReportSize = AulaConstants.chunkLength,
            maxFeatureReportSize = 64,
            product = "Aula F75 Max",
            transport = "usbHost"
        )

        assertEquals("Wired display", endpoint.role)
    }
}
