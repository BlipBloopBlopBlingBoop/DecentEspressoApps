//
//  AnalyticsView.swift
//  Good Espresso
//
//  Full ML-powered analytics dashboard with customizable cards.
//  All computation runs on-device via Accelerate (vDSP).
//

import SwiftUI

// MARK: - Dashboard Card Types

enum AnalyticsCard: String, CaseIterable, Identifiable, Codable {
    case scoreTimeline   = "Score Timeline"
    case overviewStats   = "Overview"
    case pressureChart   = "Pressure Trends"
    case flowChart       = "Flow Trends"
    case tempChart       = "Temperature Trends"
    case scoreDist       = "Score Distribution"
    case durationDist    = "Shot Duration"
    case profileRanking  = "Profile Ranking"
    case bestShots       = "Best Shots"
    case channelingRate  = "Channeling Rate"
    case weeklyProgress  = "Weekly Progress"
    case shotComparison  = "Shot Comparison"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .scoreTimeline:  return "chart.line.uptrend.xyaxis"
        case .overviewStats:  return "square.grid.2x2"
        case .pressureChart:  return "gauge.with.needle.fill"
        case .flowChart:      return "drop.fill"
        case .tempChart:      return "thermometer.medium"
        case .scoreDist:      return "chart.bar.fill"
        case .durationDist:   return "timer"
        case .profileRanking: return "list.number"
        case .bestShots:      return "trophy.fill"
        case .channelingRate: return "exclamationmark.triangle.fill"
        case .weeklyProgress: return "calendar"
        case .shotComparison: return "arrow.left.arrow.right"
        }
    }

    var color: Color {
        switch self {
        case .scoreTimeline:  return .purple
        case .overviewStats:  return .orange
        case .pressureChart:  return .blue
        case .flowChart:      return .cyan
        case .tempChart:      return .orange
        case .scoreDist:      return .green
        case .durationDist:   return .indigo
        case .profileRanking: return .mint
        case .bestShots:      return .yellow
        case .channelingRate: return .red
        case .weeklyProgress: return .purple
        case .shotComparison: return .blue
        }
    }
}

// MARK: - Main Analytics View

struct AnalyticsView: View {
    @EnvironmentObject var machineStore: MachineStore
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @State private var dashboard: DashboardAnalytics?
    @State private var visibleCards: Set<AnalyticsCard> = Set(AnalyticsCard.allCases)
    @State private var showingCardPicker = false
    @State private var comparisonShotA: Int = 0
    @State private var comparisonShotB: Int = 1

    private var isCompact: Bool { horizontalSizeClass == .compact }

    var body: some View {
        NavigationStack {
            Group {
                if machineStore.shotHistory.isEmpty {
                    emptyState
                } else if let dashboard = dashboard {
                    dashboardContent(dashboard)
                } else {
                    loadingState
                }
            }
            .background(Color.systemGroupedBg)
            .navigationTitle("Analytics")
            .toolbar {
                ToolbarItem(placement: .topBarTrailingCompat) {
                    Button {
                        showingCardPicker = true
                    } label: {
                        Image(systemName: "slider.horizontal.3")
                    }
                }
            }
            .sheet(isPresented: $showingCardPicker) {
                CardPickerSheet(visibleCards: $visibleCards)
            }
            .task {
                await computeAnalytics()
            }
        }
    }

    // MARK: - Empty State

