import Foundation

/// Keycap colour family. The F75 Max ships with a two-tone set: light grey on
/// the top rows fading to black at the bottom.
public enum KeycapTone: Equatable, Sendable {
    case light
    case dark
}

/// One key of the drawn keyboard. `frame` is in key units (1 = a normal key),
/// measured from the top-left corner of the key area.
public struct KeyboardKey: Identifiable, Sendable {
    public let id: String
    public let label: String
    public let frame: CGRect
    public let row: Int
    public let tone: KeycapTone
}

/// Everything needed to draw one keyboard: its keys plus the screen and knob.
public struct KeyboardLayoutSpec: Sendable {
    public let keys: [KeyboardKey]
    /// Width and height of the whole key area, in key units.
    public let size: CGSize
    public let screenFrame: CGRect
    public let knobCenter: CGPoint
    public let knobRadius: CGFloat
}

/// Layout data for keyboards the app can draw.
public enum KeyboardLayout {
    /// The Aula F75 Max, matching the owner's top-down reference photo:
    /// a function row with the screen and knob at the right, then a 75% block
    /// with a right-hand column and the arrow cluster set slightly lower.
    public static let f75Max: KeyboardLayoutSpec = {
        var builder = RowBuilder()

        // Row 0: Esc, F1-F4, F5-F8, F9-F12 in groups with small gaps.
        builder.startRow(0, y: 0)
        builder.add("Esc")
        builder.skip(0.25)
        for number in 1...4 { builder.add("F\(number)") }
        builder.skip(0.25)
        for number in 5...8 { builder.add("F\(number)") }
        builder.skip(0.25)
        for number in 9...12 { builder.add("F\(number)") }

        // Row 1: number row.
        builder.startRow(1, y: 1.25)
        for label in ["`", "1", "2", "3", "4", "5", "6", "7", "8", "9", "0", "-", "="] { builder.add(label) }
        builder.add("Backspace", width: 2)
        builder.add("Del")

        // Row 2.
        builder.startRow(2, y: 2.25)
        builder.add("Tab", width: 1.5)
        for label in ["Q", "W", "E", "R", "T", "Y", "U", "I", "O", "P", "[", "]"] { builder.add(label) }
        builder.add("\\", width: 1.5)
        builder.add("PgUp")

        // Row 3.
        builder.startRow(3, y: 3.25)
        builder.add("Caps", width: 1.75)
        for label in ["A", "S", "D", "F", "G", "H", "J", "K", "L", ";", "'"] { builder.add(label) }
        builder.add("Enter", width: 2.25, tone: .light)
        builder.add("PgDn")

        // Row 4.
        builder.startRow(4, y: 4.25)
        builder.add("Shift", id: "LShift", width: 2.25)
        for label in ["Z", "X", "C", "V", "B", "N", "M", ",", ".", "/"] { builder.add(label) }
        builder.add("Shift", id: "RShift", width: 1.75)
        builder.add("↑", id: "Up")
        builder.add("End")

        // Row 5: modifiers, space, then the arrows set slightly lower.
        builder.startRow(5, y: 5.25)
        builder.add("Ctrl", width: 1.25)
        builder.add("Win", width: 1.25)
        builder.add("Alt", id: "LAlt", width: 1.25)
        builder.add("", id: "Space", width: 6.25)
        builder.add("Alt", id: "RAlt")
        builder.add("Fn")
        builder.skip(1)
        builder.yOffset = 0.12
        builder.add("←", id: "Left")
        builder.add("↓", id: "Down")
        builder.add("→", id: "Right")

        return KeyboardLayoutSpec(
            keys: builder.keys,
            size: CGSize(width: 16, height: 6.4),
            screenFrame: CGRect(x: 13.95, y: 0.05, width: 1.1, height: 0.9),
            knobCenter: CGPoint(x: 15.55, y: 0.5),
            knobRadius: 0.42
        )
    }()
}

/// Places keys left to right, one row at a time, so the layout above reads
/// like the physical keyboard.
private struct RowBuilder {
    var keys: [KeyboardKey] = []
    var x: CGFloat = 0
    var y: CGFloat = 0
    var row = 0
    var yOffset: CGFloat = 0

    mutating func startRow(_ row: Int, y: CGFloat) {
        self.row = row
        self.y = y
        x = 0
        yOffset = 0
    }

    mutating func skip(_ width: CGFloat) {
        x += width
    }

    mutating func add(_ label: String, id: String? = nil, width: CGFloat = 1, tone: KeycapTone? = nil) {
        let frame = CGRect(x: x, y: y + yOffset, width: width, height: 1)
        keys.append(KeyboardKey(
            id: id ?? label,
            label: label,
            frame: frame,
            row: row,
            tone: tone ?? (row <= 2 ? .light : .dark)
        ))
        x += width
    }
}
