import SwiftUI

private let epicStreakDays: Set<Int> = [30, 100, 365]

struct BadgeCelebrationView: View {
    let badge: Badge
    let onDismiss: () -> Void
    var epic: Bool { badge.isTotal || epicStreakDays.contains(badge.days) }

    @State private var iconScale: CGFloat = 0.1
    @State private var iconOpacity: Double = 0
    @State private var iconRotation: Double = -30
    @State private var textOpacity: Double = 0
    @State private var textOffset: CGFloat = 15
    @State private var glowOpacity: Double = 0
    @State private var glowScale: CGFloat = 0.5
    @State private var ring1Scale: CGFloat = 0.3
    @State private var ring1Opacity: Double = 0
    @State private var sparkRotation: Double = 0
    @State private var sparkOpacity: Double = 0
    @State private var shimmerOffset: CGFloat = -150
    @State private var shimmer2Offset: CGFloat = -150
    @State private var cardScale: CGFloat = 0.6
    @State private var cardOpacity: Double = 0

    // Physics-based confetti
    @State private var confetti: [ConfettiState] = []
    @State private var timer: Timer?

    // View frame size
    private let viewW: CGFloat = 420
    private let viewH: CGFloat = 500

    var body: some View {
        ZStack {
            // Main card
            VStack(spacing: 0) {
                // Badge icon area
                ZStack {
                    // Spark rays
                    ForEach(0..<12, id: \.self) { i in
                        Capsule()
                            .fill(
                                LinearGradient(
                                    colors: [.purple.opacity(0.6), .purple.opacity(0)],
                                    startPoint: .bottom,
                                    endPoint: .top
                                )
                            )
                            .frame(width: 2, height: 45)
                            .offset(y: -70)
                            .rotationEffect(.degrees(Double(i) * 30 + sparkRotation))
                            .opacity(sparkOpacity)
                    }

                    // Ring
                    Circle()
                        .stroke(
                            AngularGradient(
                                colors: [.purple.opacity(0.6), .blue.opacity(0.4), .white.opacity(0.6), .blue.opacity(0.4), .purple.opacity(0.6)],
                                center: .center
                            ),
                            lineWidth: 2
                        )
                        .frame(width: 120, height: 120)
                        .scaleEffect(ring1Scale)
                        .opacity(ring1Opacity)

                    // Glow
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [.purple.opacity(0.3), .blue.opacity(0.1), .clear],
                                center: .center,
                                startRadius: 5,
                                endRadius: 65
                            )
                        )
                        .frame(width: 140, height: 140)
                        .scaleEffect(glowScale)
                        .opacity(glowOpacity)

                    // Badge icon
                    Text(badge.icon)
                        .font(.system(size: epic ? 90 : 80))
                        .shadow(color: .purple.opacity(0.4), radius: 15)
                        .scaleEffect(iconScale)
                        .opacity(iconOpacity)
                        .rotationEffect(.degrees(iconRotation))
                        .overlay(
                            LinearGradient(
                                colors: [.clear, .white.opacity(0.5), .clear],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                            .frame(width: 50)
                            .offset(x: shimmerOffset)
                            .mask(Text(badge.icon).font(.system(size: epic ? 90 : 80)))
                        )
                        .overlay(
                            LinearGradient(
                                colors: [.clear, .purple.opacity(0.4), .clear],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                            .frame(width: 35)
                            .offset(x: shimmer2Offset)
                            .mask(Text(badge.icon).font(.system(size: epic ? 90 : 80)))
                            .opacity(epic ? 1 : 0)
                        )
                }
                .frame(height: 180)
                .padding(.top, 24)

                // Badge name & desc
                VStack(spacing: 8) {
                    Text(L.badgeUnlocked)
                        .font(.system(size: 12, weight: .medium))
                        .tracking(1.5)
                        .foregroundColor(Color(red: 0.65, green: 0.55, blue: 0.9))

                    Text(badge.name)
                        .font(.system(size: 26, weight: .bold))
                        .foregroundColor(.white)

                    Text(badge.desc)
                        .font(.system(size: 14))
                        .foregroundColor(.white.opacity(0.5))
                }
                .opacity(textOpacity)
                .offset(y: textOffset)
                .padding(.bottom, 30)
            }
            .padding(.horizontal, 24)
            .frame(width: 240)
            .background(
                ZStack {
                    // Dark gradient background
                    RoundedRectangle(cornerRadius: 20)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color(red: 0.14, green: 0.12, blue: 0.22),
                                    Color(red: 0.10, green: 0.08, blue: 0.18),
                                    Color(red: 0.08, green: 0.06, blue: 0.14),
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )

                    // Subtle purple glow at top
                    RoundedRectangle(cornerRadius: 20)
                        .fill(
                            RadialGradient(
                                colors: [
                                    Color(red: 0.4, green: 0.3, blue: 0.7).opacity(0.15),
                                    .clear
                                ],
                                center: .init(x: 0.5, y: 0.15),
                                startRadius: 0,
                                endRadius: 160
                            )
                        )

                    // Thin border
                    RoundedRectangle(cornerRadius: 20)
                        .strokeBorder(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.15),
                                    Color.purple.opacity(0.2),
                                    Color.white.opacity(0.08),
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            ),
                            lineWidth: 1
                        )
                }
                .shadow(color: Color(red: 0.3, green: 0.2, blue: 0.5).opacity(0.4), radius: 30)
                .shadow(color: .black.opacity(0.3), radius: 15, x: 0, y: 10)
            )
            .scaleEffect(cardScale)
            .opacity(cardOpacity)

            // Physics confetti (rendered above card)
            Canvas { ctx, size in
                let cx = size.width / 2
                let cy = size.height / 2
                for p in confetti where p.opacity > 0.01 {
                    let x = cx + p.x
                    let y = cy + p.y
                    guard x > -20 && x < size.width + 20 && y < size.height + 20 else { continue }

                    ctx.opacity = p.opacity
                    ctx.translateBy(x: x, y: y)
                    ctx.rotate(by: .degrees(p.rotation))

                    let rect: CGRect
                    switch p.shape {
                    case 0: // circle
                        rect = CGRect(x: -p.size/2, y: -p.size/2, width: p.size, height: p.size)
                        ctx.fill(Ellipse().path(in: rect), with: .color(p.color))
                    case 1: // rectangle / ribbon
                        let w = p.size * 0.4
                        let h = p.size * 1.6
                        rect = CGRect(x: -w/2, y: -h/2, width: w, height: h)
                        ctx.fill(RoundedRectangle(cornerRadius: 1).path(in: rect), with: .color(p.color))
                    default: // square confetti
                        rect = CGRect(x: -p.size/2, y: -p.size/2, width: p.size, height: p.size)
                        ctx.fill(Rectangle().path(in: rect), with: .color(p.color))
                    }

                    ctx.rotate(by: .degrees(-p.rotation))
                    ctx.translateBy(x: -x, y: -y)
                }
            }
            .frame(width: viewW, height: viewH)
            .allowsHitTesting(false)
        }
        .frame(width: viewW, height: viewH)
        .contentShape(Rectangle())
        .onTapGesture { onDismiss() }
        .onAppear { animate() }
        .onDisappear { timer?.invalidate() }
    }

    // MARK: - Animation orchestration

    private func animate() {
        // Card pop in
        withAnimation(.spring(response: 0.5, dampingFraction: 0.65)) {
            cardScale = 1.0
            cardOpacity = 1
        }

        withAnimation(.spring(response: 0.6, dampingFraction: 0.45).delay(0.15)) {
            iconScale = 1.0
            iconOpacity = 1
            iconRotation = 0
        }

        withAnimation(.easeOut(duration: epic ? 0.5 : 0.4).delay(0.3)) {
            glowScale = epic ? 1.4 : 1.2
            glowOpacity = 1
        }
        withAnimation(.easeInOut(duration: epic ? 1.2 : 1.5).delay(0.8).repeatForever(autoreverses: true)) {
            glowScale = epic ? 1.0 : 0.9
            glowOpacity = epic ? 0.6 : 0.4
        }

        withAnimation(.easeOut(duration: 0.5).delay(0.3)) {
            ring1Scale = 1.4
            ring1Opacity = 0.8
        }
        withAnimation(.easeOut(duration: 0.4).delay(0.7)) {
            ring1Opacity = 0
        }

        withAnimation(.easeOut(duration: 0.3).delay(0.3)) {
            sparkOpacity = 0.6
        }
        withAnimation(.linear(duration: 4).delay(0.3).repeatForever(autoreverses: false)) {
            sparkRotation = 360
        }

        // Launch confetti cannons
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            launchCannon(fromLeft: true)
            launchCannon(fromLeft: false)
            startPhysicsLoop()
        }

        // Second burst for epic
        if epic {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                launchCannon(fromLeft: true)
                launchCannon(fromLeft: false)
            }
        }

        withAnimation(.easeInOut(duration: 0.6).delay(0.8)) {
            shimmerOffset = 150
        }
        if epic {
            withAnimation(.easeInOut(duration: 0.5).delay(1.2)) {
                shimmer2Offset = 150
            }
        }

        withAnimation(.spring(response: 0.5, dampingFraction: 0.7).delay(0.5)) {
            textOpacity = 1
            textOffset = 0
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 4.0) {
            timer?.invalidate()
            onDismiss()
        }
    }

    // MARK: - Confetti cannon

    private func launchCannon(fromLeft: Bool) {
        let count = epic ? 45 : 30
        let originX: CGFloat = fromLeft ? -160 : 160
        let originY: CGFloat = 190
        let baseAngle: Double = fromLeft ? -75 : -105  // steeper upward
        let spread: Double = 40

        let newPieces = (0..<count).map { _ -> ConfettiState in
            let angle = baseAngle + Double.random(in: -spread...spread)
            let rad = angle * .pi / 180
            let velocity = CGFloat.random(in: 450...750)
            let vx = cos(rad) * velocity
            let vy = sin(rad) * velocity

            return ConfettiState(
                x: originX,
                y: originY,
                vx: vx,
                vy: vy,
                rotation: Double.random(in: 0...360),
                rotationSpeed: Double.random(in: -600...600),
                size: CGFloat.random(in: 5...10),
                shape: Int.random(in: 0...2),
                color: ConfettiState.randomColor(),
                gravity: CGFloat.random(in: 180...280),
                drag: CGFloat.random(in: 0.015...0.03),
                drift: CGFloat.random(in: -15...15),
                opacity: 1.0,
                ticks: 0
            )
        }
        confetti.append(contentsOf: newPieces)
    }

    // MARK: - Physics loop

    private func startPhysicsLoop() {
        let dt: CGFloat = 1.0 / 60.0
        timer = Timer.scheduledTimer(withTimeInterval: TimeInterval(dt), repeats: true) { _ in
            DispatchQueue.main.async {
                var alive = false
                for i in confetti.indices {
                    confetti[i].ticks += 1

                    // Apply drag
                    confetti[i].vx *= (1 - confetti[i].drag)
                    confetti[i].vy *= (1 - confetti[i].drag)

                    // Apply gravity + drift
                    confetti[i].vy += confetti[i].gravity * dt
                    confetti[i].vx += confetti[i].drift * dt

                    // Update position
                    confetti[i].x += confetti[i].vx * dt
                    confetti[i].y += confetti[i].vy * dt

                    // Rotate
                    confetti[i].rotation += confetti[i].rotationSpeed * Double(dt)

                    // Fade out after a while
                    if confetti[i].ticks > 120 {
                        confetti[i].opacity -= Double(dt) * 1.5
                    }

                    if confetti[i].opacity > 0.01 && confetti[i].y < 250 {
                        alive = true
                    }
                }

                // Remove dead particles
                if !alive {
                    timer?.invalidate()
                }
            }
        }
    }
}

// MARK: - Confetti state (physics particle)

private struct ConfettiState: Identifiable {
    let id = UUID()
    var x: CGFloat
    var y: CGFloat
    var vx: CGFloat
    var vy: CGFloat
    var rotation: Double
    var rotationSpeed: Double
    var size: CGFloat
    var shape: Int           // 0=circle, 1=ribbon, 2=square
    var color: Color
    var gravity: CGFloat
    var drag: CGFloat
    var drift: CGFloat
    var opacity: Double
    var ticks: Int

    static func randomColor() -> Color {
        let colors: [Color] = [
            Color(red: 1, green: 0.22, blue: 0.22),
            Color(red: 1, green: 0.6, blue: 0),
            Color(red: 1, green: 0.84, blue: 0),
            Color(red: 0.2, green: 0.78, blue: 0.35),
            Color(red: 0.25, green: 0.52, blue: 1),
            Color(red: 0.69, green: 0.32, blue: 0.87),
            Color(red: 1, green: 0.42, blue: 0.62),
            Color(red: 0, green: 0.8, blue: 0.82),
        ]
        return colors.randomElement()!
    }
}
