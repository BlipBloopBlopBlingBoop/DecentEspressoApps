//
//  ShotChartView.swift
//  Good Espresso
//
//  Real-time and historical shot extraction chart with axis scales
//

import SwiftUI

struct ShotChartView: View {
    let dataPoints: [ShotDataPoint]
    let isLive: Bool

    @State private var selectedIndex: Int?

    // Chart dimensions
    private let leftAxisWidth: CGFloat = 35
    private let bottomAxisHeight: CGFloat = 25
    private let rightAxisWidth: CGFloat = 35

    var maxTime: Double {
        max(dataPoints.map(\.timestamp).max() ?? 30000, 30000) // At least 30 seconds
    }

    var maxPressure: Double {
        max(dataPoints.map(\.pressure).max() ?? 10, 10)
    }

    var maxFlow: Double {
        max(dataPoints.map(\.flow).max() ?? 6, 6)
    }

    var body: some View {
        HStack(spacing: 0) {
            // Left Y-axis (Pressure)
            VStack(spacing: 0) {
                ForEach([10, 8, 6, 4, 2, 0], id: \.self) { value in
                    Text("\(value)")
                        .font(.system(size: 8))
                        .foregroundStyle(.blue)
                        .frame(maxHeight: .infinity, alignment: value == 10 ? .top : (value == 0 ? .bottom : .center))
                }
            }
            .frame(width: leftAxisWidth)
            .padding(.bottom, bottomAxisHeight)

            // Main chart area
            VStack(spacing: 0) {
                GeometryReader { geometry in
                    ZStack {
                        // Background grid
                        ChartGrid(size: geometry.size)

                        // Chart lines
                        if !dataPoints.isEmpty {
                            ChartLines(
                                dataPoints: dataPoints,
                                size: geometry.size,
                                maxTime: maxTime,
                                maxPressure: maxPressure,
                                maxFlow: maxFlow,
                                selectedIndex: $selectedIndex
                            )
                        } else {
                            VStack {
                                Image(systemName: "chart.xyaxis.line")
                                    .font(.largeTitle)
                                    .foregroundStyle(.secondary)
                                Text("No data")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }

                        // Tooltip
                        if let index = selectedIndex, index < dataPoints.count {
                            ChartTooltip(
                                point: dataPoints[index],
                                position: tooltipPosition(index: index, size: geometry.size)
                            )
                        }
                    }
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { value in
                                guard !dataPoints.isEmpty else { return }
                                let progress = value.location.x / geometry.size.width
                                let targetTime = progress * maxTime

                                var closestIndex = 0
                                var closestDistance = Double.infinity
                                for (i, point) in dataPoints.enumerated() {
                                    let distance = abs(point.timestamp - targetTime)
                                    if distance < closestDistance {
                                        closestDistance = distance
                                        closestIndex = i
                                    }
                                }
                                selectedIndex = closestIndex
                            }
                            .onEnded { _ in
                                selectedIndex = nil
                            }
                    )
                }
                .background(Color.tertiarySystemGroupedBg)
                .clipShape(RoundedRectangle(cornerRadius: 4))

                // X-axis (Time)
                HStack {
                    ForEach([0, 10, 20, 30], id: \.self) { sec in
                        Text("\(sec)s")
                            .font(.system(size: 8))
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: sec == 0 ? .leading : (sec == 30 ? .trailing : .center))
                    }
                }
                .frame(height: bottomAxisHeight)
            }

            // Right Y-axis (Flow)
            VStack(spacing: 0) {
                ForEach([6, 5, 4, 3, 2, 1, 0], id: \.self) { value in
                    Text("\(value)")
                        .font(.system(size: 8))
                        .foregroundStyle(.cyan)
                        .frame(maxHeight: .infinity, alignment: value == 6 ? .top : (value == 0 ? .bottom : .center))
                }
            }
            .frame(width: rightAxisWidth)
            .padding(.bottom, bottomAxisHeight)
        }
        .overlay(alignment: .topLeading) {
            // Legend
            HStack(spacing: 12) {
                LegendItem(color: .blue, label: "bar")
                LegendItem(color: .cyan, label: "ml/s")
                LegendItem(color: .orange, label: "°C")
            }
            .font(.system(size: 9))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(.ultraThinMaterial)
            .clipShape(Capsule())
            .padding(.leading, leftAxisWidth + 8)
            .padding(.top, 8)
        }
    }

    func tooltipPosition(index: Int, size: CGSize) -> CGPoint {
        guard !dataPoints.isEmpty else { return .zero }
        let point = dataPoints[index]
        let x = (point.timestamp / maxTime) * size.width
        return CGPoint(x: min(max(x, 50), size.width - 50), y: 30)
    }
}

// MARK: - Chart Grid
struct ChartGrid: View {
    let size: CGSize

    var body: some View {
        Canvas { context, size in
            let gridColor = Color.gray.opacity(0.15)

            // Horizontal lines (5 divisions)
            for i in 0...5 {
                let y = CGFloat(i) * size.height / 5
                var path = Path()
                path.move(to: CGPoint(x: 0, y: y))
                path.addLine(to: CGPoint(x: size.width, y: y))
                context.stroke(path, with: .color(gridColor), lineWidth: i == 0 || i == 5 ? 1 : 0.5)
            }

            // Vertical lines (every 10 seconds for 30s total = 3 divisions)
            for i in 0...3 {
                let x = CGFloat(i) * size.width / 3
                var path = Path()
                path.move(to: CGPoint(x: x, y: 0))
                path.addLine(to: CGPoint(x: x, y: size.height))
                context.stroke(path, with: .color(gridColor), lineWidth: i == 0 || i == 3 ? 1 : 0.5)
            }
        }
    }
}

