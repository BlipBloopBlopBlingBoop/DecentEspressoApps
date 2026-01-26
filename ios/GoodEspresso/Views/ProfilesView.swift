//
//  ProfilesView.swift
//  Good Espresso
//
//  Browse and select brewing profiles
//

import SwiftUI

struct ProfilesView: View {
    @EnvironmentObject var machineStore: MachineStore
    @State private var searchText = ""
    @State private var selectedCategory: ProfileCategory = .all
    @State private var showingNewProfile = false
    @State private var editingProfile: Recipe?

    enum ProfileCategory: String, CaseIterable {
        case all = "All"
        case espresso = "Espresso"
        case tea = "Tea"
        case custom = "Custom"
        case favorites = "Favorites"
    }

    var filteredProfiles: [Recipe] {
        var profiles: [Recipe]

        switch selectedCategory {
        case .all:
            profiles = machineStore.recipes
        case .espresso:
            profiles = machineStore.espressoProfiles
        case .tea:
            profiles = machineStore.teaProfiles
        case .custom:
            profiles = machineStore.customRecipes
        case .favorites:
            profiles = machineStore.favoriteRecipes
        }

        if searchText.isEmpty {
            return profiles
        }

        return profiles.filter {
            $0.name.localizedCaseInsensitiveContains(searchText) ||
            $0.description.localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Category Picker
                Picker("Category", selection: $selectedCategory) {
                    ForEach(ProfileCategory.allCases, id: \.self) { category in
                        Text(category.rawValue).tag(category)
                    }
                }
                .pickerStyle(.segmented)
                .padding()

                // Profile List
                List {
                    ForEach(filteredProfiles) { recipe in
                        ProfileRow(recipe: recipe) { recipeToEdit in
                            editingProfile = recipeToEdit
                        }
                    }
                }
                .listStyle(.plain)
            }
            .navigationTitle("Profiles")
            .searchable(text: $searchText, prompt: "Search profiles")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showingNewProfile = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingNewProfile) {
                ProfileEditorView(existingRecipe: nil)
            }
            .sheet(item: $editingProfile) { recipe in
                ProfileEditorView(existingRecipe: recipe)
            }
        }
    }
}

// MARK: - Profile Row
struct ProfileRow: View {
    @EnvironmentObject var machineStore: MachineStore
    let recipe: Recipe
    var onEdit: ((Recipe) -> Void)?

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
        NavigationLink {
            ProfileDetailView(recipe: recipe, onEdit: onEdit)
        } label: {
            HStack(spacing: 12) {
                // Icon
                ZStack {
                    Circle()
                        .fill(isTea ? .green.opacity(0.2) : .orange.opacity(0.2))
                        .frame(width: 44, height: 44)

                    Image(systemName: isTea ? "leaf.fill" : "cup.and.saucer.fill")
                        .foregroundStyle(isTea ? .green : .orange)
                }

                // Info
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(recipe.name)
                            .font(.headline)

                        if isActive {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                                .font(.caption)
                        }
                    }

                    Text("\(recipe.steps.count) steps \u{2022} \(Int(recipe.targetWeight))g target")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    if isTea {
                        Text("Pulse Brew")
                            .font(.caption2)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(.green.opacity(0.2))
                            .foregroundStyle(.green)
                            .clipShape(Capsule())
                    }
                }

                Spacer()

                // Favorite button
                Button {
                    machineStore.toggleFavorite(recipe)
                } label: {
                    Image(systemName: recipe.favorite ? "star.fill" : "star")
                        .foregroundStyle(recipe.favorite ? .yellow : .gray)
                }
                .buttonStyle(.plain)
            }
            .padding(.vertical, 4)
        }
        .swipeActions(edge: .leading) {
            Button {
                machineStore.setActiveRecipe(recipe)
            } label: {
                Label("Select", systemImage: "checkmark.circle")
            }
            .tint(.green)
        }
        .swipeActions(edge: .trailing) {
            Button {
                machineStore.toggleFavorite(recipe)
            } label: {
                Label(
                    recipe.favorite ? "Unfavorite" : "Favorite",
                    systemImage: recipe.favorite ? "star.slash" : "star"
                )
            }
            .tint(.yellow)

            if isCustom {
                Button(role: .destructive) {
                    machineStore.deleteCustomProfile(recipe)
                } label: {
                    Label("Delete", systemImage: "trash")
                }
            }

            Button {
                let copy = machineStore.duplicateProfile(recipe)
                machineStore.saveCustomProfile(copy)
            } label: {
                Label("Duplicate", systemImage: "doc.on.doc")
            }
            .tint(.blue)
        }
        .contextMenu {
            Button {
                machineStore.setActiveRecipe(recipe)
            } label: {
                Label("Select", systemImage: "checkmark.circle")
            }

            Button {
                machineStore.toggleFavorite(recipe)
            } label: {
                Label(
                    recipe.favorite ? "Remove from Favorites" : "Add to Favorites",
                    systemImage: recipe.favorite ? "star.slash" : "star"
                )
            }

            Button {
                let copy = machineStore.duplicateProfile(recipe)
                machineStore.saveCustomProfile(copy)
            } label: {
                Label("Duplicate", systemImage: "doc.on.doc")
            }

            if isCustom {
                Divider()

                Button {
                    onEdit?(recipe)
                } label: {
                    Label("Edit", systemImage: "pencil")
                }

                Button(role: .destructive) {
                    machineStore.deleteCustomProfile(recipe)
                } label: {
                    Label("Delete", systemImage: "trash")
                }
            }
        }
    }
}

#Preview {
    ProfilesView()
        .environmentObject(MachineStore())
}
