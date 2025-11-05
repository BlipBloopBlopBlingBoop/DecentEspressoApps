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
import { useRecipeStore } from '../stores/recipeStore'
import { parseShotSample, parseStateInfo, mapStateToType } from '../utils/decentProtocol'

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

      console.log('Requesting Decent device...')

      // Request device - DE1 machines advertise with namePrefix "DE1"
      this.device = await navigator.bluetooth.requestDevice({
        filters: [
          {
            namePrefix: 'DE1',
            services: [DECENT_SERVICE_UUID]
          }
        ],
        optionalServices: [DECENT_SERVICE_UUID]
      })

      console.log('Device selected:', this.device.name)

      if (!this.device.gatt) {
        throw new Error('GATT not available on device')
      }

      // Add disconnect listener
      this.device.addEventListener('gattserverdisconnected', this.onDisconnected.bind(this))

      // Connect to GATT server
      console.log('Connecting to GATT server...')
      this.server = await this.device.gatt.connect()
      connectionStore.setDeviceName(this.device.name || 'Decent Machine')

      // Get primary service
      console.log('Getting primary service...')
      const service = await this.server.getPrimaryService(DECENT_SERVICE_UUID)

      // Get all characteristics
      console.log('Setting up characteristics...')
      await this.setupCharacteristics(service)

      // Start listening to notifications
      console.log('Setting up notifications...')
      await this.setupNotifications()

      connectionStore.setConnected(true)
      connectionStore.updateLastConnected()

      console.log('Connected successfully!')

      return {
        id: this.device.id,
        name: this.device.name || 'Decent Machine',
        connected: true,
        device: this.device,
        server: this.server,
      }
    } catch (error) {
      console.error('Connection error:', error)
      connectionStore.setError(this.getErrorMessage(error))
      connectionStore.setConnecting(false)
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
          console.log(`Got characteristic: ${name}`)
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
    // STATE_INFO - Machine state changes
    const stateChar = this.characteristics.get('STATE_INFO')
    if (stateChar) {
      try {
        await stateChar.startNotifications()
        stateChar.addEventListener('characteristicvaluechanged', this.handleStateUpdate.bind(this))
        console.log('STATE_INFO notifications enabled')
      } catch (error) {
        console.warn('Could not setup state notifications:', error)
      }
    }

    // SHOT_SAMPLE - Real-time shot data (THIS IS CRITICAL!)
    const shotChar = this.characteristics.get('SHOT_SAMPLE')
    if (shotChar) {
      try {
        await shotChar.startNotifications()
        shotChar.addEventListener('characteristicvaluechanged', this.handleShotSample.bind(this))
        console.log('SHOT_SAMPLE notifications enabled')
      } catch (error) {
        console.warn('Could not setup shot sample notifications:', error)
      }
    } else {
      console.error('SHOT_SAMPLE characteristic not found!')
    }
  }

  /**
   * Handle shot sample updates (real-time data)
   */
  private handleShotSample(event: Event): void {
    const characteristic = event.target as BluetoothRemoteGATTCharacteristic
    const value = characteristic.value

    if (!value) return

    try {
      const data = parseShotSample(value)

      // Update machine store with current readings
      const machineStore = useMachineStore.getState()
      const currentState = machineStore.state

      machineStore.setState({
        state: currentState?.state || 'idle',
        substate: currentState?.substate || '',
        temperature: {
          mix: data.mixTemp,
          head: data.headTemp,
          steam: data.steamTemp,
          target: data.setMixTemp,
        },
        pressure: data.groupPressure,
        flow: data.groupFlow,
        weight: currentState?.weight || 0,
        timestamp: Date.now(),
      })

      // If recording a shot, add data point
      const shotStore = useShotStore.getState()
      if (shotStore.isRecording) {
        shotStore.addDataPoint({
          timestamp: Date.now() - (shotStore.activeShot?.startTime || Date.now()),
          temperature: data.mixTemp,
          pressure: data.groupPressure,
          flow: data.groupFlow,
          weight: 0, // TODO: Get from scale
        })
      }
    } catch (error) {
      console.error('Error parsing shot sample:', error)
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
      const data = parseStateInfo(value)
      const stateType = mapStateToType(data.state)

      const machineStore = useMachineStore.getState()
      const currentState = machineStore.state

      machineStore.setState({
        state: stateType as MachineState['state'],
        substate: data.substate.toString(),
        temperature: currentState?.temperature || { mix: 0, head: 0, steam: 0, target: 0 },
        pressure: currentState?.pressure || 0,
        flow: currentState?.flow || 0,
        weight: currentState?.weight || 0,
        timestamp: Date.now(),
      })

      console.log(`State changed: ${stateType} (${data.state}:${data.substate})`)

      // Handle shot recording based on state
      const shotStore = useShotStore.getState()
      if (stateType === 'brewing' && !shotStore.isRecording) {
        // Auto-start recording on brew
        const recipeStore = useRecipeStore.getState()
        shotStore.startShot({
          profileName: recipeStore.activeRecipe?.name || 'Manual',
          profileId: recipeStore.activeRecipe?.id,
          startTime: Date.now(),
        })
      } else if (stateType !== 'brewing' && shotStore.isRecording) {
        // Auto-stop recording when brew ends
        shotStore.endShot()
      }
    } catch (error) {
      console.error('Error parsing state data:', error)
    }
  }

  /**
   * Send a command to the machine
   */
  async sendCommand(command: DecentCommand, data?: Uint8Array): Promise<void> {
    const commandChar = this.characteristics.get('REQUESTED_STATE')

    if (!commandChar) {
      throw new Error('Command characteristic not available')
    }

    const buffer = new Uint8Array(data ? data.length + 1 : 1)
    buffer[0] = command
    if (data) {
      buffer.set(data, 1)
    }

    console.log(`Sending command: ${command}`)
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
  async uploadProfile(_profile: ShotProfile): Promise<void> {
    console.warn('Profile upload not yet implemented - requires full protocol')
    // TODO: Implement profile upload via HEADER_WRITE and FRAME_WRITE characteristics
    // This requires understanding the full profile binary format
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
