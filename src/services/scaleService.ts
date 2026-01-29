/**
 * ScaleService - BLE Scale Support for Web
 *
 * Supports multiple scale brands:
 * - Bookoo (Ultra, Mini, etc.)
 * - Acaia (Lunar, Pearl, Pyxis)
 * - Felicita (Arc, Incline)
 * - Decent Scale
 * - Hiroia Jimmy
 * - Timemore Black Mirror
 * - Generic BLE Weight Scales (Bluetooth SIG standard)
 */

import { create } from 'zustand'

// Scale brand detection
export type ScaleBrand =
  | 'bookoo'
  | 'acaia'
  | 'felicita'
  | 'decent'
  | 'hiroia'
  | 'timemore'
  | 'skale'
  | 'generic'

export interface ScaleData {
  weight: number       // grams
  flowRate: number     // g/s (calculated)
  isStable: boolean
  batteryLevel?: number
  timestamp: number
}

export interface ScaleState {
  isConnected: boolean
  isConnecting: boolean
  scaleName: string | null
  brand: ScaleBrand
  data: ScaleData
  error: string | null

  // Actions
  setConnected: (connected: boolean, name?: string) => void
  setConnecting: (connecting: boolean) => void
  setBrand: (brand: ScaleBrand) => void
  setData: (data: Partial<ScaleData>) => void
  setError: (error: string | null) => void
  reset: () => void
}

// Zustand store for scale state
export const useScaleStore = create<ScaleState>((set) => ({
  isConnected: false,
  isConnecting: false,
  scaleName: null,
  brand: 'generic',
  data: {
    weight: 0,
    flowRate: 0,
    isStable: false,
    timestamp: Date.now(),
  },
  error: null,

  setConnected: (connected, name) =>
    set({ isConnected: connected, scaleName: name || null, error: null }),
  setConnecting: (connecting) => set({ isConnecting: connecting }),
  setBrand: (brand) => set({ brand }),
  setData: (data) =>
    set((state) => ({ data: { ...state.data, ...data, timestamp: Date.now() } })),
  setError: (error) => set({ error }),
  reset: () =>
    set({
      isConnected: false,
      isConnecting: false,
      scaleName: null,
      brand: 'generic',
      data: { weight: 0, flowRate: 0, isStable: false, timestamp: Date.now() },
      error: null,
    }),
}))

// Scale UUIDs
const SCALE_UUIDS = {
  // Bookoo
  bookoo: {
    service: '0000fff0-0000-1000-8000-00805f9b34fb',
    weight: '0000fff4-0000-1000-8000-00805f9b34fb',
    command: '0000fff1-0000-1000-8000-00805f9b34fb',
  },
  // Acaia (old protocol)
  acaia: {
    service: '00001820-0000-1000-8000-00805f9b34fb',
    weight: '00002a80-0000-1000-8000-00805f9b34fb',
  },
  // Acaia (new protocol - Lunar 2021+)
  acaiaNew: {
    service: '49535343-fe7d-4ae5-8fa9-9fafd205e455',
    weight: '49535343-1e4d-4bd9-ba61-23c647249616',
  },
  // Felicita
  felicita: {
    service: '0000ffe0-0000-1000-8000-00805f9b34fb',
    weight: '0000ffe1-0000-1000-8000-00805f9b34fb',
  },
  // Decent Scale
  decent: {
    service: '0000fff0-0000-1000-8000-00805f9b34fb',
    weight: '0000fff4-0000-1000-8000-00805f9b34fb',
    command: '000036f5-0000-1000-8000-00805f9b34fb',
  },
  // Timemore Black Mirror
  timemore: {
    service: '0000ff08-0000-1000-8000-00805f9b34fb',
    weight: '0000ff0a-0000-1000-8000-00805f9b34fb',
    command: '0000ff09-0000-1000-8000-00805f9b34fb',
  },
  // Generic Weight Scale (Bluetooth SIG standard)
  generic: {
    service: '0000181d-0000-1000-8000-00805f9b34fb', // Weight Scale Service
    weight: '00002a9d-0000-1000-8000-00805f9b34fb', // Weight Measurement
  },
}