    var emptyState: some View {
        VStack(spacing: 20) {
            Image(systemName: "brain.head.profile.fill")
                .font(.system(size: 60))
                .foregroundStyle(.purple)

            Text("No Data Yet")
                .font(.title2)
                .fontWeight(.semibold)

            Text("Start brewing to see ML-powered analytics.\nAll analysis runs locally on your device.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
    }

    // MARK: - Loading State

    var loadingState: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.5)
            Text("Crunching your shot data...")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Dashboard Content

    func dashboardContent(_ data: DashboardAnalytics) -> some View {
        ScrollView {
            if isCompact {
                compactDashboard(data)
            } else {
                wideDashboard(data)
            }
        }
    }

    // MARK: - Compact (iPhone)

    func compactDashboard(_ data: DashboardAnalytics) -> some View {
        LazyVStack(spacing: 16) {
            if visibleCards.contains(.overviewStats)   { OverviewStatsCard(data: data) }
            if visibleCards.contains(.scoreTimeline)    { ScoreTimelineCard(data: data) }
            if visibleCards.contains(.scoreDist)        { ScoreDistributionCard(data: data) }
            if visibleCards.contains(.pressureChart)    { MetricTrendCard(title: "Pressure Trends", unit: "bar", values: data.avgPressures, color: .blue) }
            if visibleCards.contains(.flowChart)        { MetricTrendCard(title: "Flow Trends", unit: "ml/s", values: data.avgFlows, color: .cyan) }
            if visibleCards.contains(.tempChart)        { MetricTrendCard(title: "Temperature Trends", unit: "\u{00B0}C", values: data.avgTemps, color: .orange) }
            if visibleCards.contains(.durationDist)     { DurationDistCard(data: data) }
            if visibleCards.contains(.profileRanking)   { ProfileRankingCard(data: data) }
            if visibleCards.contains(.bestShots)        { BestShotsCard(data: data) }
            if visibleCards.contains(.channelingRate)   { ChannelingRateCard(data: data) }
            if visibleCards.contains(.weeklyProgress)   { WeeklyProgressCard(data: data) }
            if visibleCards.contains(.shotComparison)   { ShotComparisonCard(data: data, indexA: $comparisonShotA, indexB: $comparisonShotB) }
        }
        .padding()
    }

    // MARK: - Wide (iPad / macOS)

    func wideDashboard(_ data: DashboardAnalytics) -> some View {
        LazyVStack(spacing: 20) {
            // Top row: overview + score timeline
            if visibleCards.contains(.overviewStats) || visibleCards.contains(.scoreTimeline) {
                HStack(alignment: .top, spacing: 20) {
                    if visibleCards.contains(.overviewStats)  { OverviewStatsCard(data: data).frame(maxWidth: .infinity) }
                    if visibleCards.contains(.scoreTimeline)  { ScoreTimelineCard(data: data).frame(maxWidth: .infinity) }
                }
            }

            // Second row: metric trends
            let metricCards = [
                (visibleCards.contains(.pressureChart), "Pressure Trends", "bar", data.avgPressures, Color.blue),
                (visibleCards.contains(.flowChart),     "Flow Trends",     "ml/s", data.avgFlows,     Color.cyan),
                (visibleCards.contains(.tempChart),     "Temperature Trends", "\u{00B0}C", data.avgTemps, Color.orange)
            ].filter { $0.0 }

            if !metricCards.isEmpty {
                HStack(alignment: .top, spacing: 20) {
                    ForEach(metricCards, id: \.1) { card in
                        MetricTrendCard(title: card.1, unit: card.2, values: card.3, color: card.4)
                            .frame(maxWidth: .infinity)
                    }
                }
            }

            // Third row: distributions + ranking
            if visibleCards.contains(.scoreDist) || visibleCards.contains(.durationDist) || visibleCards.contains(.profileRanking) {
                HStack(alignment: .top, spacing: 20) {
                    if visibleCards.contains(.scoreDist)      { ScoreDistributionCard(data: data).frame(maxWidth: .infinity) }
                    if visibleCards.contains(.durationDist)   { DurationDistCard(data: data).frame(maxWidth: .infinity) }
                    if visibleCards.contains(.profileRanking) { ProfileRankingCard(data: data).frame(maxWidth: .infinity) }
                }
            }

            // Fourth row: best shots + channeling + weekly
            if visibleCards.contains(.bestShots) || visibleCards.contains(.channelingRate) || visibleCards.contains(.weeklyProgress) {
                HStack(alignment: .top, spacing: 20) {
                    if visibleCards.contains(.bestShots)      { BestShotsCard(data: data).frame(maxWidth: .infinity) }
                    if visibleCards.contains(.channelingRate) { ChannelingRateCard(data: data).frame(maxWidth: .infinity) }
                    if visibleCards.contains(.weeklyProgress) { WeeklyProgressCard(data: data).frame(maxWidth: .infinity) }
                }
            }

            // Shot comparison full-width
            if visibleCards.contains(.shotComparison) {
                ShotComparisonCard(data: data, indexA: $comparisonShotA, indexB: $comparisonShotB)
            }
        }
        .padding()
        .frame(maxWidth: 1400)
        .frame(maxWidth: .infinity)
    }

    func computeAnalytics() async {
        let shots = machineStore.shotHistory
        let result = await Task.detached {
            ShotAnalyzer.computeDashboard(shots)
        }.value
        dashboard = result
    }
}

// MARK: - Card Picker Sheet

struct CardPickerSheet: View {
    @Binding var visibleCards: Set<AnalyticsCard>
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(AnalyticsCard.allCases) { card in
                        Toggle(isOn: Binding(
                            get: { visibleCards.contains(card) },
                            set: { on in
                                if on { visibleCards.insert(card) }
                                else { visibleCards.remove(card) }
                            }
                        )) {
                            Label(card.rawValue, systemImage: card.icon)
                                .foregroundStyle(card.color)
                        }
                    }
                } header: {
                    Text("Toggle dashboard cards")
                }

