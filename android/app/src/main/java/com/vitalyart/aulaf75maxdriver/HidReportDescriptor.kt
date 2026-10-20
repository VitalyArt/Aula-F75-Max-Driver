package com.vitalyart.aulaf75maxdriver

/** HID report lengths can span many USB packets and must not be inferred from endpoint size. */
data class HidReportInfo(
    val usagePages: Set<Int> = emptySet(),
    val inputBytes: Int = 0,
    val outputBytes: Int = 0,
    val featureBytes: Int = 0
)

object HidReportDescriptor {
    private data class Globals(val page: Int = 0, val size: Int = 0, val count: Int = 0, val id: Int = 0)

    fun usagePages(bytes: ByteArray): Set<Int> = parse(bytes).usagePages

    /** Parses short items, nested collections, global Push/Pop, and report IDs. */
    fun parse(bytes: ByteArray): HidReportInfo {
        val pages = mutableSetOf<Int>()
        val stack = mutableListOf<Globals>()
        val inputs = mutableMapOf<Int, Long>()
        val outputs = mutableMapOf<Int, Long>()
        val features = mutableMapOf<Int, Long>()
        var globals = Globals()
        var depth = 0
        var offset = 0
        fun addReport(target: MutableMap<Int, Long>) {
            val bits = globals.size.toLong().coerceIn(0, 65536) * globals.count.toLong().coerceIn(0, 65536)
            target[globals.id] = ((target[globals.id] ?: 0) + bits).coerceAtMost(65536L * 8)
        }
        while (offset < bytes.size) {
            val prefix = bytes[offset++].toInt() and 0xff
            if (prefix == 0xfe) {
                if (offset + 2 > bytes.size) break
                val length = bytes[offset].toInt() and 0xff
                offset += 2 + length
                continue
            }
            val size = when (prefix and 3) { 3 -> 4; else -> prefix and 3 }
            if (offset + size > bytes.size) break
            var value = 0
            repeat(size) { index -> value = value or ((bytes[offset + index].toInt() and 0xff) shl (index * 8)) }
            offset += size
            val type = (prefix shr 2) and 3
            val tag = prefix shr 4
            when {
                type == 1 && tag == 0 -> globals = globals.copy(page = value)
                type == 1 && tag == 7 -> globals = globals.copy(size = value)
                type == 1 && tag == 8 -> globals = globals.copy(id = value and 0xff)
                type == 1 && tag == 9 -> globals = globals.copy(count = value)
                type == 1 && tag == 10 -> stack.add(globals)
                type == 1 && tag == 11 && stack.isNotEmpty() -> globals = stack.removeAt(stack.lastIndex)
                type == 0 && tag == 10 -> {
                    if (depth == 0) pages.add(globals.page)
                    depth++
                }
                type == 0 && tag == 12 -> depth = (depth - 1).coerceAtLeast(0)
                type == 0 && tag == 8 -> addReport(inputs)
                type == 0 && tag == 9 -> addReport(outputs)
                type == 0 && tag == 11 -> addReport(features)
            }
        }
        fun length(reports: Map<Int, Long>): Int = reports.maxOfOrNull { (id, bits) ->
            ((bits + 7) / 8).toInt() + if (id == 0) 0 else 1
        } ?: 0
        return HidReportInfo(pages, length(inputs), length(outputs), length(features))
    }
}