// Brand detection patterns
const BRAND_PATTERNS: Record<ScaleBrand, string[]> = {
  bookoo: ['Bookoo', 'BOOKOO', 'BK-'],
  acaia: ['ACAIA', 'LUNAR', 'PEARL', 'PYXIS', 'Acaia'],
  felicita: ['FELICITA', 'Felicita', 'Arc'],
  decent: ['DE1-SCALE', 'Decent Scale'],
  hiroia: ['HIROIA', 'JIMMY', 'Jimmy'],
  timemore: ['Timemore', 'TIMEMORE', 'Black Mirror'],
  skale: ['SKALE', 'Skale'],
  generic: [],
}

class ScaleService {
  private device: BluetoothDevice | null = null
  private server: BluetoothRemoteGATTServer | null = null
  private weightCharacteristic: BluetoothRemoteGATTCharacteristic | null = null
  private commandCharacteristic: BluetoothRemoteGATTCharacteristic | null = null
  private brand: ScaleBrand = 'generic'

  // Flow rate calculation
  private lastWeight: number = 0
  private lastWeightTime: number = Date.now()
  private flowRateHistory: number[] = []

  // Weight callback for integration with machine store
  public onWeightUpdate: ((weight: number) => void) | null = null

  /**
   * Check if Web Bluetooth is supported
   */
  isSupported(): boolean {
    return 'bluetooth' in navigator
  }

  /**
   * Request and connect to a BLE scale
   */
  async connect(): Promise<void> {
    const store = useScaleStore.getState()

    if (!this.isSupported()) {
      store.setError('Web Bluetooth is not supported in this browser')
      return
    }

    store.setConnecting(true)
    store.setError(null)

    try {
      // Request device with filters for all known scale services
      console.log('[ScaleService] Requesting scale device...')

      this.device = await navigator.bluetooth.requestDevice({
        acceptAllDevices: true,
        optionalServices: [
          SCALE_UUIDS.bookoo.service,
          SCALE_UUIDS.acaia.service,
          SCALE_UUIDS.acaiaNew.service,
          SCALE_UUIDS.felicita.service,
          SCALE_UUIDS.decent.service,
          SCALE_UUIDS.timemore.service,
          SCALE_UUIDS.generic.service,
        ],
      })

      if (!this.device) {
        throw new Error('No device selected')
      }

      console.log('[ScaleService] Device selected:', this.device.name)

      // Detect brand
      this.brand = this.detectBrand(this.device.name || '')
      store.setBrand(this.brand)
      console.log('[ScaleService] Detected brand:', this.brand)

      // Connect to GATT server
      if (!this.device.gatt) {
        throw new Error('GATT not available')
      }

      this.device.addEventListener('gattserverdisconnected', () => {
        this.onDisconnected()
      })

      console.log('[ScaleService] Connecting to GATT server...')
      this.server = await this.device.gatt.connect()

      // Get service and characteristics
      await this.setupCharacteristics()

      // Start notifications
      await this.setupNotifications()

      store.setConnected(true, this.device.name || 'Unknown Scale')
      store.setConnecting(false)
      console.log('[ScaleService] Connected successfully')
    } catch (error) {
      console.error('[ScaleService] Connection failed:', error)
      store.setConnecting(false)
      store.setError(
        error instanceof Error ? error.message : 'Failed to connect to scale'
      )
    }
  }

  /**
   * Disconnect from scale
   */
  async disconnect(): Promise<void> {
    if (this.server?.connected) {
      this.server.disconnect()
    }
    this.device = null
    this.server = null
    this.weightCharacteristic = null
    this.commandCharacteristic = null
    useScaleStore.getState().reset()
    console.log('[ScaleService] Disconnected')
  }

  /**
   * Tare the scale
   */
  async tare(): Promise<void> {
    await this.sendCommand('tare')
  }

