//
//  ParticleView.swift
//  Velo
//
//  AI-Powered Terminal - Ambient Particle System
//

import SwiftUI

// MARK: - Particle View
/// Subtle ambient particles for visual depth
struct ParticleView: View {
    let particleCount: Int
    let color: Color
    
    @State private var particles: [Particle] = []
    
    init(particleCount: Int = 50, color: Color = VeloDesign.Colors.neonCyan) {
        self.particleCount = particleCount
        self.color = color
    }
    
    var body: some View {
        GeometryReader { geometry in
            Canvas { context, size in
                for particle in particles {
                    let rect = CGRect(
                        x: particle.position.x,
                        y: particle.position.y,
                        width: particle.size,
                        height: particle.size
                    )
                    
                    context.opacity = particle.opacity
                    context.fill(
                        Circle().path(in: rect),
                        with: .color(color)
                    )
                }
            }
            .onAppear {
                initializeParticles(in: geometry.size)
                startAnimation()
            }
        }
        .allowsHitTesting(false)
    }
    
    private func initializeParticles(in size: CGSize) {
        particles = (0..<particleCount).map { _ in
            Particle(
                position: CGPoint(
                    x: CGFloat.random(in: 0...size.width),
                    y: CGFloat.random(in: 0...size.height)
                ),
                velocity: CGPoint(
                    x: CGFloat.random(in: -0.2...0.2),
                    y: CGFloat.random(in: -0.1...0.1)
                ),
                size: CGFloat.random(in: 1...3),
                opacity: Double.random(in: 0.1...0.3)
            )
        }
    }
    
    private func startAnimation() {
        Timer.scheduledTimer(withTimeInterval: 1/30, repeats: true) { _ in
            updateParticles()
        }
    }
    
    private func updateParticles() {
        for i in particles.indices {
            particles[i].position.x += particles[i].velocity.x
            particles[i].position.y += particles[i].velocity.y
            
            // Subtle opacity fluctuation
            particles[i].opacity = max(0.05, min(0.4, particles[i].opacity + Double.random(in: -0.01...0.01)))
        }
    }
}

// MARK: - Particle
struct Particle: Identifiable {
    let id = UUID()
    var position: CGPoint
    var velocity: CGPoint
    var size: CGFloat
    var opacity: Double
}

// MARK: - Floating Orbs
/// Larger, slower floating orbs for background ambiance
struct FloatingOrbs: View {
    let orbCount: Int
    
    @State private var orbs: [Orb] = []
    @State private var animationPhase: Bool = false
    
    init(orbCount: Int = 5) {
        self.orbCount = orbCount
    }
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                ForEach(orbs) { orb in
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [orb.color.opacity(0.3), orb.color.opacity(0)],
                                center: .center,
                                startRadius: 0,
                                endRadius: orb.size / 2
                            )
                        )
                        .frame(width: orb.size, height: orb.size)
                        .position(
                            x: orb.position.x + (animationPhase ? orb.drift.x : -orb.drift.x),
                            y: orb.position.y + (animationPhase ? orb.drift.y : -orb.drift.y)
                        )
                        .blur(radius: orb.size / 4)
                }
            }
            .onAppear {
                initializeOrbs(in: geometry.size)
                withAnimation(.easeInOut(duration: 8).repeatForever(autoreverses: true)) {
                    animationPhase = true
                }
            }
        }
        .allowsHitTesting(false)
    }
    
    private func initializeOrbs(in size: CGSize) {
        let colors = [
            VeloDesign.Colors.neonCyan,
            VeloDesign.Colors.neonPurple,
            VeloDesign.Colors.neonGreen
        ]
        
        orbs = (0..<orbCount).map { i in
            Orb(
                position: CGPoint(
                    x: CGFloat.random(in: size.width * 0.1...size.width * 0.9),
                    y: CGFloat.random(in: size.height * 0.1...size.height * 0.9)
                ),
                size: CGFloat.random(in: 100...200),
                color: colors[i % colors.count],
                drift: CGPoint(
                    x: CGFloat.random(in: 20...50),
                    y: CGFloat.random(in: 20...50)
                )
            )
        }
    }
}

// MARK: - Orb
struct Orb: Identifiable {
    let id = UUID()
    var position: CGPoint
    var size: CGFloat
    var color: Color
    var drift: CGPoint
}

// MARK: - Grid Lines
/// Subtle grid lines for futuristic background
struct GridLines: View {
    let spacing: CGFloat
    let color: Color
    let opacity: Double
    
    init(spacing: CGFloat = 40, color: Color = VeloDesign.Colors.neonCyan, opacity: Double = 0.05) {
        self.spacing = spacing
        self.color = color
        self.opacity = opacity
    }
    
    var body: some View {
        GeometryReader { geometry in
            Canvas { context, size in
                // Vertical lines
                for x in stride(from: 0, through: size.width, by: spacing) {
                    var path = Path()
                    path.move(to: CGPoint(x: x, y: 0))
                    path.addLine(to: CGPoint(x: x, y: size.height))
                    context.stroke(path, with: .color(color.opacity(opacity)), lineWidth: 0.5)
                }
                
                // Horizontal lines
                for y in stride(from: 0, through: size.height, by: spacing) {
                    var path = Path()
                    path.move(to: CGPoint(x: 0, y: y))
                    path.addLine(to: CGPoint(x: size.width, y: y))
                    context.stroke(path, with: .color(color.opacity(opacity)), lineWidth: 0.5)
                }
            }
        }
        .allowsHitTesting(false)
    }
}

// MARK: - Preview
#Preview {
    ZStack {
        VeloDesign.Colors.deepSpace
            .ignoresSafeArea()
        
        FloatingOrbs(orbCount: 3)
        ParticleView(particleCount: 30)
        GridLines()
    }
    .frame(width: 600, height: 400)
}
