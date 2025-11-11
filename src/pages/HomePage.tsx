import { useState, useEffect } from 'react'
import { useMachineStore } from '../stores/machineStore'
import { useShotStore } from '../stores/shotStore'
import { useRecipeStore } from '../stores/recipeStore'
import { bluetoothService } from '../services/bluetoothService'
import { demoService } from '../services/demoService'
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
  time: number
  temperature: number
  pressure: number
  flow: number
  targetTemp: number
  targetPressure: number
}

export default function HomePage() {
  const { state, isActive } = useMachineStore()
  const { activeRecipe } = useRecipeStore()
  const { isRecording } = useShotStore()
  const [historicalData, setHistoricalData] = useState<DataPoint[]>([])
  const [timeRange, setTimeRange] = useState(60) // seconds
  const isDemoMode = demoService.isActive()

  // Update historical data
  useEffect(() => {
    if (!state) return

    const now = Date.now()
    const newPoint: DataPoint = {
      time: now,
      temperature: state.temperature.mix,
      pressure: state.pressure,
      flow: state.flow,
      targetTemp: state.temperature.target,
      targetPressure: 9.0, // Default target pressure
    }

    setHistoricalData((prev) => {
      const cutoff = now - timeRange * 1000
      const filtered = prev.filter((p) => p.time > cutoff)
      return [...filtered, newPoint].slice(-300) // Keep last 300 points
    })
  }, [state, timeRange])

  // Format data for charts
  const chartData = historicalData.map((point, index) => ({
    time: index,
    temperature: point.temperature,
    targetTemp: point.targetTemp,
    pressure: point.pressure,
    flow: point.flow,
  }))

  const handleStartEspresso = async () => {
    try {
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
    } catch (error) {
      console.error('Failed to start espresso:', error)
    }
  }

  const handleStop = async () => {
    try {
      if (isDemoMode) {
        demoService.simulateStop()
        const shotStore = useShotStore.getState()
        if (shotStore.isRecording) {
          shotStore.endShot(state?.weight)
        }
      } else {
        await bluetoothService.stop()
      }
    } catch (error) {
      console.error('Failed to stop:', error)
    }
  }

  const handleStartSteam = async () => {
    try {
      if (isDemoMode) {
        demoService.simulateStartSteam()
      } else {
        await bluetoothService.startSteam()
      }
    } catch (error) {
      console.error('Failed to start steam:', error)
    }
  }

  const handleStartFlush = async () => {
    try {
      if (isDemoMode) {
        demoService.simulateFlush()
      } else {
        await bluetoothService.startFlush()
      }
    } catch (error) {
      console.error('Failed to start flush:', error)
    }
  }

  const handleStartWater = async () => {
    try {
      if (isDemoMode) {
        // Demo not implemented
      } else {
        await bluetoothService.startWater()
      }
    } catch (error) {
      console.error('Failed to start water:', error)
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
      {/* Main Content - Charts */}
      <div className="flex-1 p-4 overflow-y-auto">
        <div className="space-y-4">
          {/* Status Header */}
          <div className="bg-gray-800 rounded-lg p-4">
            <div className="flex items-center justify-between">
              <div>
                <h1 className="text-2xl font-bold text-white mb-1">Live Monitor</h1>
                <p className="text-gray-400 text-sm">
                  Real-time machine parameters and control
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
              label="Temperature"
              value={state.temperature.mix}
              target={state.temperature.target}
              unit="°C"
              color="orange"
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
            <MetricCard
              icon={Activity}
              label="Group Head"
              value={state.temperature.head}
              unit="°C"
              color="purple"
            />
          </div>

          {/* Temperature Chart */}
          <div className="bg-gray-800 rounded-lg p-4">
            <h3 className="text-lg font-semibold text-white mb-3 flex items-center gap-2">
              <Thermometer className="w-5 h-5" />
              Temperature
            </h3>
            <ResponsiveContainer width="100%" height={250}>
              <LineChart data={chartData}>
                <CartesianGrid strokeDasharray="3 3" stroke="#374151" />
                <XAxis
                  dataKey="time"
                  stroke="#9CA3AF"
                  tick={{ fill: '#9CA3AF' }}
                  label={{ value: 'Time', position: 'insideBottom', offset: -5, fill: '#9CA3AF' }}
                />
                <YAxis
                  stroke="#9CA3AF"
                  tick={{ fill: '#9CA3AF' }}
                  label={{ value: '°C', angle: -90, position: 'insideLeft', fill: '#9CA3AF' }}
                  domain={[0, 100]}
                />
                <Tooltip
                  contentStyle={{ backgroundColor: '#1F2937', border: '1px solid #374151' }}
                  labelStyle={{ color: '#9CA3AF' }}
                />
                <Legend />
                <Line
                  type="monotone"
                  dataKey="temperature"
                  stroke="#F97316"
                  strokeWidth={2}
                  dot={false}
                  name="Mix Temp"
                />
                <Line
                  type="monotone"
                  dataKey="targetTemp"
                  stroke="#FB923C"
                  strokeWidth={1}
                  strokeDasharray="5 5"
                  dot={false}
                  name="Target"
                />
              </LineChart>
            </ResponsiveContainer>
          </div>

          {/* Pressure Chart */}
          <div className="bg-gray-800 rounded-lg p-4">
            <h3 className="text-lg font-semibold text-white mb-3 flex items-center gap-2">
              <Gauge className="w-5 h-5" />
              Pressure
            </h3>
            <ResponsiveContainer width="100%" height={250}>
              <LineChart data={chartData}>
                <CartesianGrid strokeDasharray="3 3" stroke="#374151" />
                <XAxis
                  dataKey="time"
                  stroke="#9CA3AF"
                  tick={{ fill: '#9CA3AF' }}
                  label={{ value: 'Time', position: 'insideBottom', offset: -5, fill: '#9CA3AF' }}
                />
                <YAxis
                  stroke="#9CA3AF"
                  tick={{ fill: '#9CA3AF' }}
                  label={{ value: 'bar', angle: -90, position: 'insideLeft', fill: '#9CA3AF' }}
                  domain={[0, 12]}
                />
                <Tooltip
                  contentStyle={{ backgroundColor: '#1F2937', border: '1px solid #374151' }}
                  labelStyle={{ color: '#9CA3AF' }}
                />
                <Legend />
                <Line
                  type="monotone"
                  dataKey="pressure"
                  stroke="#3B82F6"
                  strokeWidth={2}
                  dot={false}
                  name="Pressure"
                />
              </LineChart>
            </ResponsiveContainer>
          </div>

          {/* Flow Chart */}
          <div className="bg-gray-800 rounded-lg p-4">
            <h3 className="text-lg font-semibold text-white mb-3 flex items-center gap-2">
              <Droplets className="w-5 h-5" />
              Flow Rate
            </h3>
            <ResponsiveContainer width="100%" height={250}>
              <LineChart data={chartData}>
                <CartesianGrid strokeDasharray="3 3" stroke="#374151" />
                <XAxis
                  dataKey="time"
                  stroke="#9CA3AF"
                  tick={{ fill: '#9CA3AF' }}
                  label={{ value: 'Time', position: 'insideBottom', offset: -5, fill: '#9CA3AF' }}
                />
                <YAxis
                  stroke="#9CA3AF"
                  tick={{ fill: '#9CA3AF' }}
                  label={{ value: 'ml/s', angle: -90, position: 'insideLeft', fill: '#9CA3AF' }}
                  domain={[0, 6]}
                />
                <Tooltip
                  contentStyle={{ backgroundColor: '#1F2937', border: '1px solid #374151' }}
                  labelStyle={{ color: '#9CA3AF' }}
                />
                <Legend />
                <Line
                  type="monotone"
                  dataKey="flow"
                  stroke="#06B6D4"
                  strokeWidth={2}
                  dot={false}
                  name="Flow Rate"
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
              className="w-full py-4 bg-green-600 hover:bg-green-700 disabled:bg-gray-700 disabled:text-gray-500 text-white rounded-lg font-medium transition-colors flex items-center justify-center gap-2"
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
                onClick={() => {
                  if (isDemoMode) {
                    // Demo
                  } else {
                    bluetoothService.sendCommand(0) // SLEEP
                  }
                }}
                disabled={false}
              />
            </div>
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

          {/* Chart Controls */}
          <div className="bg-gray-800 rounded-lg p-3">
            <h3 className="text-sm font-semibold text-white mb-2">Display</h3>
            <div className="space-y-2">
              <label className="text-xs text-gray-400">Time Range</label>
              <select
                value={timeRange}
                onChange={(e) => setTimeRange(Number(e.target.value))}
                className="w-full bg-gray-700 text-white rounded px-3 py-2 text-sm"
              >
                <option value={30}>30 seconds</option>
                <option value={60}>1 minute</option>
                <option value={120}>2 minutes</option>
                <option value={300}>5 minutes</option>
              </select>
            </div>
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
      className="py-3 bg-gray-700 hover:bg-gray-600 disabled:bg-gray-800 disabled:text-gray-600 text-white rounded-lg text-sm font-medium transition-colors flex flex-col items-center justify-center gap-1"
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