                Section {
                    Button("Show All") {
                        visibleCards = Set(AnalyticsCard.allCases)
                    }
                    Button("Hide All") {
                        visibleCards = []
                    }
                }
            }
            .navigationTitle("Customize Dashboard")
            .inlineNavigationBarTitle()
            .toolbar {
                ToolbarItem(placement: .topBarTrailingCompat) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

// MARK: - Overview Stats Card

struct OverviewStatsCard: View {
    let data: DashboardAnalytics

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            cardHeader("Overview", icon: "square.grid.2x2", color: .orange)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                BigStat(value: "\(data.trend.shotCount)", label: "Total Shots", icon: "cup.and.saucer.fill", color: .orange)
                BigStat(value: "\(data.trend.averageScore)", label: "Avg Score", icon: "brain", color: scoreColor(data.trend.averageScore))
                BigStat(value: "\(Int(data.channelingRate * 100))%", label: "Channeling Rate", icon: "exclamationmark.triangle", color: data.channelingRate > 0.3 ? .red : .green)
                BigStat(value: trendLabel(data.trend.trend), label: "Trend", icon: trendIcon(data.trend.trend), color: trendColor(data.trend.trend))
            }
        }
        .analyticsCard()
    }
}

struct BigStat: View {
    let value: String
    let label: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(color)
            Text(value)
                .font(.title2)
                .fontWeight(.bold)
                .monospacedDigit()
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
    }
}

// MARK: - Score Timeline Card

struct ScoreTimelineCard: View {
    let data: DashboardAnalytics
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    private var chartHeight: CGFloat {
        horizontalSizeClass == .compact ? 200 : 280
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            cardHeader("Score Timeline", icon: "chart.line.uptrend.xyaxis", color: .purple)

            if data.scoreHistory.count >= 2 {
                AreaChart(
                    values: data.scoreHistory.map { Double($0.score) },
                    color: .purple,
                    minValue: 0,
                    maxValue: 100,
                    showGrid: true,
                    gridLabels: ["0", "25", "50", "75", "100"]
                )
                .frame(minHeight: chartHeight)
            } else {
                Text("Need at least 2 shots")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, minHeight: 120)
            }
        }
        .analyticsCard()
    }
}

// MARK: - Metric Trend Card (Pressure / Flow / Temperature)

struct MetricTrendCard: View {
    let title: String
    let unit: String
    let values: [Double]
    let color: Color
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    private var chartHeight: CGFloat {
        horizontalSizeClass == .compact ? 160 : 200
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(title)
                    .font(.headline)
                Spacer()
                if let last = values.first {
                    Text(String(format: "%.1f %@", last, unit))
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundStyle(color)
                }
            }

