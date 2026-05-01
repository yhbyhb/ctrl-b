# ctrl-b

[![CI](https://github.com/yhbyhb/ctrl-b/actions/workflows/ci.yml/badge.svg)](https://github.com/yhbyhb/ctrl-b/actions/workflows/ci.yml)

一个 macOS 菜单栏工具，用于修复在中文（或其他 CJK）输入法激活时，终端中 Ctrl+键快捷键失效的问题。

> 开着中文输入法，tmux 里 `Ctrl+b` 没反应？ctrl-b 帮你解决这个问题。

[English](README.md)

## 问题说明

当 macOS 输入法（中文、韩文、日文或其他 CJK 输入法）处于激活状态时，终端模拟器中的 Ctrl+键快捷键（如 `Ctrl+b` tmux 前缀键）会静默失效。原因是输入法在 `interpretKeyEvents:` 层消耗了按键事件，终端根本收不到它。

## 工作原理

ctrl-b 作为菜单栏应用运行，通过 CGEventTap 拦截键盘事件。当检测到在输入法激活状态下按下 Ctrl+字母键时：

1. 消耗原始事件（该事件携带输入法元数据）
2. 创建不含输入法元数据的干净合成 CGEvent
3. 发布合成事件，终端可正确处理

**前缀后续键支持**：当 `Ctrl+b`（tmux 前缀键）被重映射后，ctrl-b 还会在接下来 1.5 秒内对下一个按键进行重映射——这样 `Ctrl+b` → `n`（新建窗口）等组合键也能正常工作。

## 支持的输入法

所有注册为 `TISTypeKeyboardInputMode` 类型的 macOS 输入法均受支持——应用不区分语言，全部兼容：

- **中文**：拼音（简体）、注音 / 仓颉（繁体）、五笔等
- **日文**：平假名、片假名
- **韩文**：두벌식（2键）、세벌식（3键）
- **越南语**：Telex、VNI 等
- **其他**：任何基于输入法模式的 macOS 输入源

普通键盘布局（ABC、AZERTY、QWERTY 等）不受影响——ctrl-b 仅在输入法激活时生效。

## 截图

<p align="center">
  <img src="docs/screenshots/menu.png" width="300" alt="ctrl-b 菜单" />
  &nbsp;&nbsp;&nbsp;
  <img src="docs/screenshots/about.png" width="300" alt="ctrl-b 关于面板" />
</p>

## 安装

### 下载安装（推荐）

1. 从 [最新版本](https://github.com/yhbyhb/ctrl-b/releases/latest) 下载 `ctrl-b.app.zip`
2. 解压后将 `ctrl-b.app` 移动到 `/Applications`
3. 启动 ctrl-b

> **注意：** 当前发布的二进制文件未经签名，macOS 首次启动时会拦截。
> 打开方式：**右键 → 打开**，或在终端运行：
> ```bash
> xattr -cr ctrl-b.app && open ctrl-b.app
> ```

### 从源码构建

```bash
git clone https://github.com/yhbyhb/ctrl-b.git
cd ctrl-b
make app
make install
```

### 系统要求

- macOS 13（Ventura）或更高版本

## 初始设置

启动后，在弹出的对话框中授予**辅助功能权限**：

**系统设置 → 隐私与安全性 → 辅助功能 → ctrl-b → 开启**

授权后 ctrl-b 自动开始工作，无需重启。

### 为什么需要辅助功能权限？

ctrl-b 使用 CGEventTap 在系统级拦截并替换键盘事件。这是 macOS 上唯一能消耗原始事件并发布干净合成事件的机制——正是去除 Ctrl+键事件中输入法元数据所必需的。此 API 需要辅助功能权限。

## 使用方法

应用在菜单栏显示 **⌃b** 图标，点击可以：

- 开启 / 关闭重映射
- 查看重映射统计（今日 / 累计）
- 重置统计数据
- 切换登录时自动启动
- 打开关于面板（版本、当前输入法、相关链接）

## 开发

```bash
swift build -c release   # 构建
swift test               # 运行测试
make lint                # SwiftLint（--strict 模式）
make lint-fix            # 自动修复 lint 问题
make setup               # 配置 git hooks（克隆后运行一次）
```

**开发依赖：** Xcode Command Line Tools、[SwiftLint](https://github.com/realm/SwiftLint)（`brew install swiftlint`）

贡献指南请参阅 [CONTRIBUTING.md](CONTRIBUTING.md)。

## 支持

ctrl-b 免费提供，作者利用业余时间开发维护。如果对您有帮助，欢迎赞助以支持持续维护：[GitHub Sponsors](https://github.com/sponsors/yhbyhb) · [Ko-fi](https://ko-fi.com/yhbyhb)

## 许可证

MIT — 详见 [LICENSE](LICENSE)
