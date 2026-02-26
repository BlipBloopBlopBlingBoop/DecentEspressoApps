//
//  PuckSimulationView.swift
//  Good Espresso
//
//  Interactive CFD-based puck flow visualization.
//  Canvas-rendered 2D cross-section with real-time parameter adjustment.
//

import SwiftUI

// MARK: - Visualization Mode

enum PuckVizMode: String, CaseIterable, Identifiable {
    case pressure     = "Pressure"
    case flow         = "Flow Velocity"
    case extraction   = "Extraction"
    case permeability = "Permeability"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .pressure:     return "gauge.with.needle.fill"
        case .flow:         return "wind"
        case .extraction:   return "cup.and.saucer.fill"
        case .permeability: return "circle.grid.3x3.fill"
        }
    }

    var legend: (low: String, high: String) {
        switch self {
        case .pressure:     return ("0 bar", "Brew P")
        case .flow:         return ("Stagnant", "Fast")
        case .extraction:   return ("Under", "Over")
        case .permeability: return ("Dense", "Porous")
        }
    }
}

// MARK: - Main View

struct PuckSimulationView: View {
    @EnvironmentObject var machineStore: MachineStore
    @State private var params = PuckParameters()
    @State private var result: PuckSimulationResult?
    @State private var vizMode: PuckVizMode = .flow
    @State private var isComputing = false
    @State private var showBasketPicker = false
    @State private var showParameterInfo = false
    @State private var isLiveMode = false
    @State private var simulationSerial: Int = 0
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    private var isCompact: Bool { horizontalSizeClass == .compact }

