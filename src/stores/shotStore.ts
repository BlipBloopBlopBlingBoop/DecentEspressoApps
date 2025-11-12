import { create } from 'zustand'
import { ShotData, ShotDataPoint } from '../types/decent'
import { databaseService } from '../services/databaseService'

interface ShotStore {
  shots: ShotData[]
  activeShot: ShotData | null
  isRecording: boolean

  loadShots: (shots: ShotData[]) => void
  startShot: (shot: Omit<ShotData, 'id' | 'dataPoints' | 'duration'>) => void
  addDataPoint: (dataPoint: ShotDataPoint) => void
  endShot: (finalWeight?: number) => void
  updateShot: (id: string, updates: Partial<ShotData>) => void
  deleteShot: (id: string) => void
  clearActiveShot: () => void
}

export const useShotStore = create<ShotStore>((set, get) => ({
  shots: [],
  activeShot: null,
  isRecording: false,

  loadShots: (shots) => set({ shots }),

  startShot: (shotData) => {
    const newShot: ShotData = {
      ...shotData,
      id: `shot-${Date.now()}`,
      dataPoints: [],
      duration: 0,
    }
    console.log(`[ShotStore] Starting shot: ${newShot.id}`)
    console.log(`[ShotStore] Profile: ${newShot.profileName}`)
    set({ activeShot: newShot, isRecording: true })
  },

  addDataPoint: (dataPoint) => set((state) => {
    if (!state.activeShot) return state

    const updatedShot: ShotData = {
      ...state.activeShot,
      dataPoints: [...state.activeShot.dataPoints, dataPoint],
      duration: dataPoint.timestamp,
    }

    return { activeShot: updatedShot }
  }),

  endShot: (finalWeight) => {
    const state = get()
    if (!state.activeShot) {
      console.warn('[ShotStore] endShot called but no active shot')
      return
    }

    const completedShot: ShotData = {
      ...state.activeShot,
      endTime: Date.now(),
      finalWeight,
    }

    console.log(`[ShotStore] Ending shot: ${completedShot.id}`)
    console.log(`[ShotStore] Duration: ${completedShot.duration}ms`)
    console.log(`[ShotStore] Data points: ${completedShot.dataPoints.length}`)
    console.log(`[ShotStore] Final weight: ${finalWeight || 0}g`)

    // Save to database immediately - ALWAYS save, even with 0 data points
    databaseService.saveShot(completedShot)
      .then(() => {
        console.log(`[ShotStore] ✓ Shot saved to database: ${completedShot.id}`)
      })
      .catch(error => {
        console.error('[ShotStore] ✗ Failed to save shot to database:', error)
      })

    set({
      shots: [completedShot, ...state.shots],
      activeShot: null,
      isRecording: false,
    })
  },

  updateShot: (id, updates) => set((state) => ({
    shots: state.shots.map((shot) =>
      shot.id === id ? { ...shot, ...updates } : shot
    )
  })),

  deleteShot: (id) => set((state) => ({
    shots: state.shots.filter((shot) => shot.id !== id)
  })),

  clearActiveShot: () => set({ activeShot: null, isRecording: false }),
}))
