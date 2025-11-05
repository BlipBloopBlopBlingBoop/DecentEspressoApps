import {
  DecentMachine,
  DecentCommand,
  MachineState,
  DECENT_SERVICE_UUID,
  DECENT_CHARACTERISTICS,
  ShotProfile,
} from '../types/decent'
import { parseStateInfo, parseShotSample, mapStateToType } from '../utils/decentProtocol'
import { useConnectionStore } from '../stores/connectionStore'
import { useMachineStore } from '../stores/machineStore'
import { useShotStore } from '../stores/shotStore'

class BluetoothService {
  private device: BluetoothDevice | null = null
  private server: BluetoothRemoteGATTServer | null = null
  private characteristics: Map<string, BluetoothRemoteGATTCharacteristic> = new Map()
  private dataUpdateInterval: number | null = null
  private readonly READ_TIMEOUT_MS = 5000 // 5 second timeout for reads
  private readonly INITIAL_STATE_TIMEOUT_MS = 10000 // 10 second timeout for initial connection

  /**
   * Check if Web Bluetooth is supported
   */
  isSupported(): boolean {
    return 'bluetooth' in navigator
  }

  /**
   * Wrapper to add timeout to Bluetooth read operations
   */
  private async readWithTimeout(
    characteristic: BluetoothRemoteGATTCharacteristic,
    timeoutMs: number = this.READ_TIMEOUT_MS
  ): Promise<DataView> {
    return Promise.race([
      characteristic.readValue(),
      new Promise<DataView>((_, reject) =>
        setTimeout(() => reject(new Error('Bluetooth read timeout - machine not responding')), timeoutMs)
      )
    ])
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

      // Verify we can get initial machine state before marking as connected
      await this.verifyInitialState()

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
    const shotSampleChar = this.characteristics.get('SHOT_SAMPLE')

    // Set up STATE_INFO notifications (state and substate)
    if (stateChar) {
      try {
        await stateChar.startNotifications()
        stateChar.addEventListener('characteristicvaluechanged', this.handleStateInfoUpdate.bind(this))
        console.log('STATE_INFO notifications enabled')
      } catch (error) {
        console.warn('Could not setup STATE_INFO notifications:', error)
      }
    }

    // Set up SHOT_SAMPLE notifications (real-time sensor data)
    if (shotSampleChar) {
      try {
        await shotSampleChar.startNotifications()
        shotSampleChar.addEventListener('characteristicvaluechanged', this.handleShotSampleUpdate.bind(this))
        console.log('SHOT_SAMPLE notifications enabled')
      } catch (error) {
        console.warn('Could not setup SHOT_SAMPLE notifications:', error)
      }
    }
  }

  /**
   * Verify that we can get initial state from the machine
   * This prevents the "waiting for machine info" freeze
   */
  private async verifyInitialState(): Promise<void> {
    const stateChar = this.characteristics.get('STATE_INFO')
    const shotSampleChar = this.characteristics.get('SHOT_SAMPLE')

    if (!stateChar && !shotSampleChar) {
      throw new Error('No data characteristics available')
    }

    try {
      // Wait for first notification with timeout
      // STATE_INFO and SHOT_SAMPLE are notification-only, not readable
      await this.waitForFirstNotification(this.INITIAL_STATE_TIMEOUT_MS)
      console.log('Initial machine data received')
    } catch (error) {
      console.error('Failed to get initial machine state:', error)
      throw new Error(
        'Unable to retrieve machine information. The machine may not be ready. ' +
        'Please ensure the machine is fully warmed up and try reconnecting.'
      )
    }
  }

  /**
   * Wait for first notification from the machine
   */
  private waitForFirstNotification(timeoutMs: number): Promise<void> {
    return new Promise((resolve, reject) => {
      const timer = setTimeout(() => {
        reject(new Error('Timeout waiting for machine data'))
      }, timeoutMs)

      // Check if we already have state (notification arrived during setup)
      if (useMachineStore.getState().state) {
        clearTimeout(timer)
        resolve()
        return
      }

      // Wait for state to be set by notification handler
      const unsubscribe = useMachineStore.subscribe((state) => {
        if (state.state) {
          clearTimeout(timer)
          unsubscribe()
          resolve()
        }
      })
    })
  }

