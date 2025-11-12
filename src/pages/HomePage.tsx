import { useState, useEffect } from 'react'
import { useMachineStore } from '../stores/machineStore'
import { useShotStore } from '../stores/shotStore'
import { useRecipeStore } from '../stores/recipeStore'
import { bluetoothService } from '../services/bluetoothService'
import { demoService } from '../services/demoService'
import Joystick from '../components/Joystick'
import {
  LineChart,
  Line,
  XAxis,
  YAxis,
  CartesianGrid,
  Tooltip,
  Legend,
  ResponsiveContainer,
} from 'recharts'
import {
  Play,
  Square,
  Wind,
  Droplets,
  Power,
  Thermometer,
  Gauge,
  Activity,
} from 'lucide-react'

interface DataPoint {
  time: number // seconds since start
  temperature: number
  headTemp: number
  pressure: number
  flow: number
  targetTemp: number
}

export default function HomePage() {
  const { state, isActive } = useMachineStore()
  const { activeRecipe } = useRecipeStore()
  const { isRecording } = useShotStore()
  const [historicalData, setHistoricalData] = useState<DataPoint[]>([])
  const [timeRange, setTimeRange] = useState(60) // seconds
  const [startTime] = useState(Date.now())
  const isDemoMode = demoService.isActive()

  // Update historical data
  useEffect(() => {
    if (!state) return

    const now = Date.now()
    const elapsedSeconds = (now - startTime) / 1000

    const newPoint: DataPoint = {
      time: elapsedSeconds,
      temperature: state.temperature.mix,
      headTemp: state.temperature.head,
      pressure: state.pressure,
      flow: state.flow,
      targetTemp: state.temperature.target,
    }

    setHistoricalData((prev) => {
      // Keep only data within time range
      const cutoffTime = elapsedSeconds - timeRange
      const filtered = prev.filter((p) => p.time > cutoffTime)
      return [...filtered, newPoint].slice(-300) // Keep last 300 points
    })
  }, [state, timeRange, startTime])

  const handleStartEspresso = async () => {
    try {
      console.log('[HomePage] Starting espresso...')
      if (isDemoMode) {
        const shotStore = useShotStore.getState()
        shotStore.startShot({
          profileName: activeRecipe?.name || 'Manual',
          profileId: activeRecipe?.id,
          startTime: Date.now(),
        })
        demoService.simulateStartEspresso()
      } else {
        await bluetoothService.startEspresso()
      }
      console.log('[HomePage] Espresso started successfully')
    } catch (error) {
      console.error('[HomePage] Failed to start espresso:', error)
      alert(`Failed to start espresso: ${error}`)
    }
  }

  const handleStop = async () => {
    try {
      console.log('[HomePage] Stopping...')
      if (isDemoMode) {
        demoService.simulateStop()
        const shotStore = useShotStore.getState()
        if (shotStore.isRecording) {
          shotStore.endShot(state?.weight)
        }
      } else {
        await bluetoothService.stop()
      }
      console.log('[HomePage] Stop command sent successfully')
    } catch (error) {
      console.error('[HomePage] Failed to stop:', error)
      alert(`Failed to stop: ${error}`)
    }
  }

  const handleStartSteam = async () => {
    try {
      console.log('[HomePage] Starting steam...')
      if (isDemoMode) {
        demoService.simulateStartSteam()
      } else {
        await bluetoothService.startSteam()
      }
      console.log('[HomePage] Steam started successfully')
    } catch (error) {
      console.error('[HomePage] Failed to start steam:', error)
      alert(`Failed to start steam: ${error}`)
    }
  }

  const handleStartFlush = async () => {
    try {
      console.log('[HomePage] Starting flush...')
      if (isDemoMode) {
        demoService.simulateFlush()
      } else {
        await bluetoothService.startFlush()
      }
      console.log('[HomePage] Flush started successfully')
    } catch (error) {
      console.error('[HomePage] Failed to start flush:', error)
      alert(`Failed to start flush: ${error}`)
    }
  }

  const handleStartWater = async () => {
    try {
      console.log('[HomePage] Starting hot water...')
      if (isDemoMode) {
        // Demo not implemented
      } else {
        await bluetoothService.startWater()
      }
      console.log('[HomePage] Hot water started successfully')
    } catch (error) {
      console.error('[HomePage] Failed to start water:', error)
      alert(`Failed to start water: ${error}`)
    }
  }

  const handleJoystickUpdate = (flowAdjust: number, pressureAdjust: number) => {
    // flowAdjust: -1 to 1 (left to right)
    // pressureAdjust: -1 to 1 (down to up)
    console.log(`[HomePage] Joystick: Flow ${(flowAdjust * 100).toFixed(0)}%, Pressure ${(pressureAdjust * 100).toFixed(0)}%`)

    // Only send commands if we're actively brewing
    if (state?.state !== 'brewing') {
      return
    }

    // Send live adjustments to machine
    if (isDemoMode) {
      // In demo mode, could simulate the adjustments
      console.log('[HomePage] Demo mode - joystick adjustments simulated')
    } else {
      // Send adjustment commands via Bluetooth
      // Note: This requires MMR protocol implementation
      console.log('[HomePage] Live adjustment - would send via Bluetooth')
      // bluetoothService.adjustFlowPressure(flowAdjust, pressureAdjust)
    }
  }

  if (!state) {
    return (
      <div className="flex items-center justify-center h-full">
        <div className="text-center">
          <Activity className="w-12 h-12 text-gray-500 animate-pulse mx-auto mb-4" />
          <p className="text-gray-500">Waiting for machine data...</p>
        </div>
      </div>
    )
  }

  const canStartEspresso = (state.state === 'idle' || state.state === 'warming' || state.state === 'ready') && !isActive
  const canStartOther = !isActive

  return (
    <div className="flex h-full">
      {/* Main Content - Unified Plot */}
      <div className="flex-1 p-4 overflow-y-auto">
        <div className="space-y-4">
          {/* Status Header */}
          <div className="bg-gray-800 rounded-lg p-4">
            <div className="flex items-center justify-between">
              <div>
                <h1 className="text-2xl font-bold text-white mb-1">Live Monitor</h1>
                <p className="text-gray-400 text-sm">
                  Real-time machine parameters
                </p>
              </div>
              <div className="text-right">
                <div
                  className={`px-4 py-2 rounded-full text-sm font-medium inline-block ${
                    isActive
                      ? 'bg-green-900 text-green-300'
                      : state.state === 'ready'
                      ? 'bg-blue-900 text-blue-300'
                      : 'bg-gray-700 text-gray-300'
                  }`}
                >
                  {state.state.toUpperCase()}
                </div>
                {isRecording && (
                  <div className="mt-2 text-xs text-red-400 flex items-center justify-end gap-1">
                    <div className="w-2 h-2 bg-red-500 rounded-full animate-pulse" />
                    RECORDING
                  </div>
                )}
              </div>
            </div>
          </div>

          {/* Current Values */}
          <div className="grid grid-cols-4 gap-3">
            <MetricCard
              icon={Thermometer}
              label="Mix Temp"
              value={state.temperature.mix}
              target={state.temperature.target}
              unit="°C"
              color="orange"
            />
            <MetricCard
              icon={Thermometer}
              label="Head Temp"
              value={state.temperature.head}
              target={state.temperature.target}
              unit="°C"
              color="purple"
            />
            <MetricCard
              icon={Gauge}
              label="Pressure"
              value={state.pressure}
              target={9.0}
              unit="bar"
              color="blue"
            />
            <MetricCard
              icon={Droplets}
              label="Flow"
              value={state.flow}
              unit="ml/s"
              color="cyan"
            />
          </div>

          {/* Unified Plot with Dual Y-Axes */}
          <div className="bg-gray-800 rounded-lg p-4">
            <div className="flex items-center justify-between mb-3">
              <h3 className="text-lg font-semibold text-white flex items-center gap-2">
                <Activity className="w-5 h-5" />
                All Parameters
              </h3>
              <select
                value={timeRange}
                onChange={(e) => setTimeRange(Number(e.target.value))}
                className="bg-gray-700 text-white rounded px-3 py-1 text-sm"
              >
                <option value={30}>30s</option>
                <option value={60}>1m</option>
                <option value={120}>2m</option>
                <option value={300}>5m</option>
              </select>
            </div>
            <ResponsiveContainer width="100%" height={450}>
              <LineChart data={historicalData}>
                <CartesianGrid strokeDasharray="3 3" stroke="#374151" />

                {/* X-Axis: Time in seconds */}
                <XAxis
                  dataKey="time"
                  stroke="#9CA3AF"
                  tick={{ fill: '#9CA3AF', fontSize: 12 }}
                  label={{ value: 'Time (s)', position: 'insideBottom', offset: -5, fill: '#9CA3AF' }}
                  type="number"
                  domain={['dataMin', 'dataMax']}
                  tickFormatter={(value) => value.toFixed(0)}
                />

                {/* Left Y-Axis: Temperature (°C) */}
                <YAxis
                  yAxisId="temp"
                  stroke="#F97316"
                  tick={{ fill: '#F97316', fontSize: 12 }}
                  label={{ value: 'Temperature (°C)', angle: -90, position: 'insideLeft', fill: '#F97316' }}
                  domain={[0, 100]}
                />

                {/* Right Y-Axis: Pressure (bar) & Flow (ml/s) */}
                <YAxis
                  yAxisId="pressure"
                  orientation="right"
                  stroke="#3B82F6"
                  tick={{ fill: '#3B82F6', fontSize: 12 }}
                  label={{ value: 'Pressure (bar) / Flow (ml/s)', angle: 90, position: 'insideRight', fill: '#3B82F6' }}
                  domain={[0, 12]}
                />

                <Tooltip
                  contentStyle={{ backgroundColor: '#1F2937', border: '1px solid #374151' }}
                  labelStyle={{ color: '#9CA3AF' }}
                  formatter={(value: number) => value.toFixed(2)}
                  labelFormatter={(value) => `${value.toFixed(1)}s`}
                />
                <Legend />

                {/* Temperature Lines */}
                <Line
                  yAxisId="temp"
                  type="monotone"
                  dataKey="temperature"
                  stroke="#F97316"
                  strokeWidth={2}
                  dot={false}
                  name="Mix Temp"
                  isAnimationActive={false}
                />
                <Line
                  yAxisId="temp"
                  type="monotone"
                  dataKey="headTemp"
                  stroke="#A855F7"
                  strokeWidth={2}
                  dot={false}
                  name="Head Temp"
                  isAnimationActive={false}
                />
                <Line
                  yAxisId="temp"
                  type="monotone"
                  dataKey="targetTemp"
                  stroke="#FB923C"
                  strokeWidth={1}
                  strokeDasharray="5 5"
                  dot={false}
                  name="Target"
                  isAnimationActive={false}
                />

                {/* Pressure & Flow Lines */}
                <Line
                  yAxisId="pressure"
                  type="monotone"
                  dataKey="pressure"
                  stroke="#3B82F6"
                  strokeWidth={2}
                  dot={false}
                  name="Pressure"
                  isAnimationActive={false}
                />
                <Line
                  yAxisId="pressure"
                  type="monotone"
                  dataKey="flow"
                  stroke="#06B6D4"
                  strokeWidth={2}
                  dot={false}
                  name="Flow"
                  isAnimationActive={false}
                />
              </LineChart>
            </ResponsiveContainer>
          </div>
        </div>
      </div>

      {/* Side Control Panel */}
      <div className="w-80 bg-gray-900 border-l border-gray-700 p-4 overflow-y-auto">
        <div className="space-y-4">
          <h2 className="text-xl font-bold text-white">Controls</h2>

          {/* Active Recipe */}
          {activeRecipe && (
            <div className="bg-gradient-to-r from-decent-blue/20 to-transparent border border-decent-blue/50 rounded-lg p-3">
              <div className="text-xs text-gray-400 mb-1">Active Recipe</div>
              <div className="text-sm font-semibold text-white">{activeRecipe.name}</div>
            </div>
          )}

          {/* Primary Control */}
          <div className="space-y-2">
            <button
              onClick={handleStartEspresso}
              disabled={!canStartEspresso}
              className="w-full py-4 bg-green-600 hover:bg-green-700 disabled:bg-gray-700 disabled:text-gray-500 disabled:cursor-not-allowed text-white rounded-lg font-medium transition-colors flex items-center justify-center gap-2"
            >
              <Play className="w-5 h-5" />
              Start Espresso
            </button>

            {isActive && (
              <button
                onClick={handleStop}
                className="w-full py-4 bg-red-600 hover:bg-red-700 text-white rounded-lg font-medium transition-colors flex items-center justify-center gap-2"
              >
                <Square className="w-5 h-5" />
                Stop
              </button>
            )}
          </div>

          {/* Secondary Controls */}
          <div className="space-y-2">
            <h3 className="text-sm font-semibold text-gray-400 uppercase tracking-wide">
              Other Functions
            </h3>
            <div className="grid grid-cols-2 gap-2">
              <ControlButton
                icon={Wind}
                label="Steam"
                onClick={handleStartSteam}
                disabled={!canStartOther}
              />
              <ControlButton
                icon={Droplets}
                label="Flush"
                onClick={handleStartFlush}
                disabled={!canStartOther}
              />
              <ControlButton
                icon={Droplets}
                label="Water"
                onClick={handleStartWater}
                disabled={!canStartOther}
              />
              <ControlButton
                icon={Power}
                label="Sleep"
                onClick={async () => {
                  try {
                    console.log('[HomePage] Entering sleep mode...')
                    if (isDemoMode) {
                      // Demo
                    } else {
                      await bluetoothService.sendCommand(0) // SLEEP
                    }
                    console.log('[HomePage] Sleep command sent')
                  } catch (error) {
                    console.error('[HomePage] Failed to enter sleep:', error)
                    alert(`Failed to enter sleep: ${error}`)
                  }
                }}
                disabled={false}
              />
            </div>
          </div>

          {/* Live Control Joystick */}
          <div className="bg-gray-800 rounded-lg p-4">
            <h3 className="text-sm font-semibold text-gray-400 uppercase tracking-wide mb-3">
              Live Control
            </h3>
            <div className="flex justify-center">
              <Joystick
                onUpdate={handleJoystickUpdate}
                size={180}
                disabled={state.state !== 'brewing'}
              />
            </div>
            {state.state !== 'brewing' && (
              <p className="text-xs text-gray-500 text-center mt-3">
                Active only during brewing
              </p>
            )}
          </div>

          {/* Status Details */}
          <div className="bg-gray-800 rounded-lg p-3 space-y-2">
            <h3 className="text-sm font-semibold text-white mb-2">Status</h3>
            <StatusRow label="State" value={state.state.toUpperCase()} />
            <StatusRow label="Mix Temp" value={`${state.temperature.mix.toFixed(1)}°C`} />
            <StatusRow label="Head Temp" value={`${state.temperature.head.toFixed(1)}°C`} />
            <StatusRow label="Steam Temp" value={`${state.temperature.steam}°C`} />
            <StatusRow label="Pressure" value={`${state.pressure.toFixed(2)} bar`} />
            <StatusRow label="Flow" value={`${state.flow.toFixed(2)} ml/s`} />
            <StatusRow label="Weight" value={`${state.weight.toFixed(1)} g`} />
          </div>
        </div>
      </div>
    </div>
  )
}

