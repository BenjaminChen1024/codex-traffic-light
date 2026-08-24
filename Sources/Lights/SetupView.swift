import SwiftUI
import AppKit

struct SetupView: View {
    @ObservedObject var mgr: SetupManager = .shared
    @AppStorage("appLanguage") private var appLanguage: AppLanguage = .english
    var onDone: () -> Void = {}

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            intro
            toolList
            Spacer(minLength: 0)
            footer
        }
        .frame(width: 500, height: 380)
        .onAppear { mgr.refreshAll() }
    }

    private var header: some View {
        HStack {
            Text(L10n.t("Lights Setup", "Lights 配置"))
                .font(.title2.bold())
            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.top, 16)
        .padding(.bottom, 10)
    }

    private var intro: some View {
        Text(L10n.t("Connect Lights to your AI coding tools. Lights must be running for hooks to reach it.", "将 Lights 连接到 AI 编程工具。Lights 必须保持运行，Hooks 才能更新状态。"))
            .font(.callout)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 20)
            .padding(.top, 12)
            .padding(.bottom, 12)
    }

    private var toolList: some View {
        VStack(spacing: 6) {
            ForEach(mgr.tools) { state in
                ToolRow(state: state, mgr: mgr)
            }
        }
        .padding(.horizontal, 20)
    }

    private var footer: some View {
        HStack {
            Text(L10n.t("Backups saved beside the config files.", "备份会保存在配置文件旁。"))
                .font(.caption)
                .foregroundStyle(.tertiary)
            Spacer()
            Button(L10n.t("Refresh", "刷新")) { mgr.refreshAll() }
            Button(L10n.t("Done", "完成")) {
                SetupManager.markSetupSeen()
                onDone()
            }
            .keyboardShortcut(.defaultAction)
        }
        .padding(20)
    }
}

private struct ToolRow: View {
    @ObservedObject var state: ToolIntegrationState
    let mgr: SetupManager

    var body: some View {
        HStack(spacing: 12) {
            badge.frame(width: 12)

            VStack(alignment: .leading, spacing: 2) {
                Text(state.tool.displayName).font(.body.weight(.medium))
                Text(state.tool.statusBlurb)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                if let err = state.lastError {
                    Text(err)
                        .font(.caption2)
                        .foregroundStyle(.red)
                        .lineLimit(2)
                }
                if let success = mgr.lastSuccess[state.id] {
                    Text(success)
                        .font(.caption2)
                        .foregroundStyle(.green)
                        .lineLimit(2)
                }
            }

            Spacer()
            actionButton
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(NSColor.controlBackgroundColor).opacity(0.4))
        )
    }

    @ViewBuilder
    private var badge: some View {
        switch state.status {
        case .configured:             dot(.green)
        case .toolPresentHookMissing: dot(.orange)
        case .toolNotInstalled:       dot(.gray)
        case .unknown:                dot(.red)
        }
    }

    private func dot(_ color: Color) -> some View {
        Circle().fill(color).frame(width: 10, height: 10)
    }

    @ViewBuilder
    private var actionButton: some View {
        if state.tool.id == "codex-desktop" {
            Button(L10n.t("Configure", "配置")) { mgr.install(state) }
                .buttonStyle(.borderedProminent)
        } else {
            switch (state.tool.supportLevel, state.status) {
            case (.notSupported, _):
                Text("N/A").font(.caption).foregroundStyle(.tertiary)
            case (.comingSoon, _):
                Text("v2").font(.caption).foregroundStyle(.tertiary)
            case (.events, .toolNotInstalled):
                Text("—").font(.caption).foregroundStyle(.tertiary)
            case (.events, .toolPresentHookMissing):
                Button(L10n.t("Install", "安装")) { mgr.install(state) }
                    .buttonStyle(.borderedProminent)
            case (.events, .configured):
                Button(L10n.t("Uninstall", "移除")) { mgr.uninstall(state) }
            case (.events, .unknown):
                Button(L10n.t("Retry", "重试")) { state.refresh() }
            }
        }
    }
}
