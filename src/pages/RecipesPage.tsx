import { useState, useEffect } from 'react'
import { useRecipeStore } from '../stores/recipeStore'
import { databaseService } from '../services/databaseService'
import { Recipe } from '../types/decent'
import { Plus, Star, Clock, Search, Trash2, Edit, Play } from 'lucide-react'
import { formatDate } from '../utils/formatters'
import RecipeBuilder from '../components/RecipeBuilder'

export default function RecipesPage() {
  const { recipes, activeRecipe, setActiveRecipe } = useRecipeStore()
  const [searchQuery, setSearchQuery] = useState('')
  const [showRecipeBuilder, setShowRecipeBuilder] = useState(false)
  const [editingRecipe, setEditingRecipe] = useState<Recipe | undefined>(undefined)
  const [filter, setFilter] = useState<'all' | 'favorites'>('all')

  useEffect(() => {
    loadRecipes()
  }, [])

  const loadRecipes = async () => {
    const stored = await databaseService.getAllRecipes()
    useRecipeStore.getState().loadRecipes(stored)
  }

  const filteredRecipes = recipes
    .filter((recipe) => {
      if (filter === 'favorites' && !recipe.favorite) return false
      if (searchQuery) {
        const query = searchQuery.toLowerCase()
        return (
          recipe.name.toLowerCase().includes(query) ||
          recipe.description?.toLowerCase().includes(query) ||
          recipe.author?.toLowerCase().includes(query)
        )
      }
      return true
    })
    .sort((a, b) => {
      // Sort by favorite first, then by last used
      if (a.favorite && !b.favorite) return -1
      if (!a.favorite && b.favorite) return 1
      return (b.lastUsed || 0) - (a.lastUsed || 0)
    })

  return (
    <div className="flex flex-col h-full">
      {/* Header */}
      <div className="bg-gray-800 p-4 space-y-3">
        <div className="flex items-center justify-between">
          <h1 className="text-2xl font-bold text-white">Recipes</h1>
          <button
            onClick={() => {
              setEditingRecipe(undefined)
              setShowRecipeBuilder(true)
            }}
            className="p-2 bg-decent-blue hover:bg-blue-700 text-white rounded-lg transition-colors"
          >
            <Plus className="w-5 h-5" />
          </button>
        </div>

        {/* Search */}
        <div className="relative">
          <Search className="absolute left-3 top-1/2 -translate-y-1/2 w-5 h-5 text-gray-400" />
          <input
            type="text"
            placeholder="Search recipes..."
            value={searchQuery}
            onChange={(e) => setSearchQuery(e.target.value)}
            className="w-full pl-10 pr-4 py-2 bg-gray-900 border border-gray-700 rounded-lg text-white placeholder-gray-500 focus:outline-none focus:border-decent-blue"
          />
        </div>

        {/* Filters */}
        <div className="flex gap-2">
          <FilterButton
            label="All"
            active={filter === 'all'}
            onClick={() => setFilter('all')}
            count={recipes.length}
          />
          <FilterButton
            label="Favorites"
            active={filter === 'favorites'}
            onClick={() => setFilter('favorites')}
            count={recipes.filter((r) => r.favorite).length}
          />
        </div>
      </div>

      {/* Recipe List */}
      <div className="flex-1 overflow-y-auto p-4 space-y-3">
        {filteredRecipes.length === 0 ? (
          <div className="text-center py-12">
            <p className="text-gray-500">No recipes found</p>
            <button
              onClick={() => {
                setEditingRecipe(undefined)
                setShowRecipeBuilder(true)
              }}
              className="mt-4 px-4 py-2 bg-decent-blue hover:bg-blue-700 text-white rounded-lg transition-colors"
            >
              Create Your First Recipe
            </button>
          </div>
        ) : (
          filteredRecipes.map((recipe) => (
            <RecipeCard
              key={recipe.id}
              recipe={recipe}
              isActive={activeRecipe?.id === recipe.id}
              onSelect={() => setActiveRecipe(recipe)}
              onEdit={(recipe) => {
                setEditingRecipe(recipe)
                setShowRecipeBuilder(true)
              }}
            />
          ))
        )}
      </div>

      {/* Recipe Builder Modal */}
      {showRecipeBuilder && (
        <div className="fixed inset-0 bg-black/90 z-50 overflow-y-auto">
          <RecipeBuilder
            recipe={editingRecipe}
            onSave={async (recipe) => {
              if (editingRecipe) {
                useRecipeStore.getState().updateRecipe(recipe.id, recipe)
              } else {
                useRecipeStore.getState().addRecipe(recipe)
              }
              await databaseService.saveRecipe(recipe)
              setShowRecipeBuilder(false)
              setEditingRecipe(undefined)
            }}
            onCancel={() => {
              setShowRecipeBuilder(false)
              setEditingRecipe(undefined)
            }}
          />
        </div>
      )}
    </div>
  )
}

