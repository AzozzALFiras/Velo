//
//  Animations.swift
//  Velo
//
//  AI-Powered Terminal - Animation Utilities
//

import SwiftUI

// MARK: - Pulse Animation
struct PulseAnimation: ViewModifier {
    @State private var isPulsing = false
    let color: Color
    let duration: Double
    
    func body(content: Content) -> some View {
        content
            .overlay(
                Circle()
                    .stroke(color, lineWidth: 2)
                    .scaleEffect(isPulsing ? 1.5 : 1.0)
                    .opacity(isPulsing ? 0 : 0.5)
            )
            .onAppear {
                withAnimation(.easeOut(duration: duration).repeatForever(autoreverses: false)) {
                    isPulsing = true
                }
            }
    }
}

extension View {
    func pulseAnimation(color: Color = VeloDesign.Colors.neonCyan, duration: Double = 1.5) -> some View {
        modifier(PulseAnimation(color: color, duration: duration))
    }
}

// MARK: - Shimmer Animation
struct ShimmerAnimation: ViewModifier {
    @State private var phase: CGFloat = 0
    let duration: Double
    
    func body(content: Content) -> some View {
        content
            .overlay(
                LinearGradient(
                    colors: [
                        .clear,
                        Color.white.opacity(0.2),
                        .clear
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .rotationEffect(.degrees(30))
                .offset(x: phase)
                .mask(content)
            )
            .onAppear {
                withAnimation(.linear(duration: duration).repeatForever(autoreverses: false)) {
                    phase = 400
                }
            }
    }
}

extension View {
    func shimmerAnimation(duration: Double = 2.0) -> some View {
        modifier(ShimmerAnimation(duration: duration))
    }
}

// MARK: - Typing Animation
struct TypingAnimation: ViewModifier {
    let text: String
    let speed: Double
    @State private var displayedText = ""
    @State private var currentIndex = 0
    
    func body(content: Content) -> some View {
        Text(displayedText)
            .onAppear {
                animateText()
            }
    }
    
    private func animateText() {
        guard currentIndex < text.count else { return }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + speed) {
            let index = text.index(text.startIndex, offsetBy: currentIndex)
            displayedText += String(text[index])
            currentIndex += 1
            animateText()
        }
    }
}

// MARK: - Bounce In Animation
struct BounceInModifier: ViewModifier {
    @State private var isVisible = false
    let delay: Double
    
    func body(content: Content) -> some View {
        content
            .scaleEffect(isVisible ? 1.0 : 0.5)
            .opacity(isVisible ? 1.0 : 0)
            .onAppear {
                withAnimation(VeloDesign.Animation.bounce.delay(delay)) {
                    isVisible = true
                }
            }
    }
}

extension View {
    func bounceIn(delay: Double = 0) -> some View {
        modifier(BounceInModifier(delay: delay))
    }
}

// MARK: - Slide In Animation
struct SlideInModifier: ViewModifier {
    let edge: Edge
    let delay: Double
    @State private var isVisible = false
    
    func body(content: Content) -> some View {
        content
            .offset(x: offsetX, y: offsetY)
            .opacity(isVisible ? 1.0 : 0)
            .onAppear {
                withAnimation(VeloDesign.Animation.smooth.delay(delay)) {
                    isVisible = true
                }
            }
    }
    
    private var offsetX: CGFloat {
        guard !isVisible else { return 0 }
        switch edge {
        case .leading: return -30
        case .trailing: return 30
        default: return 0
        }
    }
    
    private var offsetY: CGFloat {
        guard !isVisible else { return 0 }
        switch edge {
        case .top: return -30
        case .bottom: return 30
        default: return 0
        }
    }
}

extension View {
    func slideIn(from edge: Edge, delay: Double = 0) -> some View {
        modifier(SlideInModifier(edge: edge, delay: delay))
    }
}

// MARK: - Glow Pulse
struct GlowPulseModifier: ViewModifier {
    let color: Color
    let minRadius: CGFloat
    let maxRadius: CGFloat
    @State private var isPulsing = false
    
    func body(content: Content) -> some View {
        content
            .shadow(color: color.opacity(0.5), radius: isPulsing ? maxRadius : minRadius)
            .shadow(color: color.opacity(0.3), radius: isPulsing ? maxRadius * 1.5 : minRadius * 1.5)
            .onAppear {
                withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                    isPulsing = true
                }
            }
    }
}

extension View {
    func glowPulse(color: Color = VeloDesign.Colors.neonCyan, minRadius: CGFloat = 5, maxRadius: CGFloat = 15) -> some View {
        modifier(GlowPulseModifier(color: color, minRadius: minRadius, maxRadius: maxRadius))
    }
}

// MARK: - Staggered Animation
struct StaggeredAnimationContainer<Content: View>: View {
    let content: Content
    let staggerDelay: Double
    
    init(staggerDelay: Double = 0.05, @ViewBuilder content: () -> Content) {
        self.staggerDelay = staggerDelay
        self.content = content()
    }
    
    var body: some View {
        content
    }
}

// MARK: - Loading Dots
struct LoadingDots: View {
    @State private var dotScales: [CGFloat] = [1, 1, 1]
    let color: Color
    
    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<3) { index in
                Circle()
                    .fill(color)
                    .frame(width: 6, height: 6)
                    .scaleEffect(dotScales[index])
            }
        }
        .onAppear {
            startAnimation()
        }
    }
    
    private func startAnimation() {
        for i in 0..<3 {
            withAnimation(.easeInOut(duration: 0.4).repeatForever(autoreverses: true).delay(Double(i) * 0.15)) {
                dotScales[i] = 0.5
            }
        }
    }
}

// MARK: - Progress Ring
struct ProgressRing: View {
    let progress: Double
    let lineWidth: CGFloat
    let color: Color
    
    @State private var animatedProgress: Double = 0
    
    var body: some View {
        ZStack {
            Circle()
                .stroke(color.opacity(0.2), lineWidth: lineWidth)
            
            Circle()
                .trim(from: 0, to: animatedProgress)
                .stroke(
                    color,
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .animation(.easeInOut(duration: 0.5), value: animatedProgress)
        }
        .onAppear {
            animatedProgress = progress
        }
        .onChange(of: progress) { newValue in
            animatedProgress = newValue
        }
    }
}
