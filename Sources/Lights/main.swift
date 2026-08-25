import SwiftUI
import AppKit

extension Notification.Name {
    static let lightsResize = Notification.Name("LightsResize")
}

enum LightsLayout: String, CaseIterable, Identifiable {
    case vertical, horizontal
    var id: String { rawValue }
    var label: String { self == .vertical ? L10n.t("Vertical", "纵向") : L10n.t("Horizontal", "横向") }
}

enum LightsSize: String, CaseIterable, Identifiable {
    case small, medium, large, extraLarge, huge
    var id: String { rawValue }

    var bulb: CGFloat   { switch self { case .small: 16; case .medium: 22; case .large: 28; case .extraLarge: 34; case .huge: 40 } }
    var spacing: CGFloat { switch self { case .small: 6;  case .medium: 8;  case .large: 10; case .extraLarge: 12; case .huge: 14 } }
    var padding: CGFloat { switch self { case .small: 7;  case .medium: 9;  case .large: 11; case .extraLarge: 13; case .huge: 15 } }
    var corner: CGFloat  { switch self { case .small: 12; case .medium: 15; case .large: 18; case .extraLarge: 21; case .huge: 24 } }
    var socket: CGFloat { bulb + 8 }
    // Keep glow inside the housing padding so edge bulbs do not create a clipped halo.
    var glowOuter: CGFloat { bulb * 0.18 }
    var glowFar:   CGFloat { bulb * 0.35 }
    var highlightInset: CGFloat { bulb / 18 + 1 }
    var label: String { switch self { case .small: L10n.t("Small", "小"); case .medium: L10n.t("Medium", "中"); case .large: L10n.t("Large", "大"); case .extraLarge: L10n.t("Extra Large", "特大"); case .huge: L10n.t("Huge", "超大") } }
    var statusBarScale: CGFloat { switch self { case .small: 0.85; case .medium: 1.05; case .large: 1.25; case .extraLarge: 1.45; case .huge: 1.65 } }

    func windowSize(for layout: LightsLayout) -> NSSize {
        switch layout {
        case .vertical:
            NSSize(width: socket + 2 * padding,
                   height: 3 * socket + 2 * spacing + 2 * padding)
        case .horizontal:
            NSSize(width: 3 * socket + 2 * spacing + 2 * padding,
                   height: socket + 2 * padding)
        }
    }
}

// MARK: - Entry

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
setupMainMenu(app: app)
app.run()

func setupMainMenu(app: NSApplication) {
    let main = NSMenu()
    let appItem = NSMenuItem()
    main.addItem(appItem)

    let appMenu = NSMenu()
    appMenu.addItem(NSMenuItem(
        title: "About Lights",
        action: #selector(NSApplication.orderFrontStandardAboutPanel(_:)),
        keyEquivalent: ""
    ))
    appMenu.addItem(.separator())
    appMenu.addItem(NSMenuItem(
        title: "Hide Lights",
        action: #selector(NSApplication.hide(_:)),
        keyEquivalent: "h"
    ))
    appMenu.addItem(.separator())
    appMenu.addItem(NSMenuItem(
        title: "Quit Lights",
        action: #selector(NSApplication.terminate(_:)),
        keyEquivalent: "q"
    ))
    appItem.submenu = appMenu

    app.mainMenu = main
}

// MARK: - App Delegate

