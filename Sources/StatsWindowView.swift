import SwiftUI

struct StatsWindowView: View {
    @EnvironmentObject var state: AppState
    private let db = Database.shared

    var body: some View {
        VStack(spacing: 0) {
            heroSection
                .padding(24)

            Divider().padding(.horizontal, 20)

            HStack(alignment: .top, spacing: 0) {
                // Left: charts
                VStack(spacing: 20) {
                    weekChart
                    heatmapSection
                    Spacer()
                    Text(state.encourageText)
                        .font(.system(size: 13))
                        .foregroundStyle(.green)
                        .padding(.bottom, 4)
                }
                .padding(24)
                .frame(maxWidth: .infinity)

                Divider().padding(.vertical, 16)

                // Right: badges
                badgesPanel
            }
        }
    }

    // MARK: - Hero

    private var heroSection: some View {
        let goal = state.config.dailyGoal
        let (wDone, wTotal) = db.weekCompletionRate(goal: goal)
        let (mDone, mTotal) = db.monthCompletionRate(goal: goal)

        return HStack(spacing: 32) {
            VStack(spacing: 6) {
                ZStack {
                    Circle()
                        .stroke(.quaternary, lineWidth: 5)
                    Circle()
                        .trim(from: 0, to: min(1, Double(state.todayDone) / Double(max(goal, 1))))
                        .stroke(.green.gradient, style: StrokeStyle(lineWidth: 5, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                    VStack(spacing: 0) {
                        Text("\(state.todayDone)")
                            .font(.system(size: 32, weight: .bold, design: .rounded))
                            .foregroundStyle(.green)
                        Text("/\(goal)")
                            .font(.system(size: 13, design: .rounded))
                            .foregroundStyle(.tertiary)
                    }
                }
                .frame(width: 88, height: 88)
                Text(L.todayDone)
                    .font(.system(size: 11))
                    .foregroundStyle(.tertiary)
            }

            HStack(spacing: 24) {
                heroStat(value: "\(state.currentStreak)", label: L.currentStreak, icon: "flame.fill", color: .orange)
                heroStat(value: "\(state.maxStreak)", label: L.maxStreak, icon: "crown.fill", color: .yellow)
                heroStat(value: "\(wDone)/\(wTotal)", label: L.weekGoal, icon: "calendar", color: .purple)
                heroStat(value: "\(mDone)/\(mTotal)", label: L.monthGoal, icon: "calendar.badge.checkmark", color: .pink)
            }
        }
        .padding(.vertical, 4)
    }

    private func heroStat(value: String, label: String, icon: String, color: Color) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 13))
                .foregroundStyle(color)
                .frame(width: 18)
            VStack(alignment: .leading, spacing: 2) {
                Text(value)
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .monospacedDigit()
                Text(label)
                    .font(.system(size: 11))
                    .foregroundStyle(.tertiary)
            }
        }
        .frame(width: 110, alignment: .leading)
    }

    // MARK: - Week Chart

    private var weekChart: some View {
        let data = db.recent7DaysCounts()
        let goal = state.config.dailyGoal
        let maxVal = max(goal, data.map(\.1).max() ?? 1)

        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(L.last7Days)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                let total = data.reduce(0) { $0 + $1.1 }
                Text(L.totalTimes(total))
                    .font(.system(size: 11))
                    .foregroundStyle(.tertiary)
            }

            HStack(alignment: .bottom, spacing: 10) {
                ForEach(Array(data.enumerated()), id: \.offset) { _, item in
                    VStack(spacing: 5) {
                        if item.1 > 0 {
                            Text("\(item.1)")
                                .font(.system(size: 11, weight: .semibold, design: .rounded))
                                .foregroundStyle(item.1 >= goal ? .green : .secondary)
                        } else {
                            Text(" ")
                                .font(.system(size: 11))
                        }

                        RoundedRectangle(cornerRadius: 4)
                            .fill(barColor(count: item.1, goal: goal))
                            .frame(height: item.1 == 0 ? 3 : max(10, CGFloat(item.1) / CGFloat(maxVal) * 80))

                        Text(shortDay(item.0))
                            .font(.system(size: 10))
                            .foregroundStyle(.tertiary)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .frame(height: 120)
        }
    }

    private func barColor(count: Int, goal: Int) -> Color {
        if count == 0 { return Color.gray.opacity(0.12) }
        if count >= goal { return .green }
        return .green.opacity(0.35)
    }

    private func shortDay(_ s: String) -> String {
        let p = s.split(separator: "-")
        guard p.count == 3, let d = Int(p[2]) else { return s }
        return L.dayLabel(d)
    }

    // MARK: - Heatmap

    private var heatmapSection: some View {
        let data = db.last30DaysCounts()
        let goal = state.config.dailyGoal
        let cols = 7
        let rows = (data.count + cols - 1) / cols

        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(L.last30Days)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                let goalDays = data.filter { $0.1 >= goal }.count
                Text(L.goalDays(goalDays))
                    .font(.system(size: 11))
                    .foregroundStyle(.tertiary)
            }

            VStack(spacing: 4) {
                ForEach(0..<rows, id: \.self) { row in
                    HStack(spacing: 4) {
                        ForEach(0..<cols, id: \.self) { col in
                            let idx = row * cols + col
                            if idx < data.count {
                                let item = data[idx]
                                let ratio = Double(item.1) / Double(max(goal, 1))
                                RoundedRectangle(cornerRadius: 3)
                                    .fill(heatColor(ratio: ratio))
                                    .frame(width: 30, height: 30)
                                    .overlay(
                                        Text(heatDay(item.0))
                                            .font(.system(size: 8))
                                            .foregroundStyle(item.1 > 0 ? .white.opacity(0.7) : .gray.opacity(0.3))
                                    )
                                    .help("\(shortDate(item.0)): \(item.1)")
                            } else {
                                Color.clear.frame(width: 30, height: 30)
                            }
                        }
                        Spacer()
                    }
                }

                HStack(spacing: 5) {
                    Text(L.less).font(.system(size: 10)).foregroundStyle(.primary.opacity(0.45))
                    ForEach([0.0, 0.25, 0.5, 0.75, 1.0], id: \.self) { r in
                        RoundedRectangle(cornerRadius: 2)
                            .fill(heatColor(ratio: r))
                            .frame(width: 14, height: 14)
                    }
                    Text(L.more).font(.system(size: 10)).foregroundStyle(.primary.opacity(0.45))
                    Spacer()
                }
                .padding(.top, 4)
            }
        }
    }

    private func heatColor(ratio: Double) -> Color {
        if ratio <= 0 { return Color.gray.opacity(0.1) }
        if ratio < 0.5 { return Color.green.opacity(0.3) }
        if ratio < 1.0 { return Color.green.opacity(0.55) }
        return Color.green
    }

    private func heatDay(_ s: String) -> String {
        let p = s.split(separator: "-")
        guard p.count == 3, let d = Int(p[2]) else { return "" }
        return "\(d)"
    }

    private func shortDate(_ s: String) -> String {
        let p = s.split(separator: "-")
        guard p.count == 3, let m = Int(p[1]), let d = Int(p[2]) else { return s }
        return "\(m)/\(d)"
    }

    // MARK: - Badges

    private var badgesPanel: some View {
        let earnedBadges = allBadges.filter { state.maxStreak >= $0.days }
        let nextBadge = allBadges.first(where: { state.maxStreak < $0.days })

        return VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text(L.earnedBadges)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                Text(L.badgeCount(earnedBadges.count))
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(.tertiary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(.quaternary, in: Capsule())
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 12)

            if earnedBadges.isEmpty {
                VStack(spacing: 12) {
                    Spacer()
                    Text("?")
                        .font(.system(size: 48))
                        .foregroundStyle(.quaternary)
                    Text(L.noBadgesYet)
                        .font(.system(size: 13))
                        .foregroundStyle(.tertiary)
                    if let next = nextBadge {
                        Text(L.firstBadgeHint(next.days))
                            .font(.system(size: 11))
                            .foregroundStyle(.quaternary)
                    }
                    Spacer()
                }
                .frame(maxWidth: .infinity)
            } else {
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 4) {
                        ForEach(Array(earnedBadges.enumerated()), id: \.offset) { _, badge in
                            earnedBadgeRow(badge: badge)
                        }
                    }
                    .padding(.horizontal, 12)
                }
            }

            Spacer(minLength: 0)

            if let next = nextBadge {
                VStack(spacing: 6) {
                    HStack(spacing: 6) {
                        Text("🎯")
                            .font(.system(size: 16))
                        Text(L.nextGoal)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(.green)
                    }

                    let progress = min(1.0, Double(state.maxStreak) / Double(next.days))
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 3)
                                .fill(.quaternary)
                            RoundedRectangle(cornerRadius: 3)
                                .fill(.green.gradient)
                                .frame(width: geo.size.width * progress)
                        }
                    }
                    .frame(height: 6)

                    Text(L.daysToUnlock(next.days - state.maxStreak))
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(.green.opacity(0.06), in: RoundedRectangle(cornerRadius: 10))
                .padding(.horizontal, 12)
                .padding(.bottom, 12)
            }
        }
        .frame(width: 260)
        .background(.quaternary.opacity(0.08))
    }

    private func earnedBadgeRow(badge: Badge) -> some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color.green.opacity(0.15))
                    .frame(width: 42, height: 42)
                Text(badge.icon)
                    .font(.system(size: 22))
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(badge.name)
                    .font(.system(size: 13, weight: .semibold))
                Text(badge.desc)
                    .font(.system(size: 11))
                    .foregroundStyle(.tertiary)
            }

            Spacer()

            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 16))
                .foregroundStyle(.green)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(.green.opacity(0.05), in: RoundedRectangle(cornerRadius: 10))
    }
}
