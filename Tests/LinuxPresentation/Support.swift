import Foundation

enum L10n {
    static func text(_ key: String) -> String { key }
}

func writeCString(_ message: String, to buffer: UnsafeMutablePointer<CChar>?, capacity: Int32) {
    guard let buffer, capacity > 0 else { return }
    let bytes = Array(message.utf8.prefix(Int(capacity) - 1))
    for (i, byte) in bytes.enumerated() { buffer[i] = CChar(bitPattern: byte) }
    buffer[bytes.count] = 0
}
