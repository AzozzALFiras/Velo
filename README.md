# Velo 🚀

**The AI-Powered Terminal for the Future.**

Velo is a next-generation terminal emulator built for macOS, designed to bridge the gap between classic command-line power and modern AI intelligence. It features a futuristic "glassmorphism" UI, intelligent command prediction, and a high-performance rendering engine that eliminates UI blocking.

![Velo Terminal UI](https://via.placeholder.com/800x450?text=Velo+UI+Concept) -> *Replace with actual screenshot*

## ✨ Key Features

### 🧠 AI & Intelligence
- **Smart Autocomplete**: Context-aware suggestions based on your history, recent files, and common patterns.
- **Command Prediction**: Learns your workflow (e.g., `git add` → `git commit` → `git push`) and suggests the next step.
- **AI Insights Panel**: A dedicated panel providing explanations, error analysis, and command tips.
- **Fuzzy History**: Instant retrieval of past commands with a robust fuzzy search.

### ⚡ Performance Engine
- **Throttled Rendering**: Custom `OutputBuffer` processes high-speed logs (like `brew install` or `npm install`) on background threads, updating the UI at a smooth 60fps (10Hz batches) to prevent "beach ball" freezes.
- **Non-Blocking I/O**: File existence checks and extensive parsing are offloaded, ensuring buttons and interactions remain 100% responsive during heavy loads.
- **Native Swift**: Built with pure SwiftUI and Combine for maximum performance on macOS.

### 🎨 Futuristic UI
- **Glassmorphism Design**: Beautiful, translucent interfaces with blur effects and neon accents.
- **Warp-Inspired Blocks**: Commands are grouped into distinct "blocks" with clear separation between input and output.
- **Interactive Output**: 
  - Click any file path to open, preview, or run it.
  - Hover effects that don't lag the UI.
  - Context menus for advanced file operations.
- **Decoupled Headers**: Sticky headers for command blocks that remain interactive independently of the scrolling log stream.

## 🛠 Architecture

Velo follows a clean **MVVM (Model-View-ViewModel)** architecture:

- **Services**:
  - `TerminalEngine`: Core PTY management, process execution, and thread-safe output buffering.
  - `PredictionEngine`: Handles AI logic and suggestion generation.
  - `HistoryManager`: Persists and indexes command history.
- **ViewModels**:
  - `TerminalViewModel`: Manages the state of the active session and coordinates services.
- **Views**:
  - `TerminalWallView`: The main orchestrator view.
  - `OutputStreamView`: High-performance list rendering for logs.
  - `CommandBlockHeader`: Decoupled, interactive status headers.

## 💻 Tech Stack

- **Language**: Swift 5.9
- **Frameworks**: SwiftUI, Combine, AppKit, Foundation
- **Data Persistence**: CoreData / JSON (History)
- **Concurrency**: Swift Concurrency (`async`/`await`), `MainActor`, `Task`

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

## 🤝 Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## 🔮 Next Steps (Future Enhancements)

- **Multi-tab support**: Manage multiple terminal sessions in parallel.
- **Cloud AI integration**: Optional connection to OpenAI/Anthropic for smarter explanations.
- **Theme customization**: User-defined color schemes and fonts.
- **Plugin system**: Extensions for custom commands and UI widgets.
- **SSH session management**: Saved remote connections with key management.

---
*Built with ❤️ by the Azozz ALFiras*