  /**
   * Start timer on scale (if supported)
   */
  async startTimer(): Promise<void> {
    await this.sendCommand('startTimer')
  }

  /**
   * Stop timer on scale (if supported)
   */
  async stopTimer(): Promise<void> {
    await this.sendCommand('stopTimer')
  }

  /**
   * Reset timer on scale (if supported)
   */
  async resetTimer(): Promise<void> {
    await this.sendCommand('resetTimer')
  }

  /**
   * Detect brand from device name
   */
  private detectBrand(name: string): ScaleBrand {
    const upperName = name.toUpperCase()
    for (const [brand, patterns] of Object.entries(BRAND_PATTERNS)) {
      for (const pattern of patterns) {
        if (upperName.includes(pattern.toUpperCase())) {
          return brand as ScaleBrand
        }
      }
    }
    return 'generic'
  }

  /**
   * Setup characteristics based on detected brand
   */
  private async setupCharacteristics(): Promise<void> {
    if (!this.server) return

    const uuids = this.getUuidsForBrand()
    console.log('[ScaleService] Looking for service:', uuids.service)

    try {
      const service = await this.server.getPrimaryService(uuids.service)
      console.log('[ScaleService] Found service')

      // Get weight characteristic
      try {
        this.weightCharacteristic = await service.getCharacteristic(uuids.weight)
        console.log('[ScaleService] Found weight characteristic')
      } catch (e) {
        console.warn('[ScaleService] Weight characteristic not found, trying generic')
        // Try generic service as fallback
        const genericService = await this.server.getPrimaryService(
          SCALE_UUIDS.generic.service
        )
        this.weightCharacteristic = await genericService.getCharacteristic(
          SCALE_UUIDS.generic.weight
        )
      }

      // Get command characteristic if available
      if ('command' in uuids) {
        try {
          this.commandCharacteristic = await service.getCharacteristic(
            (uuids as any).command
          )
          console.log('[ScaleService] Found command characteristic')
        } catch {
          console.log('[ScaleService] Command characteristic not available')
        }
      }
    } catch (error) {
      console.error('[ScaleService] Error setting up characteristics:', error)
      throw new Error('Could not find scale service. Is this a supported scale?')
    }
  }

  /**
   * Get UUIDs for detected brand
   */
  private getUuidsForBrand(): { service: string; weight: string; command?: string } {
    switch (this.brand) {
      case 'bookoo':
        return SCALE_UUIDS.bookoo
      case 'acaia':
        return SCALE_UUIDS.acaia
      case 'felicita':
        return SCALE_UUIDS.felicita
      case 'decent':
        return SCALE_UUIDS.decent
      case 'timemore':
        return SCALE_UUIDS.timemore
      default:
        return SCALE_UUIDS.generic
    }
  }

  /**
   * Setup notifications for weight updates
   */
  private async setupNotifications(): Promise<void> {
    if (!this.weightCharacteristic) return

    try {
      await this.weightCharacteristic.startNotifications()
      this.weightCharacteristic.addEventListener(
        'characteristicvaluechanged',
        this.handleWeightUpdate.bind(this)
      )
      console.log('[ScaleService] Weight notifications enabled')
    } catch (error) {
      console.error('[ScaleService] Failed to start notifications:', error)
    }
  }

  /**
   * Handle weight update from scale
   */
  private handleWeightUpdate(event: Event): void {
    const characteristic = event.target as BluetoothRemoteGATTCharacteristic
    const value = characteristic.value
    if (!value) return

    const { weight, isStable } = this.parseWeight(value)

    // Calculate flow rate
    const now = Date.now()
    const timeDelta = (now - this.lastWeightTime) / 1000
    if (timeDelta > 0.05 && timeDelta < 1.0) {
      const flowRate = (weight - this.lastWeight) / timeDelta
      this.flowRateHistory.push(flowRate)
      if (this.flowRateHistory.length > 5) {
        this.flowRateHistory.shift()
      }
    }

    this.lastWeight = weight
    this.lastWeightTime = now

    const avgFlowRate =
      this.flowRateHistory.length > 0
        ? this.flowRateHistory.reduce((a, b) => a + b, 0) /
          this.flowRateHistory.length
        : 0

    // Update store
    useScaleStore.getState().setData({
      weight,
      flowRate: avgFlowRate,
      isStable,
    })

    // Callback for integration
    if (this.onWeightUpdate) {
      this.onWeightUpdate(weight)
    }
  }

