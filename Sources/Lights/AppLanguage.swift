import Foundation

enum AppLanguage: String, CaseIterable, Identifiable {
    case english, chinese

    var id: String { rawValue }
    var label: String { self == .english ? "English" : "中文" }

    static var current: AppLanguage {
        AppLanguage(rawValue: UserDefaults.standard.string(forKey: "appLanguage") ?? "") ?? .english
    }
}

enum L10n {
    static func t(_ english: String, _ chinese: String) -> String {
        AppLanguage.current == .chinese ? chinese : english
    }
}
