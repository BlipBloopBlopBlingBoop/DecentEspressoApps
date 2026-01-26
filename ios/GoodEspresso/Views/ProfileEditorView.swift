//
//  ProfileEditorView.swift
//  Good Espresso
//
//  Create and edit brewing profiles
//

import SwiftUI

struct ProfileEditorView: View {
    @EnvironmentObject var machineStore: MachineStore
    @Environment(\.dismiss) private var dismiss

    // If editing existing, pass the recipe; otherwise nil for new
    var existingRecipe: Recipe?

    @State private var name: String = ""
    @State private var description: String = ""
    @State private var author: String = ""
    @State private var targetWeight: Double = 36
    @State private var dose: Double = 18
    @State private var coffeeType: String = ""
    @State private var notes: String = ""
    @State private var steps: [ProfileStep] = []
    @State private var profileType: ProfileType = .espresso

    @State private var showingAddStep = false
    @State private var editingStepIndex: Int?
    @State private var showingDeleteAlert = false

    enum ProfileType: String, CaseIterable {
        case espresso = "Espresso"
        case tea = "Tea"
    }

    var isEditing: Bool {
        existingRecipe != nil
    }

    var isValid: Bool {
        !name.isEmpty && !steps.isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                // Basic Info Section
                Section("Basic Information") {
                    TextField("Profile Name", text: $name)
                    TextField("Description", text: $description, axis: .vertical)
                        .lineLimit(2...4)
                    TextField("Author", text: $author)

                    Picker("Type", selection: $profileType) {
                        ForEach(ProfileType.allCases, id: \.self) { type in
                            Text(type.rawValue).tag(type)
                        }
                    }
                }

                // Brewing Parameters
                Section("Brewing Parameters") {
                    HStack {
                        Text("Target Weight")
                        Spacer()
                        TextField("g", value: $targetWeight, format: .number)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 60)
                        Text("g")
                            .foregroundStyle(.secondary)
                    }

                    HStack {
                        Text("Dose")
                        Spacer()
                        TextField("g", value: $dose, format: .number)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 60)
                        Text("g")
                            .foregroundStyle(.secondary)
                    }

