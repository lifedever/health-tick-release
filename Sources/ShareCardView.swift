import SwiftUI

// MARK: - Data struct for ImageRenderer (no @EnvironmentObject)

struct ShareCardData {
    let todayDone: Int
    let dailyGoal: Int
    let currentStreak: Int
    let maxStreak: Int
    let totalCount: Int
    let todayWorkMinutes: Int
    let weekData: [(String, Int)]
    let earnedBadge: Badge?
    let nextBadge: Badge?
    let dateString: String

    @MainActor
    init(from state: AppState) {
        self.todayDone = state.todayDone
        self.dailyGoal = state.config.dailyGoal
        self.currentStreak = state.currentStreak
        self.maxStreak = state.maxStreak
        self.totalCount = state.totalCount
        self.todayWorkMinutes = state.todayWorkMinutes
        self.weekData = state.weekData
        self.earnedBadge = state.earnedBadge
        self.nextBadge = state.nextBadge
        self.dateString = Database.todayString()
    }

    /// Init for a specific date, loading data directly from DB
    @MainActor
    init(forDate dateString: String, goal: Int, state: AppState) {
        let db = Database.shared
        let fmt = Database.dateFmt()
        let date = fmt.date(from: dateString) ?? Date()

        self.dateString = dateString
        self.dailyGoal = goal
        self.todayDone = db.countForDate(dateString)
        self.todayWorkMinutes = db.workMinutesForDate(dateString)
        self.weekData = db.recent7DaysCountsEndingOn(date)
        // These are global stats, not date-specific
        self.currentStreak = state.currentStreak
        self.maxStreak = state.maxStreak
        self.totalCount = state.totalCount
        self.earnedBadge = state.earnedBadge
        self.nextBadge = state.nextBadge
    }
}

// MARK: - Share Card View

struct ShareCardView: View {
    let data: ShareCardData

    private let cardWidth: CGFloat = 375
    private let cardHeight: CGFloat = 580

    // Colors
    private let accentGreen = Color(red: 0.20, green: 0.83, blue: 0.60)
    private let badgeGold = Color(red: 0.85, green: 0.70, blue: 0.32)
    private let softCyan = Color(red: 0.30, green: 0.80, blue: 0.90)
    private let warmOrange = Color(red: 0.95, green: 0.60, blue: 0.25)

    private var goalReached: Bool { data.todayDone >= data.dailyGoal }
    private var progress: Double {
        guard data.dailyGoal > 0 else { return 0 }
        return min(1.0, Double(data.todayDone) / Double(data.dailyGoal))
    }