    /// Fingerprint of all params — when this changes, re-run simulation
    private var paramFingerprint: String {
        "\(params.grindSizeMicrons)|\(params.doseGrams)|\(params.tampPressureKg)|" +
        "\(params.brewPressureBar)|\(params.waterTempC)|\(params.beanDensity)|" +
        "\(params.moistureContent)|\(params.distributionQuality)|\(params.basket.id)"
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                if isCompact {
                    compactLayout
                } else {
                    wideLayout
                }
            }
            .background(Color.systemGroupedBg)
            .navigationTitle("Puck Simulation")
            .inlineNavigationBarTitle()
            .toolbar {
                ToolbarItem(placement: .topBarTrailingCompat) {
                    HStack(spacing: 12) {
                        Button {
                            withAnimation { isLiveMode.toggle() }
                        } label: {
                            Image(systemName: isLiveMode ? "antenna.radiowaves.left.and.right.circle.fill" : "antenna.radiowaves.left.and.right.circle")
                                .foregroundStyle(isLiveMode ? .green : .secondary)
                        }
                        .disabled(!machineStore.isConnected)

                        Button {
                            showParameterInfo = true
                        } label: {
                            Image(systemName: "info.circle")
                        }
                    }
                }
            }
            .sheet(isPresented: $showParameterInfo) {
                ParameterInfoSheet()
            }
            .task {
                await runSimulation()
            }
            .onChangeCompat(of: paramFingerprint) {
                // Debounced auto-run: increment serial, wait, check if still current
                simulationSerial += 1
                let serial = simulationSerial
                Task {
                    try? await Task.sleep(nanoseconds: 200_000_000) // 200ms debounce
                    guard serial == simulationSerial else { return }
                    await runSimulation()
                }
            }
            .onChangeCompat(of: machineStore.machineState.pressure) {
                guard isLiveMode else { return }
                syncFromMachine()
            }
            .onChangeCompat(of: isLiveMode) {
                if isLiveMode { syncFromMachine() }
            }
        }
    }

    // MARK: - Compact Layout (iPhone)

    private var compactLayout: some View {
        LazyVStack(spacing: 16) {
            basketSelector
            visualizationCard
            summaryStatsCard
            parameterSliders
        }
        .padding()
    }

    // MARK: - Wide Layout (iPad/Mac)

    private var wideLayout: some View {
        LazyVStack(spacing: 20) {
            basketSelector

            HStack(alignment: .top, spacing: 20) {
                visualizationCard
                    .frame(maxWidth: .infinity)

                VStack(spacing: 20) {
                    summaryStatsCard
                    parameterSliders
                }
                .frame(maxWidth: 400)
            }
        }
        .padding()
        .frame(maxWidth: 1400)
        .frame(maxWidth: .infinity)
    }

    // MARK: - Basket Selector

    private var basketSelector: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 6) {
                Image(systemName: "basket.fill")
                    .foregroundStyle(.orange)
                Text("Basket")
                    .font(.headline)
                Spacer()
                Text(params.basket.name)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(BasketSpec.allBaskets) { basket in
                        BasketChip(
                            basket: basket,
                            isSelected: params.basket.id == basket.id
                        ) {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                params.basket = basket
                                params.doseGrams = basket.nominalDose
                            }
                        }
                    }
                }
            }

            // Basket description
            Text(params.basket.description)
                .font(.caption)
                .foregroundStyle(.secondary)
                .transition(.opacity)

            if params.basket.hasBackPressureValve {
                HStack(spacing: 6) {
                    Image(systemName: "valve.fill")
                        .font(.caption)
                        .foregroundStyle(.orange)
                    Text("Back-pressure valve: \(String(format: "%.1f", params.basket.backPressureBar)) bar")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(Color.orange.opacity(0.1))
                .clipShape(Capsule())
            }
        }
        .analyticsCard()
    }

    // MARK: - Visualization Card

    private var visualizationCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 6) {
                Image(systemName: "drop.degreesign.fill")
                    .foregroundStyle(.cyan)
                Text("Puck Cross-Section")
                    .font(.headline)
                Spacer()
                Text("CFD")
                    .font(.system(size: 9))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.cyan.opacity(0.1))
                    .clipShape(Capsule())
            }

            // Viz mode picker
            Picker("Mode", selection: $vizMode) {
                ForEach(PuckVizMode.allCases) { mode in
                    Label(mode.rawValue, systemImage: mode.icon).tag(mode)
                }
            }
            .pickerStyle(.segmented)

            // Live mode banner
            if isLiveMode {
                HStack(spacing: 6) {
                    Circle()
                        .fill(machineStore.machineState.state == .brewing ? .green : .orange)
                        .frame(width: 8, height: 8)
                    Text(machineStore.machineState.state == .brewing ? "Live — Brewing" : "Live — Waiting for shot")
                        .font(.caption)
                        .fontWeight(.medium)
                    Spacer()
                    Text(String(format: "%.1f bar / %.1f\u{00B0}C",
                                machineStore.machineState.pressure,
                                machineStore.machineState.temperature.mix))
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color.green.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 6))
            }

            // 3D Visualization
            if let result = result {
                Puck3DSceneView(
                    result: result,
                    mode: vizMode,
                    basketSpec: params.basket,
                    grindSizeMicrons: params.grindSizeMicrons,
                    isComputing: isComputing
                )
                .aspectRatio(1.1, contentMode: .fit)
                .frame(minHeight: isCompact ? 260 : 320)
                .frame(maxWidth: .infinity)
                .clipShape(RoundedRectangle(cornerRadius: 8))

                // Legend bar
                legendBar
            } else {
                VStack(spacing: 8) {
                    ProgressView()
                        .tint(.cyan)
                    Text("Running CFD simulation...")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, minHeight: 200)
            }
        }
        .analyticsCard()
    }

    private var legendBar: some View {
        VStack(spacing: 4) {
            // Gradient bar
            GeometryReader { geo in
                Canvas { context, size in
                    let steps = 60
                    let stepWidth = size.width / CGFloat(steps)
                    for i in 0..<steps {
                        let t = Double(i) / Double(steps - 1)
                        let color = heatmapColor(t, mode: vizMode)
                        let rect = CGRect(x: stepWidth * CGFloat(i), y: 0, width: stepWidth + 1, height: size.height)
                        context.fill(Path(rect), with: .color(color))
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 3))
            }
            .frame(height: 12)

            HStack {
                Text(vizMode.legend.low)
                    .font(.system(size: 9))
                    .foregroundStyle(.secondary)
                Spacer()
                Text(vizMode.legend.high)
                    .font(.system(size: 9))
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Summary Stats

    private var summaryStatsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 6) {
                Image(systemName: "chart.bar.doc.horizontal.fill")
                    .foregroundStyle(.green)
                Text("Simulation Results")
                    .font(.headline)
            }

            if let r = result {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    SimStat(
                        label: "Flow Rate",
                        value: String(format: "%.1f ml/s", r.totalFlowRate),
                        icon: "drop.fill",
                        color: .cyan
                    )
                    SimStat(
                        label: "Channeling Risk",
                        value: String(format: "%.0f%%", r.channelingRisk * 100),
                        icon: "exclamationmark.triangle.fill",
                        color: r.channelingRisk > 0.5 ? .red : (r.channelingRisk > 0.25 ? .yellow : .green)
                    )
                    SimStat(
                        label: "Uniformity",
                        value: String(format: "%.0f%%", r.uniformityIndex * 100),
                        icon: "circle.grid.3x3.fill",
                        color: r.uniformityIndex > 0.7 ? .green : .orange
                    )
                    SimStat(
                        label: "Est. Shot Time",
                        value: String(format: "%.0fs", r.effectiveShotTime),
                        icon: "timer",
                        color: (r.effectiveShotTime >= 24 && r.effectiveShotTime <= 32) ? .green : .orange
                    )
                    SimStat(
                        label: "Puck Height",
                        value: String(format: "%.1f mm", params.puckHeightMM),
                        icon: "ruler.fill",
                        color: .purple
                    )
                    SimStat(
                        label: "Porosity",
                        value: String(format: "%.1f%%", params.porosity * 100),
                        icon: "circle.dotted",
                        color: .indigo
                    )
                }

                // Channeling advisory
                if r.channelingRisk > 0.5 {
                    HStack(spacing: 8) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.red)
                        Text("High channeling risk. Improve distribution (WDT), reduce dose, or grind coarser.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(10)
                    .background(Color.red.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                } else if r.channelingRisk > 0.25 {
                    HStack(spacing: 8) {
                        Image(systemName: "info.circle.fill")
                            .foregroundStyle(.yellow)
                        Text("Moderate channeling risk at edges. Consider a more thorough WDT.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(10)
                    .background(Color.yellow.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                } else {
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                        Text("Good flow uniformity. Even extraction predicted.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(10)
                    .background(Color.green.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
            } else {
                ProgressView()
                    .frame(maxWidth: .infinity, minHeight: 100)
            }
        }
        .analyticsCard()
    }

    // MARK: - Parameter Sliders

    private var parameterSliders: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 6) {
                Image(systemName: "slider.horizontal.3")
                    .foregroundStyle(.purple)
                Text("Parameters")
                    .font(.headline)
            }

            SimSlider(
                label: "Grind Size",
                value: $params.grindSizeMicrons,
                range: 200...800,
                step: 10,
                unit: "µm",
                icon: "circle.grid.2x1.fill",
                color: .brown,
                hint: "200 = Turkish, 400 = Espresso, 800 = Filter"
            )

            SimSlider(
                label: "Dose",
                value: $params.doseGrams,
                range: 5...25,
                step: 0.5,
                unit: "g",
                icon: "scalemass.fill",
                color: .orange,
                hint: "Weight of ground coffee in the basket"
            )

            SimSlider(
                label: "Tamp Pressure",
                value: $params.tampPressureKg,
                range: 5...30,
                step: 1,
                unit: "kg",
                icon: "arrow.down.circle.fill",
                color: .blue,
                hint: "Force applied when tamping. 15 kg is standard."
            )

            SimSlider(
                label: "Brew Pressure",
                value: $params.brewPressureBar,
                range: 1...12,
                step: 0.5,
                unit: "bar",
                icon: "gauge.with.needle.fill",
                color: .red,
                hint: "Machine pump pressure. 9 bar is traditional."
            )

            SimSlider(
                label: "Water Temp",
                value: $params.waterTempC,
                range: 70...100,
                step: 0.5,
                unit: "\u{00B0}C",
                icon: "thermometer.medium",
                color: .orange,
                hint: "Affects water viscosity: hotter = thinner = faster flow"
            )

            SimSlider(
                label: "Bean Density",
                value: $params.beanDensity,
                range: 1.05...1.25,
                step: 0.01,
                unit: "g/cm\u{00B3}",
                icon: "leaf.fill",
                color: .green,
                hint: "Light roast ~1.10, Medium ~1.15, Dark ~1.20"
            )

            SimSlider(
                label: "Moisture",
                value: $params.moistureContent,
                range: 0.02...0.18,
                step: 0.01,
                unit: "%",
                icon: "humidity.fill",
                color: .cyan,
                hint: "Bean moisture. Fresh ~10-12%, stale/dry <5%",
                displayMultiplier: 100
            )

            SimSlider(
                label: "Distribution",
                value: $params.distributionQuality,
                range: 0.3...1.0,
                step: 0.05,
                unit: "",
                icon: "wand.and.stars",
                color: .purple,
                hint: "Puck prep quality. 1.0 = perfect WDT, 0.3 = dump and tamp",
                displayMultiplier: 100,
                displayUnit: "%"
            )

            // Status
            HStack(spacing: 6) {
                if isComputing {
                    ProgressView()
                        .scaleEffect(0.7)
                    Text("Updating...")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.caption)
                        .foregroundStyle(.green)
                    Text("Visualization is live — drag sliders to update")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .analyticsCard()
    }

    // MARK: - Live Machine Sync

    private func syncFromMachine() {
        let state = machineStore.machineState
        if state.pressure > 0 {
            params.brewPressureBar = state.pressure
        }
        if state.temperature.mix > 0 {
            params.waterTempC = state.temperature.mix
        }
    }

    // MARK: - Simulation Runner

    private func runSimulation() async {
        isComputing = true
        let p = params
        let res = await Task.detached {
            PuckCFDSolver.simulate(params: p)
        }.value
        withAnimation(.easeInOut(duration: 0.3)) {
            result = res
        }
        isComputing = false
    }
}

// MARK: - Heatmap Color Function

func heatmapColor(_ value: Double, mode: PuckVizMode) -> Color {
    let t = max(0, min(1, value))

    switch mode {
    case .pressure:
        // Blue (low) -> Cyan -> Green -> Yellow -> Red (high)
        if t < 0.25 {
            let f = t / 0.25
            return Color(red: 0, green: f * 0.5, blue: 0.6 + f * 0.4)
        } else if t < 0.5 {
            let f = (t - 0.25) / 0.25
            return Color(red: 0, green: 0.5 + f * 0.5, blue: 1.0 - f * 0.5)
        } else if t < 0.75 {
            let f = (t - 0.5) / 0.25
            return Color(red: f, green: 1.0, blue: 0.5 - f * 0.5)
        } else {
            let f = (t - 0.75) / 0.25
            return Color(red: 1.0, green: 1.0 - f * 0.7, blue: 0)
        }

    case .flow:
        // Dark blue (slow) -> Cyan -> White -> Yellow -> Red (fast/channel)
        if t < 0.2 {
            let f = t / 0.2
            return Color(red: 0.02, green: 0.02 + f * 0.15, blue: 0.15 + f * 0.4)
        } else if t < 0.4 {
            let f = (t - 0.2) / 0.2
            return Color(red: 0, green: 0.17 + f * 0.63, blue: 0.55 + f * 0.45)
        } else if t < 0.6 {
            let f = (t - 0.4) / 0.2
            return Color(red: f * 0.9, green: 0.8 + f * 0.2, blue: 1.0 - f * 0.2)
        } else if t < 0.8 {
            let f = (t - 0.6) / 0.2
            return Color(red: 0.9 + f * 0.1, green: 1.0 - f * 0.3, blue: 0.8 - f * 0.8)
        } else {
            let f = (t - 0.8) / 0.2
            return Color(red: 1.0, green: 0.7 - f * 0.5, blue: 0)
        }

    case .extraction:
        // Dark (under) -> Green (ideal) -> Orange -> Red (over)
        if t < 0.3 {
            let f = t / 0.3
            return Color(red: 0.05, green: 0.08 + f * 0.3, blue: 0.05 + f * 0.1)
        } else if t < 0.55 {
            let f = (t - 0.3) / 0.25
            return Color(red: 0.05 + f * 0.1, green: 0.38 + f * 0.52, blue: 0.15 - f * 0.05)
        } else if t < 0.75 {
            let f = (t - 0.55) / 0.2
            return Color(red: 0.15 + f * 0.85, green: 0.9 - f * 0.2, blue: 0.1)
        } else {
            let f = (t - 0.75) / 0.25
            return Color(red: 1.0, green: 0.7 - f * 0.55, blue: 0.1 - f * 0.1)
        }

    case .permeability:
        // Dark purple (dense) -> Blue -> Teal -> Light green (porous)
        if t < 0.33 {
            let f = t / 0.33
            return Color(red: 0.15 + f * 0.05, green: 0.05 + f * 0.15, blue: 0.25 + f * 0.35)
        } else if t < 0.66 {
            let f = (t - 0.33) / 0.33
            return Color(red: 0.2 - f * 0.1, green: 0.2 + f * 0.45, blue: 0.6 - f * 0.1)
        } else {
            let f = (t - 0.66) / 0.34
            return Color(red: 0.1 + f * 0.3, green: 0.65 + f * 0.25, blue: 0.5 - f * 0.25)
        }
    }
}

// MARK: - Supporting Views

struct BasketChip: View {
    let basket: BasketSpec
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: basket.hasBackPressureValve ? "leaf.fill" : "circle.circle")
                    .font(.system(size: 16))
                Text(basket.name)
                    .font(.system(size: 11, weight: .medium))
                Text("\(Int(basket.nominalDose))g")
                    .font(.system(size: 9))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(isSelected ? Color.orange.opacity(0.15) : Color.tertiarySystemGroupedBg)
            .foregroundStyle(isSelected ? .orange : .primary)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .strokeBorder(isSelected ? Color.orange : Color.clear, lineWidth: 1.5)
            )
        }
        .buttonStyle(.plain)
    }
}

