import SwiftUI

struct StatsWindowView: View {
    @EnvironmentObject var state: AppState
    private let db = Database.shared

    var body: some View {
        TabView {
            statsTab
                .tabItem { Label(L.tabStats, systemImage: "chart.bar.fill") }
            badgesTab
                .tabItem { Label(L.tabBadges, systemImage: "medal.fill") }
        }
    }

    // =========================================================================
    // MARK: - Stats Tab
    // =========================================================================

    private var statsTab: some View {
        let goal = state.config.dailyGoal
        let (wDone, wTotal) = db.weekCompletionRate(goal: goal)
        let (mDone, mTotal) = db.monthCompletionRate(goal: goal)
        let active = db.activeDays()
        let (bestDate, bestCount) = db.bestDayCount()
        let avgDaily = active > 0 ? Double(state.totalCount) / Double(active) : 0
        let firstDate = db.firstRecordDate()
        let usingDays: Int = {
            guard let first = firstDate else { return 0 }
            let fmt = DateFormatter()
            fmt.dateFormat = "yyyy-MM-dd"
            guard let d = fmt.date(from: first) else { return 0 }
            return max(1, (Calendar.current.dateComponents([.day], from: d, to: Date()).day ?? 0) + 1)
        }()

        return VStack(spacing: 0) {
            VStack(spacing: 12) {
                // Top: stat cards — 2 rows of 4
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 4), spacing: 8) {
                    statCard(
                        value: "\(state.todayDone)/\(goal)",
                        label: L.todayDone,
                        icon: "checkmark.circle.fill",
                        color: .green,
                        progress: Double(state.todayDone) / Double(max(goal, 1))
                    )
                    statCard(value: "\(state.currentStreak)", label: L.currentStreak, icon: "flame.fill", color: .orange)
                    statCard(value: "\(state.maxStreak)", label: L.maxStreak, icon: "crown.fill", color: .yellow)
                    statCard(value: "\(state.totalCount)", label: L.isZhAccess ? "累计" : "Total", icon: "sum", color: .cyan)
                    statCard(value: "\(wDone)/\(wTotal)", label: L.weekGoal, icon: "calendar", color: .purple)
                    statCard(value: "\(mDone)/\(mTotal)", label: L.monthGoal, icon: "calendar.badge.checkmark", color: .pink)
                    statCard(value: String(format: "%.1f", avgDaily), label: L.avgDaily, icon: "divide", color: .teal)
                    statCard(value: "\(bestCount)", label: L.bestDay, icon: "trophy.fill", color: .mint)
                }
                .padding(.horizontal, 20)

                // Middle: week chart + summary side by side
                HStack(spacing: 12) {
                    weekChart
                        .padding(.horizontal, 14)
                        .padding(.vertical, 12)
                        .background(.quaternary.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))

                    VStack(alignment: .leading, spacing: 12) {
                        Text(L.isZhAccess ? "概览" : "Overview")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(.secondary)

                        summaryRow(icon: "calendar.badge.clock", label: L.usingDays, value: "\(usingDays)", color: .blue)
                        summaryRow(icon: "sun.max.fill", label: L.activeDays, value: "\(active)", color: .orange)
                        summaryRow(icon: "trophy.fill", label: L.bestDay, value: bestDate.isEmpty ? "-" : "\(shortDate(bestDate)) (\(bestCount))", color: .mint)

                        Spacer(minLength: 0)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                    .frame(width: 200)
                    .background(.quaternary.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
                }
                .padding(.horizontal, 20)

                // Heatmap — full width
                heatmapSection
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                    .background(.quaternary.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
                    .padding(.horizontal, 20)
            }
            .padding(.top, 12)

            Spacer(minLength: 0)

            // Encourage
            Text(state.encourageText)
                .font(.system(size: 13))
                .foregroundStyle(.green)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(.green.opacity(0.04))
        }
    }

