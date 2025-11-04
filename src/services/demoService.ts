/**
 * Demo Mode Service - Simulates Decent Espresso Machine
 * For testing without a physical machine
 */

import { useMachineStore } from '../stores/machineStore'
import { useConnectionStore } from '../stores/connectionStore'
import { useShotStore } from '../stores/shotStore'
import { MachineState } from '../types/decent'

class DemoService {
  private simulationInterval: number | null = null
  private currentSimulatedState: 'idle' | 'warming' | 'ready' | 'brewing' | 'steam' = 'idle'
  private shotStartTime: number = 0
  private shotElapsedTime: number = 0

  /**
   * Start demo mode
   */
  async startDemo(): Promise<void> {
    const connectionStore = useConnectionStore.getState()

    connectionStore.setConnecting(true)

    // Simulate connection delay
    await new Promise(resolve => setTimeout(resolve, 1500))

    connectionStore.setDeviceName('DE1 (Demo Mode)')
    connectionStore.setConnected(true)
    connectionStore.updateLastConnected()

    // Initialize machine state
    this.initializeSimulatedState()

    // Start simulation loop
    this.startSimulation()
  }

  /**
   * Stop demo mode
   */
  stopDemo(): void {
    if (this.simulationInterval) {
      clearInterval(this.simulationInterval)
      this.simulationInterval = null
    }

    useConnectionStore.getState().reset()
    useMachineStore.getState().reset()
    this.currentSimulatedState = 'idle'
  }

  /**
   * Initialize simulated machine state
   */
  private initializeSimulatedState(): void {
    const machineStore = useMachineStore.getState()

    // Start in warming state
    this.currentSimulatedState = 'warming'

    const initialState: MachineState = {
      state: 'warming',
      substate: '0',
      temperature: {
        mix: 65,
        head: 60,
        steam: 40,
        target: 93,
      },
      pressure: 0,
      flow: 0,
      weight: 0,
      timestamp: Date.now(),
    }

    machineStore.setState(initialState)

    // Warm up to ready over 5 seconds
    setTimeout(() => {
      if (this.currentSimulatedState === 'warming') {
        this.currentSimulatedState = 'ready'
        const readyState = { ...initialState }
        readyState.state = 'ready'
        readyState.temperature.mix = 93
        readyState.temperature.head = 93
        machineStore.setState(readyState)
      }
    }, 5000)
  }

  /**
   * Start simulation loop
   */
  private startSimulation(): void {
    let updateCount = 0

    this.simulationInterval = window.setInterval(() => {
      updateCount++
      this.updateSimulatedState(updateCount)
    }, 100) // 10 Hz update rate
  }