final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    var window: NSWindow!
    var setupWindow: NSPanel?
    let statusServer = StatusServer()
    let menuBar = MenuBarController()

    func applicationDidFinishLaunching(_ notification: Notification) {
        // LSUIElement=true in Info.plist already hides Dock.
        // Belt-and-suspenders for builds run without the bundle:
        NSApp.setActivationPolicy(.accessory)
        statusServer.start()
        menuBar.install()

        let storedRaw = UserDefaults.standard.string(forKey: "lightsSize") ?? LightsSize.large.rawValue
        let initialSize = LightsSize(rawValue: storedRaw) ?? .large
        let storedLayout = UserDefaults.standard.string(forKey: "lightsLayout") ?? LightsLayout.vertical.rawValue
        let initialLayout = LightsLayout(rawValue: storedLayout) ?? .vertical
        let legacyDisplayMode = UserDefaults.standard.string(forKey: "lightsDisplayMode")
        let initialFloatingVisible = UserDefaults.standard.object(forKey: "lightsFloatingVisible") as? Bool
            ?? (legacyDisplayMode != "menuBar")
        let size = initialSize.windowSize(for: initialLayout)
        // NSScreen.main can be nil for LSUIElement apps at launch (no key window).
        // Fall back to the first screen in the list (system primary).
        let screenObj = NSScreen.main ?? NSScreen.screens.first
        let screen = screenObj?.visibleFrame ?? CGRect(x: 0, y: 0, width: 1440, height: 900)
        let origin = NSPoint(
            x: screen.maxX - size.width - 24,
            y: screen.maxY - size.height - 24
        )
        NSLog("[Lights] Placing window at \(origin) size \(size) on screen \(screen)")

        let win = FloatingWindow(
            contentRect: NSRect(origin: origin, size: size),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        win.level = .floating
        win.isMovableByWindowBackground = true
        win.backgroundColor = .clear
        win.isOpaque = false
        win.hasShadow = true
        win.collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary]
        win.contentView = NSHostingView(rootView: ContentView())
        if initialFloatingVisible {
            win.makeKeyAndOrderFront(nil)
        } else {
            win.orderOut(nil)
        }

        self.window = win
        if initialFloatingVisible {
            NSApp.activate(ignoringOtherApps: true)
        }

        NotificationCenter.default.addObserver(
            forName: .lightsResize, object: nil, queue: .main
        ) { [weak self] note in
            self?.applyResize(note)
        }
        NotificationCenter.default.addObserver(
            forName: .lightsShowSetup, object: nil, queue: .main
        ) { [weak self] _ in
            self?.showSetupPanel()
        }
        NotificationCenter.default.addObserver(
            forName: .lightsSetDisplayMode, object: nil, queue: .main
        ) { [weak self] note in
            guard let visible = note.userInfo?["visible"] as? Bool else { return }
            self?.setFloatingVisibility(visible)
        }

        // First-launch: auto-open Setup
        if !SetupManager.hasSeenSetup {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { [weak self] in
                self?.showSetupPanel()
            }
        }
    }

    private func setFloatingVisibility(_ visible: Bool) {
        guard let win = window else { return }
        if visible {
            win.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
        } else {
            win.orderOut(nil)
        }
    }

    private func showSetupPanel() {
        // Temporarily switch to regular activation so the window can take focus
        // and receive button clicks. Restored to .accessory on window close.
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)

        if let panel = setupWindow {
            panel.makeKeyAndOrderFront(nil)
            return
        }
        let view = SetupView(onDone: { [weak self] in
            self?.setupWindow?.close()
        })
        let hosting = NSHostingView(rootView: view)
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 500, height: 380),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        panel.title = "Lights Setup"
        panel.titleVisibility = .hidden     // hide title text (we have header inside)
        panel.titlebarAppearsTransparent = true
        panel.contentView = hosting
        panel.center()
        panel.isReleasedWhenClosed = false
        panel.hidesOnDeactivate = false     // don't auto-hide when user clicks elsewhere
        panel.delegate = self
        panel.makeKeyAndOrderFront(nil)
        setupWindow = panel
    }

    private func applyResize(_ note: Notification) {
        guard let win = window,
              let width  = note.userInfo?["width"]  as? CGFloat,
              let height = note.userInfo?["height"] as? CGFloat else { return }
        var frame = win.frame
        let oldTop = frame.maxY
        let oldRight = frame.maxX
        frame.size = NSSize(width: width, height: height)
        frame.origin.y = oldTop - height
        frame.origin.x = oldRight - width
        win.setFrame(frame, display: true, animate: true)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        // Menu bar agent stays alive even when no windows are open.
        false
    }

    // NSWindowDelegate
    func windowWillClose(_ notification: Notification) {
        if let panel = notification.object as? NSPanel, panel === setupWindow {
            SetupManager.markSetupSeen()
            setupWindow = nil
            // Return to accessory mode (no Dock icon) once setup window closes.
            DispatchQueue.main.async {
                NSApp.setActivationPolicy(.accessory)
            }
        }
    }
}

