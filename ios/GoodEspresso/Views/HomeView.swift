//
//  HomeView.swift
//  Good Espresso
//
//  Main dashboard showing machine status and quick controls
//

import SwiftUI

struct HomeView: View {
    @EnvironmentObject var machineStore: MachineStore
    @EnvironmentObject var bluetoothService: BluetoothService
    @State private var showingConnectionSheet = false
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    var isCompact: Bool {
        horizontalSizeClass == .compact
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                if machineStore.isConnected {
                    if isCompact {
                        // iPhone layout - vertical stack
                        compactLayout
                    } else {
                        // iPad layout - two column grid
                        regularLayout
                    }
                } else {
                    VStack(spacing: 20) {
                        ConnectionStatusCard(showingConnectionSheet: $showingConnectionSheet)
                        NotConnectedCard()
                    }
                    .padding()
                }
            }
            .background(Color.systemGroupedBg)
            .navigationTitle("Good Espresso")
            .toolbar {
                ToolbarItem(placement: .topBarTrailingCompat) {
                    Button {
                        showingConnectionSheet = true
                    } label: {
                        Image(systemName: machineStore.isConnected ? "antenna.radiowaves.left.and.right" : "antenna.radiowaves.left.and.right.slash")
                            .foregroundStyle(machineStore.isConnected ? .green : .gray)
                    }
                }
            }
            .sheet(isPresented: $showingConnectionSheet) {
                ConnectionView()
            }
        }
    }

    // MARK: - Compact Layout (iPhone)
    var compactLayout: some View {
        VStack(spacing: 20) {
            ConnectionStatusCard(showingConnectionSheet: $showingConnectionSheet)
            MachineStatusCard()
            QuickControlsCard()
            ActiveProfileCard()
            ShotChartCard()

            if !machineStore.shotHistory.isEmpty {
                ShotTrendCard()
            }
        }
        .padding()
    }

    // MARK: - Regular Layout (iPad / macOS)
    var regularLayout: some View {
        VStack(spacing: 20) {
            // Top row: Connection + Status
            HStack(alignment: .top, spacing: 20) {
                ConnectionStatusCard(showingConnectionSheet: $showingConnectionSheet)
                    .frame(maxWidth: .infinity)
                MachineStatusCard()
                    .frame(maxWidth: .infinity)
            }

            // Main content: Chart + Controls side by side
            HStack(alignment: .top, spacing: 20) {
                // Left column: Chart (larger)
                VStack(spacing: 20) {
                    ShotChartCard()
                    ActiveProfileCard()
                }
                .frame(maxWidth: .infinity)

                // Right column: Controls + ML insights
                VStack(spacing: 20) {
                    QuickControlsCard()

                    if !machineStore.shotHistory.isEmpty {
                        ShotTrendCard()
                    }
                }
                .frame(minWidth: 260, idealWidth: 320, maxWidth: 380)
            }
        }
        .padding()
        .frame(maxWidth: 1100)
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Connection Status Card
struct ConnectionStatusCard: View {
    @EnvironmentObject var machineStore: MachineStore
    @Binding var showingConnectionSheet: Bool

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Circle()
                    .fill(machineStore.isConnected ? .green : .red)
                    .frame(width: 12, height: 12)

                Text(machineStore.isConnected ? "Connected" : "Disconnected")
                    .font(.headline)

                Spacer()

                if let name = machineStore.deviceName {
                    Text(name)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            if !machineStore.isConnected {
                Button {
                    showingConnectionSheet = true
                } label: {
                    Label("Connect to Machine", systemImage: "link")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(.orange)
            }

            if let error = machineStore.connectionError {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
            }
        }
        .padding()
        .background(Color.secondarySystemGroupedBg)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Machine Status Card
struct MachineStatusCard: View {
    @EnvironmentObject var machineStore: MachineStore

    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Machine Status")
                    .font(.headline)
                Spacer()
                StatusBadge(state: machineStore.machineState.state)
            }

            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 16) {
                StatusItem(
                    icon: "thermometer.medium",
                    value: machineStore.formatTemperature(machineStore.machineState.temperature.head),
                    label: "Head Temp"
                )

                StatusItem(
                    icon: "gauge.with.needle",
                    value: String(format: "%.1f bar", machineStore.machineState.pressure),
                    label: "Pressure"
                )

                StatusItem(
                    icon: "drop.fill",
                    value: String(format: "%.1f ml/s", machineStore.machineState.flow),
                    label: "Flow"
                )
            }
        }
        .padding()
        .background(Color.secondarySystemGroupedBg)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

struct StatusBadge: View {
    let state: MachineStateType

    var body: some View {
        Text(state.displayName)
            .font(.caption)
            .fontWeight(.semibold)
            .padding(.horizontal, 12)
            .padding(.vertical, 4)
            .background(backgroundColor)
            .foregroundStyle(.white)
            .clipShape(Capsule())
    }

    var backgroundColor: Color {
        switch state {
        case .idle: return .gray
        case .sleep: return .purple
        case .warming: return .orange
        case .ready: return .green
        case .brewing: return .blue
        case .steam: return .red
        case .flush: return .cyan
        case .cleaning: return .yellow
        case .error: return .red
        case .disconnected: return .gray
        }
    }
}

struct StatusItem: View {
    let icon: String
    let value: String
    let label: String

    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(.orange)

            Text(value)
                .font(.headline)
                .monospacedDigit()

            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - Quick Controls Card
struct QuickControlsCard: View {
    @EnvironmentObject var machineStore: MachineStore
    @EnvironmentObject var bluetoothService: BluetoothService
    @State private var isLoading = false

    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Quick Controls")
                    .font(.headline)
                Spacer()
            }

            HStack(spacing: 12) {
                ControlButton(
                    title: "Espresso",
                    icon: "cup.and.saucer.fill",
                    color: .orange,
                    isActive: machineStore.machineState.state == .brewing
                ) {
                    Task {
                        do {
                            if machineStore.machineState.state == .brewing {
                                try await bluetoothService.stop()
                            } else {
                                try await bluetoothService.startEspresso()
                            }
                        } catch {
                            print("Error: \(error)")
                        }
                    }
                }

                ControlButton(
                    title: "Steam",
                    icon: "cloud.fill",
                    color: .red,
                    isActive: machineStore.machineState.state == .steam
                ) {
                    Task {
                        do {
                            if machineStore.machineState.state == .steam {
                                try await bluetoothService.stop()
                            } else {
                                try await bluetoothService.startSteam()
                            }
                        } catch {
                            print("Error: \(error)")
                        }
                    }
                }

                ControlButton(
                    title: "Flush",
                    icon: "drop.fill",
                    color: .cyan,
                    isActive: machineStore.machineState.state == .flush
                ) {
                    Task {
                        do {
                            if machineStore.machineState.state == .flush {
                                try await bluetoothService.stop()
                            } else {
                                try await bluetoothService.startFlush()
                            }
                        } catch {
                            print("Error: \(error)")
                        }
                    }
                }

                ControlButton(
                    title: "Hot Water",
                    icon: "mug.fill",
                    color: .blue,
                    isActive: false
                ) {
                    Task {
                        do {
                            try await bluetoothService.startHotWater()
                        } catch {
                            print("Error: \(error)")
                        }
                    }
                }
            }

            // Stop button
            if machineStore.machineState.state == .brewing ||
               machineStore.machineState.state == .steam ||
               machineStore.machineState.state == .flush {
                Button {
                    Task {
                        try? await bluetoothService.stop()
                    }
                } label: {
                    Label("Stop", systemImage: "stop.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(.red)
            }
        }
        .padding()
        .background(Color.secondarySystemGroupedBg)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

struct ControlButton: View {
    let title: String
    let icon: String
    let color: Color
    let isActive: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.title)
                Text(title)
                    .font(.caption)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(isActive ? color : Color.tertiarySystemGroupedBg)
            .foregroundStyle(isActive ? .white : color)
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
    }
}

// MARK: - Active Profile Card
struct ActiveProfileCard: View {
    @EnvironmentObject var machineStore: MachineStore

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Text("Active Profile")
                    .font(.headline)
                Spacer()
                NavigationLink {
                    ProfilesView()
                } label: {
                    Text("Change")
                        .font(.subheadline)
                }
            }

            if let recipe = machineStore.activeRecipe {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(recipe.name)
                            .font(.title3)
                            .fontWeight(.semibold)

                        Text("\(recipe.steps.count) steps • Target: \(Int(recipe.targetWeight))g")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    NavigationLink {
                        ProfileDetailView(recipe: recipe)
                    } label: {
                        Image(systemName: "chevron.right")
                            .foregroundStyle(.secondary)
                    }
                }
                .padding()
                .background(Color.tertiarySystemGroupedBg)
                .clipShape(RoundedRectangle(cornerRadius: 8))
            } else {
                Text("No profile selected")
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .background(Color.secondarySystemGroupedBg)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Shot Chart Card (Live or Last Shot)
struct ShotChartCard: View {
    @EnvironmentObject var machineStore: MachineStore
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    var isLive: Bool {
        machineStore.machineState.state == .brewing || machineStore.isRecording
    }

    var dataPoints: [ShotDataPoint] {
        if let activeShot = machineStore.activeShot, !activeShot.dataPoints.isEmpty {
            return activeShot.dataPoints
        } else if let lastShot = machineStore.shotHistory.first, !lastShot.dataPoints.isEmpty {
            return lastShot.dataPoints
        }
        return []
    }

    var chartTitle: String {
        if isLive {
            return "Live Extraction"
        } else if machineStore.shotHistory.first != nil {
            return "Last Shot"
        }
        return "Extraction Chart"
    }

    private var chartHeight: CGFloat {
        horizontalSizeClass == .compact ? 200 : 360
    }

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Text(chartTitle)
                    .font(.headline)

                Spacer()

                if isLive && machineStore.isRecording {
                    Circle()
                        .fill(.red)
                        .frame(width: 8, height: 8)
                    Text("Recording")
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }

            if !dataPoints.isEmpty {
                ShotChartView(dataPoints: dataPoints, isLive: isLive)
                    .frame(minHeight: chartHeight)
            } else {
                VStack(spacing: 8) {
                    Image(systemName: "chart.xyaxis.line")
                        .font(.largeTitle)
                        .foregroundStyle(.secondary)
                    Text("No shot data yet")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("Start an extraction to see the chart")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
                .frame(height: chartHeight)
            }
        }
        .padding()
        .background(Color.secondarySystemGroupedBg)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Not Connected Card
struct NotConnectedCard: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "cup.and.saucer")
                .font(.system(size: 60))
                .foregroundStyle(.orange)

            Text("Welcome to Good Espresso")
                .font(.title2)
                .fontWeight(.semibold)

            Text("Connect to your Decent espresso machine to start brewing amazing coffee and tea.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            VStack(alignment: .leading, spacing: 8) {
                FeatureRow(icon: "waveform.path.ecg", text: "Real-time extraction monitoring")
                FeatureRow(icon: "list.bullet.rectangle", text: "Professional brewing profiles")
                FeatureRow(icon: "leaf.fill", text: "Pulse-brew tea profiles")
                FeatureRow(icon: "chart.line.uptrend.xyaxis", text: "Shot history and analytics")
            }
            .padding(.top)
        }
        .padding(24)
        .background(Color.secondarySystemGroupedBg)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

