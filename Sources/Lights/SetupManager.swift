import Foundation
import SwiftUI

final class ToolIntegrationState: ObservableObject, Identifiable {
    let tool: ToolIntegration
    @Published var status: InstallStatus = .toolNotInstalled
    @Published var lastError: String?

    var id: String { tool.id }

    init(tool: ToolIntegration) {
        self.tool = tool
    }

    @MainActor
    func refresh() {
        status = tool.detectStatus()
    }
}

@MainActor
final class SetupManager: ObservableObject {
    static let shared = SetupManager()
    @Published var tools: [ToolIntegrationState]
    @Published var lastSuccess: [String: String] = [:]

    private init() {
        let initial = [
            ToolIntegrationState(tool: ClaudeCodeIntegration()),
            ToolIntegrationState(tool: CodexIntegration()),
            ToolIntegrationState(tool: CodexDesktopIntegration()),
            ToolIntegrationState(tool: OpenCodeIntegration()),
        ]
        for s in initial { s.status = s.tool.detectStatus() }
        tools = initial
    }

    func refreshAll() {
        for t in tools { t.refresh() }
    }

    func install(_ state: ToolIntegrationState) {
        state.lastError = nil
        lastSuccess[state.id] = nil
        do {
            try state.tool.install()
            state.refresh()
            if state.tool.id == "codex-desktop" {
                lastSuccess[state.id] = L10n.t("Configured. Restart Codex to apply.", "已配置，请重启 Codex 生效。")
            } else {
                lastSuccess[state.id] = L10n.t("Configured successfully.", "配置成功。")
            }
        } catch {
            state.lastError = error.localizedDescription
        }
    }

    func uninstall(_ state: ToolIntegrationState) {
        state.lastError = nil
        lastSuccess[state.id] = nil
        do {
            try state.tool.uninstall()
            state.refresh()
        } catch {
            state.lastError = error.localizedDescription
        }
    }

    // MARK: - First-launch flag

    private static var seenFlagPath: String {
        let support = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return support.appendingPathComponent("Lights/seen-setup.flag").path
    }

    static var hasSeenSetup: Bool {
        FileManager.default.fileExists(atPath: seenFlagPath)
    }

    static func markSetupSeen() {
        let path = seenFlagPath
        let dir = (path as NSString).deletingLastPathComponent
        try? FileManager.default.createDirectory(
            atPath: dir, withIntermediateDirectories: true
        )
        FileManager.default.createFile(atPath: path, contents: nil)
    }
}