final class FloatingWindow: NSWindow {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}

// MARK: - Content

enum Light: Hashable { case red, yellow, green }

struct ContentView: View {
    @State private var active: Light? = .green
    @State private var yellowStickyUntil: Date = .distantPast
    @State private var greenFlashVisible = true
    @State private var greenFlashGeneration = 0
    @AppStorage("lightsSize") private var size: LightsSize = .large
    @AppStorage("lightsLayout") private var layout: LightsLayout = .vertical
    @AppStorage("statusBarSize") private var statusBarSize: LightsSize = .large
    @AppStorage("statusBarBackground") private var statusBarBackground: StatusBarBackground = .black
    @AppStorage("greenLightAlert") private var greenAlert: GreenLightAlert = .three
    @AppStorage("greenAlertSpeed") private var alertSpeed: GreenAlertSpeed = .seconds08
    @AppStorage("appLanguage") private var appLanguage: AppLanguage = .english
    @ObservedObject private var launchAtLogin = LaunchAtLoginManager.shared

    var body: some View {
        Group {
            if layout == .vertical {
                VStack(spacing: size.spacing) {
                    lights
                }
            } else {
                HStack(spacing: size.spacing) {
                    lights
                }
            }
        }
        .padding(size.padding)
        .background(housing)
        .contextMenu {
            Toggle(L10n.t("Show Light", "显示悬浮灯"), isOn: Binding(
                get: { UserDefaults.standard.object(forKey: "lightsFloatingVisible") as? Bool ?? true },
                set: { visible in
                    UserDefaults.standard.set(visible, forKey: "lightsFloatingVisible")
                    NotificationCenter.default.post(
                        name: .lightsSetDisplayMode, object: nil,
                        userInfo: ["visible": visible]
                    )
                }
            ))
            Divider()
            Menu(L10n.t("Size", "大小")) {
                Menu(L10n.t("Floating Light", "悬浮灯")) {
                    ForEach(LightsSize.allCases) { opt in
                        Button {
                            size = opt
                        } label: {
                            HStack {
                                Text(opt.label)
                                if size == opt { Spacer(); Image(systemName: "checkmark") }
                            }
                        }
                    }
                }
                Menu(L10n.t("Status Bar", "状态栏")) {
                    ForEach(LightsSize.allCases) { opt in
                        Button {
                            statusBarSize = opt
                        } label: {
                            HStack {
                                Text(opt.label)
                                if statusBarSize == opt { Spacer(); Image(systemName: "checkmark") }
                            }
                        }
                    }
                }
            }
            Menu(L10n.t("Layout", "布局")) {
                ForEach(LightsLayout.allCases) { opt in
                    Button {
                        layout = opt
                    } label: {
                        HStack {
                            Text(opt.label)
                            if layout == opt { Spacer(); Image(systemName: "checkmark") }
                        }
                    }
                }
            }
            Menu(L10n.t("Status Bar Background", "状态栏背景")) {
                ForEach(StatusBarBackground.allCases, id: \.rawValue) { opt in
                    Button {
                        statusBarBackground = opt
                    } label: {
                        HStack {
                            Text(opt.label)
                            if statusBarBackground == opt { Spacer(); Image(systemName: "checkmark") }
                        }
                    }
                }
            }
            Menu(L10n.t("Green Light Alert", "绿灯提醒")) {
                Menu(L10n.t("Flash Interval", "闪烁间隔")) {
                    ForEach(GreenAlertSpeed.allCases, id: \.rawValue) { opt in
                        Button {
                            alertSpeed = opt
                        } label: {
                            HStack {
                                Text(opt.label)
                                if alertSpeed == opt { Spacer(); Image(systemName: "checkmark") }
                            }
                        }
                    }
                }
                Divider()
                ForEach(GreenLightAlert.allCases, id: \.rawValue) { opt in
                    Button {
                        greenAlert = opt
                    } label: {
                        HStack {
                            Text(opt.label)
                            if greenAlert == opt { Spacer(); Image(systemName: "checkmark") }
                        }
                    }
                }
            }
            Divider()
            Button(L10n.t("Setup Hooks…", "配置 Hooks…")) {
                NotificationCenter.default.post(name: .lightsShowSetup, object: nil)
            }
            Toggle(L10n.t("Launch Lights at Login", "登录时启动 Lights"), isOn: Binding(
                get: { launchAtLogin.isEnabled },
                set: { launchAtLogin.setEnabled($0) }
            ))
            Menu("Language / 语言") {
                ForEach(AppLanguage.allCases) { language in
                    Button {
                        appLanguage = language
                    } label: {
                        HStack {
                            Text(language.label)
                            if appLanguage == language { Spacer(); Image(systemName: "checkmark") }
                        }
                    }
                }
            }
            Divider()
            Button(L10n.t("Quit Lights", "退出 Lights")) { NSApp.terminate(nil) }
        }
        .onReceive(NotificationCenter.default.publisher(for: .lightsStateChange)) { note in
            guard let raw = note.userInfo?["state"] as? String else { return }
            handleSignal(raw)
        }
        .onReceive(NotificationCenter.default.publisher(for: .lightsRequestOff)) { _ in
            setActive(nil)
        }
        .onReceive(NotificationCenter.default.publisher(for: .lightsGreenFlash)) { _ in
            startGreenFlash()
        }
        .onChange(of: size) { _, newSize in
            let dim = newSize.windowSize(for: layout)
            NotificationCenter.default.post(
                name: .lightsResize, object: nil,
                userInfo: ["width": dim.width, "height": dim.height]
            )
        }
        .onChange(of: layout) { _, newLayout in
            let dim = size.windowSize(for: newLayout)
            NotificationCenter.default.post(
                name: .lightsResize, object: nil,
                userInfo: ["width": dim.width, "height": dim.height]
            )
        }
    }