interface FilterButtonProps {
  label: string
  active: boolean
  onClick: () => void
  count: number
}

function FilterButton({ label, active, onClick, count }: FilterButtonProps) {
  return (
    <button
      onClick={onClick}
      className={`px-4 py-2 rounded-lg font-medium transition-colors ${
        active
          ? 'bg-decent-blue text-white'
          : 'bg-gray-700 text-gray-300 hover:bg-gray-600'
      }`}
    >
      {label} ({count})
    </button>
  )
}

interface RecipeCardProps {
  recipe: Recipe
  isActive: boolean
  onSelect: () => void
  onEdit: (recipe: Recipe) => void
}

function RecipeCard({ recipe, isActive, onSelect, onEdit }: RecipeCardProps) {
  const recipeStore = useRecipeStore()

  const handleToggleFavorite = async (e: React.MouseEvent) => {
    e.stopPropagation()
    recipeStore.toggleFavorite(recipe.id)
    await databaseService.saveRecipe({ ...recipe, favorite: !recipe.favorite })
  }

  const handleDelete = async (e: React.MouseEvent) => {
    e.stopPropagation()
    if (confirm(`Delete recipe "${recipe.name}"?`)) {
      recipeStore.deleteRecipe(recipe.id)
      await databaseService.deleteRecipe(recipe.id)
    }
  }

  return (
    <div
      onClick={onSelect}
      className={`bg-gray-800 rounded-lg p-4 cursor-pointer transition-all ${
        isActive
          ? 'ring-2 ring-decent-blue bg-decent-blue/10'
          : 'hover:bg-gray-750'
      }`}
    >
      <div className="flex items-start justify-between mb-2">
        <div className="flex-1">
          <div className="flex items-center gap-2">
            <h3 className="text-lg font-semibold text-white">{recipe.name}</h3>
            {isActive && (
              <span className="px-2 py-0.5 bg-decent-blue text-white text-xs rounded-full">
                Active
              </span>
            )}
          </div>
          {recipe.author && (
            <p className="text-sm text-gray-400">by {recipe.author}</p>
          )}
        </div>
        <button
          onClick={handleToggleFavorite}
          className="p-1 hover:bg-gray-700 rounded"
        >
          <Star
            className={`w-5 h-5 ${
              recipe.favorite ? 'fill-yellow-500 text-yellow-500' : 'text-gray-500'
            }`}
          />
        </button>
      </div>

      {recipe.description && (
        <p className="text-sm text-gray-300 mb-3">{recipe.description}</p>
      )}

      <div className="flex items-center gap-4 text-xs text-gray-400 mb-3">
        {recipe.usageCount && recipe.usageCount > 0 && (
          <div className="flex items-center gap-1">
            <Play className="w-3 h-3" />
            <span>{recipe.usageCount} shots</span>
          </div>
        )}
        {recipe.lastUsed && (
          <div className="flex items-center gap-1">
            <Clock className="w-3 h-3" />
            <span>Last used {formatDate(recipe.lastUsed)}</span>
          </div>
        )}
      </div>

      <div className="flex items-center gap-2 text-xs">
        <span className="px-2 py-1 bg-gray-700 rounded">
          {recipe.steps.length} steps
        </span>
        {recipe.targetWeight && (
          <span className="px-2 py-1 bg-gray-700 rounded">
            {recipe.targetWeight}g target
          </span>
        )}
        {recipe.metadata?.dose && (
          <span className="px-2 py-1 bg-gray-700 rounded">
            {recipe.metadata.dose}g dose
          </span>
        )}
      </div>

      <div className="flex gap-2 mt-3 pt-3 border-t border-gray-700">
        <button
          onClick={onSelect}
          className="flex-1 py-2 bg-decent-blue hover:bg-blue-700 text-white rounded text-sm font-medium transition-colors"
        >
          Use Recipe
        </button>
        <button
          onClick={(e) => {
            e.stopPropagation()
            onEdit(recipe)
          }}
          className="p-2 bg-gray-700 hover:bg-gray-600 text-white rounded transition-colors"
        >
          <Edit className="w-4 h-4" />
        </button>
        <button
          onClick={handleDelete}
          className="p-2 bg-gray-700 hover:bg-red-600 text-white rounded transition-colors"
        >
          <Trash2 className="w-4 h-4" />
        </button>
      </div>
    </div>
  )
}
