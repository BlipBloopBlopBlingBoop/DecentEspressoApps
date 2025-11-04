import {
  DecentMachine,
  DecentCommand,
  MachineState,
  DECENT_SERVICE_UUID,
  DECENT_CHARACTERISTICS,
  ShotProfile,
} from '../types/decent'
import { useConnectionStore } from '../stores/connectionStore'
import { useMachineStore } from '../stores/machineStore'
import { useShotStore } from '../stores/shotStore'

class BluetoothService {
  private device: BluetoothDevice | null = null
  private server: BluetoothRemoteGATTServer | null = null
  private characteristics: Map<string, BluetoothRemoteGATTCharacteristic> = new Map()
  private dataUpdateInterval: number | null = null

  /**
   * Check if Web Bluetooth is supported
   */
  isSupported(): boolean {
    return 'bluetooth' in navigator
  }

  /**
   * Request and connect to a Decent espresso machine
   */
  async connect(): Promise<DecentMachine> {
    const connectionStore = useConnectionStore.getState()

    try {
      connectionStore.setConnecting(true)

      if (!this.isSupported()) {
        throw new Error('Web Bluetooth is not supported in this browser')
      }

      // Request device
      this.device = await navigator.bluetooth.requestDevice({
        filters: [
          { namePrefix: 'DE1' },
          { services: [DECENT_SERVICE_UUID] }
        ],
        optionalServices: [DECENT_SERVICE_UUID]
      })

      if (!this.device.gatt) {
        throw new Error('GATT not available on device')
      }

      // Add disconnect listener
      this.device.addEventListener('gattserverdisconnected', this.onDisconnected.bind(this))

      // Connect to GATT server
      this.server = await this.device.gatt.connect()
      connectionStore.setDeviceName(this.device.name || 'Decent Machine')

      // Get primary service
      const service = await this.server.getPrimaryService(DECENT_SERVICE_UUID)

      // Get all characteristics
      await this.setupCharacteristics(service)

      // Start listening to notifications
      await this.setupNotifications()

      connectionStore.setConnected(true)
      connectionStore.updateLastConnected()

      // Start periodic data updates
      this.startDataUpdates()

      return {
        id: this.device.id,
        name: this.device.name || 'Decent Machine',
        connected: true,
        device: this.device,
        server: this.server,
      }
    } catch (error) {
      connectionStore.setError(this.getErrorMessage(error))
      throw error
    }
  }

  /**
   * Disconnect from the machine
   */
  async disconnect(): Promise<void> {
    if (this.dataUpdateInterval) {
      clearInterval(this.dataUpdateInterval)
      this.dataUpdateInterval = null
    }

    if (this.server && this.server.connected) {
      this.server.disconnect()
    }

    this.device = null
    this.server = null
    this.characteristics.clear()

    useConnectionStore.getState().reset()
    useMachineStore.getState().reset()
  }

  /**
   * Setup all characteristics
   */
  private async setupCharacteristics(service: BluetoothRemoteGATTService): Promise<void> {
    try {
      for (const [name, uuid] of Object.entries(DECENT_CHARACTERISTICS)) {
        try {
          const characteristic = await service.getCharacteristic(uuid)
          this.characteristics.set(name, characteristic)
        } catch (error) {
          console.warn(`Could not get characteristic ${name}:`, error)
        }
      }
    } catch (error) {
      console.error('Error setting up characteristics:', error)
      throw new Error('Failed to setup machine characteristics')
    }
  }

  /**
   * Setup notifications for real-time data
   */
  private async setupNotifications(): Promise<void> {
    const stateChar = this.characteristics.get('STATE_INFO')

    if (stateChar) {
      try {
        await stateChar.startNotifications()
        stateChar.addEventListener('characteristicvaluechanged', this.handleStateUpdate.bind(this))
      } catch (error) {
        console.warn('Could not setup state notifications:', error)
      }
    }
  }

  /**
   * Handle state updates from the machine
   */
  private handleStateUpdate(event: Event): void {
    const characteristic = event.target as BluetoothRemoteGATTCharacteristic
    const value = characteristic.value

    if (!value) return

    try {
      const state = this.parseStateData(value)
      useMachineStore.getState().setState(state)

      // If recording a shot, add data point
      const shotStore = useShotStore.getState()
      if (shotStore.isRecording && state.state === 'brewing') {
        shotStore.addDataPoint({
          timestamp: Date.now() - (shotStore.activeShot?.startTime || Date.now()),
          temperature: state.temperature.mix,
          pressure: state.pressure,
          flow: state.flow,
          weight: state.weight,
        })
      }
    } catch (error) {
      console.error('Error parsing state data:', error)
    }
  }

  /**
   * Parse state data from DataView
   */
  private parseStateData(dataView: DataView): MachineState {
    // This is a simplified parser - actual implementation would depend on
    // the Decent machine's exact data format
    return {
      state: this.parseMachineState(dataView.getUint8(0)),
      substate: dataView.getUint8(1).toString(),
      temperature: {
        mix: dataView.getFloat32(2, true),
        head: dataView.getFloat32(6, true),
        steam: dataView.getFloat32(10, true),
        target: dataView.getFloat32(14, true),
      },
      pressure: dataView.getFloat32(18, true),
      flow: dataView.getFloat32(22, true),
      weight: dataView.getFloat32(26, true),
      timestamp: Date.now(),
    }
  }

