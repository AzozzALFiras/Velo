# Velo 🚀

**The AI-Powered Terminal for the Future.**

Velo is a next-generation terminal emulator built for macOS, designed to bridge the gap between classic command-line power and modern AI intelligence. It features a futuristic "glassmorphism" UI, intelligent command prediction, multi-tab support, cloud AI integration, and a high-performance rendering engine that eliminates UI blocking.

![Velo Terminal UI](https://raw.githubusercontent.com/AzozzALFiras/Velo/refs/heads/main/Velo/screenshots/1.png)
## ✨ Key Features

### 🎨 Theme Customization
- **4 Built-in Themes**: Choose from Neon Dark (default), Classic Dark, Light, and Cyberpunk themes
- **Custom Theme Creation**: Full control over 17 color properties and font settings
- **Live Preview**: Real-time theme preview cards showing color palettes
- **Font Customization**: Select from System Monospaced, Menlo, Monaco, SF Mono, or Courier New
- **Persistent Storage**: Custom themes saved locally and persist between sessions
- **Import/Export**: Share themes with JSON import/export functionality

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
- **Decoupled Headers**: Sticky headers for command blocks that remain interactive independently of the scrolling log stream.

### 🔄 App Management
- **Remote Configuration**: Dynamic AI model and endpoint fetching from the Velo API.
- **Version Control**: Automatic version checking with `X-Velo-Version` header on all API requests.
- **Smart Updates**: Detects outdated versions (HTTP 426) and displays a beautiful update overlay with release notes.
- **Manual Update Check**: Built-in "Check for Update" button in Settings.

## 🛠 Architecture

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
  - `TerminalWallView`: The main orchestrator view with tab management.
  - `TabBarView`: Horizontal tab switcher with close and new tab buttons.
  - `TerminalTabContent`: Content view for each terminal tab.
  - `OutputStreamView`: High-performance list rendering for logs.
  - `AIInsightPanel`: Cloud AI chat interface with thinking animations.
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

- **Advanced theme features**: Theme marketplace, theme sharing via URL, per-tab themes
- **Plugin system**: Extensions for custom commands and UI widgets
- **SSH session management**: Saved remote connections with key management
- **Enhanced AI Features**: Code generation, refactoring suggestions, and project analysis
- **Syntax highlighting themes**: Customizable code highlighting for different languages

---
*Built with ❤️ by Azozz ALFiras*