  /**
   * Handle STATE_INFO updates (state and substate only)
   */
  private handleStateInfoUpdate(event: Event): void {
    const characteristic = event.target as BluetoothRemoteGATTCharacteristic
    const value = characteristic.value

    if (!value) return

    try {
      const stateInfo = parseStateInfo(value)
      const machineStore = useMachineStore.getState()
      const currentState = machineStore.state

      // Update state type based on the state number
      const stateType = mapStateToType(stateInfo.state) as MachineState['state']

      // Preserve existing sensor data, just update state
      machineStore.setState({
        ...currentState,
        state: stateType,
        substate: stateInfo.substate.toString(),
        timestamp: Date.now(),
      } as MachineState)
    } catch (error) {
      console.error('Error parsing STATE_INFO:', error)
    }
  }

  /**
   * Handle SHOT_SAMPLE updates (real-time sensor data)
   */
  private handleShotSampleUpdate(event: Event): void {
    const characteristic = event.target as BluetoothRemoteGATTCharacteristic
    const value = characteristic.value

    if (!value) return

    try {
      const sample = parseShotSample(value)
      const machineStore = useMachineStore.getState()
      const currentState = machineStore.state

      // Build complete machine state with sensor data
      const state: MachineState = {
        state: currentState?.state || 'idle',
        substate: currentState?.substate || '0',
        temperature: {
          mix: sample.mixTemp,
          head: sample.headTemp,
          steam: sample.steamTemp,
          target: sample.setMixTemp,
        },
        pressure: sample.groupPressure,
        flow: sample.groupFlow,
        weight: 0, // Weight comes from a separate characteristic
        timestamp: Date.now(),
      }

      machineStore.setState(state)

      // If recording a shot, add data point
      const shotStore = useShotStore.getState()
      if (shotStore.isRecording && currentState?.state === 'brewing') {
        shotStore.addDataPoint({
          timestamp: Date.now() - (shotStore.activeShot?.startTime || Date.now()),
          temperature: sample.mixTemp,
          pressure: sample.groupPressure,
          flow: sample.groupFlow,
          weight: 0,
        })
      }
    } catch (error) {
      console.error('Error parsing SHOT_SAMPLE:', error)
    }
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
    await this.sendCommand(DecentCommand.ESPRESSO)

    const shotStore = useShotStore.getState()
    const recipeStore = useRecipeStore.getState()

    shotStore.startShot({
      profileName: recipeStore.activeRecipe?.name || 'Manual',
      profileId: recipeStore.activeRecipe?.id,
      startTime: Date.now(),
    })
  }

  /**
   * Stop current operation (go to idle)
   */
  async stop(): Promise<void> {
    await this.sendCommand(DecentCommand.IDLE)

    const shotStore = useShotStore.getState()
    if (shotStore.isRecording) {
      shotStore.endShot()
    }
  }

  /**
   * Start steam mode
   */
  async startSteam(): Promise<void> {
    await this.sendCommand(DecentCommand.STEAM)
  }

  /**
   * Start flush
   */
  async startFlush(): Promise<void> {
    await this.sendCommand(DecentCommand.HOT_WATER_RINSE)
  }

  /**
   * Start water dispense
   */
  async startWater(): Promise<void> {
    await this.sendCommand(DecentCommand.HOT_WATER)
  }

  /**
   * Set target temperature
   * Note: Temperature setting via WriteToMMR requires MMR protocol
   * This is a placeholder - full implementation requires MMR writes
   */
  async setTemperature(_temperature: number): Promise<void> {
    console.warn('Temperature setting requires MMR protocol - not yet implemented')
    // TODO: Implement MMR write for temperature control
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
   * Note: For Decent machines, STATE_INFO and SHOT_SAMPLE are notification-only.
   * This method is kept for potential future use with other characteristics.
   */
  private startDataUpdates(): void {
    // Notifications handle all real-time updates
    // This could be used in the future for keepalive or other periodic tasks
    console.log('Data updates will be handled via BLE notifications')
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