            if values.count >= 2 {
                // Reverse so oldest is left
                let reversed = Array(values.reversed())
                AreaChart(values: reversed, color: color, minValue: nil, maxValue: nil, showGrid: false, gridLabels: [])
                    .frame(minHeight: chartHeight)
            } else {
                Text("Need more shots")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, minHeight: 80)
            }
        }
        .analyticsCard()
    }
}

// MARK: - Score Distribution Card

struct ScoreDistributionCard: View {
    let data: DashboardAnalytics

    private let labels = ["0-9", "10-19", "20-29", "30-39", "40-49", "50-59", "60-69", "70-79", "80-89", "90-100"]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            cardHeader("Score Distribution", icon: "chart.bar.fill", color: .green)

            BarChart(
                values: data.scoreDistribution.map { Double($0) },
                labels: labels,
                color: .green
            )
            .frame(minHeight: 160)
        }
        .analyticsCard()
    }
}

// MARK: - Duration Distribution Card

struct DurationDistCard: View {
    let data: DashboardAnalytics

    private let labels = ["<15", "15-20", "20-25", "25-30", "30-35", "35-40", "40-45", ">45"]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                cardHeader("Shot Duration", icon: "timer", color: .indigo)
            }

            BarChart(
                values: data.durationDistribution.map { Double($0) },
                labels: labels,
                color: .indigo,
                highlightIndex: 3 // 25-30s is the sweet spot
            )
            .frame(minHeight: 160)

            Text("Sweet spot: 25-30 seconds")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .analyticsCard()
    }
}

// MARK: - Profile Ranking Card

struct ProfileRankingCard: View {
    let data: DashboardAnalytics

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            cardHeader("Profile Ranking", icon: "list.number", color: .mint)

            if data.profilePerformance.isEmpty {
                Text("No profile data")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(Array(data.profilePerformance.prefix(8).enumerated()), id: \.offset) { index, profile in
                    HStack(spacing: 12) {
                        Text("#\(index + 1)")
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundStyle(.secondary)
                            .frame(width: 24)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(profile.name)
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .lineLimit(1)
                            Text("\(profile.count) shots")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        ZStack {
                            Circle()
                                .stroke(scoreColor(profile.avgScore).opacity(0.2), lineWidth: 4)
                            Circle()
                                .trim(from: 0, to: Double(profile.avgScore) / 100.0)
                                .stroke(scoreColor(profile.avgScore), style: StrokeStyle(lineWidth: 4, lineCap: .round))
                                .rotationEffect(.degrees(-90))
                            Text("\(profile.avgScore)")
                                .font(.caption)
                                .fontWeight(.bold)
                                .monospacedDigit()
                        }
                        .frame(width: 40, height: 40)
                    }

                    if index < min(data.profilePerformance.count, 8) - 1 {
                        Divider()
                    }
                }
            }
        }
        .analyticsCard()
    }
}

// MARK: - Best Shots Card

struct BestShotsCard: View {
    let data: DashboardAnalytics

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            cardHeader("Best Shots", icon: "trophy.fill", color: .yellow)

            ForEach(Array(data.bestShots.enumerated()), id: \.offset) { index, entry in
                HStack(spacing: 12) {
                    Image(systemName: index == 0 ? "trophy.fill" : "medal.fill")
                        .foregroundStyle(index == 0 ? .yellow : .orange.opacity(0.6))
                        .frame(width: 22)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(entry.shot.profileName)
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .lineLimit(1)
                        Text(formatDate(entry.shot.startTime))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Text("\(entry.score)")
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundStyle(scoreColor(entry.score))
                }

                if index < data.bestShots.count - 1 { Divider() }
            }
        }
        .analyticsCard()
    }
}

// MARK: - Channeling Rate Card

struct ChannelingRateCard: View {
    let data: DashboardAnalytics

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            cardHeader("Channeling Rate", icon: "exclamationmark.triangle.fill", color: .red)

