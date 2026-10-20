package com.vitalyart.aulaf75maxdriver

import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class HidReportDescriptorTest {
    private fun bytes(vararg values: Int) = values.map { it.toByte() }.toByteArray()

    @Test fun distinguishesVendorCommandAndRawCollections() {
        val command = bytes(0x06, 0x59, 0xff, 0x09, 0x61, 0xa1, 0x01, 0xc0)
        val raw = bytes(0x06, 0x60, 0xff, 0x09, 0x61, 0xa1, 0x01, 0xc0)
        assertEquals(setOf(0xff59), HidReportDescriptor.usagePages(command))
        assertEquals(setOf(0xff60), HidReportDescriptor.usagePages(raw))
        assertEquals(setOf(0xff59, 0xff60), HidReportDescriptor.usagePages(command + raw))
    }

    @Test fun identifiesWiredDisplayRegardlessOfUsbPacketSize() {
        // The display has only a 64-byte USB IN endpoint; its HID output report is 4096 bytes.
        val display = bytes(0x06, 0x68, 0xff, 0x09, 0x01, 0xa1, 0x01,
            0x75, 0x08, 0x95, 0x40, 0x81, 0x02, 0x96, 0x00, 0x10, 0x91, 0x02, 0xc0)
        val command = bytes(0x06, 0x13, 0xff, 0x09, 0x01, 0xa1, 0x01, 0xc0)
        val info = HidReportDescriptor.parse(display)
        assertEquals(setOf(AulaConstants.wiredRawUsagePage), info.usagePages)
        assertEquals(4096, info.outputBytes)
        assertEquals(64, info.inputBytes)
        assertEquals(0, info.featureBytes)
        assertEquals(setOf(AulaConstants.wiredCommandUsagePage), HidReportDescriptor.usagePages(command))
    }

    @Test fun nestedKeyboardItemsDoNotChangeTopLevelPage() {
        val keyboard = bytes(0x05, 0x01, 0x09, 0x06, 0xa1, 0x01,
            0x05, 0x07, 0xa1, 0x00, 0xc0, 0xc0)
        assertEquals(setOf(1), HidReportDescriptor.usagePages(keyboard))
    }

    @Test fun supportsPushPopAndSkipsLongItems() {
        val descriptor = bytes(0x06, 0x60, 0xff, 0xa4, 0x05, 0x01, 0xb4,
            0xfe, 0x02, 0x00, 0xff, 0xff, 0xa1, 0x01, 0xc0)
        assertEquals(setOf(0xff60), HidReportDescriptor.usagePages(descriptor))
    }

    @Test fun sumsBitFieldsAndIncludesNumberedReportId() {
        val descriptor = bytes(0x05, 0x01, 0xa1, 0x01, 0x85, 0x02,
            0x75, 0x01, 0x95, 0x03, 0x81, 0x02,
            0xa4, 0x75, 0x05, 0x95, 0x01, 0x81, 0x03, 0xb4,
            0x81, 0x02, 0xc0)
        // 3 + 5 + 3 input bits, rounded up to 2 bytes, plus the report ID.
        assertEquals(3, HidReportDescriptor.parse(descriptor).inputBytes)
    }

    @Test fun truncatedDescriptorsDoNotInventAnInterface() {
        assertTrue(HidReportDescriptor.usagePages(bytes(0x06, 0x60)).isEmpty())
        assertTrue(HidReportDescriptor.usagePages(bytes(0xfe)).isEmpty())
        assertTrue(HidReportDescriptor.usagePages(byteArrayOf()).isEmpty())
    }
}
