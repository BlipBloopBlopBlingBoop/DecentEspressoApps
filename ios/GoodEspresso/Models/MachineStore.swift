//
//  MachineStore.swift
//  Good Espresso
//
//  Observable state store for machine data and app state
//

import Foundation
import SwiftUI
import Combine

@MainActor
class MachineStore: ObservableObject {
    // MARK: - Connection State
    @Published var isConnected: Bool = false
    @Published var isConnecting: Bool = false
    @Published var connectionError: String?
    @Published var deviceName: String?

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

    // MARK: - Initialization
    init() {
        loadRecipes()
        loadShotHistory()
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
}