    private func summaryRow(icon: String, label: String, value: String, color: Color) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 12))
                .foregroundStyle(color)
                .frame(width: 20)
            VStack(alignment: .leading, spacing: 1) {
                Text(label)
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
                Text(value)
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
            }
            Spacer()
        }
    }

    // MARK: - Stat Card

    private func statCard(value: String, label: String, icon: String, color: Color, progress: Double? = nil) -> some View {
        VStack(spacing: 4) {
            ZStack {
                Circle()
                    .fill(color.opacity(0.1))
                    .frame(width: 30, height: 30)

                if let progress {
                    Circle()
                        .trim(from: 0, to: min(1, progress))
                        .stroke(color.opacity(0.5), style: StrokeStyle(lineWidth: 2, lineCap: .round))
                        .frame(width: 30, height: 30)
                        .rotationEffect(.degrees(-90))
                }

                Image(systemName: icon)
                    .font(.system(size: 12))
                    .foregroundStyle(color)
            }

            Text(value)
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .monospacedDigit()

            Text(label)
                .font(.system(size: 10))
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(.quaternary.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
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

            HStack(alignment: .bottom, spacing: 8) {
                ForEach(Array(data.enumerated()), id: \.offset) { _, item in
                    VStack(spacing: 4) {
                        if item.1 > 0 {
                            Text("\(item.1)")
                                .font(.system(size: 11, weight: .semibold, design: .rounded))
                                .foregroundStyle(item.1 >= goal ? .green : .secondary)
                        } else {
                            Text(" ").font(.system(size: 11))
                        }

                        RoundedRectangle(cornerRadius: 5)
                            .fill(barColor(count: item.1, goal: goal))
                            .frame(maxWidth: 50)
                            .frame(height: item.1 == 0 ? 4 : max(14, CGFloat(item.1) / CGFloat(maxVal) * 100))

                        Text(shortDay(item.0))
                            .font(.system(size: 10))
                            .foregroundStyle(.tertiary)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .frame(height: 140)
        }
        .frame(maxWidth: .infinity)
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
        let cols = 10

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
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: cols), spacing: 4) {
                    ForEach(Array(data.enumerated()), id: \.offset) { _, item in
                        let ratio = Double(item.1) / Double(max(goal, 1))
                        RoundedRectangle(cornerRadius: 4)
                            .fill(heatColor(ratio: ratio))
                            .aspectRatio(1, contentMode: .fit)
                            .overlay(
                                VStack(spacing: 1) {
                                    Text(heatDay(item.0))
                                        .font(.system(size: 10))
                                        .foregroundStyle(item.1 > 0 ? .white.opacity(0.7) : .primary.opacity(0.2))
                                    if item.1 > 0 {
                                        Text("\(item.1)")
                                            .font(.system(size: 9, weight: .semibold, design: .rounded))
                                            .foregroundStyle(.white.opacity(0.8))
                                    }
                                }
                            )
                            .help("\(shortDate(item.0)): \(item.1)")
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
                }
                .padding(.top, 4)
            }
        }
        .frame(maxWidth: .infinity)
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

    // =========================================================================
    // MARK: - Badges Tab
    // =========================================================================

    private var badgesTab: some View {
        let gold = Color(red: 0.82, green: 0.68, blue: 0.30)
        let earnedStreakDays = Set(allBadges.filter { state.maxStreak >= $0.days }.map(\.days))
        let earnedTotalDays = Set(state.earnedTotalBadges.map(\.days))
        let allEarnedCount = earnedStreakDays.count + earnedTotalDays.count
        let allTotal = allBadges.count + allTotalBadges.count

        let nextStreakBadge = allBadges.first(where: { state.maxStreak < $0.days })
        let nextTotalBadge = state.nextTotalBadge
        let streakDaysLeft = nextStreakBadge.map { $0.days - state.maxStreak }
        let totalDaysLeft = nextTotalBadge.map { $0.days - state.totalCount }
        let closestIsStreak: Bool
        if let s = streakDaysLeft, let t = totalDaysLeft {
            closestIsStreak = s <= t
        } else {
            closestIsStreak = streakDaysLeft != nil
        }

        return VStack(spacing: 0) {
            // Collection progress
            VStack(spacing: 8) {
                HStack {
                    Text(L.earnedBadges)
                        .font(.system(size: 14, weight: .semibold))
                    Spacer()
                    Text("\(allEarnedCount) / \(allTotal)")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundStyle(gold)
                }

                // Progress bar
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(gold.opacity(0.12))
                        RoundedRectangle(cornerRadius: 4)
                            .fill(
                                LinearGradient(
                                    colors: [gold.opacity(0.6), gold],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: geo.size.width * CGFloat(allEarnedCount) / CGFloat(max(allTotal, 1)))
                    }
                }
                .frame(height: 8)
            }
            .padding(.horizontal, 28)
            .padding(.top, 16)
            .padding(.bottom, 12)

            Divider().padding(.horizontal, 24)

            // Badge grid
            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 20) {
                    badgeWallSection(
                        title: L.streakBadges,
                        icon: "flame.fill",
                        badges: allBadges,
                        earnedDays: earnedStreakDays,
                        currentValue: state.maxStreak
                    )
                    badgeWallSection(
                        title: L.totalBadges,
                        icon: "star.fill",
                        badges: allTotalBadges,
                        earnedDays: earnedTotalDays,
                        currentValue: state.totalCount
                    )
                }
                .padding(.horizontal, 28)
                .padding(.vertical, 16)
            }

            // Next goal
            if closestIsStreak, let next = nextStreakBadge {
                nextBadgeCard(badge: next, current: state.maxStreak, label: L.daysToUnlock(next.days - state.maxStreak))
            } else if let next = nextTotalBadge {
                nextBadgeCard(badge: next, current: state.totalCount, label: L.daysToUnlock(next.days - state.totalCount))
            }
        }
    }

    // MARK: - Badge Wall Section

    private func badgeWallSection(title: String, icon: String, badges: [Badge], earnedDays: Set<Int>, currentValue: Int) -> some View {
        let gold = Color(red: 0.82, green: 0.68, blue: 0.30)
        let columns = Array(repeating: GridItem(.flexible(), spacing: 16), count: 6)

        return VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 11))
                    .foregroundStyle(gold)
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(gold)
                Spacer()
                let earned = badges.filter { earnedDays.contains($0.days) }.count
                Text("\(earned)/\(badges.count)")
                    .font(.system(size: 11, design: .rounded))
                    .foregroundStyle(.tertiary)
            }

            LazyVGrid(columns: columns, spacing: 16) {
                ForEach(Array(badges.enumerated()), id: \.offset) { _, badge in
                    let isEarned = earnedDays.contains(badge.days)
                    let progress = isEarned ? 1.0 : min(1.0, Double(currentValue) / Double(badge.days))
                    badgeWallCell(badge: badge, earned: isEarned, progress: progress)
                }
            }
        }
    }

    private func badgeWallCell(badge: Badge, earned: Bool, progress: Double) -> some View {
        let gold = Color(red: 0.82, green: 0.68, blue: 0.30)

        return VStack(spacing: 5) {
            ZStack {
                // Background ring showing progress for locked badges
                if earned {
                    Circle()
                        .fill(gold.opacity(0.1))
                        .frame(width: 56, height: 56)
                    // Golden ring for earned
                    Circle()
                        .strokeBorder(
                            LinearGradient(
                                colors: [gold.opacity(0.6), gold, gold.opacity(0.6)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 2
                        )
                        .frame(width: 56, height: 56)
                } else {
                    // Gray background + progress arc
                    Circle()
                        .fill(Color.gray.opacity(0.06))
                        .frame(width: 56, height: 56)
                    Circle()
                        .stroke(Color.gray.opacity(0.1), lineWidth: 2)
                        .frame(width: 56, height: 56)
                    Circle()
                        .trim(from: 0, to: progress)
                        .stroke(gold.opacity(0.3), style: StrokeStyle(lineWidth: 2, lineCap: .round))
                        .frame(width: 56, height: 56)
                        .rotationEffect(.degrees(-90))
                }

                // Icon: show emoji for all, but gray out locked ones
                Text(badge.icon)
                    .font(.system(size: 28))
                    .saturation(earned ? 1 : 0)
                    .opacity(earned ? 1 : 0.3)
            }

            Text(badge.name)
                .font(.system(size: 10, weight: earned ? .semibold : .regular))
                .foregroundStyle(earned ? .primary : .tertiary)
                .lineLimit(1)

            Text(badge.desc)
                .font(.system(size: 8))
                .foregroundStyle(earned ? .secondary : .quaternary)
                .lineLimit(1)
        }
        .contentShape(Rectangle())
        .onTapGesture {
            if earned {
                state.showBadgeCelebration(badge)
            }
        }
    }

    // MARK: - Next Badge Card

    private func nextBadgeCard(badge: Badge, current: Int, label: String) -> some View {
        let gold = Color(red: 0.82, green: 0.68, blue: 0.30)
        return VStack(spacing: 6) {
            HStack(spacing: 6) {
                Text("🎯")
                    .font(.system(size: 16))
                Text(L.nextGoal)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(gold)
            }

            let progress = min(1.0, Double(current) / Double(badge.days))
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(.quaternary)
                    RoundedRectangle(cornerRadius: 3)
                        .fill(gold.gradient)
                        .frame(width: geo.size.width * progress)
                }
            }
            .frame(height: 6)

            Text(label)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(gold.opacity(0.06), in: RoundedRectangle(cornerRadius: 10))
        .padding(.horizontal, 28)
        .padding(.bottom, 12)
    }
}
