/**
 * ProfileService - Profile Export/Import for Web
 *
 * Supports:
 * - Visualizer.coffee compatible JSON format
 * - Native app format
 * - Generic Decent profile format
 */

import { ShotProfile, ProfileStep } from '../types/decent'

// Visualizer.coffee compatible format
export interface VisualizerProfile {
  version: string
  title: string
  author: string
  notes: string
  beverage_type: string
  steps: VisualizerStep[]
  target_weight?: number
  target_volume?: number
  tank_temperature?: number
  id?: string
  created_at?: string
  updated_at?: string
}

export interface VisualizerStep {
  name: string
  temperature: number
  pressure: number
  flow: number
  seconds: number
  weight?: number
  transition: string
  limiter_value?: number
  limiter_range?: number
  exit_type?: string
  exit_value?: number
}

// Generic Decent profile format
export interface DecentProfile {
  profile_title?: string
  title?: string
  author?: string
  notes?: string
  beverage_type?: string
  steps?: DecentStep[]
  advanced_shot?: DecentStep[]
  target_weight?: number
  target_volume?: number
}

export interface DecentStep {
  name?: string
  temperature?: number
  pressure?: number
  flow?: number
  seconds?: number
  weight?: number
  transition?: string
  pump?: string
  sensor?: string
  exit_if?: number
  exit_type?: string
  exit_flow_under?: number
  exit_flow_over?: number
  exit_pressure_under?: number
  exit_pressure_over?: number
}

class ProfileService {
  /**
   * Export a profile to Visualizer.coffee compatible JSON
   */
  exportToVisualizer(profile: ShotProfile): VisualizerProfile {
    const now = new Date().toISOString()

    return {
      version: '1.0',
      title: profile.name,
      author: profile.author || 'Good Espresso',
      notes: profile.notes || profile.description || '',
      beverage_type: profile.coffeeType || 'espresso',
      target_weight: profile.targetWeight,
      id: profile.id,
      created_at: profile.createdAt ? new Date(profile.createdAt).toISOString() : now,
      updated_at: profile.updatedAt ? new Date(profile.updatedAt).toISOString() : now,
      steps: profile.steps.map((step) => ({
        name: step.name,
        temperature: step.temperature,
        pressure: step.pressure,
        flow: step.flow,
        seconds: step.exit.type === 'time' ? step.exit.value : 0,
        weight: step.exit.type === 'weight' ? step.exit.value : undefined,
        transition: step.transition === 'smooth' ? 'linear' : 'instant',
        limiter_value: step.limiter?.value,
        limiter_range: step.limiter?.range,
        exit_type: step.exit.type,
        exit_value: step.exit.value,
      })),
    }
  }

  /**
   * Export profile to JSON string
   */
  exportToJSON(profile: ShotProfile): string {
    const visualizerProfile = this.exportToVisualizer(profile)
    return JSON.stringify(visualizerProfile, null, 2)
  }

  /**
   * Export profile and trigger download
   */
  downloadProfile(profile: ShotProfile): void {
    const json = this.exportToJSON(profile)
    const blob = new Blob([json], { type: 'application/json' })
    const url = URL.createObjectURL(blob)

    const a = document.createElement('a')
    a.href = url
    a.download = `${profile.name.replace(/\s+/g, '_')}.json`
    document.body.appendChild(a)
    a.click()
    document.body.removeChild(a)
    URL.revokeObjectURL(url)

    console.log('[ProfileService] Profile exported:', profile.name)
  }

  /**
   * Import profile from JSON string
   */
  importFromJSON(json: string): ShotProfile | null {
    try {
      const data = JSON.parse(json)

      // Try Visualizer format first
      if (this.isVisualizerFormat(data)) {
        return this.fromVisualizerFormat(data as VisualizerProfile)
      }

      // Try generic Decent format
      if (this.isDecentFormat(data)) {
        return this.fromDecentFormat(data as DecentProfile)
      }

      // Try native format
      if (this.isNativeFormat(data)) {
        return data as ShotProfile
      }

      console.warn('[ProfileService] Unknown profile format')
      return null
    } catch (error) {
      console.error('[ProfileService] Failed to parse profile:', error)
      return null
    }
  }

  /**
   * Import profile from file
   */
  async importFromFile(file: File): Promise<ShotProfile | null> {
    try {
      const text = await file.text()
      return this.importFromJSON(text)
    } catch (error) {
      console.error('[ProfileService] Failed to read file:', error)
      return null
    }
  }

  /**
   * Check if data is Visualizer format
   */
  private isVisualizerFormat(data: any): boolean {
    return (
      typeof data === 'object' &&
      ('title' in data || 'version' in data) &&
      'steps' in data &&
      Array.isArray(data.steps)
    )
  }

  /**
   * Check if data is Decent format
   */
  private isDecentFormat(data: any): boolean {
    return (
      typeof data === 'object' &&
      ('profile_title' in data || 'advanced_shot' in data)
    )
  }

