import AppKit
import ApplicationServices

/// Read-only monitor for Codex Desktop's visible accessibility state.
/// It never performs accessibility actions or records conversation content.
final class CodexDesktopAccessibilityMonitor {
    private var timer: Timer?
    private var lastState: LightsState?

    /// Codex Desktop can be distributed standalone or inside the ChatGPT macOS app.
    private let knownBundleIDs: Set<String> = [
        "com.openai.codex",
        "ai.openai.codex",
        "com.openai.chat"
    ]

    func start() {
        requestAccessibilityPermissionIfNeeded()
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.poll()
        }
        poll()
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    private func requestAccessibilityPermissionIfNeeded() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
    }

    private func poll() {
        guard AXIsProcessTrusted(), let app = codexApplication() else { return }
        let element = AXUIElementCreateApplication(app.processIdentifier)
        let snapshot = accessibilitySnapshot(from: element)
        guard let state = classify(snapshot: snapshot) else { return }
        guard state != lastState else { return }
        lastState = state
        NotificationCenter.default.post(
            name: .lightsStateChange,
            object: nil,
            userInfo: ["state": state.rawValue]
        )
    }

    private func codexApplication() -> NSRunningApplication? {
        NSWorkspace.shared.runningApplications.first { app in
            if let bundleID = app.bundleIdentifier, knownBundleIDs.contains(bundleID) {
                return true
            }
            return app.localizedName?.localizedCaseInsensitiveContains("Codex") == true
        }
    }

    private struct AccessibilitySnapshot {
        let text: String
        let isBusy: Bool
    }

    private func accessibilitySnapshot(from root: AXUIElement) -> AccessibilitySnapshot {
        var pending = [root]
        var visited = 0
        var fragments = [String]()
        var isBusy = false

        // A bounded traversal keeps polling lightweight even for a large chat history.
        while !pending.isEmpty && visited < 240 {
            let element = pending.removeFirst()
            visited += 1

            for attribute in [kAXTitleAttribute, kAXDescriptionAttribute, kAXValueAttribute, kAXHelpAttribute] {
                var value: CFTypeRef?
                if AXUIElementCopyAttributeValue(element, attribute as CFString, &value) == .success,
                   let string = value as? String, !string.isEmpty {
                    fragments.append(string)
                }
            }

            var busyValue: CFTypeRef?
            if AXUIElementCopyAttributeValue(element, "AXBusy" as CFString, &busyValue) == .success,
               let busy = busyValue as? Bool, busy {
                isBusy = true
            }

            var children: CFTypeRef?
            if AXUIElementCopyAttributeValue(element, kAXChildrenAttribute as CFString, &children) == .success,
               let childElements = children as? [AXUIElement] {
                pending.append(contentsOf: childElements)
            }
        }
        return AccessibilitySnapshot(text: fragments.joined(separator: " ").lowercased(), isBusy: isBusy)
    }

    private func classify(snapshot: AccessibilitySnapshot) -> LightsState? {
        let text = snapshot.text
        // Explicit requests always take priority over an otherwise busy interface.
        let waitingMarkers = [
            "request approval", "needs your approval", "waiting for your input",
            "requires your input", "approve", "allow", "permission",
            "需要你的批准", "需要批准", "等待你的输入", "需要你的输入",
            "批准", "允许", "权限"
        ]
        if waitingMarkers.contains(where: text.contains) { return .permission }

        let workingMarkers = [
            "working", "thinking", "generating", "running", "executing",
            "in progress", "stop generating", "stop",
            "正在工作", "正在思考", "正在生成", "正在运行", "正在执行", "处理中", "停止"
        ]
        if snapshot.isBusy || workingMarkers.contains(where: text.contains) { return .executing }

        // A reachable Codex window with no active marker is treated as ready.
        return .idle
    }
}
