import { create } from 'zustand'
import { MachineState, MachineSettings, MachineStateType, TemperatureData } from '../types/decent'

interface MachineStore {
  state: MachineState | null
  settings: MachineSettings
  isActive: boolean

  setState: (state: MachineState) => void
  updateTemperature: (temp: TemperatureData) => void
  updatePressure: (pressure: number) => void
  updateFlow: (flow: number) => void
  updateWeight: (weight: number) => void
  setMachineState: (state: MachineStateType) => void
  updateSettings: (settings: Partial<MachineSettings>) => void
  reset: () => void
}

const defaultSettings: MachineSettings = {
  targetSteamTemp: 160,
  targetEspressoTemp: 93,
  sleepTime: 15,
  units: 'metric',
}

export const useMachineStore = create<MachineStore>((set) => ({
  state: null,
  settings: defaultSettings,
  isActive: false,

  setState: (state) => set({
    state,
    isActive: ['brewing', 'steam', 'flush'].includes(state.state)
  }),

  updateTemperature: (temperature) => set((state) => ({
    state: state.state ? { ...state.state, temperature } : null
  })),

  updatePressure: (pressure) => set((state) => ({
    state: state.state ? { ...state.state, pressure } : null
  })),

  updateFlow: (flow) => set((state) => ({
    state: state.state ? { ...state.state, flow } : null
  })),

  updateWeight: (weight) => set((state) => ({
    state: state.state ? { ...state.state, weight } : null
  })),

  setMachineState: (machineState) => set((state) => ({
    state: state.state ? { ...state.state, state: machineState } : null,
    isActive: ['brewing', 'steam', 'flush'].includes(machineState)
  })),

  updateSettings: (newSettings) => set((state) => ({
    settings: { ...state.settings, ...newSettings }
  })),

  reset: () => set({
    state: null,
    settings: defaultSettings,
    isActive: false,
  }),
}))
