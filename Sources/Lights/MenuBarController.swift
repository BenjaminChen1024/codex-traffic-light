import AppKit

extension Notification.Name {
    static let lightsToggleWindow = Notification.Name("LightsToggleWindow")
    static let lightsShowSetup    = Notification.Name("LightsShowSetup")
    static let lightsRequestOff   = Notification.Name("LightsRequestOff")
    static let lightsSetSize      = Notification.Name("LightsSetSize")
    static let lightsSetLayout    = Notification.Name("LightsSetLayout")
    static let lightsSetDisplayMode = Notification.Name("LightsSetDisplayMode")
}

final class MenuBarController: NSObject, NSMenuDelegate {
    private var statusItem: NSStatusItem?
    private var currentState: LightsState = .idle

    func install() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let btn = item.button {
            btn.image = Self.renderStatusIcon(state: currentState)
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
        NSLog("[Lights] StatusItem isVisible=\(item.isVisible) length=\(item.length)")
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        rebuild(menu: menu)
    }

    private func rebuild(menu: NSMenu) {
        menu.removeAllItems()

        let displayItem = NSMenuItem(title: "Display Location", action: nil, keyEquivalent: "")
        let displayMenu = NSMenu()
        let currentDisplay = LightsDisplayMode(rawValue:
            UserDefaults.standard.string(forKey: "lightsDisplayMode") ?? "") ?? .floating
        for opt in LightsDisplayMode.allCases {
            let m = NSMenuItem(title: opt.label,
                               action: #selector(actionSetDisplayMode(_:)),
                               keyEquivalent: "")
            m.target = self
            m.representedObject = opt.rawValue
            m.state = opt == currentDisplay ? .on : .off
            displayMenu.addItem(m)
        }
        displayItem.submenu = displayMenu
        menu.addItem(displayItem)
        if currentDisplay == .floating {
            menu.addItem(item("Show / Hide Window", #selector(actionToggleWindow)))
        }
        menu.addItem(.separator())
        menu.addItem(item("Setup Hooks…", #selector(actionShowSetup)))
        menu.addItem(.separator())

        let sizeItem = NSMenuItem(title: "Size", action: nil, keyEquivalent: "")
        let sizeMenu = NSMenu()
        let currentSize = LightsSize(rawValue:
            UserDefaults.standard.string(forKey: "lightsSize") ?? "") ?? .large
        for opt in LightsSize.allCases {
            let m = NSMenuItem(title: opt.label,
                               action: #selector(actionSetSize(_:)),
                               keyEquivalent: "")
            m.target = self
            m.representedObject = opt.rawValue
            m.state = (opt == currentSize) ? .on : .off
            sizeMenu.addItem(m)
        }
        sizeItem.submenu = sizeMenu
        menu.addItem(sizeItem)

        let layoutItem = NSMenuItem(title: "Layout", action: nil, keyEquivalent: "")
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

        menu.addItem(item("Turn Lights Off", #selector(actionOff)))
        menu.addItem(.separator())
        menu.addItem(item("Quit Lights", #selector(actionQuit), key: "q"))
    }

    private func item(_ title: String, _ selector: Selector, key: String = "") -> NSMenuItem {
        let i = NSMenuItem(title: title, action: selector, keyEquivalent: key)
        i.target = self
        return i
    }

    // MARK: - Actions

    @objc private func actionToggleWindow() {
        NotificationCenter.default.post(name: .lightsToggleWindow, object: nil)
    }

    @objc private func actionShowSetup() {
        NotificationCenter.default.post(name: .lightsShowSetup, object: nil)
    }

    @objc private func actionSetSize(_ sender: NSMenuItem) {
        guard let raw = sender.representedObject as? String else { return }
        UserDefaults.standard.set(raw, forKey: "lightsSize")
        NotificationCenter.default.post(
            name: .lightsSetSize, object: nil, userInfo: ["raw": raw]
        )
    }

    @objc private func actionSetLayout(_ sender: NSMenuItem) {
        guard let raw = sender.representedObject as? String else { return }
        UserDefaults.standard.set(raw, forKey: "lightsLayout")
        NotificationCenter.default.post(
            name: .lightsSetLayout, object: nil, userInfo: ["raw": raw]
        )
    }

    @objc private func actionSetDisplayMode(_ sender: NSMenuItem) {
        guard let raw = sender.representedObject as? String else { return }
        UserDefaults.standard.set(raw, forKey: "lightsDisplayMode")
        NotificationCenter.default.post(
            name: .lightsSetDisplayMode, object: nil, userInfo: ["raw": raw]
        )
    }

    @objc private func handleStateChange(_ note: Notification) {
        guard let raw = note.userInfo?["state"] as? String,
              let state = LightsState(rawValue: raw) else { return }
        currentState = state
        statusItem?.button?.image = Self.renderStatusIcon(state: state)
    }

    @objc private func actionOff() {
        NotificationCenter.default.post(name: .lightsRequestOff, object: nil)
    }

    @objc private func actionQuit() {
        NSApp.terminate(nil)
    }

    // MARK: - Icon

    static func renderStatusIcon(state: LightsState) -> NSImage {
        let size = NSSize(width: 16, height: 22)
        let img = NSImage(size: size)
        img.lockFocus()
        let ctx = NSGraphicsContext.current!.cgContext
        ctx.setShouldAntialias(true)
        ctx.interpolationQuality = .high

        let housing = CGRect(x: 1, y: 0.5, width: 14, height: 21)
        ctx.setFillColor(NSColor(calibratedWhite: 0.10, alpha: 1).cgColor)
        ctx.fillPath()
        let housingPath = CGPath(roundedRect: housing, cornerWidth: 4, cornerHeight: 4, transform: nil)
        ctx.addPath(housingPath)
        ctx.fillPath()
        ctx.setStrokeColor(NSColor(calibratedWhite: 0.75, alpha: 0.22).cgColor)
        ctx.setLineWidth(0.7)
        ctx.addPath(housingPath)
        ctx.strokePath()

        let dotD: CGFloat = 4.4
        let spacing: CGFloat = 1.65
        let colors: [NSColor] = [.systemRed, .systemYellow, .systemGreen]
        let activeIndex: Int? = switch state {
        case .executing: 0
        case .permission: 1
        case .idle: 2
        case .off: nil
        }
        for i in 0..<3 {
            let isActive = activeIndex == i
            let y = size.height - 3.5 - dotD - CGFloat(i) * (dotD + spacing)
            if isActive {
                ctx.setShadow(offset: .zero, blur: 2.2,
                              color: colors[i].withAlphaComponent(0.80).cgColor)
            }
            ctx.setFillColor(colors[i].withAlphaComponent(isActive ? 1 : 0.20).cgColor)
            ctx.fillEllipse(in: CGRect(x: (size.width - dotD) / 2, y: y,
                                       width: dotD, height: dotD))
            ctx.setShadow(offset: .zero, blur: 0, color: nil)
        }
        img.unlockFocus()
        img.isTemplate = false
        return img
    }
}