// MARK: - Chart Lines
struct ChartLines: View {
    let dataPoints: [ShotDataPoint]
    let size: CGSize
    let maxTime: Double
    let maxPressure: Double
    let maxFlow: Double
    @Binding var selectedIndex: Int?

    var body: some View {
        ZStack {
            // Pressure line (blue)
            Path { path in
                for (index, point) in dataPoints.enumerated() {
                    let x = (point.timestamp / maxTime) * size.width
                    let y = size.height - (point.pressure / maxPressure) * size.height

                    if index == 0 {
                        path.move(to: CGPoint(x: x, y: y))
                    } else {
                        path.addLine(to: CGPoint(x: x, y: y))
                    }
                }
            }
            .stroke(Color.blue, lineWidth: 2.5)

            // Flow line (cyan)
            Path { path in
                for (index, point) in dataPoints.enumerated() {
                    let x = (point.timestamp / maxTime) * size.width
                    let y = size.height - (point.flow / maxFlow) * size.height

                    if index == 0 {
                        path.move(to: CGPoint(x: x, y: y))
                    } else {
                        path.addLine(to: CGPoint(x: x, y: y))
                    }
                }
            }
            .stroke(Color.cyan, lineWidth: 2.5)

            // Temperature line (orange, subtle)
            Path { path in
                for (index, point) in dataPoints.enumerated() {
                    let x = (point.timestamp / maxTime) * size.width
                    let normalizedTemp = (point.temperature - 80) / 20  // Normalize 80-100C
                    let y = size.height - min(max(normalizedTemp, 0), 1) * size.height

                    if index == 0 {
                        path.move(to: CGPoint(x: x, y: y))
                    } else {
                        path.addLine(to: CGPoint(x: x, y: y))
                    }
                }
            }
            .stroke(Color.orange.opacity(0.6), lineWidth: 1.5)

            // Selected point indicator
            if let index = selectedIndex, index < dataPoints.count {
                let point = dataPoints[index]
                let x = (point.timestamp / maxTime) * size.width

                // Vertical line
                Path { path in
                    path.move(to: CGPoint(x: x, y: 0))
                    path.addLine(to: CGPoint(x: x, y: size.height))
                }
                .stroke(Color.white.opacity(0.7), style: StrokeStyle(lineWidth: 1, dash: [4, 4]))

                // Pressure point
                let pressureY = size.height - (point.pressure / maxPressure) * size.height
                Circle()
                    .fill(.blue)
                    .frame(width: 10, height: 10)
                    .position(x: x, y: pressureY)

                // Flow point
                let flowY = size.height - (point.flow / maxFlow) * size.height
                Circle()
                    .fill(.cyan)
                    .frame(width: 10, height: 10)
                    .position(x: x, y: flowY)
            }
        }
    }
}

// MARK: - Legend Item
struct LegendItem: View {
    let color: Color
    let label: String

    var body: some View {
        HStack(spacing: 3) {
            RoundedRectangle(cornerRadius: 1)
                .fill(color)
                .frame(width: 12, height: 3)
            Text(label)
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - Chart Tooltip
struct ChartTooltip: View {
    let point: ShotDataPoint
    let position: CGPoint

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(String(format: "%.1fs", point.timestamp / 1000))
                .font(.caption2)
                .fontWeight(.bold)

            HStack(spacing: 10) {
                HStack(spacing: 2) {
                    Circle().fill(.blue).frame(width: 6, height: 6)
                    Text(String(format: "%.1f", point.pressure))
                }

                HStack(spacing: 2) {
                    Circle().fill(.cyan).frame(width: 6, height: 6)
                    Text(String(format: "%.1f", point.flow))
                }

                HStack(spacing: 2) {
                    Circle().fill(.orange).frame(width: 6, height: 6)
                    Text(String(format: "%.0f°", point.temperature))
                }
            }
            .font(.caption2)
        }
        .padding(8)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .shadow(radius: 2)
        .position(position)
    }
}

#Preview {
    VStack {
        ShotChartView(
            dataPoints: [
                ShotDataPoint(timestamp: 0, temperature: 93, pressure: 0, flow: 0, weight: 0),
                ShotDataPoint(timestamp: 2000, temperature: 93, pressure: 1, flow: 0.5, weight: 1),
                ShotDataPoint(timestamp: 5000, temperature: 93, pressure: 3, flow: 1.5, weight: 3),
                ShotDataPoint(timestamp: 8000, temperature: 93, pressure: 6, flow: 2.0, weight: 6),
                ShotDataPoint(timestamp: 10000, temperature: 93, pressure: 9, flow: 2.5, weight: 8),
                ShotDataPoint(timestamp: 15000, temperature: 93, pressure: 9, flow: 2.5, weight: 14),
                ShotDataPoint(timestamp: 20000, temperature: 93, pressure: 9, flow: 2.5, weight: 20),
                ShotDataPoint(timestamp: 25000, temperature: 93, pressure: 9, flow: 2.5, weight: 26),
                ShotDataPoint(timestamp: 30000, temperature: 92, pressure: 8, flow: 2.0, weight: 32)
            ],
            isLive: false
        )
        .frame(height: 220)
        .padding()
    }
}
