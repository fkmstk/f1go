//
//  ContentView.swift
//  f1go
//
//  Created by 福井　正剛 on 2026/01/03.
//

import SwiftUI

struct ContentView: View {
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 12), count: 3)
    private let timer = Timer.publish(every: 0.12, on: .main, in: .common).autoconnect()

    @State private var isPlaying = false
    @State private var activeIndex: Int? = nil
    @State private var score = 0
    @AppStorage("bestScore") private var bestScore = 0
    @State private var timeRemaining: Double = 30
    @State private var lastTick: Date = .now
    @State private var lastSpawn: Date = .now
    @State private var speed: Double = 0.6
    @State private var streak = 0
    @State private var message = "タップしてスタート"
    @State private var backgroundSpin = false
    @State private var hitFlash = false

    var body: some View {
        ZStack {
            movingBackground

            VStack(spacing: 20) {
                header
                grid
                controls
                footer
            }
            .padding(20)
        }
        .overlay(alignment: .topTrailing) {
            pillBadge(text: "F1 GO", symbol: "flame.fill")
                .padding(.top, 10)
                .padding(.trailing, 16)
        }
        .onReceive(timer) { date in
            guard isPlaying else { lastTick = date; return }

            let delta = date.timeIntervalSince(lastTick)
            timeRemaining = max(0, timeRemaining - delta)
            if timeRemaining <= 0 { endGame(); return }

            let spawnInterval = max(0.3, 1.35 - speed) // スライダーでスピード調整
            if date.timeIntervalSince(lastSpawn) >= spawnInterval {
                spawnNewTarget()
                lastSpawn = date
            }

            lastTick = date
        }
    }

    private var movingBackground: some View {
        ZStack {
            LinearGradient(colors: [Color(red: 0.03, green: 0.05, blue: 0.12), Color(red: 0.05, green: 0.22, blue: 0.33)], startPoint: .topLeading, endPoint: .bottomTrailing)
                .ignoresSafeArea()

            AngularGradient(colors: [.mint, .cyan, .purple, .mint], center: .center)
                .opacity(0.25)
                .blur(radius: 140)
                .rotationEffect(.degrees(backgroundSpin ? 360 : 0))
                .animation(.linear(duration: 22).repeatForever(autoreverses: false), value: backgroundSpin)
                .onAppear { backgroundSpin = true }

            RadialGradient(colors: [.white.opacity(0.08), .clear], center: .bottomLeading, startRadius: 80, endRadius: 380)
                .blendMode(.screen)
                .ignoresSafeArea()
        }
    }

    private var header: some View {
        VStack(spacing: 12) {
            HStack {
                statBlock(title: "SCORE", value: "\(score)", tint: .mint)
                statBlock(title: "BEST", value: "\(max(score, bestScore))", tint: .yellow)
                statBlock(title: "TIME", value: String(format: "%.0f", timeRemaining), tint: .orange, extra: {
                    ProgressView(value: timeRemaining / 30)
                        .tint(.orange)
                        .scaleEffect(x: 1, y: 0.8, anchor: .center)
                })
            }
            .frame(maxWidth: .infinity)

            Text(message)
                .font(.headline.weight(.semibold))
                .foregroundStyle(.white.opacity(0.9))
                .frame(maxWidth: .infinity)
                .padding(12)
                .background(.white.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .animation(.easeOut, value: message)
        }
    }

    private var grid: some View {
        LazyVGrid(columns: columns, spacing: 12) {
            ForEach(0..<9, id: \.self) { index in
                TargetCell(isActive: index == activeIndex, hitFlash: hitFlash) {
                    handleTap(index)
                }
                .aspectRatio(1, contentMode: .fit)
            }
        }
        .frame(maxWidth: 420)
    }

    private var controls: some View {
        VStack(spacing: 14) {
            HStack {
                Text("スピード")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.white.opacity(0.8))
                Slider(value: $speed, in: 0.3...1.2) { _ in
                    lastSpawn = .now // スライダー変更時に即反映
                }
                .tint(.mint)
            }

            Button(action: toggleGame) {
                Text(isPlaying ? "一時停止" : (timeRemaining <= 0 ? "もう一度" : "スタート"))
                    .font(.title3.bold())
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(
                        LinearGradient(colors: isPlaying ? [.orange, .pink] : [.mint, .cyan],
                                       startPoint: .leading, endPoint: .trailing)
                    )
                    .foregroundStyle(.black)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .shadow(color: .black.opacity(0.35), radius: 16, x: 0, y: 12)
            }
        }
        .frame(maxWidth: 480)
    }

    private var footer: some View {
        VStack(spacing: 8) {
            Text("光っているパネルをタップしてスコアを稼ごう。外すと1点減点、連続ヒットでボーナス。30秒勝負！")
                .font(.footnote)
                .foregroundStyle(.white.opacity(0.75))
                .multilineTextAlignment(.center)
            if !isPlaying && timeRemaining <= 0 {
                Text("ベスト \(bestScore) 点を超えられる？")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.yellow)
            }
        }
        .frame(maxWidth: 520)
    }

    private func toggleGame() {
        if isPlaying {
            isPlaying = false
            message = "一時停止中"
        } else {
            startGame()
        }
    }

    private func startGame() {
        score = 0
        streak = 0
        timeRemaining = 30
        lastTick = .now
        lastSpawn = .now
        spawnNewTarget()
        isPlaying = true
        message = "GO! 光るところを叩いて！"
    }

    private func endGame() {
        isPlaying = false
        activeIndex = nil
        bestScore = max(bestScore, score)
        message = "終了！ベスト: \(bestScore)点"
    }

    private func spawnNewTarget() {
        let next = (0..<9).filter { $0 != activeIndex }.randomElement() ?? Int.random(in: 0..<9)
        activeIndex = next
    }

    private func handleTap(_ index: Int) {
        guard isPlaying else {
            message = "スタートを押してね"
            return
        }

        if index == activeIndex {
            score += 2 + streak
            streak += 1
            message = ["ナイス！","速い！","いい反応！"].randomElement() ?? "Good!"
            hitFlash.toggle()
            spawnNewTarget()
            lastSpawn = .now
        } else {
            score = max(0, score - 1)
            streak = 0
            message = "外した！ -1"
        }
    }

    private func statBlock<Content: View>(title: String, value: String, tint: Color, @ViewBuilder extra: () -> Content = { EmptyView() }) -> some View {
        VStack(spacing: 8) {
            Text(title)
                .font(.caption.bold())
                .foregroundStyle(.white.opacity(0.7))
            Text(value)
                .font(.title2.bold())
                .foregroundStyle(tint)
            extra()
        }
        .frame(maxWidth: .infinity)
        .padding(12)
        .background(.white.opacity(0.07))
        .overlay {
            RoundedRectangle(cornerRadius: 12)
                .stroke(tint.opacity(0.35), lineWidth: 1.2)
        }
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func pillBadge(text: String, symbol: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: symbol)
            Text(text)
                .font(.caption.bold())
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.ultraThinMaterial)
        .clipShape(Capsule())
        .shadow(color: .black.opacity(0.28), radius: 10, x: 0, y: 8)
    }
}

private struct TargetCell: View {
    let isActive: Bool
    let hitFlash: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(.white.opacity(0.06))

                Circle()
                    .fill(isActive ? Color.mint.opacity(0.95) : Color.clear)
                    .blur(radius: isActive ? 14 : 0)
                    .scaleEffect(isActive ? 1.05 : 1)

                Circle()
                    .strokeBorder(isActive ? Color.mint : Color.white.opacity(0.25), lineWidth: 3)

                Image(systemName: isActive ? "bolt.fill" : "hand.tap")
                    .foregroundStyle(isActive ? .black : .white.opacity(0.6))
                    .font(.title2.bold())

                if isActive {
                    Circle()
                        .strokeBorder(Color.white.opacity(0.6), lineWidth: 2)
                        .scaleEffect(hitFlash ? 1.12 : 0.92)
                        .opacity(0.4)
                        .animation(.easeOut(duration: 0.2), value: hitFlash)
                }
            }
        }
        .buttonStyle(.plain)
        .animation(.spring(response: 0.25, dampingFraction: 0.8), value: isActive)
        .shadow(color: .mint.opacity(isActive ? 0.8 : 0), radius: 16, x: 0, y: 10)
    }
}

#Preview {
    ContentView()
}