    @ViewBuilder
    private var lights: some View {
        LightView(palette: .red,    isOn: active == .red,    size: size)
        LightView(palette: .yellow, isOn: active == .yellow, size: size)
        LightView(palette: .green,  isOn: active == .green && greenFlashVisible, size: size)
    }

    private func handleSignal(_ raw: String) {
        let target: Light?
        switch raw {
        case "executing":  target = .red
        case "permission": target = .yellow
        case "idle":       target = .green
        case "off":        target = nil
        default: return
        }

        // Yellow is sticky briefly — guards against true ms-scale races
        // where /executing arrives right after /permission. Short enough
        // that intentional transitions (e.g. PostToolUse after the user
        // answers an AskUserQuestion) still take effect.
        if active == .yellow, target == .red, Date() < yellowStickyUntil {
            return
        }
        if target == .yellow {
            yellowStickyUntil = Date().addingTimeInterval(0.2)
        }
        if target != .green {
            cancelGreenFlash()
        }
        setActive(target)
    }

    private var housing: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size.corner, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.18, green: 0.18, blue: 0.20),
                            Color(red: 0.07, green: 0.07, blue: 0.09)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
            RoundedRectangle(cornerRadius: size.corner, style: .continuous)
                .strokeBorder(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.20),
                            Color.white.opacity(0.03)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    ),
                    lineWidth: 1
                )
        }
    }

    private func setActive(_ light: Light?) {
        withAnimation(.spring(response: 0.28, dampingFraction: 0.7)) {
            active = light
        }
    }

    private func cancelGreenFlash() {
        greenFlashGeneration += 1
        greenFlashVisible = true
    }

    private func startGreenFlash() {
        guard active == .green else { return }
        greenFlashGeneration += 1
        let generation = greenFlashGeneration
        Task { @MainActor in
            for _ in 0..<greenAlert.count {
                guard generation == greenFlashGeneration else { return }
                withAnimation(.easeInOut(duration: min(Double(alertSpeed.halfCycleNanoseconds) / 2_000_000_000, 0.25))) { greenFlashVisible = false }
                try? await Task.sleep(nanoseconds: alertSpeed.halfCycleNanoseconds)
                guard generation == greenFlashGeneration else { return }
                withAnimation(.easeInOut(duration: min(Double(alertSpeed.halfCycleNanoseconds) / 2_000_000_000, 0.25))) { greenFlashVisible = true }
                try? await Task.sleep(nanoseconds: alertSpeed.halfCycleNanoseconds)
            }
        }
    }
}

