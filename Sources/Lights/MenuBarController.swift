import AppKit

enum StatusBarBackground: String, CaseIterable {
    case black, transparent
    var label: String { self == .black ? L10n.t("Black", "黑色") : L10n.t("Transparent", "透明") }
}

enum GreenLightAlert: String, CaseIterable {
    case never, once, three, five, ten
    var count: Int { switch self { case .never: 0; case .once: 1; case .three: 3; case .five: 5; case .ten: 10 } }
    var label: String { switch self { case .never: L10n.t("Never", "不闪烁"); case .once: L10n.t("Flash Once", "闪烁 1 次"); case .three: L10n.t("Flash 3 Times", "闪烁 3 次"); case .five: L10n.t("Flash 5 Times", "闪烁 5 次"); case .ten: L10n.t("Flash 10 Times", "闪烁 10 次") } }
}

enum GreenAlertSpeed: String, CaseIterable {
    case fast, normal, slow
    var label: String { switch self { case .fast: L10n.t("Fast", "快"); case .normal: L10n.t("Normal", "普通"); case .slow: L10n.t("Slow", "慢") } }
    var halfCycleNanoseconds: UInt64 {
        switch self {
        case .fast: 160_000_000
        case .normal: 300_000_000
        case .slow: 500_000_000
        }
    }
}

extension Notification.Name {
    static let lightsShowSetup    = Notification.Name("LightsShowSetup")
    static let lightsRequestOff   = Notification.Name("LightsRequestOff")
    static let lightsSetSize      = Notification.Name("LightsSetSize")
    static let lightsSetLayout    = Notification.Name("LightsSetLayout")
    static let lightsSetDisplayMode = Notification.Name("LightsSetDisplayMode")
}

final class MenuBarController: NSObject, NSMenuDelegate {
    private var statusItem: NSStatusItem?
    private var currentState: LightsState = .idle
    private var greenFlashGeneration = 0
    private let launchAtLogin = LaunchAtLoginManager.shared

