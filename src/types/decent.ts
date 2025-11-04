// Decent Espresso Machine Type Definitions

export interface DecentMachine {
  id: string
  name: string
  connected: boolean
  device?: BluetoothDevice
  server?: BluetoothRemoteGATTServer
  characteristics?: DecentCharacteristics
}

export interface DecentCharacteristics {
  // Read characteristics
  stateInfo?: BluetoothRemoteGATTCharacteristic
  waterLevel?: BluetoothRemoteGATTCharacteristic
  shotSettings?: BluetoothRemoteGATTCharacteristic

  // Write characteristics
  command?: BluetoothRemoteGATTCharacteristic
  shotProfile?: BluetoothRemoteGATTCharacteristic
  calibration?: BluetoothRemoteGATTCharacteristic
}

export interface MachineState {
  state: MachineStateType
  substate: string
  temperature: TemperatureData
  pressure: number
  flow: number
  weight: number
  timestamp: number
}

export type MachineStateType =
  | 'idle'
  | 'sleep'
  | 'warming'
  | 'ready'
  | 'brewing'
  | 'steam'
  | 'flush'
  | 'cleaning'
  | 'error'

export interface TemperatureData {
  mix: number // Mix chamber temperature
  head: number // Group head temperature
  steam: number // Steam temperature
  target: number // Target temperature
}

export interface PressureData {
  current: number
  target: number
  timestamp: number
}

export interface FlowData {
  current: number
  target: number
  timestamp: number
}

export interface ShotProfile {
  id: string
  name: string
  description?: string
  author?: string
  createdAt: number
  updatedAt: number
  steps: ProfileStep[]
  targetWeight?: number
  targetVolume?: number
  targetTime?: number
  metadata?: {
    coffee?: string
    grindSize?: string
    dose?: number
    notes?: string
  }
}

export interface ProfileStep {
  name: string
  temperature: number
  pressure: number
  flow: number
  transition: 'fast' | 'smooth'
  exit: ExitCondition
  limiter?: {
    value: number
    range: number
  }
}

export interface ExitCondition {
  type: 'pressure' | 'flow' | 'time' | 'weight'
  value: number
}

export interface ShotData {
  id: string
  profileId?: string
  profileName: string
  startTime: number
  endTime?: number
  duration: number
  dataPoints: ShotDataPoint[]
  finalWeight?: number
  rating?: number
  notes?: string
  metadata?: {
    coffee?: string
    grindSize?: string
    dose?: number
    yield?: number
    ratio?: string
  }
}

export interface ShotDataPoint {
  timestamp: number // Milliseconds from shot start
  temperature: number
  pressure: number
  flow: number
  weight: number
}

export interface Recipe extends ShotProfile {
  favorite?: boolean
  usageCount?: number
  lastUsed?: number
}

export interface CalibrationSettings {
  flowCalibration: number
  pressureCalibration: number
  temperatureOffset: number
  scaleOffset: number
}

export interface MachineSettings {
  targetSteamTemp: number
  targetEspressoTemp: number
  sleepTime: number
  units: 'metric' | 'imperial'
  ghcInfo?: {
    version: string
    serialNumber: string
  }
}

export interface ConnectionStatus {
  connected: boolean
  connecting: boolean
  error?: string
  lastConnected?: number
  deviceName?: string
}

// Bluetooth Service UUIDs for Decent Espresso
export const DECENT_SERVICE_UUID = '0000a000-0000-1000-8000-00805f9b34fb'
export const DECENT_CHARACTERISTICS = {
  STATE_INFO: '0000a001-0000-1000-8000-00805f9b34fb',
  COMMAND: '0000a002-0000-1000-8000-00805f9b34fb',
  SHOT_SETTINGS: '0000a003-0000-1000-8000-00805f9b34fb',
  WATER_LEVEL: '0000a004-0000-1000-8000-00805f9b34fb',
  CALIBRATION: '0000a005-0000-1000-8000-00805f9b34fb',
  SHOT_PROFILE: '0000a006-0000-1000-8000-00805f9b34fb',
} as const

// Machine Commands
export enum DecentCommand {
  START_ESPRESSO = 0x01,
  STOP = 0x02,
  START_STEAM = 0x03,
  START_FLUSH = 0x04,
  START_WATER = 0x05,
  SLEEP = 0x06,
  WAKE = 0x07,
  SET_TEMPERATURE = 0x10,
  SET_PROFILE = 0x11,
}

export interface TroubleshootingStep {
  id: string
  title: string
  description: string
  action?: () => void
  completed?: boolean
}
