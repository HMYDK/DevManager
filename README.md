# RuntimePilot

<p align="center">
  <img src="https://img.shields.io/badge/platform-macOS%2013.0+-blue" alt="Platform">
  <img src="https://img.shields.io/badge/Swift-5.9+-orange" alt="Swift">
  <img src="https://img.shields.io/badge/license-MIT-green" alt="License">
</p>

**RuntimePilot** 是一个原生 macOS 应用，为 **Java / Node.js / Python / Go** 提供统一的运行时版本管理界面。  
通过单一 UI 发现已安装的运行时，快速切换版本，并将选定的版本配置到你的 Shell 环境中。

## ✨ 特性

### 🖥️ 原生 macOS 体验
- 使用 SwiftUI 构建，采用 NavigationSplitView + Grid 布局
- 可调整大小的窗口，左侧边栏选择语言，右侧详情面板展示版本卡片
- 现代化卡片式版本展示，配有官方语言图标
- 自定义 Design System（DMTheme），统一的间距、圆角、排版规范

### 📊 Dashboard 仪表板
- 一览所有语言环境的状态概览
- 显示已激活版本、安装来源、已安装数量
- 快速导航到各语言详情页
- 内置 Quick Start 引导，帮助新用户完成 Shell 配置

### 📦 版本安装/卸载（通过 Homebrew）
- 无需离开应用即可直接从 Homebrew 安装新版本
- **动态版本发现**：使用 `brew search` 自动查询所有可用版本
- 支持的语言和 formula：
  - **Node.js**: `node`, `node@18`, `node@20`, `node@22`, `node@24` 等
  - **Java**: `openjdk`, `openjdk@8`, `openjdk@11`, `openjdk@17`, `openjdk@21` 等
  - **Python**: `python@3.9`, `python@3.10`, `python@3.11`, `python@3.12`, `python@3.13`, `python@3.14` 等
  - **Go**: `go`, `go@1.20`, `go@1.21`, `go@1.22`, `go@1.23`, `go@1.24` 等
- Homebrew 新增版本后自动可用
- **实时下载进度**：显示下载百分比和安装阶段
- **系统通知**：安装完成后发送 macOS 通知
- 一键卸载已安装的 Homebrew 版本
- Homebrew 安装的版本在列表中标记为 🍺

### ☕ Java
- 通过 `/usr/libexec/java_home -X` 发现 JDK
- 写入 `JAVA_HOME` 并将 `"$JAVA_HOME/bin"` 添加到 `PATH`
- 配置文件：`java_env.sh`

### 📗 Node.js
- 扫描 Homebrew（`/opt/homebrew/Cellar/node`, `/usr/local/Cellar/node`）和 NVM（`~/.nvm/versions/node`）
- 将选定 Node 的 `bin` 目录添加到 `PATH`
- 配置文件：`node_env.sh`

### 🐍 Python
- 支持 Homebrew、pyenv（`~/.pyenv/versions`）和 asdf（`~/.asdf/installs/python`）
- 通过 `/usr/bin/env python3` 检测当前系统 Python
- 配置文件：`python_env.sh`

### 🐹 Go
- 支持 Homebrew、gvm（`~/.gvm/gos`）和 asdf（`~/.asdf/installs/golang`）
- 通过 `go version` 和 `go env GOROOT` 检测当前系统 Go
- 写入 `GOROOT` 并将 `"$GOROOT/bin"` 添加到 `PATH`
- 配置文件：`go_env.sh`

### 🔄 一致的交互体验
- 侧边栏选择语言，卡片列表展示所有已检测版本
- 当前激活版本固定在顶部并标记为 **Active**
- 每个版本卡片提供 **Use**、**Open in Finder**、**Uninstall** 等操作
- 支持复制路径、在 Finder 中显示等上下文操作

### 🐚 Shell 集成
- RuntimePilot **不直接修改**你的 Shell 配置文件
- 为每种语言生成小型 `*_env.sh` 脚本，存放于 `~/.config/devmanager/`
- 只需在 Shell 配置中 source 这些文件一次，应用切换版本时会自动更新它们

## 📋 系统要求

- macOS 13.0 或更高版本
- Swift 5.9+
- Homebrew（可选，安装/卸载功能需要）

## 🚀 如何运行

