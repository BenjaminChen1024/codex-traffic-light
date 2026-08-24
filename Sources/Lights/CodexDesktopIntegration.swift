import Foundation

/// Desktop Codex uses the same user-level hook file as the CLI, but does not
/// depend on the `codex` shell command being installed or present in PATH.
final class CodexDesktopIntegration: ToolIntegration {
    let id = "codex-desktop"
    let displayName = "Codex Desktop"
    let supportLevel: SupportLevel = .events

    private var hooksPath: String { "\(NSHomeDirectory())/.codex/hooks.json" }
    private var configPath: String { "\(NSHomeDirectory())/.codex/config.toml" }
    private var dir: String { "\(NSHomeDirectory())/.codex" }

    private let specs: [HookSpec] = [
        HookSpec(event: "UserPromptSubmit", matcher: nil,
                 command: JSONHookMerger.lightsCommand("executing"), timeout: 2000),
        HookSpec(event: "PreToolUse", matcher: "*",
                 command: JSONHookMerger.lightsCommand("executing"), timeout: 2000),
        HookSpec(event: "PostToolUse", matcher: "*",
                 command: JSONHookMerger.lightsCommand("executing"), timeout: 2000),
        HookSpec(event: "Stop", matcher: nil,
                 command: JSONHookMerger.lightsCommand("idle"), timeout: 2000),
        HookSpec(event: "PreToolUse", matcher: "AskUserQuestion|ExitPlanMode",
                 command: JSONHookMerger.lightsCommand("permission"), timeout: 2000),
    ]

    var statusBlurb: String {
        switch detectStatus() {
        case .toolNotInstalled: return L10n.t("Codex data folder not found", "未找到 Codex 数据文件夹")
        case .toolPresentHookMissing: return L10n.t("Ready for one-click configuration", "可一键配置")
        case .configured: return L10n.t("Desktop hooks configured ✓", "桌面端 Hooks 已配置 ✓")
        case .unknown(let why): return L10n.t("Error: \(why)", "错误：\(why)")
        }
    }

    func detectStatus() -> InstallStatus {
        let fm = FileManager.default
        guard fm.fileExists(atPath: dir) else { return .toolNotInstalled }
        guard fm.fileExists(atPath: hooksPath) else { return .toolPresentHookMissing }
        do {
            let settings = try JSONHookMerger.readJSON(hooksPath)
            return JSONHookMerger.containsAllHooks(settings, specs: specs)
                ? .configured
                : .toolPresentHookMissing
        } catch {
            return .unknown(error.localizedDescription)
        }
    }

    func install() throws {
        let fm = FileManager.default
        if !fm.fileExists(atPath: dir) {
            try fm.createDirectory(atPath: dir, withIntermediateDirectories: true)
        }
        _ = try JSONHookMerger.backup(hooksPath)
        var settings = try JSONHookMerger.readJSON(hooksPath)
        JSONHookMerger.merge(into: &settings, specs: specs)
        try JSONHookMerger.writeJSON(settings, to: hooksPath)
        try ensureHooksFeatureEnabled()
    }

    func uninstall() throws {
        // The desktop panel deliberately provides only a safe configure action.
    }

    private func ensureHooksFeatureEnabled() throws {
        let fm = FileManager.default
        var content = ""
        if fm.fileExists(atPath: configPath) {
            content = (try? String(contentsOfFile: configPath, encoding: .utf8)) ?? ""
        }
        if content.range(of: #"features\.hooks\s*=\s*true"#, options: .regularExpression) != nil {
            return
        }
        if content.contains("[features]"),
           content.range(of: #"(?m)^\s*hooks\s*=\s*true"#, options: .regularExpression) != nil {
            return
        }
        _ = try? JSONHookMerger.backup(configPath)
        if !content.isEmpty && !content.hasSuffix("\n") { content += "\n" }
        content += "\n# Lights: enable lifecycle hooks subsystem\nfeatures.hooks = true\n"
        try content.write(toFile: configPath, atomically: true, encoding: .utf8)
    }
}
