//
//  MachineStore.swift
//  Good Espresso
//
//  Observable state store for machine data and app state
//

import Foundation
import SwiftUI
import Combine
import UniformTypeIdentifiers

@MainActor
class MachineStore: ObservableObject {
    // MARK: - Connection State
    @Published var isConnected: Bool = false
    @Published var isConnecting: Bool = false
    @Published var connectionError: String?
    @Published var deviceName: String?

    // MARK: - Scale Connection State
    @Published var isScaleConnected: Bool = false
    @Published var scaleName: String?
    @Published var scaleWeight: Double = 0
    @Published var scaleFlowRate: Double = 0
    @Published var isScaleStable: Bool = false

    // MARK: - Machine State
    @Published var machineState: MachineState = MachineState()

    // MARK: - Active Recipe
    @Published var activeRecipe: Recipe?

    // MARK: - Shot Recording
    @Published var isRecording: Bool = false
    @Published var activeShot: ShotRecord?
    @Published var shotHistory: [ShotRecord] = []

    // MARK: - All Recipes
    @Published var recipes: [Recipe] = []
    @Published var favoriteRecipes: [Recipe] = []
    @Published var customRecipes: [Recipe] = []

    // MARK: - Settings
    @Published var temperatureUnit: String = "celsius"  // or "fahrenheit"
    @Published var weightUnit: String = "grams"  // or "ounces"
    @Published var autoTare: Bool = true
    @Published var autoStopOnWeight: Bool = true

    // MARK: - Initialization
    init() {
        loadRecipes()
        loadShotHistory()
        loadSettings()
    }

    // MARK: - Scale Updates
    func updateScaleWeight(_ weight: Double) {
        scaleWeight = weight
        machineState.weight = weight

        // Add weight to active shot data points
        if isRecording, var shot = activeShot,
           let lastPoint = shot.dataPoints.last {
            // Update the weight on the most recent data point
            var updatedPoint = lastPoint
            updatedPoint.weight = weight
            shot.dataPoints[shot.dataPoints.count - 1] = updatedPoint
            activeShot = shot
        }

        // Auto-stop on target weight
        if autoStopOnWeight, isRecording,
           let target = activeRecipe?.targetWeight,
           weight >= target * 0.95 {  // 95% of target
            // Notify to stop - handled by view/controller
            NotificationCenter.default.post(name: .targetWeightReached, object: nil)
        }
    }

    func updateScaleFlowRate(_ flowRate: Double) {
        scaleFlowRate = flowRate
    }

    func updateScaleStable(_ stable: Bool) {
        isScaleStable = stable
    }

    func setScaleConnected(_ connected: Bool, name: String? = nil) {
        isScaleConnected = connected
        scaleName = name
        if !connected {
            scaleWeight = 0
            scaleFlowRate = 0
        }
    }

    // MARK: - Settings Persistence
    func loadSettings() {
        autoTare = UserDefaults.standard.bool(forKey: "autoTare")
        autoStopOnWeight = UserDefaults.standard.bool(forKey: "autoStopOnWeight")
        if !UserDefaults.standard.bool(forKey: "settingsInitialized") {
            autoTare = true
            autoStopOnWeight = true
            UserDefaults.standard.set(true, forKey: "settingsInitialized")
        }
    }

    func saveSettings() {
        UserDefaults.standard.set(autoTare, forKey: "autoTare")
        UserDefaults.standard.set(autoStopOnWeight, forKey: "autoStopOnWeight")
    }

    // MARK: - Recipe Management
    func loadRecipes() {
        // Load built-in profiles
        var allRecipes = ProfilesData.allProfiles

        // Load custom profiles
        loadCustomRecipes()
        allRecipes.append(contentsOf: customRecipes)

        recipes = allRecipes
        favoriteRecipes = recipes.filter { $0.favorite }

        // Set default active recipe if none selected
        if activeRecipe == nil, let first = recipes.first {
            activeRecipe = first
        }
    }

    func setActiveRecipe(_ recipe: Recipe) {
        activeRecipe = recipe
        // Save to UserDefaults
        UserDefaults.standard.set(recipe.id, forKey: "activeRecipeId")
    }

