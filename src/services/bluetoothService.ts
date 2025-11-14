import {
  DecentMachine,
  DecentCommand,
  MachineState,
  DECENT_SERVICE_UUID,
  DECENT_CHARACTERISTICS,
  ShotProfile,
  ProfileStep,
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
  private gattQueue: Promise<void> = Promise.resolve()
  private readonly GATT_WRITE_DELAY_MS = 50 // Small delay between GATT operations

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

    console.log('[BluetoothService] Initializing default state immediately')
    
    const machineStore = useMachineStore.getState()
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

    if (!stateChar && !shotSampleChar) {
      console.warn('[BluetoothService] No data characteristics available - using default state')
      return
    }

    console.log('[BluetoothService] Waiting for initial machine data...')

    try {
      await this.waitForFirstNotification(5000)
      console.log('[BluetoothService] ✓ Initial machine data received')
    } catch (error) {
      console.warn('[BluetoothService] Timeout waiting for initial data, using default state')
      console.warn('[BluetoothService] Notifications are active - data will arrive shortly')
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
   * Queue a GATT write operation to prevent overlapping operations
   */
  private queueGattOperation<T>(operation: () => Promise<T>): Promise<T> {
    const queued = this.gattQueue.then(
      async () => {
        await new Promise(resolve => setTimeout(resolve, this.GATT_WRITE_DELAY_MS))
        return operation()
      },
      async () => {
        // Ignore previous operation failures and continue with this operation
        await new Promise(resolve => setTimeout(resolve, this.GATT_WRITE_DELAY_MS))
        return operation()
      }
    )
    
    // Update the queue to include this operation
    this.gattQueue = queued.then(() => {}, () => {})
    
    return queued
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

    return this.queueGattOperation(async () => {
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
    })
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
    
    const recipeStore = useRecipeStore.getState()
    const activeRecipe = recipeStore.activeRecipe

    if (activeRecipe) {
      console.log('[BluetoothService] Active recipe found:', activeRecipe.name)
      try {
        await this.uploadProfile(activeRecipe)
        console.log('[BluetoothService] ✓ Profile uploaded successfully')
      } catch (error) {
        console.error('[BluetoothService] Failed to upload profile, continuing anyway:', error)
      }
    } else {
      console.log('[BluetoothService] No active recipe - using machine default profile')
    }

    await this.sendCommand(DecentCommand.ESPRESSO)

    const shotStore = useShotStore.getState()
    shotStore.startShot({
      profileName: activeRecipe?.name || 'Manual',
      profileId: activeRecipe?.id,
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
   * Set target temperature via MMR protocol
   */
  async setTemperature(temperature: number): Promise<void> {
    console.log(`[BluetoothService] setTemperature(${temperature}) called`)
    await this.writeMMR(0x80, temperature)
    console.log('[BluetoothService] ✓ Temperature set via MMR')
  }

  /**
   * Adjust flow and pressure in real-time during extraction (MMR protocol)
   */
  async adjustFlowPressure(flowAdjust: number, pressureAdjust: number): Promise<void> {
    console.log(`[BluetoothService] adjustFlowPressure(flow=${flowAdjust.toFixed(2)}, pressure=${pressureAdjust.toFixed(2)})`)
    
    await this.writeMMR(0x82, flowAdjust)
    await this.writeMMR(0x83, pressureAdjust)
    
    console.log('[BluetoothService] ✓ Flow/Pressure adjustments sent via MMR')
  }

  /**
   * Estimate extraction time from target weight and flow rate
   * Uses approximation: time ≈ weight / flow, with some buffer for preinfusion and puck resistance
   */
  private estimateTimeFromWeight(targetWeight: number, flowRate: number): number {
    const baseTime = targetWeight / flowRate
    const bufferMultiplier = 1.3
    const estimatedTime = Math.round(baseTime * bufferMultiplier)
    return Math.max(estimatedTime, 15)
  }

  /**
   * Write to Machine Memory Register (MMR)
   */
  private async writeMMR(address: number, value: number): Promise<void> {
    const mmrChar = this.characteristics.get('WRITE_TO_MMR')

    if (!mmrChar) {
      throw new Error('WRITE_TO_MMR characteristic not available')
    }

    return this.queueGattOperation(async () => {
      const buffer = new Uint8Array(5)
      buffer[0] = address
      
      const valueScaled = Math.round(value * 256)
      buffer[1] = (valueScaled >> 24) & 0xFF
      buffer[2] = (valueScaled >> 16) & 0xFF
      buffer[3] = (valueScaled >> 8) & 0xFF
      buffer[4] = valueScaled & 0xFF

      await mmrChar.writeValue(buffer)
    })
  }

  /**
   * Upload a shot profile to the machine using HEADER_WRITE and FRAME_WRITE
   */
  async uploadProfile(profile: ShotProfile): Promise<void> {
    console.log('[BluetoothService] uploadProfile() called for profile:', profile.name)
    
    const headerChar = this.characteristics.get('HEADER_WRITE')
    const frameChar = this.characteristics.get('FRAME_WRITE')

    if (!headerChar || !frameChar) {
      console.error('[BluetoothService] Profile upload characteristics not available')
      throw new Error('Profile upload characteristics (HEADER_WRITE/FRAME_WRITE) not available')
    }

    try {
      const headerData = this.encodeProfileHeader(profile)
      console.log('[BluetoothService] Writing profile header...', headerData)
      
      await this.queueGattOperation(async () => {
        await headerChar.writeValue(headerData)
      })
      console.log('[BluetoothService] ✓ Profile header written')

      for (let i = 0; i < profile.steps.length; i++) {
        const frameData = this.encodeProfileFrame(profile.steps[i], i)
        console.log(`[BluetoothService] Writing frame ${i}...`, frameData)
        
        await this.queueGattOperation(async () => {
          await frameChar.writeValue(frameData)
        })
        console.log(`[BluetoothService] ✓ Frame ${i} written`)
      }

      console.log('[BluetoothService] ✓ Profile upload complete')
    } catch (error) {
      console.error('[BluetoothService] Failed to upload profile:', error)
      throw new Error(`Failed to upload profile: ${error}`)
    }
  }

  /**
   * Encode profile header to binary format (Decent protocol)
   *
   * Based on TCL spec_shotdescheader from binary.tcl:
   * Byte 0: HeaderV (version = 1)
   * Byte 1: NumberOfFrames (total steps)
   * Byte 2: NumberOfPreinfuseFrames (steps before main extraction)
   * Byte 3: MinimumPressure (scaled * 16, for flow priority mode)
   * Byte 4: MaximumFlow (scaled * 16, for pressure priority mode)
   */
  private encodeProfileHeader(profile: ShotProfile): Uint8Array<ArrayBuffer> {
    const buffer = new Uint8Array(new ArrayBuffer(5)) as Uint8Array<ArrayBuffer>

    // Byte 0: Header version (always 1)
    buffer[0] = 0x01

    // Byte 1: Total number of frames/steps
    buffer[1] = profile.steps.length & 0xFF

    // Byte 2: Number of preinfusion frames
    // For now, we consider the first step as preinfusion if it has low pressure/flow
    let preinfuseFrames = 0
    if (profile.steps.length > 0) {
      const firstStep = profile.steps[0]
      if (firstStep.pressure <= 4 && firstStep.flow <= 3) {
        preinfuseFrames = 1
      }
    }
    buffer[2] = preinfuseFrames

    // Byte 3: Minimum pressure (for flow priority mode)
    // Setting to 0 means no minimum constraint
    buffer[3] = 0x00

    // Byte 4: Maximum flow (for pressure priority mode)
    // Set to a safe default of 6 ml/s (scaled * 16 = 96)
    buffer[4] = Math.round(6.0 * 16) & 0xFF

    console.log(`[BluetoothService] Profile header: version=1, frames=${profile.steps.length}, preinfuse=${preinfuseFrames}, minP=0, maxF=6.0ml/s`)

    return buffer
  }

  /**
   * Encode a single profile frame (step) to binary format
   *
   * Based on TCL spec_shotframe from binary.tcl:
   * Byte 0: FrameToWrite (frame number)
   * Byte 1: Flag (frame control flags)
   * Byte 2: SetVal (pressure or flow, scaled * 16)
   * Byte 3: Temp (temperature, scaled * 2)
   * Byte 4: FrameLen (frame duration in F8_1_7 format)
   * Byte 5: TriggerVal (exit condition value, scaled * 16)
   * Bytes 6-7: MaxVol (max volume, 16-bit)
   */
  private encodeProfileFrame(step: ProfileStep, frameNumber: number): Uint8Array<ArrayBuffer> {
    const buffer = new Uint8Array(new ArrayBuffer(8)) as Uint8Array<ArrayBuffer>

    // Byte 0: Frame number
    buffer[0] = frameNumber

    // Byte 1: Frame flag
    // Determine if this is flow control (CtrlF) or pressure control
    // The Decent machine uses EITHER pressure OR flow mode per step, not both
    // We prefer pressure mode unless pressure is 0 and flow is set
    const isFlowControl = step.pressure === 0 && step.flow > 0
    let flag = 0x00

    if (isFlowControl) {
      flag |= 0x01 // CtrlF - Flow priority mode
    }
    // Otherwise, it's pressure mode (CtrlP = 0, default)

    // Add Interpolate flag if smooth transition
    if (step.transition === 'smooth') {
      flag |= 0x20 // Interpolate
    }

    // Always set IgnoreLimit for now (no max pressure/flow constraints)
    flag |= 0x40 // IgnoreLimit

    buffer[1] = flag

    // Byte 2: SetVal (pressure or flow, depending on flag)
    const setVal = isFlowControl ? step.flow : step.pressure
    const setValScaled = Math.round(setVal * 16) & 0xFF
    buffer[2] = setValScaled

    // Byte 3: Temp (temperature in 0.5°C steps)
    buffer[3] = Math.round(step.temperature * 2) & 0xFF

    // Byte 4: FrameLen (duration in F8_1_7 format)
    let frameDuration = step.exit.value
    if (step.exit.type === 'weight') {
      // Convert weight to estimated time
      frameDuration = this.estimateTimeFromWeight(step.exit.value, step.flow)
      console.log(`[BluetoothService] Converting weight ${step.exit.value}g to time ${frameDuration}s for frame ${frameNumber}`)
    }
    buffer[4] = this.convertToF8_1_7(frameDuration)

    console.log(`[BluetoothService] Frame ${frameNumber}: ${isFlowControl ? 'FLOW' : 'PRESSURE'} mode, SetVal=${setVal.toFixed(2)} (0x${setValScaled.toString(16).padStart(2, '0')}), Temp=${step.temperature}°C, Duration=${frameDuration}s`)

    // Byte 5: TriggerVal (exit condition trigger value)
    // For now, we use time-based exits, so this is mostly unused
    buffer[5] = 0x00

    // Bytes 6-7: MaxVol (maximum volume for this step, 16-bit)
    // Setting to 0 means no volume limit
    buffer[6] = 0x00
    buffer[7] = 0x00

    return buffer
  }

  /**
   * Convert a float time value to F8_1_7 format
   *
   * F8_1_7 is a special 8-bit floating point format used by Decent:
   * - If value < 12.75: multiply by 10 (gives 0.1 second resolution)
   * - If value >= 12.75: use value directly with bit 7 set (1 second resolution)
   *
   * Based on convert_float_to_F8_1_7 from binary.tcl
   */
  private convertToF8_1_7(value: number): number {
    if (value >= 12.75) {
      // For values >= 12.75 seconds, use integer seconds with high bit set
      const intVal = Math.round(value)
      if (intVal > 127) {
        console.warn(`[BluetoothService] Frame duration ${value}s exceeds maximum 127s, capping at 127s`)
        return 127 | 128
      }
      return intVal | 128 // Set bit 7 to indicate integer mode
    } else {
      // For values < 12.75 seconds, use 0.1 second resolution
      return Math.round(value * 10) & 0x7F
    }
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
