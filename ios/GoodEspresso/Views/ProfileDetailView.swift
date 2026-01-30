//
//  ProfileDetailView.swift
//  Good Espresso
//
//  Detailed view of a brewing profile showing all steps
//

import SwiftUI

struct ProfileDetailView: View {
    @EnvironmentObject var machineStore: MachineStore
    @EnvironmentObject var bluetoothService: BluetoothService
    @Environment(\.dismiss) private var dismiss
    let recipe: Recipe
    var onEdit: ((Recipe) -> Void)?

    @State private var showingEditor = false
    @State private var showingShareSheet = false
    @State private var exportURL: URL?
    @State private var showingDeleteConfirm = false

    var isActive: Bool {
        machineStore.activeRecipe?.id == recipe.id
    }

    var isTea: Bool {
        recipe.id.contains("tea") || recipe.id.contains("herbal") || recipe.id.contains("tisane")
    }

    var isCustom: Bool {
        machineStore.isCustomProfile(recipe)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Header
                ProfileHeader(recipe: recipe, isTea: isTea)

                // Action Buttons
                ActionButtons(recipe: recipe, isActive: isActive)

                // Profile Visualization
                ProfileVisualization(steps: recipe.steps)

                // Steps List
                StepsSection(steps: recipe.steps)

                // Notes
                if let notes = recipe.notes, !notes.isEmpty {
                    NotesSection(notes: notes)
                }

                // Metadata
                MetadataSection(recipe: recipe)

                // Export/Delete for custom profiles
                if isCustom {
                    VStack(spacing: 12) {
                        Button(role: .destructive) {
                            showingDeleteConfirm = true
                        } label: {
                            Label("Delete Profile", systemImage: "trash")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                    }
                    .padding()
                    .background(Color.secondarySystemGroupedBg)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }
            .padding()
        }
        .background(Color.systemGroupedBg)
        .navigationTitle(recipe.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                // Export button
                Button {
                    exportProfile()
                } label: {
                    Image(systemName: "square.and.arrow.up")
                }

                // Duplicate button
                Menu {
                    Button {
                        let copy = machineStore.duplicateProfile(recipe)
                        machineStore.saveCustomProfile(copy)
                    } label: {
                        Label("Duplicate", systemImage: "doc.on.doc")
                    }

                    if isCustom {
                        Button {
                            showingEditor = true
                        } label: {
                            Label("Edit", systemImage: "pencil")
                        }
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }

                Button {
                    machineStore.toggleFavorite(recipe)
                } label: {
                    Image(systemName: recipe.favorite ? "star.fill" : "star")
                        .foregroundStyle(recipe.favorite ? .yellow : .gray)
                }
            }
        }
        .sheet(isPresented: $showingEditor) {
            ProfileEditorView(existingRecipe: recipe)
        }
        #if canImport(UIKit)
        .sheet(isPresented: $showingShareSheet) {
            if let url = exportURL {
                ShareSheet(items: [url])
            }
        }
        #endif
        .alert("Delete Profile?", isPresented: $showingDeleteConfirm) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                machineStore.deleteCustomProfile(recipe)
                dismiss()
            }
        } message: {
            Text("This action cannot be undone.")
        }
    }

    private func exportProfile() {
        if let url = machineStore.exportProfileToFile(recipe) {
            exportURL = url
            showingShareSheet = true
        }
    }
}

// MARK: - Share Sheet

#if canImport(UIKit)
struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
#endif

// MARK: - Profile Header
struct ProfileHeader: View {
    let recipe: Recipe
    let isTea: Bool

    var body: some View {
        VStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(isTea ? .green.opacity(0.2) : .orange.opacity(0.2))
                    .frame(width: 80, height: 80)

                Image(systemName: isTea ? "leaf.fill" : "cup.and.saucer.fill")
                    .font(.system(size: 36))
                    .foregroundStyle(isTea ? .green : .orange)
            }

            if isTea {
                HStack(spacing: 4) {
                    Image(systemName: "waveform.path")
                    Text("Pulse Brewing")
                }
                .font(.caption)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(.green.opacity(0.2))
                .foregroundStyle(.green)
                .clipShape(Capsule())
            }

            Text(recipe.description)
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(Color.secondarySystemGroupedBg)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Action Buttons
struct ActionButtons: View {
    @EnvironmentObject var machineStore: MachineStore
    @EnvironmentObject var bluetoothService: BluetoothService
    let recipe: Recipe
    let isActive: Bool

    var body: some View {
        HStack(spacing: 12) {
            Button {
                machineStore.setActiveRecipe(recipe)
            } label: {
                Label(
                    isActive ? "Selected" : "Select Profile",
                    systemImage: isActive ? "checkmark.circle.fill" : "checkmark.circle"
                )
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(isActive ? .green : .orange)

            if machineStore.isConnected && isActive {
                Button {
                    Task {
                        do {
                            try await bluetoothService.startEspresso()
                        } catch {
                            print("Error: \(error)")
                        }
                    }
                } label: {
                    Label("Start", systemImage: "play.fill")
                }
                .buttonStyle(.borderedProminent)
                .tint(.blue)
            }
        }
    }
}

// MARK: - Profile Visualization
struct ProfileVisualization: View {
    let steps: [ProfileStep]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Profile Curve")
                .font(.headline)