            HStack(spacing: 20) {
                // Big gauge
                ZStack {
                    Circle()
                        .stroke(Color.red.opacity(0.12), lineWidth: 10)
                    Circle()
                        .trim(from: 0, to: data.channelingRate)
                        .stroke(
                            data.channelingRate > 0.3 ? Color.red : (data.channelingRate > 0.15 ? Color.yellow : Color.green),
                            style: StrokeStyle(lineWidth: 10, lineCap: .round)
                        )
                        .rotationEffect(.degrees(-90))
                    VStack(spacing: 0) {
                        Text("\(Int(data.channelingRate * 100))%")
                            .font(.title2)
                            .fontWeight(.bold)
                            .monospacedDigit()
                        Text("of shots")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(width: 100, height: 100)

                VStack(alignment: .leading, spacing: 8) {
                    let count = data.shotAnalyses.filter { $0.analysis.channelingDetected }.count
                    Text("\(count) of \(data.trend.shotCount) shots")
                        .font(.subheadline)
                        .fontWeight(.medium)

                    if data.channelingRate > 0.3 {
                        Text("Try WDT (Weiss Distribution Technique) for more even puck prep.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else if data.channelingRate > 0 {
                        Text("Occasional channeling is normal. Keep up your distribution technique.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        Text("No channeling detected. Excellent puck prep!")
                            .font(.caption)
                            .foregroundStyle(.green)
                    }
                }
            }
        }
        .analyticsCard()
    }
}

// MARK: - Weekly Progress Card

struct WeeklyProgressCard: View {
    let data: DashboardAnalytics

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            cardHeader("Weekly Progress", icon: "calendar", color: .purple)

            if data.weeklyAverages.count >= 2 {
                BarChart(
                    values: data.weeklyAverages.map { Double($0.score) },
                    labels: data.weeklyAverages.map { $0.week },
                    color: .purple,
                    maxValue: 100
                )
                .frame(minHeight: 160)
            } else {
                Text("Brew across multiple weeks to see progress")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, minHeight: 80)
            }
        }
        .analyticsCard()
    }
}

// MARK: - Shot Comparison Card

struct ShotComparisonCard: View {
    let data: DashboardAnalytics
    @Binding var indexA: Int
    @Binding var indexB: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            cardHeader("Shot Comparison", icon: "arrow.left.arrow.right", color: .blue)

            if data.shotAnalyses.count < 2 {
                Text("Need at least 2 shots to compare")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, minHeight: 80)
            } else {
                let maxIndex = data.shotAnalyses.count - 1
                let safeA = min(indexA, maxIndex)
                let safeB = min(indexB, maxIndex)

                // Pickers
                HStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Shot A")
                            .font(.caption)
                            .foregroundStyle(.blue)
                        Picker("Shot A", selection: $indexA) {
                            ForEach(0...maxIndex, id: \.self) { i in
                                Text(data.shotAnalyses[i].shot.profileName).tag(i)
                            }
                        }
                        .labelsHidden()
                        #if os(iOS)
                        .pickerStyle(.menu)
                        #endif
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Shot B")
                            .font(.caption)
                            .foregroundStyle(.orange)
                        Picker("Shot B", selection: $indexB) {
                            ForEach(0...maxIndex, id: \.self) { i in
                                Text(data.shotAnalyses[i].shot.profileName).tag(i)
                            }
                        }
                        .labelsHidden()
                        #if os(iOS)
                        .pickerStyle(.menu)
                        #endif
                    }
                }

                let a = data.shotAnalyses[safeA].analysis
                let b = data.shotAnalyses[safeB].analysis

                // Side-by-side comparison bars
                ComparisonRow(label: "Score", valueA: Double(a.overallScore), valueB: Double(b.overallScore), maxVal: 100, format: "%.0f")
                ComparisonRow(label: "Pressure", valueA: a.pressureStability * 100, valueB: b.pressureStability * 100, maxVal: 100, format: "%.0f%%")
                ComparisonRow(label: "Flow", valueA: a.flowConsistency * 100, valueB: b.flowConsistency * 100, maxVal: 100, format: "%.0f%%")
                ComparisonRow(label: "Temp", valueA: a.temperatureControl * 100, valueB: b.temperatureControl * 100, maxVal: 100, format: "%.0f%%")
                ComparisonRow(label: "Timing", valueA: a.extractionEfficiency * 100, valueB: b.extractionEfficiency * 100, maxVal: 100, format: "%.0f%%")
            }
        }
        .analyticsCard()
    }
}