struct FeatureRow: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundStyle(.orange)
                .frame(width: 24)

            Text(text)
                .font(.subheadline)
        }
    }
}

// MARK: - Shot Trend Card (ML-powered)
struct ShotTrendCard: View {
    @EnvironmentObject var machineStore: MachineStore
    @State private var trend: TrendAnalysis?
    @State private var latestScore: Int?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 6) {
                Image(systemName: "brain")
                    .foregroundStyle(.purple)
                Text("Shot Intelligence")
                    .font(.headline)
                Spacer()
                Text("On-Device ML")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color.purple.opacity(0.12))
                    .clipShape(Capsule())
            }

            if let trend = trend {
                HStack(spacing: 16) {
                    // Latest score
                    if let score = latestScore {
                        VStack(spacing: 4) {
                            ZStack {
                                Circle()
                                    .stroke(scoreColor(score).opacity(0.2), lineWidth: 6)
                                Circle()
                                    .trim(from: 0, to: Double(score) / 100.0)
                                    .stroke(scoreColor(score), style: StrokeStyle(lineWidth: 6, lineCap: .round))
                                    .rotationEffect(.degrees(-90))
                                Text("\(score)")
                                    .font(.title3)
                                    .fontWeight(.bold)
                                    .monospacedDigit()
                            }
                            .frame(width: 64, height: 64)

                            Text("Latest")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        // Trend direction
                        HStack(spacing: 4) {
                            Image(systemName: trendIcon(trend.trend))
                                .foregroundStyle(trendColor(trend.trend))
                            Text(trendLabel(trend.trend))
                                .font(.subheadline)
                                .fontWeight(.medium)
                        }

                        Text("Avg score: \(trend.averageScore) across \(trend.shotCount) shots")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        // Mini sparkline of recent scores
                        if trend.scores.count >= 2 {
                            TrendSparkline(scores: trend.scores)
                                .frame(height: 28)
                        }
                    }
                }
            } else {
                ProgressView("Analyzing shots...")
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 4)
            }
        }
        .padding()
        .background(Color.secondarySystemGroupedBg)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .task {
            let shots = machineStore.shotHistory
            let result = await Task.detached {
                let trendResult = ShotAnalyzer.analyzeTrend(shots)
                let latest = shots.first.map { ShotAnalyzer.analyze($0).overallScore }
                return (trendResult, latest)
            }.value
            trend = result.0
            latestScore = result.1
        }
    }

    func scoreColor(_ score: Int) -> Color {
        if score >= 80 { return .green }
        if score >= 60 { return .yellow }
        return .red
    }

    func trendIcon(_ dir: TrendDirection) -> String {
        switch dir {
        case .improving: return "arrow.up.right"
        case .stable:    return "arrow.right"
        case .declining: return "arrow.down.right"
        }
    }

    func trendColor(_ dir: TrendDirection) -> Color {
        switch dir {
        case .improving: return .green
        case .stable:    return .blue
        case .declining: return .orange
        }
    }

    func trendLabel(_ dir: TrendDirection) -> String {
        switch dir {
        case .improving: return "Improving"
        case .stable:    return "Consistent"
        case .declining: return "Needs Attention"
        }
    }
}