            // Simple bar chart showing pressure/flow over steps
            HStack(alignment: .bottom, spacing: 4) {
                ForEach(Array(steps.enumerated()), id: \.offset) { index, step in
                    VStack(spacing: 4) {
                        // Bar representing pressure or flow
                        RoundedRectangle(cornerRadius: 4)
                            .fill(step.pressure > 0 ? .blue : (step.flow > 0 ? .cyan : .gray))
                            .frame(width: barWidth, height: barHeight(for: step))

                        // Step name (abbreviated)
                        Text(abbreviate(step.name))
                            .font(.system(size: 8))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
            }
            .frame(height: 120)
            .padding()
            .background(Color.tertiarySystemGroupedBg)
            .clipShape(RoundedRectangle(cornerRadius: 8))

            // Legend
            HStack(spacing: 16) {
                ProfileLegendItem(color: .blue, text: "Pressure")
                ProfileLegendItem(color: .cyan, text: "Flow")
                ProfileLegendItem(color: .gray, text: "Steep")
            }
            .font(.caption)
        }
        .padding()
        .background(Color.secondarySystemGroupedBg)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    var barWidth: CGFloat {
        #if canImport(UIKit)
        let screenWidth = UIScreen.main.bounds.width
        #else
        let screenWidth: CGFloat = 390
        #endif
        return max(20, (screenWidth - 80) / CGFloat(steps.count) - 4)
    }

    func barHeight(for step: ProfileStep) -> CGFloat {
        if step.pressure > 0 {
            return CGFloat(step.pressure / 10.0) * 80 + 10
        } else if step.flow > 0 {
            return CGFloat(step.flow / 6.0) * 80 + 10
        } else {
            return 10  // Steep step (no flow)
        }
    }

    func abbreviate(_ name: String) -> String {
        if name.count <= 6 {
            return name
        }
        return String(name.prefix(5)) + "."
    }
}

struct ProfileLegendItem: View {
    let color: Color
    let text: String

    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
            Text(text)
        }
    }
}

// MARK: - Steps Section
struct StepsSection: View {
    let steps: [ProfileStep]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Steps (\(steps.count))")
                .font(.headline)

            ForEach(Array(steps.enumerated()), id: \.offset) { index, step in
                StepRow(step: step, index: index + 1)
            }
        }
        .padding()
        .background(Color.secondarySystemGroupedBg)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

struct StepRow: View {
    let step: ProfileStep
    let index: Int

    var isSteepStep: Bool {
        step.pressure == 0 && step.flow == 0
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Step number
            ZStack {
                Circle()
                    .fill(isSteepStep ? .gray.opacity(0.3) : .orange.opacity(0.2))
                    .frame(width: 32, height: 32)

                Text("\(index)")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(isSteepStep ? .gray : .orange)
            }

            // Step details
            VStack(alignment: .leading, spacing: 4) {
                Text(step.name)
                    .font(.subheadline)
                    .fontWeight(.semibold)

                HStack(spacing: 16) {
                    if step.pressure > 0 {
                        Label(String(format: "%.1f bar", step.pressure), systemImage: "gauge")
                    }
                    if step.flow > 0 {
                        Label(String(format: "%.1f ml/s", step.flow), systemImage: "drop.fill")
                    }
                    if isSteepStep {
                        Label("Steeping", systemImage: "timer")
                    }
                    Label(String(format: "%.0f\u{00B0}C", step.temperature), systemImage: "thermometer")
                }
                .font(.caption)
                .foregroundStyle(.secondary)

                // Exit condition
                Text(exitDescription)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }

            Spacer()
        }
        .padding(.vertical, 4)
    }

    var exitDescription: String {
        switch step.exit.type {
        case .time:
            return "Exit after \(Int(step.exit.value))s"
        case .weight:
            return "Exit at \(Int(step.exit.value))g"
        case .pressure:
            return "Exit at \(step.exit.value) bar"
        case .flow:
            return "Exit at \(step.exit.value) ml/s"
        }
    }
}

// MARK: - Notes Section
struct NotesSection: View {
    let notes: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Brewing Notes", systemImage: "note.text")
                .font(.headline)

            Text(notes)
                .font(.body)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color.secondarySystemGroupedBg)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Metadata Section
struct MetadataSection: View {
    let recipe: Recipe

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Details")
                .font(.headline)

            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                MetadataItem(label: "Target Weight", value: "\(Int(recipe.targetWeight))g")

                if let dose = recipe.dose {
                    MetadataItem(label: "Dose", value: "\(Int(dose))g")
                }

                if let coffee = recipe.coffeeType {
                    MetadataItem(label: "Coffee/Tea", value: coffee)
                }

                MetadataItem(label: "Author", value: recipe.author)
            }
        }
        .padding()
        .background(Color.secondarySystemGroupedBg)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

struct MetadataItem: View {
    let label: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)

            Text(value)
                .font(.subheadline)
                .fontWeight(.medium)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

#Preview {
    NavigationStack {
        ProfileDetailView(recipe: ProfilesData.allProfiles.first!)
    }
    .environmentObject(MachineStore())
    .environmentObject(BluetoothService())
}
