//
//  ShotChartView.swift
//  Good Espresso
//
//  Real-time and historical shot extraction chart
//

import SwiftUI

struct ShotChartView: View {
    let dataPoints: [ShotDataPoint]
    let isLive: Bool

    @State private var selectedIndex: Int?

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Background grid
                GridBackground()

                // Chart content
                if !dataPoints.isEmpty {
                    ChartContent(
                        dataPoints: dataPoints,
                        size: geometry.size,
                        selectedIndex: $selectedIndex
                    )
                } else {
                    Text("No data")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                // Selected point tooltip
                if let index = selectedIndex, index < dataPoints.count {
                    TooltipView(
                        point: dataPoints[index],
                        position: tooltipPosition(index: index, size: geometry.size)
                    )
                }
            }
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        guard !dataPoints.isEmpty else { return }
                        let maxTime = dataPoints.map(\.timestamp).max() ?? 1
                        let x = value.location.x
                        let progress = x / geometry.size.width
                        let targetTime = progress * maxTime

                        // Find closest point
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
        .background(Color(.tertiarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    func tooltipPosition(index: Int, size: CGSize) -> CGPoint {
        guard !dataPoints.isEmpty else { return .zero }
        let maxTime = dataPoints.map(\.timestamp).max() ?? 1
        let point = dataPoints[index]
        let x = (point.timestamp / maxTime) * size.width
        return CGPoint(x: min(max(x, 60), size.width - 60), y: 20)
    }
}

// MARK: - Grid Background
struct GridBackground: View {
    var body: some View {
        GeometryReader { geometry in
            Canvas { context, size in
                let gridColor = Color.gray.opacity(0.2)

                // Horizontal lines
                for i in 0...4 {
                    let y = CGFloat(i) * size.height / 4
                    var path = Path()
                    path.move(to: CGPoint(x: 0, y: y))
                    path.addLine(to: CGPoint(x: size.width, y: y))
                    context.stroke(path, with: .color(gridColor), lineWidth: 0.5)
                }

                // Vertical lines
                for i in 0...6 {
                    let x = CGFloat(i) * size.width / 6
                    var path = Path()
                    path.move(to: CGPoint(x: x, y: 0))
                    path.addLine(to: CGPoint(x: x, y: size.height))
                    context.stroke(path, with: .color(gridColor), lineWidth: 0.5)
                }
            }
        }
    }
}

// MARK: - Chart Content
struct ChartContent: View {
    let dataPoints: [ShotDataPoint]
    let size: CGSize
    @Binding var selectedIndex: Int?

    var maxPressure: Double {
        max(dataPoints.map(\.pressure).max() ?? 10, 10)
    }

    var maxFlow: Double {
        max(dataPoints.map(\.flow).max() ?? 6, 6)
    }

    var maxTime: Double {
        dataPoints.map(\.timestamp).max() ?? 1
    }

    var body: some View {
        ZStack {
            // Pressure line (blue)
            Path { path in
                for (index, point) in dataPoints.enumerated() {
                    let x = (point.timestamp / maxTime) * size.width
                    let y = size.height - (point.pressure / maxPressure) * size.height * 0.9

                    if index == 0 {
                        path.move(to: CGPoint(x: x, y: y))
                    } else {
                        path.addLine(to: CGPoint(x: x, y: y))
                    }
                }
            }
            .stroke(Color.blue, lineWidth: 2)

            // Flow line (cyan)
            Path { path in
                for (index, point) in dataPoints.enumerated() {
                    let x = (point.timestamp / maxTime) * size.width
                    let y = size.height - (point.flow / maxFlow) * size.height * 0.9

                    if index == 0 {
                        path.move(to: CGPoint(x: x, y: y))
                    } else {
                        path.addLine(to: CGPoint(x: x, y: y))
                    }
                }
            }
            .stroke(Color.cyan, lineWidth: 2)

            // Temperature line (orange, subtle)
            Path { path in
                for (index, point) in dataPoints.enumerated() {
                    let x = (point.timestamp / maxTime) * size.width
                    let normalizedTemp = (point.temperature - 80) / 20  // Normalize 80-100C
                    let y = size.height - min(max(normalizedTemp, 0), 1) * size.height * 0.9

                    if index == 0 {
                        path.move(to: CGPoint(x: x, y: y))
                    } else {
                        path.addLine(to: CGPoint(x: x, y: y))
                    }
                }
            }
            .stroke(Color.orange.opacity(0.5), lineWidth: 1.5)

            // Legend
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 4) {
                    Circle().fill(.blue).frame(width: 6, height: 6)
                    Text("Pressure")
                }
                HStack(spacing: 4) {
                    Circle().fill(.cyan).frame(width: 6, height: 6)
                    Text("Flow")
                }
                HStack(spacing: 4) {
                    Circle().fill(.orange).frame(width: 6, height: 6)
                    Text("Temp")
                }
            }
            .font(.system(size: 9))
            .padding(6)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 4))
            .position(x: size.width - 35, y: 30)

            // Selected point indicator
            if let index = selectedIndex, index < dataPoints.count {
                let point = dataPoints[index]
                let x = (point.timestamp / maxTime) * size.width

                // Vertical line
                Path { path in
                    path.move(to: CGPoint(x: x, y: 0))
                    path.addLine(to: CGPoint(x: x, y: size.height))
                }
                .stroke(Color.white.opacity(0.5), style: StrokeStyle(lineWidth: 1, dash: [4, 4]))

                // Pressure point
                let pressureY = size.height - (point.pressure / maxPressure) * size.height * 0.9
                Circle()
                    .fill(.blue)
                    .frame(width: 8, height: 8)
                    .position(x: x, y: pressureY)

                // Flow point
                let flowY = size.height - (point.flow / maxFlow) * size.height * 0.9
                Circle()
                    .fill(.cyan)
                    .frame(width: 8, height: 8)
                    .position(x: x, y: flowY)
            }
        }
    }
}

// MARK: - Tooltip View
struct TooltipView: View {
    let point: ShotDataPoint
    let position: CGPoint

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(String(format: "%.1fs", point.timestamp / 1000))
                .font(.caption2)
                .fontWeight(.semibold)

            HStack(spacing: 8) {
                Text(String(format: "%.1f bar", point.pressure))
                    .foregroundStyle(.blue)

                Text(String(format: "%.1f ml/s", point.flow))
                    .foregroundStyle(.cyan)
            }
            .font(.caption2)

            Text(String(format: "%.0f\u{00B0}C", point.temperature))
                .font(.caption2)
                .foregroundStyle(.orange)
        }
        .padding(6)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .position(position)
    }
}

#Preview {
    // Sample data for preview
    let sampleData: [ShotDataPoint] = (0..<60).map { i in
        ShotDataPoint(
            timestamp: Double(i) * 500,
            temperature: 93 + Double.random(in: -1...1),
            pressure: i < 10 ? Double(i) * 0.9 : 9 + Double.random(in: -0.5...0.5),
            flow: i < 5 ? 0 : 2.5 + Double.random(in: -0.3...0.3),
            weight: Double(i) * 0.6
        )
    }

    ShotChartView(dataPoints: sampleData, isLive: false)
        .frame(height: 200)
        .padding()
}