    func install() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let btn = item.button {
            btn.image = Self.renderStatusIcon(state: currentState, layout: currentLayout, size: currentStatusSize, background: currentBackground)
            btn.imagePosition = .imageOnly
            btn.imageScaling = .scaleProportionallyDown
        }
        item.isVisible = true
        let menu = NSMenu()
        menu.delegate = self
        menu.autoenablesItems = false
        rebuild(menu: menu)
        item.menu = menu
        statusItem = item
        NotificationCenter.default.addObserver(
            self, selector: #selector(handleStateChange(_:)),
            name: .lightsStateChange, object: nil
        )
        NotificationCenter.default.addObserver(
            self, selector: #selector(handleGreenFlash),
            name: .lightsGreenFlash, object: nil
        )
        NotificationCenter.default.addObserver(
            self, selector: #selector(handleLayoutChange),
            name: .lightsSetLayout, object: nil
        )
        NotificationCenter.default.addObserver(
            self, selector: #selector(handleLayoutChange),
            name: UserDefaults.didChangeNotification, object: UserDefaults.standard
        )
        NSLog("[Lights] StatusItem isVisible=\(item.isVisible) length=\(item.length)")
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        rebuild(menu: menu)
    }

    private func rebuild(menu: NSMenu) {
        menu.removeAllItems()

        let floatingItem = item(L10n.t("Show Light", "显示悬浮灯"), #selector(actionToggleFloating))
        floatingItem.state = isFloatingVisible ? .on : .off
        menu.addItem(floatingItem)
        menu.addItem(.separator())

        let sizeItem = NSMenuItem(title: L10n.t("Size", "大小"), action: nil, keyEquivalent: "")
        let sizeMenu = NSMenu()
        let floatingSizeItem = NSMenuItem(title: L10n.t("Floating Light", "悬浮灯"), action: nil, keyEquivalent: "")
        let floatingSizeMenu = NSMenu()
        let currentSize = LightsSize(rawValue:
            UserDefaults.standard.string(forKey: "lightsSize") ?? "") ?? .large
        for opt in LightsSize.allCases {
            let m = NSMenuItem(title: opt.label,
                               action: #selector(actionSetSize(_:)),
                               keyEquivalent: "")
            m.target = self
            m.representedObject = opt.rawValue
            m.state = (opt == currentSize) ? .on : .off
            floatingSizeMenu.addItem(m)
        }
        floatingSizeItem.submenu = floatingSizeMenu
        sizeMenu.addItem(floatingSizeItem)

        let statusSizeItem = NSMenuItem(title: L10n.t("Status Bar", "状态栏"), action: nil, keyEquivalent: "")
        let statusSizeMenu = NSMenu()
        for opt in LightsSize.allCases {
            let m = NSMenuItem(title: opt.label,
                               action: #selector(actionSetStatusBarSize(_:)),
                               keyEquivalent: "")
            m.target = self
            m.representedObject = opt.rawValue
            m.state = (opt == currentStatusSize) ? .on : .off
            statusSizeMenu.addItem(m)
        }
        statusSizeItem.submenu = statusSizeMenu
        sizeMenu.addItem(statusSizeItem)
        sizeItem.submenu = sizeMenu
        menu.addItem(sizeItem)

        let layoutItem = NSMenuItem(title: L10n.t("Layout", "布局"), action: nil, keyEquivalent: "")
        let layoutMenu = NSMenu()
        let currentLayout = LightsLayout(rawValue:
            UserDefaults.standard.string(forKey: "lightsLayout") ?? "") ?? .vertical
        for opt in LightsLayout.allCases {
            let m = NSMenuItem(title: opt.label,
                               action: #selector(actionSetLayout(_:)),
                               keyEquivalent: "")
            m.target = self
            m.representedObject = opt.rawValue
            m.state = (opt == currentLayout) ? .on : .off
            layoutMenu.addItem(m)
        }
        layoutItem.submenu = layoutMenu
        menu.addItem(layoutItem)

        let backgroundItem = NSMenuItem(title: L10n.t("Status Bar Background", "状态栏背景"), action: nil, keyEquivalent: "")
        let backgroundMenu = NSMenu()
        for opt in StatusBarBackground.allCases {
            let m = NSMenuItem(title: opt.label,
                               action: #selector(actionSetBackground(_:)),
                               keyEquivalent: "")
            m.target = self
            m.representedObject = opt.rawValue
            m.state = opt == currentBackground ? .on : .off
            backgroundMenu.addItem(m)
        }
        backgroundItem.submenu = backgroundMenu
        menu.addItem(backgroundItem)

        let alertItem = NSMenuItem(title: L10n.t("Green Light Alert", "绿灯提醒"), action: nil, keyEquivalent: "")
        let alertMenu = NSMenu()
        let speedItem = NSMenuItem(title: L10n.t("Alert Speed", "闪烁速度"), action: nil, keyEquivalent: "")
        let speedMenu = NSMenu()
        for opt in GreenAlertSpeed.allCases {
            let m = NSMenuItem(title: opt.label, action: #selector(actionSetAlertSpeed(_:)), keyEquivalent: "")
            m.target = self
            m.representedObject = opt.rawValue
            m.state = opt == currentAlertSpeed ? .on : .off
            speedMenu.addItem(m)
        }
        speedItem.submenu = speedMenu
        alertMenu.addItem(speedItem)
        alertMenu.addItem(.separator())
        for opt in GreenLightAlert.allCases {
            let m = NSMenuItem(title: opt.label, action: #selector(actionSetGreenAlert(_:)), keyEquivalent: "")
            m.target = self
            m.representedObject = opt.rawValue
            m.state = opt == currentGreenAlert ? .on : .off
            alertMenu.addItem(m)
        }
        alertItem.submenu = alertMenu
        menu.addItem(alertItem)

        menu.addItem(.separator())
        menu.addItem(item(L10n.t("Setup Hooks…", "配置 Hooks…"), #selector(actionShowSetup)))
        let loginItem = item(L10n.t("Launch Lights at Login", "登录时启动 Lights"), #selector(actionToggleLaunchAtLogin))
        loginItem.state = launchAtLogin.isEnabled ? .on : .off
        menu.addItem(loginItem)
        let languageItem = NSMenuItem(title: "Language / 语言", action: nil, keyEquivalent: "")
        let languageMenu = NSMenu()
        for language in AppLanguage.allCases {
            let m = NSMenuItem(title: language.label, action: #selector(actionSetLanguage(_:)), keyEquivalent: "")
            m.target = self
            m.representedObject = language.rawValue
            m.state = language == AppLanguage.current ? .on : .off
            languageMenu.addItem(m)
        }
        languageItem.submenu = languageMenu
        menu.addItem(languageItem)
        menu.addItem(.separator())
        menu.addItem(item(L10n.t("Quit Lights", "退出 Lights"), #selector(actionQuit), key: "q"))
    }

    private func item(_ title: String, _ selector: Selector, key: String = "") -> NSMenuItem {
        let i = NSMenuItem(title: title, action: selector, keyEquivalent: key)
        i.target = self
        return i
    }

    // MARK: - Actions

    @objc private func actionShowSetup() {
        NotificationCenter.default.post(name: .lightsShowSetup, object: nil)
    }

    @objc private func actionSetLanguage(_ sender: NSMenuItem) {
        guard let raw = sender.representedObject as? String,
              let language = AppLanguage(rawValue: raw) else { return }
        UserDefaults.standard.set(language.rawValue, forKey: "appLanguage")
        statusItem?.menu.map { rebuild(menu: $0) }
    }

    @objc private func actionToggleLaunchAtLogin() {
        launchAtLogin.setEnabled(!launchAtLogin.isEnabled)
        if let menu = statusItem?.menu { rebuild(menu: menu) }
    }

    @objc private func actionSetSize(_ sender: NSMenuItem) {
        guard let raw = sender.representedObject as? String else { return }
        UserDefaults.standard.set(raw, forKey: "lightsSize")
        NotificationCenter.default.post(
            name: .lightsSetSize, object: nil, userInfo: ["raw": raw]
        )
    }

    @objc private func actionSetStatusBarSize(_ sender: NSMenuItem) {
        guard let raw = sender.representedObject as? String,
              let size = LightsSize(rawValue: raw) else { return }
        UserDefaults.standard.set(size.rawValue, forKey: "statusBarSize")
        statusItem?.button?.image = Self.renderStatusIcon(
            state: currentState, layout: currentLayout, size: size, background: currentBackground
        )
    }

    @objc private func actionSetLayout(_ sender: NSMenuItem) {
        guard let raw = sender.representedObject as? String else { return }
        UserDefaults.standard.set(raw, forKey: "lightsLayout")
        NotificationCenter.default.post(
            name: .lightsSetLayout, object: nil, userInfo: ["raw": raw]
        )
    }

    @objc private func actionToggleFloating() {
        let visible = !isFloatingVisible
        UserDefaults.standard.set(visible, forKey: "lightsFloatingVisible")
        NotificationCenter.default.post(
            name: .lightsSetDisplayMode, object: nil, userInfo: ["visible": visible]
        )
    }

    @objc private func actionSetBackground(_ sender: NSMenuItem) {
        guard let raw = sender.representedObject as? String,
              let background = StatusBarBackground(rawValue: raw) else { return }
        UserDefaults.standard.set(background.rawValue, forKey: "statusBarBackground")
        statusItem?.button?.image = Self.renderStatusIcon(
            state: currentState, layout: currentLayout, size: currentStatusSize, background: background
        )
    }

    @objc private func actionSetGreenAlert(_ sender: NSMenuItem) {
        guard let raw = sender.representedObject as? String,
              let alert = GreenLightAlert(rawValue: raw) else { return }
        UserDefaults.standard.set(alert.rawValue, forKey: "greenLightAlert")
    }

    @objc private func actionSetAlertSpeed(_ sender: NSMenuItem) {
        guard let raw = sender.representedObject as? String,
              let speed = GreenAlertSpeed(rawValue: raw) else { return }
        UserDefaults.standard.set(speed.rawValue, forKey: "greenAlertSpeed")
    }

    @objc private func handleStateChange(_ note: Notification) {
        guard let raw = note.userInfo?["state"] as? String,
              let state = LightsState(rawValue: raw) else { return }
        currentState = state
        if state != .idle { greenFlashGeneration += 1 }
        statusItem?.button?.image = Self.renderStatusIcon(
            state: state, layout: currentLayout, size: currentStatusSize, background: currentBackground
        )
    }

    @objc private func handleLayoutChange(_ note: Notification) {
        statusItem?.button?.image = Self.renderStatusIcon(
            state: currentState, layout: currentLayout, size: currentStatusSize, background: currentBackground
        )
    }

    @objc private func handleGreenFlash() {
        guard currentState == .idle else { return }
        greenFlashGeneration += 1
        let generation = greenFlashGeneration
        Task { @MainActor [weak self] in
            guard let self else { return }
            for _ in 0..<self.currentGreenAlert.count {
                guard generation == self.greenFlashGeneration else { return }
                self.renderStatus(.off)
                try? await Task.sleep(nanoseconds: self.currentAlertSpeed.halfCycleNanoseconds)
                guard generation == self.greenFlashGeneration else { return }
                self.renderStatus(.idle)
                try? await Task.sleep(nanoseconds: self.currentAlertSpeed.halfCycleNanoseconds)
            }
        }
    }

    private func renderStatus(_ state: LightsState) {
        statusItem?.button?.image = Self.renderStatusIcon(
            state: state, layout: currentLayout, size: currentStatusSize, background: currentBackground
        )
    }

    @objc private func actionQuit() {
        NSApp.terminate(nil)
    }

    // MARK: - Icon

    private var currentLayout: LightsLayout {
        LightsLayout(rawValue: UserDefaults.standard.string(forKey: "lightsLayout") ?? "") ?? .vertical
    }

    private var currentSize: LightsSize {
        LightsSize(rawValue: UserDefaults.standard.string(forKey: "lightsSize") ?? "") ?? .large
    }

    private var currentStatusSize: LightsSize {
        LightsSize(rawValue: UserDefaults.standard.string(forKey: "statusBarSize") ?? "") ?? .large
    }

    private var currentBackground: StatusBarBackground {
        StatusBarBackground(rawValue: UserDefaults.standard.string(forKey: "statusBarBackground") ?? "") ?? .black
    }

    private var currentGreenAlert: GreenLightAlert {
        GreenLightAlert(rawValue: UserDefaults.standard.string(forKey: "greenLightAlert") ?? "") ?? .five
    }

    private var currentAlertSpeed: GreenAlertSpeed {
        GreenAlertSpeed(rawValue: UserDefaults.standard.string(forKey: "greenAlertSpeed") ?? "") ?? .slow
    }

    private var isFloatingVisible: Bool {
        if let visible = UserDefaults.standard.object(forKey: "lightsFloatingVisible") as? Bool {
            return visible
        }
        return UserDefaults.standard.string(forKey: "lightsDisplayMode") != "menuBar"
    }

    static func renderStatusIcon(state: LightsState, layout: LightsLayout, size selectedSize: LightsSize, background: StatusBarBackground) -> NSImage {
        let scale = selectedSize.statusBarScale
        let dotD: CGFloat = 4.4 * scale
        let spacing: CGFloat = 1.65 * scale
        let pad: CGFloat = 3.5 * scale
        let iconSize = layout == .vertical
            ? NSSize(width: dotD + 2 * pad, height: 3 * dotD + 2 * spacing + 2 * pad)
            : NSSize(width: 3 * dotD + 2 * spacing + 2 * pad, height: dotD + 2 * pad)
        let img = NSImage(size: iconSize)
        img.lockFocus()
        let ctx = NSGraphicsContext.current!.cgContext
        ctx.setShouldAntialias(true)
        ctx.interpolationQuality = .high

        if background == .black {
            let housing = CGRect(origin: .zero, size: iconSize)
            let housingPath = CGPath(roundedRect: housing, cornerWidth: 4, cornerHeight: 4, transform: nil)
            ctx.setFillColor(NSColor(calibratedWhite: 0.10, alpha: 1).cgColor)
            ctx.addPath(housingPath)
            ctx.fillPath()
            ctx.setStrokeColor(NSColor(calibratedWhite: 0.75, alpha: 0.22).cgColor)
            ctx.setLineWidth(0.7)
            ctx.addPath(housingPath)
            ctx.strokePath()
        }

        let colors: [NSColor] = [.systemRed, .systemYellow, .systemGreen]
        let activeIndex: Int? = switch state {
        case .executing: 0
        case .permission: 1
        case .idle: 2
        case .off: nil
        }
        for i in 0..<3 {
            let isActive = activeIndex == i
            let x: CGFloat
            let y: CGFloat
            if layout == .vertical {
                x = (iconSize.width - dotD) / 2
                y = iconSize.height - pad - dotD - CGFloat(i) * (dotD + spacing)
            } else {
                let totalWidth = 3 * dotD + 2 * spacing
                x = (iconSize.width - totalWidth) / 2 + CGFloat(i) * (dotD + spacing)
                y = (iconSize.height - dotD) / 2
            }
            if isActive {
                ctx.setShadow(offset: .zero, blur: 2.2,
                              color: colors[i].withAlphaComponent(0.80).cgColor)
            }
            ctx.setFillColor(colors[i].withAlphaComponent(isActive ? 1 : 0.20).cgColor)
            ctx.fillEllipse(in: CGRect(x: x, y: y,
                                       width: dotD, height: dotD))
            ctx.setShadow(offset: .zero, blur: 0, color: nil)
        }
        img.unlockFocus()
        img.isTemplate = false
        return img
    }
}
