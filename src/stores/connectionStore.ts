import { create } from 'zustand'
import { ConnectionStatus } from '../types/decent'

interface ConnectionStore extends ConnectionStatus {
  setConnected: (connected: boolean) => void
  setConnecting: (connecting: boolean) => void
  setError: (error: string | undefined) => void
  setDeviceName: (name: string | undefined) => void
  updateLastConnected: () => void
  reset: () => void
}

export const useConnectionStore = create<ConnectionStore>((set) => ({
  connected: false,
  connecting: false,
  error: undefined,
  lastConnected: undefined,
  deviceName: undefined,

  setConnected: (connected) => set({ connected, connecting: false, error: undefined }),
  setConnecting: (connecting) => set({ connecting, error: undefined }),
  setError: (error) => set({ error, connecting: false }),
  setDeviceName: (deviceName) => set({ deviceName }),
  updateLastConnected: () => set({ lastConnected: Date.now() }),

  reset: () => set({
    connected: false,
    connecting: false,
    error: undefined,
    deviceName: undefined,
  }),
}))