  /**
   * Update simulated machine state
   */
  private updateSimulatedState(tick: number): void {
    const machineStore = useMachineStore.getState()
    const currentState = machineStore.state

    if (!currentState) return

    const newState = { ...currentState }
    newState.timestamp = Date.now()

    // Temperature simulation with slight variations
    const tempVariation = Math.sin(tick * 0.1) * 0.3

    switch (this.currentSimulatedState) {
      case 'warming':
        // Gradual warming
        newState.temperature.mix = Math.min(93, currentState.temperature.mix + 0.5)
        newState.temperature.head = Math.min(93, currentState.temperature.head + 0.5)
        newState.temperature.steam = Math.min(140, currentState.temperature.steam + 0.8)
        break

      case 'ready':
        // Maintain temperature with small variations
        newState.temperature.mix = 93 + tempVariation
        newState.temperature.head = 93 + tempVariation * 0.5
        newState.temperature.steam = 140
        newState.pressure = 0
        newState.flow = 0
        break

      case 'brewing':
        // Simulate espresso extraction
        this.shotElapsedTime = (Date.now() - this.shotStartTime) / 1000

        if (this.shotElapsedTime < 5) {
          // Pre-infusion (0-5s)
          newState.pressure = 2 + Math.sin(this.shotElapsedTime * 2) * 0.3
          newState.flow = 1.5 + Math.sin(this.shotElapsedTime * 3) * 0.2
          newState.weight = this.shotElapsedTime * 0.8
        } else if (this.shotElapsedTime < 10) {
          // Ramp up (5-10s)
          const rampProgress = (this.shotElapsedTime - 5) / 5
          newState.pressure = 2 + rampProgress * 7
          newState.flow = 1.5 + rampProgress * 1.5
          newState.weight = 4 + (this.shotElapsedTime - 5) * 2
        } else if (this.shotElapsedTime < 30) {
          // Main extraction (10-30s)
          newState.pressure = 9 + Math.sin(this.shotElapsedTime) * 0.5
          newState.flow = 2.5 + Math.sin(this.shotElapsedTime * 2) * 0.3
          newState.weight = 14 + (this.shotElapsedTime - 10) * 1.2
        } else {
          // Auto-stop after 30s
          this.stopBrewing()
          return
        }

        newState.temperature.mix = 93 - (this.shotElapsedTime * 0.15) + tempVariation
        newState.temperature.head = 93 - (this.shotElapsedTime * 0.1) + tempVariation

        // Record shot data
        const shotStore = useShotStore.getState()
        if (shotStore.isRecording) {
          shotStore.addDataPoint({
            timestamp: this.shotElapsedTime * 1000,
            temperature: newState.temperature.mix,
            pressure: newState.pressure,
            flow: newState.flow,
            weight: newState.weight,
          })
        }
        break

      case 'steam':
        // Simulate steam mode
        const steamTime = (Date.now() - this.shotStartTime) / 1000
        newState.temperature.steam = Math.min(165, 140 + steamTime * 2)
        newState.temperature.mix = 93 + tempVariation
        newState.temperature.head = 93 + tempVariation
        newState.pressure = 0
        newState.flow = 0
        break
    }

    machineStore.setState(newState)
  }

  /**
   * Simulate starting espresso
   */
  simulateStartEspresso(): void {
    if (this.currentSimulatedState !== 'ready') return

    this.currentSimulatedState = 'brewing'
    this.shotStartTime = Date.now()
    this.shotElapsedTime = 0

    const machineStore = useMachineStore.getState()
    const currentState = machineStore.state
    if (currentState) {
      const brewingState = { ...currentState }
      brewingState.state = 'brewing'
      machineStore.setState(brewingState)
    }
  }

  /**
   * Simulate stopping
   */
  simulateStop(): void {
    if (this.currentSimulatedState === 'brewing') {
      this.stopBrewing()
    } else if (this.currentSimulatedState === 'steam') {
      this.stopSteam()
    }
  }

  /**
   * Stop brewing simulation
   */
  private stopBrewing(): void {
    this.currentSimulatedState = 'ready'

    const machineStore = useMachineStore.getState()
    const currentState = machineStore.state
    if (currentState) {
      const readyState = { ...currentState }
      readyState.state = 'ready'
      readyState.pressure = 0
      readyState.flow = 0
      machineStore.setState(readyState)
    }
  }

  /**
   * Simulate starting steam
   */
  simulateStartSteam(): void {
    if (this.currentSimulatedState !== 'ready') return

    this.currentSimulatedState = 'steam'
    this.shotStartTime = Date.now()

    const machineStore = useMachineStore.getState()
    const currentState = machineStore.state
    if (currentState) {
      const steamState = { ...currentState }
      steamState.state = 'steam'
      machineStore.setState(steamState)
    }
  }

  /**
   * Stop steam simulation
   */
  private stopSteam(): void {
    this.currentSimulatedState = 'ready'

    const machineStore = useMachineStore.getState()
    const currentState = machineStore.state
    if (currentState) {
      const readyState = { ...currentState }
      readyState.state = 'ready'
      readyState.temperature.steam = 140
      machineStore.setState(readyState)
    }
  }

  /**
   * Simulate flush
   */
  simulateFlush(): void {
    // Quick flush simulation
    const machineStore = useMachineStore.getState()
    const currentState = machineStore.state
    if (!currentState) return

    const flushState = { ...currentState }
    flushState.state = 'flush'
    flushState.flow = 6
    machineStore.setState(flushState)

    setTimeout(() => {
      flushState.state = 'ready'
      flushState.flow = 0
      machineStore.setState(flushState)
    }, 3000)
  }

  /**
   * Check if demo mode is active
   */
  isActive(): boolean {
    return this.simulationInterval !== null
  }
}

// Export singleton instance
export const demoService = new DemoService()