// MARK: - Trend Sparkline
struct TrendSparkline: View {
    let scores: [Int]

    var body: some View {
        GeometryReader { geo in
            let points = scores.reversed() // oldest to newest left-to-right
            let maxVal = Double(points.max() ?? 100)
            let minVal = Double(max((points.min() ?? 0) - 10, 0))
            let range = max(maxVal - minVal, 1)

            Canvas { context, size in
                var path = Path()
                for (i, score) in points.enumerated() {
                    let x = size.width * CGFloat(i) / CGFloat(max(points.count - 1, 1))
                    let y = size.height - (CGFloat(Double(score) - minVal) / CGFloat(range)) * size.height
                    if i == 0 {
                        path.move(to: CGPoint(x: x, y: y))
                    } else {
                        path.addLine(to: CGPoint(x: x, y: y))
                    }
                }
                context.stroke(path, with: .color(.purple), lineWidth: 2)

                // Dot on the latest point
                if let last = points.last {
                    let x = size.width
                    let y = size.height - (CGFloat(Double(last) - minVal) / CGFloat(range)) * size.height
                    let dot = Path(ellipseIn: CGRect(x: x - 3, y: y - 3, width: 6, height: 6))
                    context.fill(dot, with: .color(.purple))
                }
            }
        }
    }
}

#Preview {
    HomeView()
        .environmentObject(MachineStore())
        .environmentObject(BluetoothService())
}