struct ComparisonRow: View {
    let label: String
    let valueA: Double
    let valueB: Double
    let maxVal: Double
    let format: String

    var body: some View {
        VStack(spacing: 4) {
            HStack {
                Text(String(format: format, valueA))
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundStyle(.blue)
                    .monospacedDigit()
                    .frame(width: 40, alignment: .trailing)

                GeometryReader { geo in
                    ZStack {
                        // A bar (left-aligned, blue)
                        HStack(spacing: 0) {
                            RoundedRectangle(cornerRadius: 2)
                                .fill(Color.blue.opacity(0.7))
                                .frame(width: max(0, geo.size.width * 0.5 * min(valueA / maxVal, 1)))
                            Spacer(minLength: 0)
                        }

                        // B bar (right-aligned, orange)
                        HStack(spacing: 0) {
                            Spacer(minLength: 0)
                            RoundedRectangle(cornerRadius: 2)
                                .fill(Color.orange.opacity(0.7))
                                .frame(width: max(0, geo.size.width * 0.5 * min(valueB / maxVal, 1)))
                        }

                        // Center label
                        Text(label)
                            .font(.caption2)
                            .fontWeight(.medium)
                    }
                }
                .frame(height: 18)

                Text(String(format: format, valueB))
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundStyle(.orange)
                    .monospacedDigit()
                    .frame(width: 40, alignment: .leading)
            }
        }
    }
}

// MARK: - Reusable Chart: Area Chart (Canvas)

struct AreaChart: View {
    let values: [Double]
    let color: Color
    let minValue: Double?
    let maxValue: Double?
    let showGrid: Bool
    let gridLabels: [String]

    var body: some View {
        GeometryReader { geo in
            let computedMin = minValue ?? ((values.min() ?? 0) * 0.9)
            let computedMax = maxValue ?? ((values.max() ?? 1) * 1.1)
            let range = max(computedMax - computedMin, 1)

            ZStack(alignment: .leading) {
                Canvas { context, size in
                    // Grid
                    if showGrid {
                        let gridColor = Color.gray.opacity(0.15)
                        for i in 0...4 {
                            let y = CGFloat(i) * size.height / 4
                            var path = Path()
                            path.move(to: CGPoint(x: 0, y: y))
                            path.addLine(to: CGPoint(x: size.width, y: y))
                            context.stroke(path, with: .color(gridColor), lineWidth: 0.5)
                        }
                    }

                    guard values.count >= 2 else { return }

                    // Build line path
                    var linePath = Path()
                    for (i, v) in values.enumerated() {
                        let x = size.width * CGFloat(i) / CGFloat(values.count - 1)
                        let y = size.height - CGFloat((v - computedMin) / range) * size.height
                        if i == 0 { linePath.move(to: CGPoint(x: x, y: y)) }
                        else { linePath.addLine(to: CGPoint(x: x, y: y)) }
                    }

                    // Fill area
                    var fillPath = linePath
                    fillPath.addLine(to: CGPoint(x: size.width, y: size.height))
                    fillPath.addLine(to: CGPoint(x: 0, y: size.height))
                    fillPath.closeSubpath()
                    context.fill(fillPath, with: .linearGradient(
                        Gradient(colors: [color.opacity(0.3), color.opacity(0.02)]),
                        startPoint: .zero,
                        endPoint: CGPoint(x: 0, y: size.height)
                    ))

                    // Stroke line
                    context.stroke(linePath, with: .color(color), lineWidth: 2.5)

                    // Latest dot
                    if let last = values.last {
                        let x = size.width
                        let y = size.height - CGFloat((last - computedMin) / range) * size.height
                        let dot = Path(ellipseIn: CGRect(x: x - 4, y: y - 4, width: 8, height: 8))
                        context.fill(dot, with: .color(color))
                    }
                }

                // Grid labels
                if showGrid && !gridLabels.isEmpty {
                    VStack {
                        ForEach(gridLabels.reversed(), id: \.self) { label in
                            Text(label)
                                .font(.system(size: 8))
                                .foregroundStyle(.secondary)
                                .frame(maxHeight: .infinity, alignment: .center)
                        }
                    }
                    .frame(width: 28)
                }
            }
        }
    }
}