    func toggleFavorite(_ recipe: Recipe) {
        if let index = recipes.firstIndex(where: { $0.id == recipe.id }) {
            recipes[index].favorite.toggle()
            favoriteRecipes = recipes.filter { $0.favorite }

            // If it's a custom recipe, save the change
            if let customIndex = customRecipes.firstIndex(where: { $0.id == recipe.id }) {
                customRecipes[customIndex].favorite.toggle()
                saveCustomRecipes()
            }
        }
    }

    // MARK: - Custom Profile Management
    func loadCustomRecipes() {
        if let data = UserDefaults.standard.data(forKey: "customRecipes"),
           let custom = try? JSONDecoder().decode([Recipe].self, from: data) {
            customRecipes = custom
        }
    }

    func saveCustomRecipes() {
        if let data = try? JSONEncoder().encode(customRecipes) {
            UserDefaults.standard.set(data, forKey: "customRecipes")
        }
    }

    func saveCustomProfile(_ recipe: Recipe) {
        // Check if updating existing
        if let index = customRecipes.firstIndex(where: { $0.id == recipe.id }) {
            customRecipes[index] = recipe
        } else {
            customRecipes.append(recipe)
        }

        saveCustomRecipes()

        // Reload all recipes to include the new/updated one
        loadRecipes()
    }

    func deleteCustomProfile(_ recipe: Recipe) {
        customRecipes.removeAll { $0.id == recipe.id }
        saveCustomRecipes()

        // If deleted recipe was active, clear it
        if activeRecipe?.id == recipe.id {
            activeRecipe = recipes.first
        }

        loadRecipes()
    }

    func isCustomProfile(_ recipe: Recipe) -> Bool {
        customRecipes.contains { $0.id == recipe.id }
    }

    func duplicateProfile(_ recipe: Recipe) -> Recipe {
        var copy = recipe
        copy.id = "\(recipe.id)-copy-\(UUID().uuidString.prefix(8))"
        copy.name = "\(recipe.name) (Copy)"
        copy.createdAt = Date()
        copy.updatedAt = Date()
        copy.author = "Custom"
        return copy
    }

    // MARK: - Shot Recording
    func startShot(profileName: String, profileId: String?) {
        let shot = ShotRecord(
            id: UUID().uuidString,
            profileId: profileId,
            profileName: profileName,
            startTime: Date(),
            endTime: nil,
            duration: 0,
            dataPoints: [],
            finalWeight: nil,
            rating: nil,
            notes: nil,
            coffeeType: activeRecipe?.coffeeType,
            dose: activeRecipe?.dose,
            yield: nil,
            ratio: nil
        )
        activeShot = shot
        isRecording = true
    }

    func addDataPoint(_ point: ShotDataPoint) {
        activeShot?.dataPoints.append(point)
    }

    func endShot() {
        guard var shot = activeShot else { return }

        shot.endTime = Date()
        shot.duration = shot.endTime!.timeIntervalSince(shot.startTime)

        if let lastPoint = shot.dataPoints.last {
            shot.finalWeight = lastPoint.weight
        }

        // Calculate yield and ratio
        if let weight = shot.finalWeight, let dose = shot.dose, dose > 0 {
            shot.yield = weight
            let ratio = weight / dose
            shot.ratio = String(format: "1:%.1f", ratio)
        }

        shotHistory.insert(shot, at: 0)
        saveShotHistory()

        activeShot = nil
        isRecording = false
    }

    // MARK: - Persistence
    func loadShotHistory() {
        if let data = UserDefaults.standard.data(forKey: "shotHistory"),
           let history = try? JSONDecoder().decode([ShotRecord].self, from: data) {
            shotHistory = history
        }
    }

    func saveShotHistory() {
        // Keep only last 100 shots
        let historyToSave = Array(shotHistory.prefix(100))
        if let data = try? JSONEncoder().encode(historyToSave) {
            UserDefaults.standard.set(data, forKey: "shotHistory")
        }
    }

    func deleteShot(_ shot: ShotRecord) {
        shotHistory.removeAll { $0.id == shot.id }
        saveShotHistory()
    }

    func rateShot(_ shot: ShotRecord, rating: Int) {
        if let index = shotHistory.firstIndex(where: { $0.id == shot.id }) {
            shotHistory[index].rating = rating
            saveShotHistory()
        }
    }

    // MARK: - State Updates (called from BluetoothService)
    func updateMachineState(_ state: MachineState) {
        machineState = state
    }

