# Velo 🚀

**The AI-Powered Terminal for the Future.**

Velo is a next-generation terminal emulator built for macOS, designed to bridge the gap between classic command-line power and modern AI intelligence. It features a futuristic "glassmorphism" UI, intelligent command prediction, multi-tab support, cloud AI integration, and a high-performance rendering engine that eliminates UI blocking.

![Velo Terminal UI](https://raw.githubusercontent.com/AzozzALFiras/Velo/refs/heads/main/Velo/screenshots/1.png)

## ✨ Key Features

### 🖥️ Dashboard Layout (NEW)
- **3-Panel Layout**: Modern NavigationSplitView with Sidebar, Workspace, and Intelligence Panel
- **Collapsible Sidebar**: Quick access to sessions, files, git, and docker panels
- **Intelligence Panel**: AI Chat, History, Files, Errors, Suggestions all in one place
- **Session Tabs Bar**: Multi-session management with visual indicators for SSH/Local

### 📁 File Explorer & Drag-Drop (NEW)
- **Integrated File Browser**: Browse local and remote (SSH) files directly in the app
- **Drag-Out to Finder**: Drag files from SSH sessions directly to Desktop/Finder
- **Drag-In Upload**: Drop local files onto SSH folders to upload via SCP
- **Auto-Authentication**: Password injection for seamless SCP transfers
- **Progress Tracking**: Real-time upload/download progress indicators
- **Toast Notifications**: Clear feedback for file operations

### 🎨 Theme Customization
- **4 Built-in Themes**: Choose from Neon Dark (default), Classic Dark, Light, and Cyberpunk themes
- **Custom Theme Creation**: Full control over 17 color properties and font settings
- **Live Preview**: Real-time theme preview cards showing color palettes
- **Font Customization**: Select from System Monospaced, Menlo, Monaco, SF Mono, or Courier New
- **Persistent Storage**: Custom themes saved locally and persist between sessions
- **Import/Export**: Share themes with JSON import/export functionality

### 🔐 SSH Session Management
- **Saved Connections**: Store SSH connections with groups for organization
- **Multiple Auth Methods**: Password, private key, or SSH agent authentication
- **Keychain Integration**: Secure credential storage in macOS Keychain
- **Quick Connect**: Fast connection via popover in tab bar with recent/saved hosts
- **Import from Config**: One-click import from `~/.ssh/config`
- **Custom Icons & Colors**: Personalize connections for easy identification
- **Remote Directory Tracking**: Accurate CWD detection even in complex SSH sessions

### 🧠 AI & Intelligence
- **Multi-Provider Cloud AI**: Integrated support for OpenAI, Anthropic, and DeepSeek with dynamic model configuration from the Velo API.
- **Smart Autocomplete**: Context-aware suggestions based on your history, recent files, and common patterns.
- **Command Prediction**: Learns your workflow (e.g., `git add` → `git commit` → `git push`) and suggests the next step.
- **Error Analysis**: One-click "Ask AI" button on command errors for instant troubleshooting and solutions.
- **AI Insights Panel**: A dedicated panel providing explanations, error analysis, and command tips with interactive code blocks.
- **Dynamic Thinking Animation**: Premium pulsing animation when AI is processing your queries.
- **System-Aware Prompts**: AI includes your macOS version, CPU cores, and RAM in its context for better recommendations.
- **Fuzzy History**: Instant retrieval of past commands with a robust fuzzy search.

### ⚡ Performance Engine
- **Throttled Rendering**: Custom `OutputBuffer` processes high-speed logs (like `brew install` or `npm install`) on background threads, updating the UI at a smooth 60fps (10Hz batches) to prevent "beach ball" freezes.
- **Non-Blocking I/O**: File existence checks and extensive parsing are offloaded, ensuring buttons and interactions remain 100% responsive during heavy loads.
- **Native Swift**: Built with pure SwiftUI and Combine for maximum performance on macOS.

### 🎨 Futuristic UI
- **Multi-Tab Support**: Browser-style tab management for parallel terminal sessions with `Cmd+T` shortcuts.
- **Glassmorphism Design**: Beautiful, translucent interfaces with blur effects and neon accents.
- **Settings in Tab Bar**: Premium integrated settings button with clean, organized preferences.
- **Warp-Inspired Blocks**: Commands are grouped into distinct "blocks" with clear separation between input and output.
- **Interactive Output**: 
  - Click any file path to open, preview, or run it.
  - Hover effects that don't lag the UI.
  - Context menus for advanced file operations.
  - One-click "Ask AI" on error lines.

### 🧭 Smart Navigation & SSH
- **Auto-List Directory**: Automatically runs `ls` after you `cd` into a directory (local or remote), ensuring you always see files immediately.
- **SSH Quick Nav**: Clickable directory badge that works even in SSH sessions. It shows the current folder's contents and lets you hop to subfolders instantly.
- **Intelligent Parsing**: Velo understands complex ANSI-colored outputs, ensuring directory suggestions are accurate even on heavily customized servers.
- **Advanced Autocomplete**: Use `Tab` or `Right Arrow` to accept inline suggestions powered by your history and current context.
- **Remote File Editor**: Edit remote files directly within Velo using a powerful VS Code-like editor. Features syntax highlighting, line numbers, and seamless saving back to the server.
- **Decoupled Headers**: Sticky headers for command blocks that remain interactive independently of the scrolling log stream.

### 🔄 App Management
- **Remote Configuration**: Dynamic AI model and endpoint fetching from the Velo API.
- **Version Control**: Automatic version checking with `X-Velo-Version` header on all API requests.
- **Smart Updates**: Detects outdated versions (HTTP 426) and displays a beautiful update overlay with release notes.
- **Manual Update Check**: Built-in "Check for Update" button in Settings.

## 🛠 Architecture

Velo utilizes a **Strict Feature-Based Architecture** organized by domain, ensuring scalability and maintainability.

### Directory Structure
```
Velo/
├── App/           # Lifecycle & Entry Points
├── Core/          # Shared Utilities, Design System, Extensions
└── Features/      # Self-contained feature modules
    ├── Dashboard/    # NEW: Main 3-panel layout
    │   ├── View/
    │   │   ├── DashboardRoot.swift
    │   │   ├── DashboardSidebar.swift
    │   │   ├── DashboardWorkspace.swift
    │   │   ├── IntelligencePanel.swift
    │   │   ├── DockerPanel.swift
    │   │   └── GitPanel.swift
    │   ├── Service/
    │   │   └── SSHFilePromiseProvider.swift
    │   └── Components/
    │       ├── SessionTabsBar.swift
    │       ├── CommandBlockView.swift
    │       └── TerminalInputBar.swift
    ├── Terminal/
    ├── SSH/
    ├── History/
    ├── AI/
    ├── Theme/
    ├── Predictions/
    ├── Settings/
    └── Tabs/
```

### Design Pattern
Velo follows a clean **MVVM (Model-View-ViewModel)** architecture:

- **Models**:
  - `VeloTheme`: Theme configuration with ColorScheme and FontScheme
  - `CommandModel`: Command execution data and metadata
  - `SessionModel`: Terminal session state
- **Services**:
  - `TerminalEngine`: Core PTY management, process execution, and thread-safe output buffering.
  - `ThemeManager`: Theme management, persistence, and custom theme CRUD operations.
  - `CloudAIService`: Multi-provider AI integration with OpenAI, Anthropic, and DeepSeek.
  - `ApiService`: Centralized API manager for Velo backend services with versioning and update handling.
  - `PredictionEngine`: Handles command prediction and suggestion generation.
  - `CommandHistoryManager`: Persists and indexes command history across all tabs.
- **ViewModels**:
  - `TabManager`: Manages multiple terminal sessions and tab switching.
  - `TerminalViewModel`: Manages the state of individual terminal sessions.
  - `HistoryViewModel`: Handles command history UI and interactions.
  - `PredictionViewModel`: Manages autocomplete suggestions and inline predictions.
- **Views**:
  - `DashboardRoot`: The main 3-panel layout orchestrator (NEW)
  - `IntelligencePanel`: Combined AI, History, Files, Errors panel (NEW)
  - `SessionTabsBar`: Multi-session tab management (NEW)
  - `TabBarView`: Horizontal tab switcher with close and new tab buttons.
  - `TerminalTabContent`: Content view for each terminal tab.
  - `OutputStreamView`: High-performance list rendering for logs.
  - `ThemeSettingsView`: Theme customization UI with preview cards and editor.
  - `SettingsView`: Comprehensive settings panel with update checking.

## 💻 Tech Stack

- **Language**: Swift 5.9
- **Frameworks**: SwiftUI, Combine, AppKit, Foundation
- **Data Persistence**: CoreData / JSON (History)
- **Concurrency**: Swift Concurrency (`async`/`await`), `MainActor`, `Task`
- **Networking**: URLSession with custom headers and error handling
- **API Integration**: RESTful API communication with the Velo backend

## 🚀 Getting Started

### Prerequisites
- macOS 14.0+ (Sonoma) or later.
- Xcode 15+

### Installation
1. Clone the repository.
   ```bash
   git clone https://github.com/azozzalfiras/velo.git
   ```
2. Open `Velo.xcodeproj` in Xcode.
3. Build and Run (⌘R).

### Configuration
1. Open Settings (gear icon in the top-right tab bar).
2. **Theme**: Choose from built-in themes or create custom themes with your preferred colors and fonts.
3. **AI Provider**: Configure your AI provider (OpenAI, Anthropic, or DeepSeek).
4. Enter your API key for the selected provider.
5. **Preferences**: Customize auto-open settings and enable/disable features.
6. Start using AI-powered features and enjoy your personalized theme!

## 🤝 Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## 🔮 Next Steps (Future Enhancements)

- **🤖 Autonomous Agents**: AI that can autonomously debug complex issues, run test suites, and refactor code across multiple files.
- **☁️ Velo Cloud Sync**: Sync your themes, history, and SSH configurations securely across all your Macs.
- **📱 Companion App**: Monitor long-running tasks and server stats remotely from your iPhone.
- **⚗️ Plugin Architecture**: Extensible API for developers to create custom widgets, themes, and command handlers.
- **🖥️ Split Panes & Layouts**: Tmux-style split views with drag-and-drop support for efficient multitasking.
- **📊 Data Visualization**: Automatically detect CSV/JSON output and render interactive charts and tables inline.
- **🗣️ Voice Command Control**: Execute complex workflows using natural language voice commands.
- **Enhanced AI Features**: Code generation, refactoring suggestions, and project analysis
- **Syntax highlighting themes**: Customizable code highlighting for different languages

---
*Built with ❤️ by Azozz ALFiras*
