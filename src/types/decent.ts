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
  // Notify characteristics (real-time data)
  shotSample?: BluetoothRemoteGATTCharacteristic  // A00D - Real-time sensor data
  stateInfo?: BluetoothRemoteGATTCharacteristic   // A00E - State changes

  // Write characteristic (commands)
  requestedState?: BluetoothRemoteGATTCharacteristic  // A002 - Send commands

  // Other characteristics
  version?: BluetoothRemoteGATTCharacteristic     // A001
  readFromMMR?: BluetoothRemoteGATTCharacteristic // A005
  writeToMMR?: BluetoothRemoteGATTCharacteristic  // A006
  temperatures?: BluetoothRemoteGATTCharacteristic // A00A
  shotSettings?: BluetoothRemoteGATTCharacteristic // A00B
  waterLevels?: BluetoothRemoteGATTCharacteristic  // A011
  calibration?: BluetoothRemoteGATTCharacteristic  // A012
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
  notes?: string
  coffeeType?: string
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

// Bluetooth Service UUIDs for Decent Espresso (Real protocol from official app)
export const DECENT_SERVICE_UUID = '0000a000-0000-1000-8000-00805f9b34fb'

export const DECENT_CHARACTERISTICS = {
  VERSION: '0000a001-0000-1000-8000-00805f9b34fb',
  REQUESTED_STATE: '0000a002-0000-1000-8000-00805f9b34fb',  // Commands
  READ_FROM_MMR: '0000a005-0000-1000-8000-00805f9b34fb',
  WRITE_TO_MMR: '0000a006-0000-1000-8000-00805f9b34fb',
  FW_MAP_REQUEST: '0000a009-0000-1000-8000-00805f9b34fb',
  TEMPERATURES: '0000a00a-0000-1000-8000-00805f9b34fb',
  SHOT_SETTINGS: '0000a00b-0000-1000-8000-00805f9b34fb',
  SHOT_SAMPLE: '0000a00d-0000-1000-8000-00805f9b34fb',    // Real-time data
  STATE_INFO: '0000a00e-0000-1000-8000-00805f9b34fb',     // State changes
  HEADER_WRITE: '0000a00f-0000-1000-8000-00805f9b34fb',
  FRAME_WRITE: '0000a010-0000-1000-8000-00805f9b34fb',
  WATER_LEVELS: '0000a011-0000-1000-8000-00805f9b34fb',
  CALIBRATION: '0000a012-0000-1000-8000-00805f9b34fb',
} as const

// Machine State Commands (write to REQUESTED_STATE characteristic)
export enum DecentCommand {
  SLEEP = 0x00,
  GO_TO_SLEEP = 0x01,
  IDLE = 0x02,
  BUSY = 0x03,
  ESPRESSO = 0x04,        // Start espresso
  STEAM = 0x05,           // Start steam
  HOT_WATER = 0x06,       // Start hot water
  SHORT_CAL = 0x07,
  SELF_TEST = 0x08,
  LONG_CAL = 0x09,
  DESCALE = 0x0A,
  FATAL_ERROR = 0x0B,
  INIT = 0x0C,
  NO_REQUEST = 0x0D,
  SKIP_TO_NEXT = 0x0E,
  HOT_WATER_RINSE = 0x0F, // Flush
  STEAM_RINSE = 0x10,
  REFILL = 0x11,
  CLEAN = 0x12,
  IN_BOOTLOADER = 0x13,
  AIR_PURGE = 0x14,
  SCHED_IDLE = 0x15,
}

export interface TroubleshootingStep {
  id: string
  title: string
  description: string
  action?: () => void
  completed?: boolean
}