  /**
   * Parse weight from characteristic value based on brand
   */
  private parseWeight(data: DataView): { weight: number; isStable: boolean } {
    switch (this.brand) {
      case 'bookoo':
        return this.parseBookooWeight(data)
      case 'acaia':
        return this.parseAcaiaWeight(data)
      case 'felicita':
        return this.parseFelicitaWeight(data)
      case 'decent':
        return this.parseDecentWeight(data)
      case 'timemore':
        return this.parseTimemoreWeight(data)
      default:
        return this.parseGenericWeight(data)
    }
  }

  private parseBookooWeight(data: DataView): { weight: number; isStable: boolean } {
    if (data.byteLength < 4) return { weight: 0, isStable: false }

    const sign = (data.getUint8(0) & 0x01) === 0 ? 1 : -1
    const weightRaw = (data.getUint8(1) << 8) | data.getUint8(2)
    const weight = sign * (weightRaw / 10)
    const isStable = (data.getUint8(3) & 0x02) !== 0

    return { weight, isStable }
  }

  private parseAcaiaWeight(data: DataView): { weight: number; isStable: boolean } {
    if (data.byteLength < 6) return { weight: 0, isStable: false }

    // Check for Acaia header
    if (data.getUint8(0) === 0xef && data.getUint8(1) === 0xdd) {
      // Old protocol
      const weightRaw = (data.getUint8(4) << 8) | data.getUint8(5)
      const weight = weightRaw / 10
      const isStable = (data.getUint8(2) & 0x01) !== 0
      return { weight, isStable }
    } else {
      // Newer protocol
      if (data.byteLength < 7) return { weight: 0, isStable: false }
      const weightRaw =
        (data.getUint8(3) << 16) | (data.getUint8(4) << 8) | data.getUint8(5)
      let weight = weightRaw / 100
      if ((data.getUint8(6) & 0x02) !== 0) {
        weight = -weight
      }
      const isStable = (data.getUint8(6) & 0x01) !== 0
      return { weight, isStable }
    }
  }

  private parseFelicitaWeight(data: DataView): { weight: number; isStable: boolean } {
    if (data.byteLength < 6) return { weight: 0, isStable: false }

    // Felicita sends ASCII
    const bytes = new Uint8Array(data.buffer, data.byteOffset, Math.min(6, data.byteLength))
    const weightString = new TextDecoder().decode(bytes).trim()
    const weight = parseFloat(weightString) || 0
    const isStable = data.byteLength > 6 && data.getUint8(6) === 0x53 // 'S'

    return { weight, isStable }
  }

  private parseDecentWeight(data: DataView): { weight: number; isStable: boolean } {
    if (data.byteLength < 2) return { weight: 0, isStable: false }

    const weightRaw = (data.getUint8(0) << 8) | data.getUint8(1)
    const weight = weightRaw / 10
    const isStable = data.byteLength > 2 ? (data.getUint8(2) & 0x01) !== 0 : false

    return { weight, isStable }
  }

  private parseTimemoreWeight(data: DataView): { weight: number; isStable: boolean } {
    if (data.byteLength < 6) return { weight: 0, isStable: false }

    const weightRaw =
      (data.getUint8(1) << 24) |
      (data.getUint8(2) << 16) |
      (data.getUint8(3) << 8) |
      data.getUint8(4)
    let weight = weightRaw / 10
    if ((data.getUint8(5) & 0x80) !== 0) {
      weight = -weight
    }
    const isStable = (data.getUint8(5) & 0x01) !== 0

    return { weight, isStable }
  }