    var body: some View {
        ZStack {
            background

            VStack(spacing: 0) {
                // Header: app name + date
                dateHeader
                    .padding(.top, 24)

                // Progress ring
                progressRing
                    .padding(.top, 14)

                // Goal status text
                Text(goalReached ? L.shareGoalReached : L.shareKeepGoing)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.85))
                    .padding(.top, 10)

                // Text-based stats list
                statsList
                    .padding(.top, 18)

                // 7-day activity
                weekActivity
                    .padding(.top, 16)

                // Earned badge
                if let badge = data.earnedBadge {
                    HStack(spacing: 6) {
                        Text(badge.icon)
                            .font(.system(size: 16))
                        Text(L.isZhAccess ? "已获得：\(badge.name)" : "Earned: \(badge.name)")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(badgeGold)
                    }
                    .padding(.top, 12)
                }

                Spacer(minLength: 8)

                // Footer
                footer
                    .padding(.bottom, 18)
            }
        }
        .frame(width: cardWidth, height: cardHeight)
        .clipShape(RoundedRectangle(cornerRadius: 4))
    }

    // MARK: - Background

    private var background: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.07, green: 0.15, blue: 0.12),
                    Color(red: 0.04, green: 0.09, blue: 0.07),
                    Color(red: 0.02, green: 0.06, blue: 0.05),
                ],
                startPoint: .top,
                endPoint: .bottom
            )

            // Glow behind ring
            Circle()
                .fill(
                    RadialGradient(
                        colors: [accentGreen.opacity(0.12), .clear],
                        center: .center,
                        startRadius: 20,
                        endRadius: 160
                    )
                )
                .frame(width: 320, height: 320)
                .offset(y: -80)

            // Decorative glow
            Circle()
                .fill(
                    RadialGradient(
                        colors: [softCyan.opacity(0.05), .clear],
                        center: .center,
                        startRadius: 10,
                        endRadius: 100
                    )
                )
                .frame(width: 200, height: 200)
                .offset(x: 140, y: -200)
        }
    }

    // MARK: - Header

    private var dateHeader: some View {
        HStack(spacing: 6) {
            Image(systemName: "figure.walk")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(accentGreen)
            Text("HealthTick")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(.white.opacity(0.7))
            Spacer()
            Text(formatDisplayDate(data.dateString))
                .font(.system(size: 11))
                .foregroundStyle(.white.opacity(0.35))
        }
        .padding(.horizontal, 28)
    }

    // MARK: - Progress Ring

    private var progressRing: some View {
        ZStack {
            Circle()
                .stroke(accentGreen.opacity(0.06), lineWidth: 18)
            Circle()
                .stroke(.white.opacity(0.05), lineWidth: 8)
            Circle()
                .trim(from: 0, to: progress)
                .stroke(
                    AngularGradient(
                        colors: [accentGreen.opacity(0.3), accentGreen],
                        center: .center,
                        startAngle: .degrees(-90),
                        endAngle: .degrees(-90 + 360 * progress)
                    ),
                    style: StrokeStyle(lineWidth: 8, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))

            VStack(spacing: 2) {
                if goalReached {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 13))
                        .foregroundStyle(accentGreen)
                        .padding(.bottom, 1)
                }
                HStack(alignment: .firstTextBaseline, spacing: 2) {
                    Text("\(data.todayDone)")
                        .font(.system(size: 36, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                    Text("/ \(data.dailyGoal)")
                        .font(.system(size: 16, weight: .medium, design: .rounded))
                        .foregroundStyle(.white.opacity(0.3))
                }
                Text(L.isZhAccess ? "今日休息次数" : "Breaks Today")
                    .font(.system(size: 10))
                    .foregroundStyle(.white.opacity(0.4))
            }
        }
        .frame(width: 130, height: 130)
    }

    // MARK: - Stats List (text-based)

    private var statsList: some View {
        VStack(spacing: 0) {
            statsTextRow(
                label: L.isZhAccess ? "今日工作时长" : "Work Time Today",
                value: L.formatWorkTime(data.todayWorkMinutes),
                color: .blue
            )
            dividerLine()
            statsTextRow(
                label: L.isZhAccess ? "今日完成打卡" : "Check-ins Today",
                value: L.isZhAccess ? "\(data.todayDone) / \(data.dailyGoal) 次" : "\(data.todayDone) / \(data.dailyGoal)",
                color: goalReached ? accentGreen : warmOrange
            )
            dividerLine()
            statsTextRow(
                label: L.isZhAccess ? "累计健康打卡" : "Total Check-ins",
                value: L.isZhAccess ? "\(data.totalCount) 次" : "\(data.totalCount) times",
                color: softCyan
            )
            if let next = data.nextBadge {
                dividerLine()
                let remaining = next.days - data.currentStreak
                statsTextRow(
                    label: L.isZhAccess ? "距离 \(next.icon)\(next.name)" : "\(next.icon) \(next.name) in",
                    value: L.isZhAccess ? "还差 \(remaining) 天" : "\(remaining) days",
                    color: badgeGold
                )
            }
        }
        .padding(.vertical, 4)
        .background(.white.opacity(0.04), in: RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal, 24)
    }

    private func statsTextRow(label: String, value: String, color: Color) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 13))
                .foregroundStyle(.white.opacity(0.55))
            Spacer()
            Text(value)
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .foregroundStyle(color)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    private func dividerLine() -> some View {
        Rectangle()
            .fill(.white.opacity(0.06))
            .frame(height: 1)
            .padding(.horizontal, 16)
    }

    // MARK: - 7-Day Activity

    private var weekActivity: some View {
        VStack(spacing: 8) {
            HStack {
                Text(L.isZhAccess ? "最近 7 天打卡" : "Last 7 Days")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.white.opacity(0.35))
                Spacer()
            }

            HStack(spacing: 6) {
                ForEach(Array(data.weekData.enumerated()), id: \.offset) { _, item in
                    VStack(spacing: 4) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 4)
                                .fill(.white.opacity(0.04))
                                .frame(width: 34, height: 34)
                            RoundedRectangle(cornerRadius: 4)
                                .fill(barFill(count: item.1))
                                .frame(width: 34, height: 34)
                            Text("\(item.1)")
                                .font(.system(size: 12, weight: .bold, design: .monospaced))
                                .foregroundStyle(item.1 > 0 ? .white : .white.opacity(0.15))
                        }
                        Text(shortDay(item.0))
                            .font(.system(size: 9))
                            .foregroundStyle(.white.opacity(0.3))
                    }
                }
            }
        }
        .padding(.horizontal, 28)
    }

    private func barFill(count: Int) -> some ShapeStyle {
        if count == 0 { return AnyShapeStyle(.clear) }
        let ratio = Double(count) / Double(max(data.dailyGoal, 1))
        if ratio >= 1.0 { return AnyShapeStyle(accentGreen.gradient) }
        if ratio >= 0.5 { return AnyShapeStyle(accentGreen.opacity(0.45)) }
        return AnyShapeStyle(accentGreen.opacity(0.25))
    }

    private func shortDay(_ dateStr: String) -> String {
        let parts = dateStr.split(separator: "-")
        guard parts.count == 3, let d = Int(parts[2]) else { return "" }
        return "\(d)"
    }

    // MARK: - Footer

    private var footer: some View {
        VStack(spacing: 3) {
            HStack(spacing: 6) {
                footerLine()
                Text("HealthTick")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.2))
                footerLine()
            }
            Text(L.appSubtitle)
                .font(.system(size: 8))
                .foregroundStyle(.white.opacity(0.15))
        }
        .padding(.horizontal, 60)
    }

    private func footerLine() -> some View {
        Rectangle()
            .fill(.white.opacity(0.1))
            .frame(height: 0.5)
    }

    // MARK: - Helpers

    private func formatDisplayDate(_ dateStr: String) -> String {
        let parts = dateStr.split(separator: "-")
        guard parts.count == 3 else { return dateStr }
        if L.isZhAccess {
            return "\(parts[0])年\(Int(parts[1]) ?? 0)月\(Int(parts[2]) ?? 0)日"
        }
        let months = ["", "Jan", "Feb", "Mar", "Apr", "May", "Jun",
                       "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
        let m = Int(parts[1]) ?? 0
        return "\(months[m]) \(Int(parts[2]) ?? 0), \(parts[0])"
    }
}
