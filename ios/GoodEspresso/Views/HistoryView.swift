//
//  HistoryView.swift
//  Good Espresso
//
//  Shot history and analytics
//

import SwiftUI

struct HistoryView: View {
    @EnvironmentObject var machineStore: MachineStore
    @State private var selectedShot: ShotRecord?
    @State private var showingDetail = false

    var body: some View {
        NavigationStack {
            Group {
                if machineStore.shotHistory.isEmpty {
                    EmptyHistoryView()
                } else {
                    ShotHistoryList(
                        shots: machineStore.shotHistory,
                        selectedShot: $selectedShot,
                        showingDetail: $showingDetail
                    )
                }
            }
            .navigationTitle("History")
            .sheet(isPresented: $showingDetail) {
                if let shot = selectedShot {
                    ShotDetailSheet(shot: shot)
                }
            }
        }
    }
}

// MARK: - Empty History View
struct EmptyHistoryView: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "clock.arrow.circlepath")
                .font(.system(size: 60))
                .foregroundStyle(.gray)

            Text("No Shot History")
                .font(.title2)
                .fontWeight(.semibold)

            Text("Your brewing history will appear here after you make your first shot.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
    }
}

// MARK: - Shot History List
struct ShotHistoryList: View {
    @EnvironmentObject var machineStore: MachineStore
    let shots: [ShotRecord]
    @Binding var selectedShot: ShotRecord?
    @Binding var showingDetail: Bool

    var body: some View {
        List {
            ForEach(shots) { shot in
                ShotHistoryRow(shot: shot)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        selectedShot = shot
                        showingDetail = true
                    }
            }
            .onDelete(perform: deleteShots)
        }
        .listStyle(.plain)
    }

    func deleteShots(at offsets: IndexSet) {
        for index in offsets {
            machineStore.deleteShot(shots[index])
        }
    }
}

// MARK: - Shot History Row
struct ShotHistoryRow: View {
    let shot: ShotRecord

    var body: some View {
        HStack(spacing: 12) {
            // Thumbnail chart
            MiniChartView(dataPoints: shot.dataPoints)
                .frame(width: 60, height: 40)
                .clipShape(RoundedRectangle(cornerRadius: 6))

            // Shot info
            VStack(alignment: .leading, spacing: 4) {
                Text(shot.profileName)
                    .font(.headline)

                HStack(spacing: 8) {
                    Text(formatDate(shot.startTime))
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Text("\u{2022}")
                        .foregroundStyle(.secondary)

                    Text(formatDuration(shot.duration))
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    if let weight = shot.finalWeight {
                        Text("\u{2022}")
                            .foregroundStyle(.secondary)

                        Text("\(Int(weight))g")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Spacer()

            // Rating
            if let rating = shot.rating {
                RatingStars(rating: rating, size: 12)
            }

            Image(systemName: "chevron.right")
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 8)
    }

    func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    func formatDuration(_ duration: TimeInterval) -> String {
        return String(format: "%.1fs", duration)
    }
}

// MARK: - Mini Chart View
struct MiniChartView: View {
    let dataPoints: [ShotDataPoint]

    var body: some View {
        GeometryReader { geometry in
            if dataPoints.isEmpty {
                Rectangle()
                    .fill(Color.gray.opacity(0.2))
            } else {
                Canvas { context, size in
                    let maxPressure = dataPoints.map(\.pressure).max() ?? 1
                    let maxTime = dataPoints.map(\.timestamp).max() ?? 1

                    // Draw pressure line
                    var path = Path()
                    for (index, point) in dataPoints.enumerated() {
                        let x = (point.timestamp / maxTime) * size.width
                        let y = size.height - (point.pressure / maxPressure) * size.height

                        if index == 0 {
                            path.move(to: CGPoint(x: x, y: y))
                        } else {
                            path.addLine(to: CGPoint(x: x, y: y))
                        }
                    }

                    context.stroke(path, with: .color(.orange), lineWidth: 1.5)
                }
            }
        }
        .background(Color.orange.opacity(0.1))
    }
}

// MARK: - Rating Stars
struct RatingStars: View {
    let rating: Int
    let size: CGFloat

    var body: some View {
        HStack(spacing: 2) {
            ForEach(1...5, id: \.self) { star in
                Image(systemName: star <= rating ? "star.fill" : "star")
                    .font(.system(size: size))
                    .foregroundStyle(star <= rating ? .yellow : .gray.opacity(0.3))
            }
        }
    }
}

// MARK: - Shot Detail Sheet
struct ShotDetailSheet: View {
    @EnvironmentObject var machineStore: MachineStore
    @Environment(\.dismiss) private var dismiss
    let shot: ShotRecord
    @State private var selectedRating: Int = 0
    @State private var notes: String = ""

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Shot Chart
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Extraction Curve")
                            .font(.headline)

                        ShotChartView(dataPoints: shot.dataPoints, isLive: false)
                            .frame(height: 200)
                    }
                    .padding()
                    .background(Color.secondarySystemGroupedBg)
                    .clipShape(RoundedRectangle(cornerRadius: 12))

                    // Shot Stats
                    ShotStatsSection(shot: shot)

                    // Rating Section
                    RatingSection(rating: $selectedRating)

                    // Notes Section
                    NotesInputSection(notes: $notes)
                }
                .padding()
            }
            .background(Color.systemGroupedBg)
            .navigationTitle(shot.profileName)
            .inlineNavigationBarTitle()
            .toolbar {
                ToolbarItem(placement: .topBarLeadingCompat) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .topBarTrailingCompat) {
                    Button("Save") {
                        if selectedRating > 0 {
                            machineStore.rateShot(shot, rating: selectedRating)
                        }
                        dismiss()
                    }
                }
            }
            .onAppear {
                selectedRating = shot.rating ?? 0
                notes = shot.notes ?? ""
            }
        }
    }
}

