# Velo 🚀

**The AI-Powered Terminal & Server Management Center.**

Velo is a next-generation terminal emulator and server management suite built for macOS. It bridges the gap between classic command-line power, modern server administration, and advanced AI intelligence. Designed with a futuristic "glassmorphism" UI, Velo offers a unified workspace for developers and sysadmins to manage SSH connections, web servers, databases, and Docker containers with ease.

![Velo Terminal UI](https://raw.githubusercontent.com/AzozzALFiras/Velo/refs/heads/main/Velo/screenshots/1.png)

## ✨ Key Features

### 🛠️ Complete Server Management
Velo transforms your terminal into a full-fledged server dashboard.
- **Web Server Control**: Manage Nginx and Apache configurations, monitor status, and handle virtual hosts.
- **Database Management**: Integrated tools for MySQL. View status, manage users, modify configurations, and inspect logs.
- **Application & Runtime Manager**: Easily manage installed runtimes (PHP, Node.js) and applications.
- **Service Monitoring**: Real-time status tracking for system services with one-click restart/stop capabilities.

### 🧠 Advanced AI Intelligence
- **Multi-Provider Support**: Seamlessly integrate with OpenAI, Anthropic, and DeepSeek.
- **Smart Context**: AI understands your OS version, hardware specs, and active context for precise suggestions.
- **Command Prediction**: Predictive engine learns your workflow (e.g., `git add` → `git commit`) to suggest the next move.
- **Error Analysis**: Instant "Ask AI" troubleshooting for terminal errors.
- **Intelligent Chat**: A dedicated panel for code generation, explanation, and pair programming.

### 🖥️ Modern Dashboard & UI
- **3-Panel Layout**: NavigationSplitView with Sidebar, Workspace, and Intelligence Panel.
- **Glassmorphism Design**: Sleek, translucent interface with neon accents and blur effects.
- **Command Bar**: Spotlight-style quick action bar for navigation and command execution.
- **Customizable Themes**: Built-in premium themes (Neon, Cyberpunk) plus a full editor to create your own.

### 📁 File Explorer & Operations
- **Remote File Manager**: Browse, edit, and manage files on SSH servers directly.
- **Drag-and-Drop**: Seamlessly drag files out to Finder or drop to upload via SCP.
- **Smart Editor**: VS Code-like editor for remote files with syntax highlighting.
- **Auto-Authentication**: Password injection for secure and smooth file transfers.

### 🐳 Docker & Git Integration
- **Docker Panel**: Monitor containers, view logs, and manage images.
- **Git Integration**: Visual commit history, diff viewing, and branch management.

### 🔐 Robust SSH & Connectivity
- **Session Manager**: Organize connections with groups, custom icons, and labels.
- **Keychain Support**: Securely store passwords and private keys.
- **Automatic Resume**: Smart reconnection handling for dropped sessions.
- **Local & Remote Tabs**: Mix local shell and remote SSH tabs in one window.

## 🛠 Architecture & Project Structure

Velo utilizes a **Strict Feature-Based Architecture** organized by domain, ensuring scalability and maintainability. The codebase is divided into clear logical layers following the **MVVM (Model-View-ViewModel)** design pattern.

### 📂 Directory Structure

```
Velo/
├── App/           # Application Lifecycle (App entry point, ContentView)
├── Core/          # Shared Utilities and Foundations
│   ├── Components/     # Reusable UI Components (Buttons, Fields, etc.)
│   ├── DesignSystem/   # Global Styles, Colors, and Typography
│   ├── Extensions/     # Swift Extensions for common types
│   ├── Models/         # Shared Data Models
│   ├── Services/       # Core Services (e.g., API, Logging)
│   └── Utilities/      # Helper Functions and Wrappers
└── Features/      # Self-contained feature modules
    ├── Dashboard/      # Main application layout and navigation
    ├── ServerManagement/ # Remote server management (Nginx, MySQL, etc.)
    │   ├── SubFeatures/    # Modular sub-components for server tasks
    ├── Terminal/       # Terminal emulation logic
    ├── SSH/            # SSH connection handling
    ├── Intelligence/   # AI chat and features
    ├── Settings/       # User preferences
    └── ...
```

### 🏗️ Design Pattern: MVVM

Each feature module (e.g., `Features/Terminal`) is self-contained and follows the MVVM separation of concerns:

- **Model**: Defines the data structures and business logic entities (e.g., `TerminalSession`, `ServerConfig`).
- **View**: SwiftUI views that render the UI and observe the ViewModel (e.g., `TerminalView`, `ServerStatusView`).
- **ViewModel**: Manages state, handles user intent, and communicates with Services (e.g., `TerminalViewModel`, `ServerManagementViewModel`).
- **Service**: Handles data fetching, networking, and heavy computations (e.g., `SSHService`, `NginxService`).

This architecture ensures that code remains testable, modular, and easy to navigate. Shared resources and UI components are centralized in `Core` to maintain consistency across the entire application.

## 💻 Tech Stack

- **Language**: Swift 5.9
- **UI Framework**: SwiftUI & AppKit
- **Architecture**: MVVM (Model-View-ViewModel) / Feature-Based
- **Concurrency**: Swift Concurrency (`async`/`await`), Combine
- **Networking**: URLSession, custom SSH implementations

## 🚀 Getting Started

### Prerequisites
- macOS 14.0+ (Sonoma) or later.
- Xcode 15+

### Installation
1. **Clone the repository**
   ```bash
   git clone https://github.com/azozzalfiras/velo.git
   cd velo
   ```
2. **Open in Xcode**
   Open `Velo.xcodeproj` in Xcode.
3. **Build and Run**
   Press `Cmd + R` to build and run the application.

### Configuration
1. **AI Setup**: Go to Settings > Intelligence to configure your API keys (OpenAI, Anthropic, DeepSeek).
2. **Theme**: Customize your appearance in Settings > Theme.
3. **SSH**: Import your `~/.ssh/config` or add hosts manually in the Sidebar.

## 🤝 Contributing

Contributions are welcome!
1. Fork the Project
2. Create your Feature Branch (`git checkout -b feature/AmazingFeature`)
3. Commit your Changes (`git commit -m 'Add some AmazingFeature'`)
4. Push to the Branch (`git push origin feature/AmazingFeature`)
5. Open a Pull Request

## 📄 License

Distributed under the MIT License. See `LICENSE` for more information.

---
*Built with ❤️ by Azozz ALFiras*