  /**
   * Check if data is native format
   */
  private isNativeFormat(data: any): boolean {
    return (
      typeof data === 'object' &&
      'id' in data &&
      'name' in data &&
      'steps' in data &&
      Array.isArray(data.steps) &&
      data.steps.every(
        (step: any) =>
          'name' in step &&
          'temperature' in step &&
          'exit' in step
      )
    )
  }

  /**
   * Convert from Visualizer format
   */
  private fromVisualizerFormat(data: VisualizerProfile): ShotProfile {
    return {
      id: data.id || `visualizer-${Date.now()}`,
      name: data.title,
      description: data.notes,
      author: data.author || 'Unknown',
      createdAt: data.created_at ? new Date(data.created_at).getTime() : Date.now(),
      updatedAt: data.updated_at ? new Date(data.updated_at).getTime() : Date.now(),
      targetWeight: data.target_weight || 36,
      coffeeType: data.beverage_type,
      notes: data.notes,
      steps: data.steps.map((step) => this.visualizerStepToProfileStep(step)),
    }
  }

  /**
   * Convert Visualizer step to ProfileStep
   */
  private visualizerStepToProfileStep(step: VisualizerStep): ProfileStep {
    let exitType: 'time' | 'weight' | 'pressure' | 'flow' = 'time'
    let exitValue = step.seconds || 10

    if (step.exit_type && step.exit_value !== undefined) {
      exitType = step.exit_type as any
      exitValue = step.exit_value
    } else if (step.weight && step.weight > 0) {
      exitType = 'weight'
      exitValue = step.weight
    }

    return {
      name: step.name,
      temperature: step.temperature,
      pressure: step.pressure,
      flow: step.flow,
      transition: step.transition === 'linear' ? 'smooth' : 'fast',
      exit: {
        type: exitType,
        value: exitValue,
      },
      limiter: step.limiter_value !== undefined ? {
        value: step.limiter_value,
        range: step.limiter_range ?? 0,
      } : undefined,
    }
  }

  /**
   * Convert from Decent format
   */
  private fromDecentFormat(data: DecentProfile): ShotProfile {
    const steps = data.steps || data.advanced_shot || []

    return {
      id: `decent-${Date.now()}`,
      name: data.profile_title || data.title || 'Imported Profile',
      description: data.notes || '',
      author: data.author || 'Unknown',
      createdAt: Date.now(),
      updatedAt: Date.now(),
      targetWeight: data.target_weight || 36,
      coffeeType: data.beverage_type,
      notes: data.notes,
      steps: steps.map((step) => this.decentStepToProfileStep(step)),
    }
  }

  /**
   * Convert Decent step to ProfileStep
   */
  private decentStepToProfileStep(step: DecentStep): ProfileStep {
    let exitType: 'time' | 'weight' | 'pressure' | 'flow' = 'time'
    let exitValue = step.seconds || 10

    if (step.weight && step.weight > 0) {
      exitType = 'weight'
      exitValue = step.weight
    }

    return {
      name: step.name || 'Step',
      temperature: step.temperature || 93,
      pressure: step.pressure || 0,
      flow: step.flow || 0,
      transition: step.transition === 'fast' ? 'fast' : 'smooth',
      exit: {
        type: exitType,
        value: exitValue,
      },
    }
  }

  /**
   * Open file picker and import profile
   */
  async openFilePicker(): Promise<ShotProfile | null> {
    return new Promise((resolve) => {
      const input = document.createElement('input')
      input.type = 'file'
      input.accept = '.json'

      input.onchange = async (e) => {
        const file = (e.target as HTMLInputElement).files?.[0]
        if (!file) {
          resolve(null)
          return
        }

        const profile = await this.importFromFile(file)
        resolve(profile)
      }

      input.click()
    })
  }

  /**
   * Copy profile JSON to clipboard
   */
  async copyToClipboard(profile: ShotProfile): Promise<boolean> {
    try {
      const json = this.exportToJSON(profile)
      await navigator.clipboard.writeText(json)
      console.log('[ProfileService] Profile copied to clipboard')
      return true
    } catch (error) {
      console.error('[ProfileService] Failed to copy to clipboard:', error)
      return false
    }
  }

  /**
   * Import profile from clipboard
   */
  async importFromClipboard(): Promise<ShotProfile | null> {
    try {
      const text = await navigator.clipboard.readText()
      return this.importFromJSON(text)
    } catch (error) {
      console.error('[ProfileService] Failed to read from clipboard:', error)
      return null
    }
  }

  /**
   * Generate shareable URL (base64 encoded profile)
   */
  generateShareURL(profile: ShotProfile): string {
    const json = this.exportToJSON(profile)
    const encoded = btoa(encodeURIComponent(json))
    const baseUrl = window.location.origin + window.location.pathname
    return `${baseUrl}?profile=${encoded}`
  }

  /**
   * Import profile from URL parameter
   */
  importFromURL(): ShotProfile | null {
    const params = new URLSearchParams(window.location.search)
    const encoded = params.get('profile')

    if (!encoded) return null

    try {
      const json = decodeURIComponent(atob(encoded))
      return this.importFromJSON(json)
    } catch (error) {
      console.error('[ProfileService] Failed to import from URL:', error)
      return null
    }
  }
}

// Export singleton
export const profileService = new ProfileService()