// MARK: - Shot Stats Section
struct ShotStatsSection: View {
    let shot: ShotRecord

    var avgPressure: Double {
        guard !shot.dataPoints.isEmpty else { return 0 }
        return shot.dataPoints.map(\.pressure).reduce(0, +) / Double(shot.dataPoints.count)
    }

    var avgFlow: Double {
        guard !shot.dataPoints.isEmpty else { return 0 }
        return shot.dataPoints.map(\.flow).reduce(0, +) / Double(shot.dataPoints.count)
    }

    var avgTemp: Double {
        guard !shot.dataPoints.isEmpty else { return 0 }
        return shot.dataPoints.map(\.temperature).reduce(0, +) / Double(shot.dataPoints.count)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Statistics")
                .font(.headline)

            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 16) {
                StatItem(label: "Duration", value: String(format: "%.1fs", shot.duration))
                StatItem(label: "Avg Pressure", value: String(format: "%.1f bar", avgPressure))
                StatItem(label: "Avg Flow", value: String(format: "%.1f ml/s", avgFlow))
                StatItem(label: "Avg Temp", value: String(format: "%.0f\u{00B0}C", avgTemp))

                if let weight = shot.finalWeight {
                    StatItem(label: "Yield", value: "\(Int(weight))g")
                }

                if let ratio = shot.ratio {
                    StatItem(label: "Ratio", value: ratio)
                }
            }
        }
        .padding()
        .background(Color.secondarySystemGroupedBg)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

struct StatItem: View {
    let label: String
    let value: String

    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.headline)
                .monospacedDigit()

            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - Rating Section
struct RatingSection: View {
    @Binding var rating: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Rate This Shot")
                .font(.headline)

            HStack(spacing: 12) {
                ForEach(1...5, id: \.self) { star in
                    Button {
                        rating = star
                    } label: {
                        Image(systemName: star <= rating ? "star.fill" : "star")
                            .font(.title)
                            .foregroundStyle(star <= rating ? .yellow : .gray.opacity(0.3))
                    }
                }
            }
            .frame(maxWidth: .infinity)
        }
        .padding()
        .background(Color.secondarySystemGroupedBg)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Notes Input Section
struct NotesInputSection: View {
    @Binding var notes: String

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Notes")
                .font(.headline)

            TextField("Add notes about this shot...", text: $notes, axis: .vertical)
                .textFieldStyle(.roundedBorder)
                .lineLimit(3...6)
        }
        .padding()
        .background(Color.secondarySystemGroupedBg)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

#Preview {
    HistoryView()
        .environmentObject(MachineStore())
}