### 开发模式

```bash
# 构建
swift build

# 运行
swift run
```

### 生成应用包

```bash
# 构建 .app 和 .dmg
./build-app.sh
```

构建完成后：
- App 包：`.build/release/RuntimePilot.app`
- DMG 镜像：`RuntimePilot-0.0.1.dmg`

## ⚙️ Shell 配置（一次性设置）

将以下内容添加到你的 Shell 配置文件（如 `~/.zshrc` 或 `~/.bash_profile`）：

```bash
# RuntimePilot - Development Environment Manager
for env_file in ~/.config/devmanager/*_env.sh; do
    [ -f "$env_file" ] && source "$env_file"
done
```

或者单独配置各语言：

```bash
# Java
[ -f ~/.config/devmanager/java_env.sh ] && source ~/.config/devmanager/java_env.sh

# Node.js
[ -f ~/.config/devmanager/node_env.sh ] && source ~/.config/devmanager/node_env.sh

# Python
[ -f ~/.config/devmanager/python_env.sh ] && source ~/.config/devmanager/python_env.sh

# Go
[ -f ~/.config/devmanager/go_env.sh ] && source ~/.config/devmanager/go_env.sh
```

然后重新加载 Shell：

```bash
source ~/.zshrc
```

或者打开一个新的终端窗口。

之后，每当你在 RuntimePilot 中点击 **Use** 切换版本，对应的 `*_env.sh` 文件就会更新，新的 Shell 会话将使用选定的版本。

## 🏗️ 项目结构

```
RuntimePilot/
├── Sources/RuntimePilot/
│   ├── RuntimePilotApp.swift    # 应用入口，注册所有语言管理器
│   ├── ContentView.swift        # 主视图，NavigationSplitView 布局
│   ├── DashboardView.swift      # Dashboard 仪表板视图
│   ├── DashboardViewModel.swift # Dashboard 视图模型
│   ├── GenericLanguageView.swift# 通用语言详情视图
│   │
│   ├── LanguageProtocols.swift  # 语言版本和管理器协议定义
│   ├── LanguageMetadata.swift   # 语言元数据（名称、图标、颜色等）
│   ├── LanguageRegistry.swift   # 语言注册表，管理所有语言
│   │
│   ├── JavaManager.swift        # Java 版本管理器
│   ├── NodeManager.swift        # Node.js 版本管理器
│   ├── PythonManager.swift      # Python 版本管理器
│   ├── GoManager.swift          # Go 版本管理器
│   │
│   ├── BrewService.swift        # Homebrew 服务（安装、卸载、查询）
│   ├── BrewScanner.swift        # Homebrew 版本扫描
│   ├── DownloadManager.swift    # 下载任务队列管理
│   ├── DownloadNotificationView.swift # 下载进度通知 UI
│   │
│   ├── VersionManagerView.swift # 版本安装管理弹窗
│   ├── VersionRemovalService.swift # 版本卸载服务
│   ├── VersionSorting.swift     # 版本号排序工具
│   │
│   ├── DMTheme.swift            # Design System（间距、圆角、排版）
│   ├── SharedViews.swift        # 共享 UI 组件
│   └── Resources/               # 语言图标资源
│
├── Package.swift                # Swift Package 配置
├── Info.plist                   # 应用信息
├── build-app.sh                 # 构建脚本
└── README.md
```

## 🎨 架构设计

### 设计模式

- **Protocol-Oriented Design**：`LanguageVersion` 和 `LanguageManager` 协议定义统一契约
- **Type Erasure**：`AnyLanguageVersion` 和 `AnyLanguageManager` 实现类型擦除，支持泛型视图
- **Registry Pattern**：`LanguageRegistry` 作为语言注册中心，支持动态扩展
- **Singleton**：`BrewService.shared` 和 `DownloadManager.shared` 管理全局状态
- **MVVM**：视图与业务逻辑分离，使用 `@StateObject` 和 `@ObservedObject`

### 扩展新语言

1. 创建新的版本模型，实现 `LanguageVersion` 协议
2. 创建新的管理器，实现 `LanguageManager` 协议
3. 在 `LanguageMetadata` 中添加新语言的元数据
4. 在 `RuntimePilotApp.swift` 中注册新语言

## 📄 License

MIT License