  /**
   * Parse machine state byte
   */
  private parseMachineState(byte: number): MachineState['state'] {
    const states = ['idle', 'sleep', 'warming', 'ready', 'brewing', 'steam', 'flush', 'cleaning', 'error']
    return (states[byte] || 'idle') as MachineState['state']
  }

  /**
   * Send a command to the machine
   */
  async sendCommand(command: DecentCommand, data?: Uint8Array): Promise<void> {
    const commandChar = this.characteristics.get('COMMAND')

    if (!commandChar) {
      throw new Error('Command characteristic not available')
    }

    const buffer = new Uint8Array(data ? data.length + 1 : 1)
    buffer[0] = command
    if (data) {
      buffer.set(data, 1)
    }

    await commandChar.writeValue(buffer)
  }

  /**
   * Start espresso extraction
   */
  async startEspresso(): Promise<void> {
    await this.sendCommand(DecentCommand.START_ESPRESSO)

    const shotStore = useShotStore.getState()
    const recipeStore = useRecipeStore.getState()

    shotStore.startShot({
      profileName: recipeStore.activeRecipe?.name || 'Manual',
      profileId: recipeStore.activeRecipe?.id,
      startTime: Date.now(),
    })
  }

  /**
   * Stop current operation
   */
  async stop(): Promise<void> {
    await this.sendCommand(DecentCommand.STOP)

    const shotStore = useShotStore.getState()
    if (shotStore.isRecording) {
      shotStore.endShot()
    }
  }

  /**
   * Start steam mode
   */
  async startSteam(): Promise<void> {
    await this.sendCommand(DecentCommand.START_STEAM)
  }

  /**
   * Start flush
   */
  async startFlush(): Promise<void> {
    await this.sendCommand(DecentCommand.START_FLUSH)
  }

  /**
   * Start water dispense
   */
  async startWater(): Promise<void> {
    await this.sendCommand(DecentCommand.START_WATER)
  }

  /**
   * Set target temperature
   */
  async setTemperature(temperature: number): Promise<void> {
    const data = new Uint8Array(4)
    const view = new DataView(data.buffer)
    view.setFloat32(0, temperature, true)
    await this.sendCommand(DecentCommand.SET_TEMPERATURE, data)
  }

  /**
   * Upload a shot profile to the machine
   */
  async uploadProfile(profile: ShotProfile): Promise<void> {
    const profileChar = this.characteristics.get('SHOT_PROFILE')

    if (!profileChar) {
      throw new Error('Profile characteristic not available')
    }

    // Convert profile to binary format (simplified - actual format depends on machine)
    const profileData = this.encodeProfile(profile)
    await profileChar.writeValue(profileData as BufferSource)
  }

  /**
   * Encode profile to binary format
   */
  private encodeProfile(profile: ShotProfile): Uint8Array {
    // This is a placeholder - actual encoding depends on Decent's protocol
    const encoder = new TextEncoder()
    return encoder.encode(JSON.stringify(profile))
  }

  /**
   * Start periodic data updates
   */
  private startDataUpdates(): void {
    // Poll for data every 100ms when connected
    this.dataUpdateInterval = window.setInterval(async () => {
      if (!this.server?.connected) {
        if (this.dataUpdateInterval) {
          clearInterval(this.dataUpdateInterval)
        }
        return
      }

      // Request current state if notifications aren't working
      await this.requestStateUpdate()
    }, 100)
  }

  /**
   * Request state update from machine
   */
  private async requestStateUpdate(): Promise<void> {
    const stateChar = this.characteristics.get('STATE_INFO')

    if (!stateChar) return

    try {
      const value = await stateChar.readValue()
      const state = this.parseStateData(value)
      useMachineStore.getState().setState(state)
    } catch (error) {
      // Silently fail - notifications should handle updates
    }
  }

  /**
   * Handle disconnection
   */
  private onDisconnected(): void {
    console.log('Device disconnected')
    useConnectionStore.getState().setConnected(false)

    if (this.dataUpdateInterval) {
      clearInterval(this.dataUpdateInterval)
      this.dataUpdateInterval = null
    }
  }

  /**
   * Get error message from exception
   */
  private getErrorMessage(error: unknown): string {
    if (error instanceof Error) {
      if (error.message.includes('User cancelled')) {
        return 'Connection cancelled by user'
      }
      if (error.message.includes('not found')) {
        return 'Decent machine not found. Make sure it is powered on and in range.'
      }
      return error.message
    }
    return 'Unknown error occurred'
  }

  /**
   * Get connection status
   */
  isConnected(): boolean {
    return this.server?.connected || false
  }
}

// Export singleton instance
export const bluetoothService = new BluetoothService()

// Import statement that was missing
import { useRecipeStore } from '../stores/recipeStore'