interface MetricCardProps {
  icon: React.ElementType
  label: string
  value: number
  target?: number
  unit: string
  color: 'orange' | 'blue' | 'cyan' | 'purple'
}

function MetricCard({ icon: Icon, label, value, target, unit, color }: MetricCardProps) {
  const colorClasses = {
    orange: 'text-orange-500 bg-orange-500/10 border-orange-500/20',
    blue: 'text-blue-500 bg-blue-500/10 border-blue-500/20',
    cyan: 'text-cyan-500 bg-cyan-500/10 border-cyan-500/20',
    purple: 'text-purple-500 bg-purple-500/10 border-purple-500/20',
  }

  return (
    <div className={`rounded-lg p-3 border ${colorClasses[color]}`}>
      <div className="flex items-center gap-2 mb-1">
        <Icon className={`w-4 h-4 ${colorClasses[color].split(' ')[0]}`} />
        <span className="text-gray-400 text-xs">{label}</span>
      </div>
      <div className="flex items-baseline gap-1">
        <span className="text-xl font-bold text-white">{value.toFixed(1)}</span>
        <span className="text-gray-500 text-xs">{unit}</span>
      </div>
      {target !== undefined && (
        <div className="text-xs text-gray-500 mt-1">→ {target.toFixed(1)}{unit}</div>
      )}
    </div>
  )
}

interface ControlButtonProps {
  icon: React.ElementType
  label: string
  onClick: () => void
  disabled: boolean
}

function ControlButton({ icon: Icon, label, onClick, disabled }: ControlButtonProps) {
  return (
    <button
      onClick={onClick}
      disabled={disabled}
      className="py-3 bg-gray-700 hover:bg-gray-600 disabled:bg-gray-800 disabled:text-gray-600 disabled:cursor-not-allowed text-white rounded-lg text-sm font-medium transition-colors flex flex-col items-center justify-center gap-1"
    >
      <Icon className="w-5 h-5" />
      <span className="text-xs">{label}</span>
    </button>
  )
}

function StatusRow({ label, value }: { label: string; value: string }) {
  return (
    <div className="flex justify-between text-xs">
      <span className="text-gray-400">{label}</span>
      <span className="text-white font-medium">{value}</span>
    </div>
  )
}
