# Codex Traffic Light

面向 **Codex Desktop** 的 macOS 悬浮交通灯。它不需要一直盯着 Codex 界面：只要看一眼交通灯，就能知道任务是否正在执行、是否需要你回复，或已经完成。

## 状态含义

| 灯色 | 含义 |
| --- | --- |
| 🔴 红灯 | Codex 正在执行、生成或调用工具 |
| 🟡 黄灯 | Codex 明确等待你回答问题或退出计划模式 |
| 🟢 绿灯 | 任务停止、完成或空闲 |

状态由 Codex 的 Hooks 通过本机接口 `http://127.0.0.1:9876` 更新；不读取聊天内容，也不会向外部网络发送状态。

## 本项目的改进

本项目基于 Lights 的架构进行面向 Codex Desktop 的定制：

- 聚焦 Codex Hooks：普通执行为红、需要回答时才为黄、停止后为绿。
- 取消交通灯点击切色，避免误触；灯色仅由状态事件控制。
- 保留窗口拖动，可自由放置在屏幕任意位置。
- 新增横向与纵向布局：横向固定为红、黄、绿从左到右。
- 扩展尺寸档位：Small、Medium、Large、Extra Large、Huge。
- macOS 菜单栏状态灯始终显示；可单独显示或隐藏桌面悬浮交通灯。
- 使用本机状态接口，状态更新不依赖外部服务。

## 使用方式

1. 安装并启动 `Lights.app`。
2. 在 Codex Desktop 中启用并信任 Hooks。
3. 在右键菜单或菜单栏菜单中选择：
   - `Size`：调整交通灯大小；
   - `Layout`：选择 Vertical 或 Horizontal；
   - `Show Floating Light`：显示或隐藏桌面悬浮交通灯；
   - `Setup Hooks…`：查看或配置 Hook 集成。

可将 Lights 加入 macOS 的“登录项与扩展”，使其开机自动启动。

## 本地构建

需要 macOS 14+、Swift 5.9+ 与 Xcode Command Line Tools：

```bash
swift build -c release --arch arm64
./build-app.sh
open Lights.app
```

## 致谢

本项目参考并基于 [fengyiqicoder/Lights](https://github.com/fengyiqicoder/Lights) 的浮动交通灯、菜单栏和本地状态服务设计开发。感谢原项目提供的开源基础。

原项目采用 MIT License；本项目继续保留 [LICENSE](LICENSE)。