    func setConnected(_ connected: Bool, deviceName: String? = nil) {
        isConnected = connected
        isConnecting = false
        self.deviceName = deviceName
        connectionError = nil

        if !connected {
            machineState.state = .disconnected
        }
    }

    func setConnecting(_ connecting: Bool) {
        isConnecting = connecting
    }

    func setConnectionError(_ error: String) {
        connectionError = error
        isConnecting = false
    }

    func reset() {
        isConnected = false
        isConnecting = false
        connectionError = nil
        deviceName = nil
        machineState = MachineState()
    }

    // MARK: - Temperature Conversion
    func formatTemperature(_ celsius: Double) -> String {
        if temperatureUnit == "fahrenheit" {
            let fahrenheit = celsius * 9/5 + 32
            return String(format: "%.1f\u{00B0}F", fahrenheit)
        }
        return String(format: "%.1f\u{00B0}C", celsius)
    }

    // MARK: - Computed Properties
    var espressoProfiles: [Recipe] {
        recipes.filter { !$0.id.contains("tea") && !$0.id.contains("herbal") && !$0.id.contains("tisane") }
    }

    var teaProfiles: [Recipe] {
        recipes.filter { $0.id.contains("tea") || $0.id.contains("herbal") || $0.id.contains("tisane") }
    }

    // MARK: - Profile Export/Import

    /// Export a profile to JSON data (Visualizer.coffee compatible)
    func exportProfile(_ recipe: Recipe) -> Data? {
        let visualizerProfile = VisualizerProfile(from: recipe)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return try? encoder.encode(visualizerProfile)
    }

    /// Export a profile to a shareable file URL
    func exportProfileToFile(_ recipe: Recipe) -> URL? {
        guard let data = exportProfile(recipe) else { return nil }

        let fileName = "\(recipe.name.replacingOccurrences(of: " ", with: "_")).json"
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)

        do {
            try data.write(to: tempURL)
            return tempURL
        } catch {
            print("[MachineStore] Failed to write profile: \(error)")
            return nil
        }
    }

    /// Import a profile from JSON data
    func importProfile(from data: Data) -> Recipe? {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        // Try Visualizer format first
        if let visualizerProfile = try? decoder.decode(VisualizerProfile.self, from: data) {
            return visualizerProfile.toRecipe()
        }

        // Try our native format
        if let recipe = try? decoder.decode(Recipe.self, from: data) {
            return recipe
        }

        // Try generic Decent profile format
        if let decentProfile = try? decoder.decode(DecentProfile.self, from: data) {
            return decentProfile.toRecipe()
        }

        return nil
    }

    /// Import a profile from a file URL
    func importProfileFromFile(_ url: URL) -> Recipe? {
        do {
            let data = try Data(contentsOf: url)
            return importProfile(from: data)
        } catch {
            print("[MachineStore] Failed to read profile: \(error)")
            return nil
        }
    }

    /// Import and save a profile
    func importAndSaveProfile(from data: Data) -> Bool {
        guard var recipe = importProfile(from: data) else { return false }

        // Generate new ID to avoid conflicts
        recipe.id = "imported-\(UUID().uuidString.prefix(8))"
        recipe.createdAt = Date()
        recipe.updatedAt = Date()

        saveCustomProfile(recipe)
        return true
    }
}

// MARK: - Notifications

extension Notification.Name {
    static let targetWeightReached = Notification.Name("targetWeightReached")
}

// MARK: - Visualizer.coffee Compatible Profile Format

struct VisualizerProfile: Codable {
    var version: String = "1.0"
    var title: String
    var author: String
    var notes: String
    var beverage_type: String
    var steps: [VisualizerStep]
    var target_weight: Double?
    var target_volume: Double?
    var tank_temperature: Double?

    // Metadata
    var id: String?
    var created_at: String?
    var updated_at: String?