                    TextField("Coffee/Tea Type", text: $coffeeType)
                }

                // Steps Section
                Section {
                    ForEach(Array(steps.enumerated()), id: \.element.id) { index, step in
                        StepRowEditor(step: step, index: index + 1)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                editingStepIndex = index
                            }
                    }
                    .onDelete(perform: deleteSteps)
                    .onMove(perform: moveSteps)

                    Button {
                        showingAddStep = true
                    } label: {
                        Label("Add Step", systemImage: "plus.circle.fill")
                    }
                } header: {
                    HStack {
                        Text("Steps (\(steps.count))")
                        Spacer()
                        EditButton()
                    }
                }

                // Notes Section
                Section("Notes") {
                    TextField("Brewing notes, tips, etc.", text: $notes, axis: .vertical)
                        .lineLimit(3...6)
                }

                // Quick Templates
                if steps.isEmpty {
                    Section("Quick Start Templates") {
                        Button {
                            loadEspressoTemplate()
                        } label: {
                            Label("Basic Espresso Profile", systemImage: "cup.and.saucer.fill")
                        }

                        Button {
                            loadTeaTemplate()
                        } label: {
                            Label("Basic Tea Pulse Profile", systemImage: "leaf.fill")
                        }
                    }
                }

                // Delete Button (for editing)
                if isEditing {
                    Section {
                        Button(role: .destructive) {
                            showingDeleteAlert = true
                        } label: {
                            Label("Delete Profile", systemImage: "trash")
                                .frame(maxWidth: .infinity)
                        }
                    }
                }
            }
            .navigationTitle(isEditing ? "Edit Profile" : "New Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveProfile()
                    }
                    .disabled(!isValid)
                }
            }
            .sheet(isPresented: $showingAddStep) {
                StepEditorSheet(step: nil) { newStep in
                    steps.append(newStep)
                }
            }
            .sheet(item: $editingStepIndex) { index in
                StepEditorSheet(step: steps[index]) { updatedStep in
                    steps[index] = updatedStep
                }
            }
            .alert("Delete Profile", isPresented: $showingDeleteAlert) {
                Button("Cancel", role: .cancel) {}
                Button("Delete", role: .destructive) {
                    deleteProfile()
                }
            } message: {
                Text("Are you sure you want to delete this profile? This cannot be undone.")
            }
            .onAppear {
                loadExistingRecipe()
            }
        }
    }

    private func loadExistingRecipe() {
        guard let recipe = existingRecipe else { return }

        name = recipe.name
        description = recipe.description
        author = recipe.author
        targetWeight = recipe.targetWeight
        dose = recipe.dose ?? 18
        coffeeType = recipe.coffeeType ?? ""
        notes = recipe.notes ?? ""
        steps = recipe.steps

        if recipe.id.contains("tea") || recipe.id.contains("herbal") {
            profileType = .tea
        }
    }

    private func saveProfile() {
        let id = existingRecipe?.id ?? "\(profileType.rawValue.lowercased())-\(UUID().uuidString)"

        let recipe = Recipe(
            id: id,
            name: name,
            description: description,
            author: author.isEmpty ? "Custom" : author,
            createdAt: existingRecipe?.createdAt ?? Date(),
            updatedAt: Date(),
            favorite: existingRecipe?.favorite ?? false,
            usageCount: existingRecipe?.usageCount ?? 0,
            targetWeight: targetWeight,
            steps: steps,
            coffeeType: coffeeType.isEmpty ? nil : coffeeType,
            notes: notes.isEmpty ? nil : notes,
            dose: dose
        )

        machineStore.saveCustomProfile(recipe)
        dismiss()
    }

    private func deleteProfile() {
        if let recipe = existingRecipe {
            machineStore.deleteCustomProfile(recipe)
        }
        dismiss()
    }

    private func deleteSteps(at offsets: IndexSet) {
        steps.remove(atOffsets: offsets)
    }

    private func moveSteps(from source: IndexSet, to destination: Int) {
        steps.move(fromOffsets: source, toOffset: destination)
    }

    private func loadEspressoTemplate() {
        profileType = .espresso
        steps = [
            ProfileStep(
                name: "Preinfusion",
                temperature: 93,
                pressure: 0,
                flow: 4,
                transition: "smooth",
                exit: ExitCondition(type: .time, value: 10)
            ),
            ProfileStep(
                name: "Ramp Up",
                temperature: 93,
                pressure: 9,
                flow: 0,
                transition: "smooth",
                exit: ExitCondition(type: .time, value: 5)
            ),
            ProfileStep(
                name: "Extraction",
                temperature: 93,
                pressure: 9,
                flow: 0,
                transition: "smooth",
                exit: ExitCondition(type: .weight, value: 36)
            )
        ]
    }

    private func loadTeaTemplate() {
        profileType = .tea
        targetWeight = 200
        steps = [
            ProfileStep(
                name: "Fill",
                temperature: 85,
                pressure: 0,
                flow: 6,
                transition: "fast",
                exit: ExitCondition(type: .time, value: 8)
            ),
            ProfileStep(
                name: "Valve Open",
                temperature: 85,
                pressure: 0.5,
                flow: 0,
                transition: "fast",
                exit: ExitCondition(type: .time, value: 2)
            ),
            ProfileStep(
                name: "Steep",
                temperature: 85,
                pressure: 0,
                flow: 0,
                transition: "smooth",
                exit: ExitCondition(type: .time, value: 30)
            ),
            ProfileStep(
                name: "Pulse",
                temperature: 85,
                pressure: 0,
                flow: 4,
                transition: "fast",
                exit: ExitCondition(type: .time, value: 3)
            ),
            ProfileStep(
                name: "Final Drain",
                temperature: 85,
                pressure: 0,
                flow: 6,
                transition: "fast",
                exit: ExitCondition(type: .time, value: 10)
            )
        ]
    }
}

// MARK: - Step Row for Display
struct StepRowEditor: View {
    let step: ProfileStep
    let index: Int

    var isSteepStep: Bool {
        step.pressure == 0 && step.flow == 0
    }

