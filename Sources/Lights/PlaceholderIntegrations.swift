import Foundation

final class OpenCodeIntegration: ToolIntegration {
    let id = "opencode"
    let displayName = "OpenCode"
    let supportLevel: SupportLevel = .notSupported

    var statusBlurb: String {
        isCommandAvailable("opencode")
            ? L10n.t("Installed — OpenCode has no event hooks", "已安装 — OpenCode 不支持事件 Hooks")
            : L10n.t("Not installed", "未安装")
    }

    func detectStatus() -> InstallStatus {
        isCommandAvailable("opencode") ? .toolPresentHookMissing : .toolNotInstalled
    }

    func install() throws   { throw ToolIntegrationError.notImplemented("OpenCode") }
    func uninstall() throws { throw ToolIntegrationError.notImplemented("OpenCode") }
}