// MARK: - Reusable Chart: Bar Chart (Canvas)

struct BarChart: View {
    let values: [Double]
    let labels: [String]
    let color: Color
    var maxValue: Double? = nil
    var highlightIndex: Int? = nil

    var body: some View {
        GeometryReader { geo in
            let computedMax = maxValue ?? (values.max() ?? 1)
            let barCount = values.count
            let spacing: CGFloat = 4
            let totalSpacing = spacing * CGFloat(barCount - 1)
            let barWidth = max(4, (geo.size.width - totalSpacing) / CGFloat(barCount))
            let chartHeight = geo.size.height - 20  // room for labels

            VStack(spacing: 0) {
                Canvas { context, size in
                    for (i, val) in values.enumerated() {
                        let x = (barWidth + spacing) * CGFloat(i)
                        let h = computedMax > 0 ? (val / computedMax) * Double(chartHeight) : 0
                        let y = chartHeight - CGFloat(h)
                        let rect = CGRect(x: x, y: y, width: barWidth, height: max(CGFloat(h), 1))
                        let barColor = highlightIndex == i ? color : color.opacity(0.65)
                        let rr = Path(roundedRect: rect, cornerRadius: 3)
                        context.fill(rr, with: .color(barColor))

                        // Value label above bar
                        if val > 0 {
                            let resolved = context.resolve(Text("\(Int(val))").font(.system(size: 9)))
                            context.draw(resolved, at: CGPoint(x: x + barWidth / 2, y: y - 8))
                        }
                    }
                }
                .frame(height: chartHeight)

                // Labels
                HStack(spacing: spacing) {
                    ForEach(0..<labels.count, id: \.self) { i in
                        Text(labels[i])
                            .font(.system(size: 8))
                            .foregroundStyle(.secondary)
                            .frame(width: barWidth)
                            .lineLimit(1)
                            .minimumScaleFactor(0.5)
                    }
                }
                .frame(height: 20)
            }
        }
    }
}

// MARK: - Helpers

private func cardHeader(_ title: String, icon: String, color: Color) -> some View {
    HStack(spacing: 6) {
        Image(systemName: icon)
            .foregroundStyle(color)
        Text(title)
            .font(.headline)
        Spacer()
        Text("Accelerate")
            .font(.system(size: 9))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(color.opacity(0.1))
            .clipShape(Capsule())
    }
}

private func scoreColor(_ score: Int) -> Color {
    if score >= 80 { return .green }
    if score >= 60 { return .yellow }
    return .red
}

private func trendIcon(_ dir: TrendDirection) -> String {
    switch dir {
    case .improving: return "arrow.up.right"
    case .stable:    return "arrow.right"
    case .declining: return "arrow.down.right"
    }
}

private func trendColor(_ dir: TrendDirection) -> Color {
    switch dir {
    case .improving: return .green
    case .stable:    return .blue
    case .declining: return .orange
    }
}

private func trendLabel(_ dir: TrendDirection) -> String {
    switch dir {
    case .improving: return "Up"
    case .stable:    return "Steady"
    case .declining: return "Down"
    }
}

private func formatDate(_ date: Date) -> String {
    let f = DateFormatter()
    f.dateStyle = .short
    f.timeStyle = .short
    return f.string(from: date)
}

// MARK: - Card Container Modifier

extension View {
    func analyticsCard() -> some View {
        self
            .padding()
            .background(Color.secondarySystemGroupedBg)
            .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Preview

#Preview {
    AnalyticsView()
        .environmentObject(MachineStore())
        .environmentObject(BluetoothService())
}
