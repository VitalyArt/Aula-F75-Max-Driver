import Foundation

enum L10n {
    private static let defaultLanguageCode = "system"
    private static let languageDefaultsKey = "app.language.code"
    nonisolated(unsafe) private static var overrideLanguageCode: String? = UserDefaults.standard.string(forKey: languageDefaultsKey)

    static let supportedLanguageCodes = ["system", "en", "ru", "es", "uz", "kk", "pt", "zh-Hans"]

    @discardableResult
    static func configure(languageCode: String?) -> String {
        let normalized = normalizedLanguageCode(languageCode)
        overrideLanguageCode = normalized
        UserDefaults.standard.set(normalized, forKey: languageDefaultsKey)
        return normalized
    }

    static func text(_ key: String) -> String {
        resolvedBundle.localizedString(forKey: key, value: key, table: nil)
    }

    static func format(_ key: String, _ arguments: CVarArg...) -> String {
        let format = text(key)
        return String(format: format, locale: .current, arguments: arguments)
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
}
