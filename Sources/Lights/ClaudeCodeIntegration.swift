import Foundation

final class ClaudeCodeIntegration: ToolIntegration {
    let id = "claude-code"
    let displayName = "Claude Code"
    let supportLevel: SupportLevel = .events

    var settingsPath: String { "\(NSHomeDirectory())/.claude/settings.json" }

    var statusBlurb: String {
        switch detectStatus() {
        case .toolNotInstalled:        return L10n.t("Not installed", "未安装")
        case .toolPresentHookMissing:  return L10n.t("Installed — Lights hook missing", "已安装 — 缺少 Lights Hook")
        case .configured:              return L10n.t("Hooks configured ✓", "Hooks 已配置 ✓")
        case .unknown(let why):        return L10n.t("Error: \(why)", "错误：\(why)")
        }
    }

    func detectStatus() -> InstallStatus {
        let fm = FileManager.default
        let hasSettings = fm.fileExists(atPath: settingsPath)
        let hasCLI = isCommandAvailable("claude")

        guard hasSettings || hasCLI else { return .toolNotInstalled }

        if hasSettings {
            do {
                let dict = try JSONHookMerger.readJSON(settingsPath)
                if JSONHookMerger.containsAnyHook(dict,
                    fragments: JSONHookMerger.lightsCommandFragments) {
                    return .configured
                }
            } catch {
                return .unknown(error.localizedDescription)
            }
        }
        return .toolPresentHookMissing
    }

    func install() throws {
        let fm = FileManager.default
        let dir = "\(NSHomeDirectory())/.claude"
        if !fm.fileExists(atPath: dir) {
            try fm.createDirectory(atPath: dir, withIntermediateDirectories: true)
        }
        _ = try JSONHookMerger.backup(settingsPath)
        var dict = try JSONHookMerger.readJSON(settingsPath)
        JSONHookMerger.merge(into: &dict, specs: JSONHookMerger.lightsHookSpecs)
        try JSONHookMerger.writeJSON(dict, to: settingsPath)
    }

    func uninstall() throws {
        _ = try JSONHookMerger.backup(settingsPath)
        var dict = try JSONHookMerger.readJSON(settingsPath)
        JSONHookMerger.removeMatching(&dict,
            fragments: JSONHookMerger.lightsCommandFragments)
        try JSONHookMerger.writeJSON(dict, to: settingsPath)
    }
}
