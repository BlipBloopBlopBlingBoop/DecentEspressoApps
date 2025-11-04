import { create } from 'zustand'
import { Recipe } from '../types/decent'

interface RecipeStore {
  recipes: Recipe[]
  activeRecipe: Recipe | null

  loadRecipes: (recipes: Recipe[]) => void
  addRecipe: (recipe: Recipe) => void
  updateRecipe: (id: string, recipe: Partial<Recipe>) => void
  deleteRecipe: (id: string) => void
  setActiveRecipe: (recipe: Recipe | null) => void
  toggleFavorite: (id: string) => void
  incrementUsage: (id: string) => void
}

export const useRecipeStore = create<RecipeStore>((set) => ({
  recipes: [],
  activeRecipe: null,

  loadRecipes: (recipes) => set({ recipes }),

  addRecipe: (recipe) => set((state) => ({
    recipes: [...state.recipes, recipe]
  })),

  updateRecipe: (id, updates) => set((state) => ({
    recipes: state.recipes.map((recipe) =>
      recipe.id === id ? { ...recipe, ...updates, updatedAt: Date.now() } : recipe
    ),
    activeRecipe: state.activeRecipe?.id === id
      ? { ...state.activeRecipe, ...updates, updatedAt: Date.now() }
      : state.activeRecipe
  })),

  deleteRecipe: (id) => set((state) => ({
    recipes: state.recipes.filter((recipe) => recipe.id !== id),
    activeRecipe: state.activeRecipe?.id === id ? null : state.activeRecipe
  })),

  setActiveRecipe: (recipe) => set({ activeRecipe: recipe }),

  toggleFavorite: (id) => set((state) => ({
    recipes: state.recipes.map((recipe) =>
      recipe.id === id ? { ...recipe, favorite: !recipe.favorite } : recipe
    )
  })),

  incrementUsage: (id) => set((state) => ({
    recipes: state.recipes.map((recipe) =>
      recipe.id === id
        ? {
            ...recipe,
            usageCount: (recipe.usageCount || 0) + 1,
            lastUsed: Date.now()
          }
        : recipe
    )
  })),
}))