struct SimStat: View {
    let label: String
    let value: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(color)
            Text(value)
                .font(.subheadline)
                .fontWeight(.bold)
                .monospacedDigit()
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
    }
}

struct SimSlider: View {
    let label: String
    @Binding var value: Double
    let range: ClosedRange<Double>
    let step: Double
    let unit: String
    let icon: String
    let color: Color
    let hint: String
    var displayMultiplier: Double = 1
    var displayUnit: String? = nil

    @State private var showHint = false

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Image(systemName: icon)
                    .font(.caption)
                    .foregroundStyle(color)
                    .frame(width: 16)
                Text(label)
                    .font(.subheadline)
                    .fontWeight(.medium)

                Button {
                    showHint.toggle()
                } label: {
                    Image(systemName: "questionmark.circle")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)

                Spacer()

                Text(String(format: displayMultiplier == 1 ? "%.1f" : "%.0f",
                           value * displayMultiplier) + " " + (displayUnit ?? unit))
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(color)
                    .fontWeight(.medium)
            }

            Slider(value: $value, in: range, step: step)
                .tint(color)

            if showHint {
                Text(hint)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }
}

// MARK: - Parameter Info Sheet

struct ParameterInfoSheet: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section("Physics Model") {
                    infoRow("Darcy's Law",
                            detail: "Q = (k\u{00B7}A\u{00B7}\u{0394}P) / (\u{00B5}\u{00B7}L)\nGoverns fluid flow through porous media. Flow rate is proportional to permeability, area, and pressure gradient, inversely proportional to viscosity and bed length.")
                    infoRow("Kozeny-Carman",
                            detail: "k = (\u{03B5}\u{00B3}\u{00B7}d\u{00B2}) / (180\u{00B7}(1-\u{03B5})\u{00B2})\nRelates puck permeability to particle size (grind) and porosity (packing). Finer grind = exponentially lower permeability.")
                    infoRow("Ergun Equation",
                            detail: "Models both viscous and inertial pressure drop through the puck. At espresso pressures, the inertial term becomes significant.")
                }

                Section("Parameters") {
                    infoRow("Grind Size",
                            detail: "Particle diameter in microns. Espresso range: 200-800 \u{00B5}m. Permeability scales with d\u{00B2}, so halving grind size quarters the flow rate.")
                    infoRow("Dose",
                            detail: "Coffee mass determines puck height for a given basket. More coffee = taller puck = more resistance = slower flow.")
                    infoRow("Tamp Pressure",
                            detail: "Compresses the puck, reducing porosity. Each kg of force reduces porosity by ~0.4%. Diminishing returns above ~15 kg.")
                    infoRow("Distribution Quality",
                            detail: "Models how evenly coffee is distributed before tamping. 100% = perfect WDT, 30% = dump and tamp. Affects local permeability variation — the #1 cause of channeling.")
                    infoRow("Bean Density",
                            detail: "Light roasts (~1.10 g/cm\u{00B3}) are denser than dark roasts (~1.20 g/cm\u{00B3}). Affects puck height for a given dose.")
                    infoRow("Moisture",
                            detail: "Bean moisture content (2-18%). Higher moisture causes particle swelling, reducing porosity and permeability. Fresh beans ~10-12%.")
                }

                Section("Basket Physics") {
                    infoRow("Wall Effects",
                            detail: "Porosity is 15-25% higher near basket walls due to geometric packing constraints. This creates the 'donut' channeling pattern common in espresso.")
                    infoRow("Fines Migration",
                            detail: "Fine particles migrate downward during extraction, reducing permeability at the puck bottom. This is modeled as a 20% permeability reduction in the bottom 30% of the puck.")
                    infoRow("Tea Basket Valve",
                            detail: "The Decent tea basket has a mushroom-style back-pressure valve (~2 bar). This maintains pressure even without a dense coffee puck, enabling tea brewing with proper infusion.")
                }
            }
            .navigationTitle("Simulation Physics")
            .inlineNavigationBarTitle()
            .toolbar {
                ToolbarItem(placement: .topBarTrailingCompat) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private func infoRow(_ title: String, detail: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.subheadline)
                .fontWeight(.semibold)
            Text(detail)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }
}