  private parseGenericWeight(data: DataView): { weight: number; isStable: boolean } {
    // Bluetooth SIG Weight Measurement (0x2A9D)
    if (data.byteLength < 3) return { weight: 0, isStable: false }

    const flags = data.getUint8(0)
    const isImperial = (flags & 0x01) !== 0

    const weightRaw = data.getUint16(1, true) // little-endian
    let weight: number

    if (isImperial) {
      weight = weightRaw * 0.01 * 453.592 // lb to g
    } else {
      weight = weightRaw * 5 // 5g resolution
    }

    // Check for finer resolution
    if (data.byteLength >= 5) {
      const fineWeight = data.getUint16(3, true)
      weight = fineWeight / 10 // 0.1g resolution
    }

    const isStable = (flags & 0x20) !== 0

    return { weight, isStable }
  }

  /**
   * Send command to scale
   */
  private async sendCommand(
    command: 'tare' | 'startTimer' | 'stopTimer' | 'resetTimer'
  ): Promise<void> {
    if (!this.commandCharacteristic) {
      console.warn('[ScaleService] Command characteristic not available')
      return
    }

    const data = this.getCommandData(command)
    if (!data) return

    try {
      await this.commandCharacteristic.writeValue(data)
      console.log('[ScaleService] Command sent:', command)
    } catch (error) {
      console.error('[ScaleService] Failed to send command:', error)
    }
  }

  /**
   * Get command data for specific brand
   */
  private getCommandData(
    command: 'tare' | 'startTimer' | 'stopTimer' | 'resetTimer'
  ): Uint8Array | null {
    switch (this.brand) {
      case 'bookoo':
        switch (command) {
          case 'tare':
            return new Uint8Array([0x07, 0x00])
          case 'startTimer':
            return new Uint8Array([0x08, 0x00])
          case 'stopTimer':
            return new Uint8Array([0x09, 0x00])
          case 'resetTimer':
            return new Uint8Array([0x0a, 0x00])
        }
        break
      case 'acaia':
        switch (command) {
          case 'tare':
            return new Uint8Array([0xef, 0xdd, 0x04, 0x00, 0x00, 0x00, 0x00, 0x00])
          case 'startTimer':
            return new Uint8Array([0xef, 0xdd, 0x0d, 0x00, 0x00, 0x00, 0x00, 0x00])
          case 'stopTimer':
            return new Uint8Array([0xef, 0xdd, 0x0d, 0x02, 0x00, 0x00, 0x00, 0x00])
          case 'resetTimer':
            return new Uint8Array([0xef, 0xdd, 0x0d, 0x01, 0x00, 0x00, 0x00, 0x00])
        }
        break
      case 'felicita':
        switch (command) {
          case 'tare':
            return new Uint8Array([0x54]) // 'T'
          case 'startTimer':
            return new Uint8Array([0x52]) // 'R'
          case 'stopTimer':
            return new Uint8Array([0x53]) // 'S'
          case 'resetTimer':
            return new Uint8Array([0x43]) // 'C'
        }
        break
      case 'timemore':
        switch (command) {
          case 'tare':
            return new Uint8Array([0x03, 0x0a, 0x01, 0x00, 0x00, 0x08])
          case 'startTimer':
            return new Uint8Array([0x03, 0x0a, 0x04, 0x00, 0x00, 0x0b])
          case 'stopTimer':
            return new Uint8Array([0x03, 0x0a, 0x05, 0x00, 0x00, 0x0c])
          case 'resetTimer':
            return new Uint8Array([0x03, 0x0a, 0x06, 0x00, 0x00, 0x0d])
        }
        break
    }
    return null
  }

  /**
   * Handle disconnection
   */
  private onDisconnected(): void {
    console.log('[ScaleService] Scale disconnected')
    useScaleStore.getState().reset()
  }
}

// Export singleton
export const scaleService = new ScaleService()
