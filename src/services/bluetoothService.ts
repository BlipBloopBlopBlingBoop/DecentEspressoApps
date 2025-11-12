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

      // Request device - filter by name and include service as optional
      // This matches all Decent machines (DE1, DE1+, DE1PRO, etc.)
      console.log('Requesting Bluetooth device with filter: namePrefix="DE1"')
      this.device = await navigator.bluetooth.requestDevice({
        filters: [
          { namePrefix: 'DE1' }
        ],
        optionalServices: [DECENT_SERVICE_UUID]
      })

      console.log('Device selected:', this.device.name, 'ID:', this.device.id)

      if (!this.device.gatt) {
        throw new Error('GATT not available on device')
      }

      // Add disconnect listener
      this.device.addEventListener('gattserverdisconnected', this.onDisconnected.bind(this))

      // Connect to GATT server
      console.log('Connecting to GATT server...')
      this.server = await this.device.gatt.connect()
      connectionStore.setDeviceName(this.device.name || 'Decent Machine')
      console.log('GATT server connected')

      // Get primary service
      console.log('Getting primary service:', DECENT_SERVICE_UUID)
      const service = await this.server.getPrimaryService(DECENT_SERVICE_UUID)
      console.log('Primary service acquired')

      // Get all characteristics
      await this.setupCharacteristics(service)

      // Start listening to notifications
      await this.setupNotifications()

      // Try to read version for diagnostics (non-blocking)
      this.readVersion().catch(e => console.warn('Could not read version:', e))

      // Verify we can get initial machine state before marking as connected
      await this.verifyInitialState()

      connectionStore.setConnected(true)
      connectionStore.updateLastConnected()

      // Start periodic data updates
      this.startDataUpdates()

      console.log('Successfully connected to Decent machine:', this.device.name)

      return {
        id: this.device.id,
        name: this.device.name || 'Decent Machine',
        connected: true,
        device: this.device,
        server: this.server,
      }
    } catch (error) {
      connectionStore.setConnecting(false)
      connectionStore.setError(this.getErrorMessage(error))
      console.error('Connection failed:', error)
      throw error
    } finally {
      connectionStore.setConnecting(false)
    }
  }

  /**
   * Disconnect from the machine
   */
  async disconnect(): Promise<void> {
    console.log('Disconnecting from machine...')

    if (this.dataUpdateInterval) {
      clearInterval(this.dataUpdateInterval)
      this.dataUpdateInterval = null
    }

    if (this.server && this.server.connected) {
      try {
        this.server.disconnect()
      } catch (error) {
        console.warn('Error during disconnect:', error)
      }
    }

    this.device = null
    this.server = null
    this.characteristics.clear()

    useConnectionStore.getState().reset()
    useMachineStore.getState().reset()

    console.log('Disconnected')
  }

  /**
   * Attempt to reconnect to a previously connected device
   */
  async reconnect(): Promise<DecentMachine | null> {
    if (!this.device) {
      console.warn('No previous device to reconnect to')
      return null
    }

    try {
      console.log('Attempting to reconnect to:', this.device.name)

      if (!this.device.gatt) {
        throw new Error('GATT not available')
      }

      // Try to reconnect to the existing device
      this.server = await this.device.gatt.connect()

      // Re-setup everything
      const service = await this.server.getPrimaryService(DECENT_SERVICE_UUID)
      await this.setupCharacteristics(service)
      await this.setupNotifications()
      await this.verifyInitialState()

      const connectionStore = useConnectionStore.getState()
      connectionStore.setConnected(true)
      connectionStore.updateLastConnected()

      console.log('Reconnected successfully')

      return {
        id: this.device.id,
        name: this.device.name || 'Decent Machine',
        connected: true,
        device: this.device,
        server: this.server,
      }
    } catch (error) {
      console.error('Reconnection failed:', error)
      return null
    }
  }

  /**
   * Setup all characteristics
   */
  private async setupCharacteristics(service: BluetoothRemoteGATTService): Promise<void> {
    console.log('Setting up characteristics...')
    const foundCharacteristics: string[] = []
    const missingCharacteristics: string[] = []

    try {
      for (const [name, uuid] of Object.entries(DECENT_CHARACTERISTICS)) {
        try {
          const characteristic = await service.getCharacteristic(uuid)
          this.characteristics.set(name, characteristic)
          foundCharacteristics.push(name)
        } catch (error) {
          missingCharacteristics.push(name)
          console.warn(`Could not get characteristic ${name} (${uuid}):`, error)
        }
      }

      console.log(`Found ${foundCharacteristics.length} characteristics:`, foundCharacteristics)
      if (missingCharacteristics.length > 0) {
        console.warn(`Missing ${missingCharacteristics.length} characteristics:`, missingCharacteristics)
      }

      // Verify critical characteristics are present
      if (!this.characteristics.has('STATE_INFO') && !this.characteristics.has('SHOT_SAMPLE')) {
        throw new Error('Critical characteristics (STATE_INFO or SHOT_SAMPLE) not found')
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
      console.warn('[BluetoothService] No data characteristics available - proceeding without initial state')
      // Don't fail - we'll get data from notifications eventually
      return
    }

    console.log('[BluetoothService] Waiting for initial machine data...')

    try {
      // Wait for first notification with a 5 second timeout
      // Reduced from 10s to be more responsive
      await this.waitForFirstNotification(5000)
      console.log('[BluetoothService] ✓ Initial machine data received')
    } catch (error) {
      // Don't fail the connection - notifications are set up and data will arrive
      console.warn('[BluetoothService] Timeout waiting for initial data, proceeding anyway')
      console.warn('[BluetoothService] Notifications are active - data will arrive shortly')

      // Initialize with a default idle state so UI isn't empty
      const machineStore = useMachineStore.getState()
      if (!machineStore.state) {
        console.log('[BluetoothService] Initializing default idle state')
        machineStore.setState({
          state: 'idle',
          substate: '0',
          temperature: {
            mix: 0,
            head: 0,
            steam: 0,
            target: 93,
          },
          pressure: 0,
          flow: 0,
          weight: 0,
          timestamp: Date.now(),
        })
      }
    }
  }

  /**
   * Wait for first notification from the machine
   */
  private waitForFirstNotification(timeoutMs: number): Promise<void> {
    console.log(`[BluetoothService] Setting up notification listener (${timeoutMs}ms timeout)`)

    return new Promise((resolve, reject) => {
      let unsubscribe: (() => void) | null = null

      const timer = setTimeout(() => {
        console.log('[BluetoothService] ⏱️ Notification timeout reached')
        if (unsubscribe) unsubscribe()
        reject(new Error('Timeout waiting for machine data'))
      }, timeoutMs)

      // Check if we already have state (notification arrived during setup)
      const currentState = useMachineStore.getState().state
      if (currentState) {
        console.log('[BluetoothService] ✓ State already present:', currentState.state)
        clearTimeout(timer)
        resolve()
        return
      }

      // Wait for state to be set by notification handler
      console.log('[BluetoothService] Subscribing to state updates...')
      unsubscribe = useMachineStore.subscribe((state) => {
        if (state.state) {
          console.log('[BluetoothService] ✓ First notification received:', state.state.state)
          clearTimeout(timer)
          if (unsubscribe) unsubscribe()
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
    console.log(`[BluetoothService] sendCommand called with: ${DecentCommand[command]} (${command})`)

    const commandChar = this.characteristics.get('REQUESTED_STATE')

    if (!commandChar) {
      console.error('[BluetoothService] REQUESTED_STATE characteristic not found!')
      console.log('[BluetoothService] Available characteristics:', Array.from(this.characteristics.keys()))
      throw new Error('REQUESTED_STATE characteristic not available - cannot send commands')
    }

    try {
      // Commands are single bytes written to REQUESTED_STATE (A002)
      const buffer = new Uint8Array(data ? data.length + 1 : 1)
      buffer[0] = command
      if (data) {
        buffer.set(data, 1)
      }

      console.log(`[BluetoothService] Writing command buffer:`, Array.from(buffer))
      await commandChar.writeValue(buffer)
      console.log(`[BluetoothService] ✓ Command sent successfully: ${DecentCommand[command]} (0x${command.toString(16).padStart(2, '0')})`)
    } catch (error) {
      console.error('[BluetoothService] ✗ Failed to send command:', error)
      throw new Error(`Failed to send command to machine: ${error}`)
    }
  }

  /**
   * Read firmware version from the machine
   */
  async readVersion(): Promise<string> {
    const versionChar = this.characteristics.get('VERSION')

    if (!versionChar) {
      throw new Error('VERSION characteristic not available')
    }

    try {
      const value = await this.readWithTimeout(versionChar)
      const decoder = new TextDecoder()
      const version = decoder.decode(value.buffer)
      console.log('Machine version:', version)
      return version
    } catch (error) {
      console.error('Failed to read version:', error)
      return 'Unknown'
    }
  }

  /**
   * Read water levels from the machine
   */
  async readWaterLevels(): Promise<number> {
    const waterChar = this.characteristics.get('WATER_LEVELS')

    if (!waterChar) {
      return 0
    }

    try {
      const value = await this.readWithTimeout(waterChar)
      // Parse water level (format depends on machine firmware)
      return value.getUint8(0)
    } catch (error) {
      console.warn('Failed to read water levels:', error)
      return 0
    }
  }

  /**
   * Start espresso extraction
   */
  async startEspresso(): Promise<void> {
    console.log('[BluetoothService] startEspresso() called')
    await this.sendCommand(DecentCommand.ESPRESSO)

    const shotStore = useShotStore.getState()
    const recipeStore = useRecipeStore.getState()

    shotStore.startShot({
      profileName: recipeStore.activeRecipe?.name || 'Manual',
      profileId: recipeStore.activeRecipe?.id,
      startTime: Date.now(),
    })
    console.log('[BluetoothService] startEspresso() completed')
  }

  /**
   * Stop current operation (go to idle)
   */
  async stop(): Promise<void> {
    console.log('[BluetoothService] stop() called')
    await this.sendCommand(DecentCommand.IDLE)

    const shotStore = useShotStore.getState()
    if (shotStore.isRecording) {
      shotStore.endShot()
    }
    console.log('[BluetoothService] stop() completed')
  }

  /**
   * Start steam mode
   */
  async startSteam(): Promise<void> {
    console.log('[BluetoothService] startSteam() called')
    await this.sendCommand(DecentCommand.STEAM)
    console.log('[BluetoothService] startSteam() completed')
  }

  /**
   * Start flush
   */
  async startFlush(): Promise<void> {
    console.log('[BluetoothService] startFlush() called')
    await this.sendCommand(DecentCommand.HOT_WATER_RINSE)
    console.log('[BluetoothService] startFlush() completed')
  }

  /**
   * Start water dispense
   */
  async startWater(): Promise<void> {
    console.log('[BluetoothService] startWater() called')
    await this.sendCommand(DecentCommand.HOT_WATER)
    console.log('[BluetoothService] startWater() completed')
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
      // User cancelled the device selection
      if (error.message.includes('User cancelled') || error.message.includes('cancelled')) {
        return 'Connection cancelled by user'
      }
      // Device not found or not available
      if (error.message.includes('not found') || error.message.includes('No device')) {
        return 'Decent machine not found. Make sure it is powered on and in Bluetooth range.'
      }
      // Bluetooth not available
      if (error.message.includes('not supported') || error.message.includes('Bluetooth')) {
        return 'Web Bluetooth is not supported. Please use Chrome, Edge, or Opera browser.'
      }
      // GATT connection issues
      if (error.message.includes('GATT') || error.message.includes('connect')) {
        return 'Failed to connect to machine. Try turning the machine off and on again.'
      }
      // Service not available
      if (error.message.includes('service')) {
        return 'Machine service not available. Ensure the machine firmware is up to date.'
      }
      // Timeout issues
      if (error.message.includes('timeout') || error.message.includes('Timeout')) {
        return 'Connection timeout. The machine may not be responding. Try restarting it.'
      }
      return error.message
    }
    return 'Unknown error occurred during connection'
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
