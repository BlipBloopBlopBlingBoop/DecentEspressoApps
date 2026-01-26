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

    enum ProfileCategory: String, CaseIterable {
        case all = "All"
        case espresso = "Espresso"
        case tea = "Tea"
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
                        ProfileRow(recipe: recipe)
                    }
                }
                .listStyle(.plain)
            }
            .navigationTitle("Profiles")
            .searchable(text: $searchText, prompt: "Search profiles")
        }
    }
}

// MARK: - Profile Row
struct ProfileRow: View {
    @EnvironmentObject var machineStore: MachineStore
    let recipe: Recipe

    var isActive: Bool {
        machineStore.activeRecipe?.id == recipe.id
    }

    var isTea: Bool {
        recipe.id.contains("tea") || recipe.id.contains("herbal") || recipe.id.contains("tisane")
    }

    var body: some View {
        NavigationLink {
            ProfileDetailView(recipe: recipe)
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
        }
    }
}

#Preview {
    ProfilesView()
        .environmentObject(MachineStore())
}
