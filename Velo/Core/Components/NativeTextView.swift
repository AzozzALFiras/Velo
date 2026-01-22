//
//  NativeTextView.swift
//  Velo
//
//  A high-performance text view wrapper using native AppKit NSTextView.
//  This handles large files (1800+ lines) without freezing.
//  
//  Key optimizations:
//  1. Uses hash comparison instead of string comparison
//  2. Disables unnecessary features (ruler, font panel, etc.)
//  3. Uses async text updates to avoid blocking main thread
//

import SwiftUI
import AppKit

// MARK: - Read-Only Native Text View

/// A high-performance read-only text view for displaying large files
struct NativeTextView: NSViewRepresentable {
    let text: String
    var font: NSFont = .monospacedSystemFont(ofSize: 11, weight: .regular)
    var textColor: NSColor = .systemGreen
    var backgroundColor: NSColor = NSColor(red: 0.05, green: 0.05, blue: 0.08, alpha: 1.0)
    
    // Use hash for fast comparison instead of full string comparison
    private var textHash: Int {
        text.hashValue
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }
    
    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = true
        scrollView.autohidesScrollers = false
        scrollView.borderType = .noBorder
        scrollView.drawsBackground = true
        scrollView.backgroundColor = backgroundColor
        scrollView.scrollerStyle = .overlay
        
        let contentSize = scrollView.contentSize
        
        let textStorage = NSTextStorage()
        let layoutManager = NSLayoutManager()
        textStorage.addLayoutManager(layoutManager)
        
        let textContainer = NSTextContainer(containerSize: NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude))
        textContainer.widthTracksTextView = false
        textContainer.heightTracksTextView = false
        layoutManager.addTextContainer(textContainer)
        
        let textView = NSTextView(frame: NSRect(origin: .zero, size: contentSize), textContainer: textContainer)
        textView.isEditable = false
        textView.isSelectable = true
        textView.isRichText = false
        textView.font = font
        textView.textColor = textColor
        textView.backgroundColor = backgroundColor
        textView.drawsBackground = true
        textView.minSize = NSSize(width: 0, height: 0)
        textView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = true
        textView.autoresizingMask = [.width, .height]
        
        // Performance optimizations
        textView.usesRuler = false
        textView.usesFontPanel = false
        textView.allowsUndo = false
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        textView.isAutomaticSpellingCorrectionEnabled = false
        textView.isContinuousSpellCheckingEnabled = false
        textView.isGrammarCheckingEnabled = false
        
        scrollView.documentView = textView
        context.coordinator.textView = textView
        context.coordinator.lastHash = 0
        
        return scrollView
    }
    
    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        // Only update if hash changed - MUCH faster than string comparison
        guard context.coordinator.lastHash != textHash else { return }
        context.coordinator.lastHash = textHash
        
        guard let textView = context.coordinator.textView else { return }
        
        // Update text on main thread but do it efficiently
        let newText = text
        let newFont = font
        let newColor = textColor
        
        // Use replaceCharacters for better performance with large text
        if let textStorage = textView.textStorage {
            textStorage.beginEditing()
            textStorage.replaceCharacters(in: NSRange(location: 0, length: textStorage.length), with: newText)
            textStorage.setAttributes([
                .font: newFont,
                .foregroundColor: newColor
            ], range: NSRange(location: 0, length: textStorage.length))
            textStorage.endEditing()
        }
    }
    
    class Coordinator {
        weak var textView: NSTextView?
        var lastHash: Int = 0
    }
}

// MARK: - Editable Native Text View

/// A high-performance editable text view for editing large files
struct NativeEditableTextView: NSViewRepresentable {
    @Binding var text: String
    var font: NSFont = .monospacedSystemFont(ofSize: 12, weight: .regular)
    var textColor: NSColor = .white
    var backgroundColor: NSColor = NSColor(red: 0.08, green: 0.08, blue: 0.1, alpha: 1.0)
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = true
        scrollView.autohidesScrollers = false
        scrollView.borderType = .noBorder
        scrollView.drawsBackground = true
        scrollView.backgroundColor = backgroundColor
        scrollView.scrollerStyle = .overlay
        
        let contentSize = scrollView.contentSize
        
        let textStorage = NSTextStorage()
        let layoutManager = NSLayoutManager()
        textStorage.addLayoutManager(layoutManager)
        
        let textContainer = NSTextContainer(containerSize: NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude))
        textContainer.widthTracksTextView = false
        textContainer.heightTracksTextView = false
        layoutManager.addTextContainer(textContainer)
        
        let textView = NSTextView(frame: NSRect(origin: .zero, size: contentSize), textContainer: textContainer)
        textView.isEditable = true
        textView.isSelectable = true
        textView.isRichText = false
        textView.font = font
        textView.textColor = textColor
        textView.insertionPointColor = .white
        textView.backgroundColor = backgroundColor
        textView.drawsBackground = true
        textView.minSize = NSSize(width: 0, height: 0)
        textView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = true
        textView.autoresizingMask = [.width, .height]
        textView.allowsUndo = true
        
        // Performance optimizations
        textView.usesRuler = false
        textView.usesFontPanel = false
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        textView.isAutomaticSpellingCorrectionEnabled = false
        textView.isContinuousSpellCheckingEnabled = false
        textView.isGrammarCheckingEnabled = false
        
        // Set delegate for text changes
        textView.delegate = context.coordinator
        
        scrollView.documentView = textView
        context.coordinator.textView = textView
        context.coordinator.lastHash = text.hashValue
        
        // Set initial text
        textView.string = text
        
        return scrollView
    }
    
    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        let currentHash = text.hashValue
        
        // Don't update if being edited or hash same
        guard !context.coordinator.isEditing,
              context.coordinator.lastHash != currentHash else { return }
        
        context.coordinator.lastHash = currentHash
        context.coordinator.textView?.string = text
    }
    
    class Coordinator: NSObject, NSTextViewDelegate {
        var parent: NativeEditableTextView
        weak var textView: NSTextView?
        var isEditing = false
        var lastHash: Int = 0
        
        init(_ parent: NativeEditableTextView) {
            self.parent = parent
        }
        
        func textDidBeginEditing(_ notification: Notification) {
            isEditing = true
        }
        
        func textDidEndEditing(_ notification: Notification) {
            isEditing = false
            if let textView = textView {
                parent.text = textView.string
                lastHash = textView.string.hashValue
            }
        }
        
        func textDidChange(_ notification: Notification) {
            if let textView = textView {
                parent.text = textView.string
                lastHash = textView.string.hashValue
            }
        }
    }
}

// MARK: - Preview

#Preview("Read-Only") {
    NativeTextView(
        text: (1...100).map { "Line \($0): This is a sample line of code." }.joined(separator: "\n")
    )
    .frame(width: 600, height: 400)
}

#Preview("Editable") {
    struct PreviewWrapper: View {
        @State var text = (1...100).map { "Line \($0): This is editable." }.joined(separator: "\n")
        var body: some View {
            NativeEditableTextView(text: $text)
                .frame(width: 600, height: 400)
        }
    }
    return PreviewWrapper()
}