// MARK: - Single Light

struct LightPalette {
    let bright: Color
    let base: Color
    let dark: Color
    let glow: Color
    let dimBright: Color
    let dimBase: Color
    let dimDark: Color

    static let red = LightPalette(
        bright:    Color(red: 1.00, green: 0.50, blue: 0.50),
        base:      Color(red: 0.98, green: 0.28, blue: 0.28),
        dark:      Color(red: 0.70, green: 0.10, blue: 0.10),
        glow:      Color(red: 1.00, green: 0.30, blue: 0.30),
        dimBright: Color(red: 0.46, green: 0.20, blue: 0.20),
        dimBase:   Color(red: 0.28, green: 0.12, blue: 0.12),
        dimDark:   Color(red: 0.16, green: 0.07, blue: 0.07)
    )

    static let yellow = LightPalette(
        bright:    Color(red: 1.00, green: 0.95, blue: 0.50),
        base:      Color(red: 1.00, green: 0.80, blue: 0.20),
        dark:      Color(red: 0.78, green: 0.55, blue: 0.05),
        glow:      Color(red: 1.00, green: 0.82, blue: 0.25),
        dimBright: Color(red: 0.46, green: 0.40, blue: 0.18),
        dimBase:   Color(red: 0.28, green: 0.24, blue: 0.10),
        dimDark:   Color(red: 0.16, green: 0.14, blue: 0.06)
    )

    static let green = LightPalette(
        bright:    Color(red: 0.55, green: 1.00, blue: 0.60),
        base:      Color(red: 0.25, green: 0.88, blue: 0.42),
        dark:      Color(red: 0.06, green: 0.55, blue: 0.20),
        glow:      Color(red: 0.30, green: 0.92, blue: 0.45),
        dimBright: Color(red: 0.18, green: 0.40, blue: 0.22),
        dimBase:   Color(red: 0.09, green: 0.24, blue: 0.13),
        dimDark:   Color(red: 0.05, green: 0.14, blue: 0.08)
    )
}

struct LightView: View {
    let palette: LightPalette
    let isOn: Bool
    let size: LightsSize

    var body: some View {
        ZStack {
            // Socket (the dark well the bulb sits in)
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            Color.black.opacity(0.85),
                            Color.black.opacity(0.40)
                        ],
                        center: .center,
                        startRadius: 0,
                        endRadius: size.socket / 2 + 2
                    )
                )
                .frame(width: size.socket, height: size.socket)
                .overlay(
                    Circle().strokeBorder(Color.black.opacity(0.6), lineWidth: 0.5)
                )
                .shadow(color: .black.opacity(0.6), radius: 1.5, x: 0, y: 1)

            // The bulb itself
            Circle()
                .fill(
                    RadialGradient(
                        colors: isOn
                            ? [palette.bright, palette.base, palette.dark]
                            : [palette.dimBright, palette.dimBase, palette.dimDark],
                        center: UnitPoint(x: 0.35, y: 0.30),
                        startRadius: 0.5,
                        endRadius: size.bulb * 0.65
                    )
                )
                .frame(width: size.bulb, height: size.bulb)
                .overlay(
                    // Specular glassy highlight
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(isOn ? 0.55 : 0.15),
                                    Color.white.opacity(0)
                                ],
                                startPoint: .topLeading,
                                endPoint: UnitPoint(x: 0.65, y: 0.55)
                            )
                        )
                        .padding(size.highlightInset)
                        .blur(radius: 0.4)
                )
                .shadow(color: isOn ? palette.glow.opacity(0.85) : .clear, radius: size.glowOuter)
                .shadow(color: isOn ? palette.glow.opacity(0.45) : .clear, radius: size.glowFar)
        }
    }
}
