import { useMachineStore } from '../stores/machineStore'
import { useShotStore } from '../stores/shotStore'
import { Thermometer, Gauge, Droplets, Scale, Activity } from 'lucide-react'
import { formatDuration } from '../utils/formatters'

export default function DashboardPage() {
  const { state, isActive } = useMachineStore()
  const { activeShot, isRecording } = useShotStore()

  if (!state) {
    return (
      <div className="flex items-center justify-center h-full">
        <p className="text-gray-500">Waiting for machine data...</p>
      </div>
    )
  }

  return (
    <div className="p-4 space-y-4">
      {/* Machine State Card */}
      <div className="bg-gray-800 rounded-lg p-6">
        <div className="flex items-center justify-between mb-4">
          <h2 className="text-xl font-bold text-white">Machine Status</h2>
          <div className={`px-3 py-1 rounded-full text-sm font-medium ${
            isActive ? 'bg-green-900 text-green-300' : 'bg-gray-700 text-gray-300'
          }`}>
            {state.state.toUpperCase()}
          </div>
        </div>

        {/* Real-time Metrics Grid */}
        <div className="grid grid-cols-2 gap-4">
          <MetricCard
            icon={Thermometer}
            label="Temperature"
            value={state.temperature.mix.toFixed(1)}
            unit="°C"
            target={state.temperature.target}
            color="orange"
          />
          <MetricCard
            icon={Gauge}
            label="Pressure"
            value={state.pressure.toFixed(1)}
            unit="bar"
            color="blue"
          />
          <MetricCard
            icon={Droplets}
            label="Flow"
            value={state.flow.toFixed(1)}
            unit="ml/s"
            color="cyan"
          />
          <MetricCard
            icon={Scale}
            label="Weight"
            value={state.weight.toFixed(1)}
            unit="g"
            color="purple"
          />
        </div>
      </div>

      {/* Active Shot Card */}
      {isRecording && activeShot && (
        <div className="bg-gradient-to-br from-green-900/50 to-gray-800 rounded-lg p-6 border border-green-800">
          <div className="flex items-center gap-2 mb-4">
            <Activity className="w-5 h-5 text-green-400 animate-pulse" />
            <h2 className="text-xl font-bold text-white">Recording Shot</h2>
          </div>

          <div className="space-y-3">
            <div className="flex justify-between">
              <span className="text-gray-300">Profile:</span>
              <span className="text-white font-medium">{activeShot.profileName}</span>
            </div>
            <div className="flex justify-between">
              <span className="text-gray-300">Duration:</span>
              <span className="text-white font-medium font-mono">
                {formatDuration(activeShot.duration)}
              </span>
            </div>
            <div className="flex justify-between">
              <span className="text-gray-300">Data Points:</span>
              <span className="text-white font-medium">{activeShot.dataPoints.length}</span>
            </div>
          </div>
        </div>
      )}

      {/* Temperature Details */}
      <div className="bg-gray-800 rounded-lg p-6">
        <h3 className="text-lg font-semibold text-white mb-4">Temperature Details</h3>
        <div className="space-y-3">
          <TempBar label="Mix Chamber" current={state.temperature.mix} target={state.temperature.target} />
          <TempBar label="Group Head" current={state.temperature.head} target={state.temperature.target} />
          <TempBar label="Steam" current={state.temperature.steam} target={160} />
        </div>
      </div>

      {/* Quick Stats */}
      <div className="grid grid-cols-3 gap-3">
        <QuickStat label="Uptime" value="2h 34m" />
        <QuickStat label="Shots Today" value="12" />
        <QuickStat label="Water Level" value="Good" />
      </div>
    </div>
  )
}

interface MetricCardProps {
  icon: React.ElementType
  label: string
  value: string
  unit: string
  target?: number
  color: 'orange' | 'blue' | 'cyan' | 'purple'
}

function MetricCard({ icon: Icon, label, value, unit, target, color }: MetricCardProps) {
  const colorClasses = {
    orange: 'text-orange-500 bg-orange-500/10',
    blue: 'text-blue-500 bg-blue-500/10',
    cyan: 'text-cyan-500 bg-cyan-500/10',
    purple: 'text-purple-500 bg-purple-500/10',
  }

  return (
    <div className="bg-gray-900 rounded-lg p-4">
      <div className="flex items-center gap-2 mb-2">
        <Icon className={`w-4 h-4 ${colorClasses[color].split(' ')[0]}`} />
        <span className="text-gray-400 text-sm">{label}</span>
      </div>
      <div className="flex items-baseline gap-1">
        <span className="text-2xl font-bold text-white">{value}</span>
        <span className="text-gray-500 text-sm">{unit}</span>
      </div>
      {target && (
        <div className="text-xs text-gray-500 mt-1">
          Target: {target.toFixed(1)}{unit}
        </div>
      )}
    </div>
  )
}

interface TempBarProps {
  label: string
  current: number
  target: number
}

function TempBar({ label, current, target }: TempBarProps) {
  const percentage = Math.min((current / target) * 100, 100)
  const isNearTarget = Math.abs(current - target) < 2

  return (
    <div>
      <div className="flex justify-between text-sm mb-1">
        <span className="text-gray-300">{label}</span>
        <span className="text-white font-medium">
          {current.toFixed(1)}°C / {target.toFixed(1)}°C
        </span>
      </div>
      <div className="w-full bg-gray-700 rounded-full h-2 overflow-hidden">
        <div
          className={`h-full transition-all duration-300 ${
            isNearTarget ? 'bg-green-500' : 'bg-orange-500'
          }`}
          style={{ width: `${percentage}%` }}
        />
      </div>
    </div>
  )
}

function QuickStat({ label, value }: { label: string; value: string }) {
  return (
    <div className="bg-gray-800 rounded-lg p-3 text-center">
      <div className="text-lg font-bold text-white">{value}</div>
      <div className="text-xs text-gray-400">{label}</div>
    </div>
  )
}