    init(from recipe: Recipe) {
        self.title = recipe.name
        self.author = recipe.author
        self.notes = recipe.notes ?? recipe.description
        self.beverage_type = recipe.coffeeType ?? "espresso"
        self.target_weight = recipe.targetWeight
        self.id = recipe.id

        let formatter = ISO8601DateFormatter()
        self.created_at = formatter.string(from: recipe.createdAt)
        self.updated_at = formatter.string(from: recipe.updatedAt)

        self.steps = recipe.steps.map { step in
            VisualizerStep(
                name: step.name,
                temperature: step.temperature,
                pressure: step.pressure,
                flow: step.flow,
                seconds: step.exit.type == .time ? step.exit.value : 0,
                weight: step.exit.type == .weight ? step.exit.value : nil,
                transition: step.transition == "smooth" ? "linear" : "instant",
                limiter_value: step.limiterValue,
                limiter_range: step.limiterRange,
                exit_type: step.exit.type.rawValue,
                exit_value: step.exit.value
            )
        }
    }

    func toRecipe() -> Recipe {
        let formatter = ISO8601DateFormatter()

        return Recipe(
            id: id ?? "visualizer-\(UUID().uuidString.prefix(8))",
            name: title,
            description: notes,
            author: author,
            createdAt: created_at.flatMap { formatter.date(from: $0) } ?? Date(),
            updatedAt: updated_at.flatMap { formatter.date(from: $0) } ?? Date(),
            favorite: false,
            usageCount: 0,
            targetWeight: target_weight ?? 36,
            steps: steps.map { $0.toProfileStep() },
            coffeeType: beverage_type,
            notes: notes,
            dose: nil
        )
    }
}

struct VisualizerStep: Codable {
    var name: String
    var temperature: Double
    var pressure: Double
    var flow: Double
    var seconds: Double
    var weight: Double?
    var transition: String
    var limiter_value: Double?
    var limiter_range: Double?
    var exit_type: String?
    var exit_value: Double?

    func toProfileStep() -> ProfileStep {
        let exitType: ExitCondition.ExitType
        let exitValue: Double

        if let type = exit_type, let value = exit_value {
            exitType = ExitCondition.ExitType(rawValue: type) ?? .time
            exitValue = value
        } else if let w = weight, w > 0 {
            exitType = .weight
            exitValue = w
        } else {
            exitType = .time
            exitValue = seconds
        }

        return ProfileStep(
            name: name,
            temperature: temperature,
            pressure: pressure,
            flow: flow,
            transition: transition == "linear" ? "smooth" : "fast",
            exit: ExitCondition(type: exitType, value: exitValue),
            limiterValue: limiter_value,
            limiterRange: limiter_range
        )
    }
}

// MARK: - Generic Decent Profile Format

struct DecentProfile: Codable {
    var profile_title: String?
    var title: String?
    var author: String?
    var notes: String?
    var beverage_type: String?
    var steps: [DecentStep]?
    var advanced_shot: [DecentStep]?
    var target_weight: Double?
    var target_volume: Double?

    func toRecipe() -> Recipe {
        let profileSteps = (steps ?? advanced_shot ?? []).map { $0.toProfileStep() }

        return Recipe(
            id: "decent-\(UUID().uuidString.prefix(8))",
            name: profile_title ?? title ?? "Imported Profile",
            description: notes ?? "",
            author: author ?? "Unknown",
            createdAt: Date(),
            updatedAt: Date(),
            favorite: false,
            usageCount: 0,
            targetWeight: target_weight ?? 36,
            steps: profileSteps,
            coffeeType: beverage_type,
            notes: notes,
            dose: nil
        )
    }
}

struct DecentStep: Codable {
    var name: String?
    var temperature: Double?
    var pressure: Double?
    var flow: Double?
    var seconds: Double?
    var weight: Double?
    var transition: String?
    var pump: String?
    var sensor: String?
    var exit_if: Int?
    var exit_type: String?
    var exit_flow_under: Double?
    var exit_flow_over: Double?
    var exit_pressure_under: Double?
    var exit_pressure_over: Double?

    func toProfileStep() -> ProfileStep {
        let exitType: ExitCondition.ExitType
        let exitValue: Double

        if let w = weight, w > 0 {
            exitType = .weight
            exitValue = w
        } else if let s = seconds, s > 0 {
            exitType = .time
            exitValue = s
        } else {
            exitType = .time
            exitValue = 10
        }

        return ProfileStep(
            name: name ?? "Step",
            temperature: temperature ?? 93,
            pressure: pressure ?? 0,
            flow: flow ?? 0,
            transition: transition ?? "smooth",
            exit: ExitCondition(type: exitType, value: exitValue)
        )
    }
}
