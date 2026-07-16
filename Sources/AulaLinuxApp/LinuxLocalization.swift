import Foundation

@_silgen_name("aula_linux_load_language")
private func cAulaLinuxLoadLanguage(_ buffer: UnsafeMutablePointer<CChar>?, _ capacity: Int32)

@_silgen_name("aula_linux_store_language")
private func cAulaLinuxStoreLanguage(_ languageCode: UnsafePointer<CChar>?)

enum L10n {
    private static let defaultLanguageCode = "system"
    nonisolated(unsafe) private static var overrideLanguageCode: String? = loadStoredLanguageCode()

    static let supportedLanguageCodes = ["system", "en", "ru", "es", "uz", "kk", "pt", "zh-Hans"]

    @discardableResult
    static func configure(languageCode: String?) -> String {
        let normalized = normalizedLanguageCode(languageCode)
        overrideLanguageCode = normalized
        normalized.withCString { cAulaLinuxStoreLanguage($0) }
        return normalized
    }

    static func text(_ key: String) -> String {
        resolvedBundle.localizedString(forKey: key, value: key, table: nil)
    }

    static func format(_ key: String, _ arguments: CVarArg...) -> String {
        let format = text(key)
        return String(format: format, locale: .current, arguments: arguments)
    }

    static var currentLanguageCode: String {
        overrideLanguageCode ?? defaultLanguageCode
    }

    private static var resolvedBundle: Bundle {
        guard let languageCode = overrideLanguageCode,
              languageCode != defaultLanguageCode,
              let path = lprojPath(for: languageCode),
              let bundle = Bundle(path: path) else {
            return Bundle.module
        }

        return bundle
    }

    private static func lprojPath(for languageCode: String) -> String? {
        Bundle.module.path(forResource: languageCode, ofType: "lproj")
            ?? Bundle.module.path(forResource: languageCode.lowercased(), ofType: "lproj")
    }

    private static func normalizedLanguageCode(_ languageCode: String?) -> String {
        guard let languageCode, !languageCode.isEmpty else {
            return defaultLanguageCode
        }
        return supportedLanguageCodes.first { $0.caseInsensitiveCompare(languageCode) == .orderedSame } ?? defaultLanguageCode
    }

    private static func loadStoredLanguageCode() -> String? {
        let bufferSize = 128
        let buffer = UnsafeMutablePointer<CChar>.allocate(capacity: bufferSize)
        defer { buffer.deallocate() }
        buffer.initialize(repeating: 0, count: bufferSize)
        cAulaLinuxLoadLanguage(buffer, Int32(bufferSize))
        let text = String(cString: buffer)
        return normalizedLanguageCode(text)
    }
}

@_cdecl("aula_linux_configure_language")
public func aulaLinuxConfigureLanguage(_ languageCode: UnsafePointer<CChar>?, _ buffer: UnsafeMutablePointer<CChar>?, _ capacity: Int32) {
    let code = languageCode.map { String(cString: $0) }
    writeCString(L10n.configure(languageCode: code), to: buffer, capacity: capacity)
}

@_cdecl("aula_linux_current_language_code")
public func aulaLinuxCurrentLanguageCode(_ buffer: UnsafeMutablePointer<CChar>?, _ capacity: Int32) {
    writeCString(L10n.currentLanguageCode, to: buffer, capacity: capacity)
}

@_cdecl("aula_linux_localized_string")
public func aulaLinuxLocalizedString(_ key: UnsafePointer<CChar>?, _ buffer: UnsafeMutablePointer<CChar>?, _ capacity: Int32) {
    let text = key.map { String(cString: $0) } ?? ""
    writeCString(L10n.text(text), to: buffer, capacity: capacity)
}

func writeCString(_ message: String, to buffer: UnsafeMutablePointer<CChar>?, capacity: Int32) {
    guard let buffer, capacity > 0 else { return }
    let limit = max(Int(capacity) - 1, 0)
    let bytes = Array(message.utf8.prefix(limit))
    for index in bytes.indices {
        buffer[index] = CChar(bitPattern: bytes[index])
    }
    buffer[bytes.count] = 0
}