    var body: some View {
        HStack(spacing: 12) {
            // Step number
            ZStack {
                Circle()
                    .fill(stepColor.opacity(0.2))
                    .frame(width: 28, height: 28)

                Text("\(index)")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(stepColor)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(step.name)
                    .font(.subheadline)
                    .fontWeight(.medium)

                HStack(spacing: 8) {
                    if step.pressure > 0 {
                        Text("\(step.pressure, specifier: "%.1f") bar")
                    }
                    if step.flow > 0 {
                        Text("\(step.flow, specifier: "%.1f") ml/s")
                    }
                    if isSteepStep {
                        Text("Steep")
                    }
                    Text("\(step.temperature, specifier: "%.0f")°C")
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 4)
    }

    var stepColor: Color {
        if step.pressure > 0 { return .blue }
        if step.flow > 0 { return .cyan }
        return .gray
    }
}

// MARK: - Step Editor Sheet
struct StepEditorSheet: View {
    @Environment(\.dismiss) private var dismiss

    var step: ProfileStep?
    var onSave: (ProfileStep) -> Void

    @State private var name: String = ""
    @State private var temperature: Double = 93
    @State private var pressure: Double = 0
    @State private var flow: Double = 0
    @State private var transition: String = "smooth"
    @State private var exitType: ExitCondition.ExitType = .time
    @State private var exitValue: Double = 10

    @State private var stepMode: StepMode = .flow

    enum StepMode: String, CaseIterable {
        case pressure = "Pressure"
        case flow = "Flow"
        case steep = "Steep (No Flow)"
    }

    var isValid: Bool {
        !name.isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Step Name") {
                    TextField("e.g., Preinfusion, Extraction", text: $name)
                }

                Section("Mode") {
                    Picker("Control Mode", selection: $stepMode) {
                        ForEach(StepMode.allCases, id: \.self) { mode in
                            Text(mode.rawValue).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                    .onChange(of: stepMode) { _, newMode in
                        switch newMode {
                        case .pressure:
                            pressure = 9
                            flow = 0
                        case .flow:
                            pressure = 0
                            flow = 4
                        case .steep:
                            pressure = 0
                            flow = 0
                        }
                    }
                }

                Section("Parameters") {
                    HStack {
                        Text("Temperature")
                        Spacer()
                        TextField("°C", value: $temperature, format: .number)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 60)
                        Text("°C")
                            .foregroundStyle(.secondary)
                    }

                    if stepMode == .pressure {
                        HStack {
                            Text("Pressure")
                            Spacer()
                            TextField("bar", value: $pressure, format: .number)
                                .keyboardType(.decimalPad)
                                .multilineTextAlignment(.trailing)
                                .frame(width: 60)
                            Text("bar")
                                .foregroundStyle(.secondary)
                        }

                        Slider(value: $pressure, in: 0...12, step: 0.5) {
                            Text("Pressure")
                        }
                    }

                    if stepMode == .flow {
                        HStack {
                            Text("Flow Rate")
                            Spacer()
                            TextField("ml/s", value: $flow, format: .number)
                                .keyboardType(.decimalPad)
                                .multilineTextAlignment(.trailing)
                                .frame(width: 60)
                            Text("ml/s")
                                .foregroundStyle(.secondary)
                        }

                        Slider(value: $flow, in: 0...10, step: 0.5) {
                            Text("Flow")
                        }
                    }

                    Picker("Transition", selection: $transition) {
                        Text("Smooth").tag("smooth")
                        Text("Fast").tag("fast")
                    }
                }

                Section("Exit Condition") {
                    Picker("Exit When", selection: $exitType) {
                        Text("Time").tag(ExitCondition.ExitType.time)
                        Text("Weight").tag(ExitCondition.ExitType.weight)
                        Text("Pressure").tag(ExitCondition.ExitType.pressure)
                        Text("Flow").tag(ExitCondition.ExitType.flow)
                    }

                    HStack {
                        Text("Value")
                        Spacer()
                        TextField("", value: $exitValue, format: .number)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 60)
                        Text(exitUnit)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle(step == nil ? "Add Step" : "Edit Step")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveStep()
                    }
                    .disabled(!isValid)
                }
            }
            .onAppear {
                loadStep()
            }
        }
    }

    var exitUnit: String {
        switch exitType {
        case .time: return "seconds"
        case .weight: return "grams"
        case .pressure: return "bar"
        case .flow: return "ml/s"
        }
    }

    private func loadStep() {
        guard let step = step else { return }

        name = step.name
        temperature = step.temperature
        pressure = step.pressure
        flow = step.flow
        transition = step.transition
        exitType = step.exit.type
        exitValue = step.exit.value

        if step.pressure > 0 {
            stepMode = .pressure
        } else if step.flow > 0 {
            stepMode = .flow
        } else {
            stepMode = .steep
        }
    }

    private func saveStep() {
        let newStep = ProfileStep(
            name: name,
            temperature: temperature,
            pressure: stepMode == .pressure ? pressure : 0,
            flow: stepMode == .flow ? flow : 0,
            transition: transition,
            exit: ExitCondition(type: exitType, value: exitValue)
        )
        onSave(newStep)
        dismiss()
    }
}

// Make Int Identifiable for sheet
extension Int: @retroactive Identifiable {
    public var id: Int { self }
}

#Preview {
    ProfileEditorView()
        .environmentObject(MachineStore())
}
