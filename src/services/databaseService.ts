import { openDB, DBSchema, IDBPDatabase } from 'idb'
import { Recipe, ShotData } from '../types/decent'

interface DecentDB extends DBSchema {
  recipes: {
    key: string
    value: Recipe
    indexes: {
      'by-name': string
      'by-favorite': number
      'by-lastUsed': number
    }
  }
  shots: {
    key: string
    value: ShotData
    indexes: {
      'by-date': number
      'by-profile': string
      'by-rating': number
    }
  }
  settings: {
    key: string
    value: any
  }
}

class DatabaseService {
  private db: IDBPDatabase<DecentDB> | null = null
  private readonly DB_NAME = 'DecentEspressoDB'
  private readonly DB_VERSION = 1

  /**
   * Initialize the database
   */
  async init(): Promise<void> {
    if (this.db) return

    this.db = await openDB<DecentDB>(this.DB_NAME, this.DB_VERSION, {
      upgrade(db) {
        // Create recipes store
        if (!db.objectStoreNames.contains('recipes')) {
          const recipeStore = db.createObjectStore('recipes', { keyPath: 'id' })
          recipeStore.createIndex('by-name', 'name')
          recipeStore.createIndex('by-favorite', 'favorite')
          recipeStore.createIndex('by-lastUsed', 'lastUsed')
        }

        // Create shots store
        if (!db.objectStoreNames.contains('shots')) {
          const shotStore = db.createObjectStore('shots', { keyPath: 'id' })
          shotStore.createIndex('by-date', 'startTime')
          shotStore.createIndex('by-profile', 'profileId')
          shotStore.createIndex('by-rating', 'rating')
        }

        // Create settings store
        if (!db.objectStoreNames.contains('settings')) {
          db.createObjectStore('settings')
        }
      },
    })
  }

  /**
   * Recipe operations
   */
  async getAllRecipes(): Promise<Recipe[]> {
    await this.ensureDb()
    return await this.db!.getAll('recipes')
  }

  async getRecipe(id: string): Promise<Recipe | undefined> {
    await this.ensureDb()
    return await this.db!.get('recipes', id)
  }

  async saveRecipe(recipe: Recipe): Promise<void> {
    await this.ensureDb()
    await this.db!.put('recipes', recipe)
  }

  async deleteRecipe(id: string): Promise<void> {
    await this.ensureDb()
    await this.db!.delete('recipes', id)
  }

  async getFavoriteRecipes(): Promise<Recipe[]> {
    await this.ensureDb()
    const all = await this.db!.getAllFromIndex('recipes', 'by-favorite', 1)
    return all.filter(r => r.favorite === true)
  }

  async searchRecipes(query: string): Promise<Recipe[]> {
    await this.ensureDb()
    const all = await this.getAllRecipes()
    const lowerQuery = query.toLowerCase()

    return all.filter(recipe =>
      recipe.name.toLowerCase().includes(lowerQuery) ||
      recipe.description?.toLowerCase().includes(lowerQuery) ||
      recipe.author?.toLowerCase().includes(lowerQuery)
    )
  }

  /**
   * Shot operations
   */
  async getAllShots(): Promise<ShotData[]> {
    await this.ensureDb()
    const shots = await this.db!.getAll('shots')
    return shots.sort((a, b) => b.startTime - a.startTime)
  }

  async getShot(id: string): Promise<ShotData | undefined> {
    await this.ensureDb()
    return await this.db!.get('shots', id)
  }

  async saveShot(shot: ShotData): Promise<void> {
    await this.ensureDb()
    await this.db!.put('shots', shot)
  }

  async deleteShot(id: string): Promise<void> {
    await this.ensureDb()
    await this.db!.delete('shots', id)
  }

  async getShotsByProfile(profileId: string): Promise<ShotData[]> {
    await this.ensureDb()
    return await this.db!.getAllFromIndex('shots', 'by-profile', profileId)
  }

  async getShotsByDateRange(startDate: number, endDate: number): Promise<ShotData[]> {
    await this.ensureDb()
    const all = await this.getAllShots()
    return all.filter(shot =>
      shot.startTime >= startDate && shot.startTime <= endDate
    )
  }

  async getRecentShots(limit: number = 10): Promise<ShotData[]> {
    await this.ensureDb()
    const all = await this.getAllShots()
    return all.slice(0, limit)
  }

  /**
   * Settings operations
   */
  async getSetting<T>(key: string): Promise<T | undefined> {
    await this.ensureDb()
    return await this.db!.get('settings', key)
  }

  async saveSetting<T>(key: string, value: T): Promise<void> {
    await this.ensureDb()
    await this.db!.put('settings', value, key)
  }

  async deleteSetting(key: string): Promise<void> {
    await this.ensureDb()
    await this.db!.delete('settings', key)
  }

  /**
   * Export/Import operations
   */
  async exportData(): Promise<string> {
    await this.ensureDb()

    const recipes = await this.getAllRecipes()
    const shots = await this.getAllShots()

    const exportData = {
      version: 1,
      exportDate: Date.now(),
      recipes,
      shots,
    }

    return JSON.stringify(exportData, null, 2)
  }

  async importData(jsonData: string): Promise<{ recipes: number; shots: number }> {
    await this.ensureDb()

    try {
      const data = JSON.parse(jsonData)

      if (!data.version || !data.recipes || !data.shots) {
        throw new Error('Invalid export format')
      }

      let recipesImported = 0
      let shotsImported = 0

      // Import recipes
      for (const recipe of data.recipes) {
        await this.saveRecipe(recipe)
        recipesImported++
      }

      // Import shots
      for (const shot of data.shots) {
        await this.saveShot(shot)
        shotsImported++
      }

      return { recipes: recipesImported, shots: shotsImported }
    } catch (error) {
      throw new Error(`Import failed: ${error instanceof Error ? error.message : 'Unknown error'}`)
    }
  }

  /**
   * Clear all data
   */
  async clearAllData(): Promise<void> {
    await this.ensureDb()
    await this.db!.clear('recipes')
    await this.db!.clear('shots')
    await this.db!.clear('settings')
  }

  /**
   * Get database statistics
   */
  async getStats(): Promise<{
    totalRecipes: number
    totalShots: number
    favoriteRecipes: number
    databaseSize: number
  }> {
    await this.ensureDb()

    const recipes = await this.getAllRecipes()
    const shots = await this.getAllShots()
    const favorites = recipes.filter(r => r.favorite).length

    // Approximate size calculation
    const dataStr = JSON.stringify({ recipes, shots })
    const sizeInBytes = new Blob([dataStr]).size

    return {
      totalRecipes: recipes.length,
      totalShots: shots.length,
      favoriteRecipes: favorites,
      databaseSize: sizeInBytes,
    }
  }

  /**
   * Ensure database is initialized
   */
  private async ensureDb(): Promise<void> {
    if (!this.db) {
      await this.init()
    }
  }

  /**
   * Close database connection
   */
  close(): void {
    if (this.db) {
      this.db.close()
      this.db = null
    }
  }
}

// Export singleton instance
export const databaseService = new DatabaseService()
