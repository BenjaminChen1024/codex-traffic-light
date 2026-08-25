# Codex Traffic Light

[简体中文](README_ZH.md)

A macOS traffic-light status indicator for **Codex Desktop**. It shows Codex activity in the menu bar and an optional draggable floating light, so you do not have to keep watching the conversation window.

![Codex Traffic Light demo](docs/demo.gif)

## Status mapping

| Light | Codex status |
| --- | --- |
| 🔴 Red | Thinking, running a command, or editing files |
| 🟡 Yellow | Waiting for your answer, or waiting to exit plan mode |
| 🟢 Green | The current task has stopped or completed |

Status is delivered only through local `127.0.0.1` hooks. Lights never reads your conversations or sends status data over the network.

## Features

- Persistent menu-bar traffic light, with an optional floating light.
- The floating light is draggable, supports horizontal and vertical layouts, and has five independent size levels.
- The menu-bar indicator has its own five size levels and black or transparent background.
- On completion, the green light can stay steady or flash 1, 3, 5, or 10 times; choose a 0.3, 0.5, 0.8, 1.2, or 1.6 second flash interval.
- English and Simplified Chinese interfaces.
- One-click **Codex Desktop** setup in `Setup Hooks…`: backs up and writes the required hooks, then clearly asks you to restart Codex.
- Launch Lights automatically at login.

## Getting started

1. Open `Lights.app`.
2. Click the menu-bar icon, or right-click the floating light, then select `Setup Hooks…`.
3. In **Codex Desktop**, select `Configure / 配置`.
4. After the confirmation appears, restart Codex Desktop and trust the hooks.

Common settings are available directly from the menu:

- `Show Light / 显示悬浮灯`
- `Size / 大小` — configure floating and menu-bar lights separately
- `Layout / 布局`
- `Status Bar Background / 状态栏背景`
- `Green Light Alert / 绿灯提醒`
- `Launch Lights at Login / 登录时启动 Lights`
- `Language / 语言`

## Build locally

Requirements: macOS 14+, Swift 5.9+, and Xcode Command Line Tools.

```bash
swift build -c release --arch arm64
./build-app.sh
open Lights.app
```

`build-app.sh` creates `Lights.app`. To create a drag-to-install DMG for others, run:

```bash
./package-dmg.sh
```

The resulting `dist/Codex-Traffic-Light-v<version>.dmg` contains `Lights.app` and an Applications shortcut. Users can drag the app into Applications; they do not need Xcode. Use `release-app.sh` and `notarize.sh` for Developer ID signing or notarization.

## Credits and license

This project is a Codex Desktop-focused customization and extension of the architecture from [fengyiqicoder/Lights](https://github.com/fengyiqicoder/Lights). Thank you to the original project.

Licensed under the [MIT License](LICENSE).
