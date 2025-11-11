import { useState } from 'react'
import { useMachineStore } from '../stores/machineStore'
import { useRecipeStore } from '../stores/recipeStore'
import { useShotStore } from '../stores/shotStore'
import { bluetoothService } from '../services/bluetoothService'
import { demoService } from '../services/demoService'
import {
  Play,
  Square,
  Wind,
  Droplets,
  Thermometer,
  Power,
  AlertTriangle,
} from 'lucide-react'

export default function ControlPage() {
  const { state, isActive, settings } = useMachineStore()
  const { activeRecipe } = useRecipeStore()
  const [targetTemp, setTargetTemp] = useState(settings.targetEspressoTemp)
  const [showConfirm, setShowConfirm] = useState<string | null>(null)

  const isDemoMode = demoService.isActive()

  const handleStartEspresso = async () => {
    try {
      if (isDemoMode) {
        // Start shot recording
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
      setShowConfirm(null)
    } catch (error) {
      console.error('Failed to start espresso:', error)
      alert('Failed to start espresso. Please try again.')
    }
  }

  const handleStop = async () => {
    try {
      if (isDemoMode) {
        demoService.simulateStop()
        // End shot recording if active
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
      setShowConfirm(null)
    } catch (error) {
      console.error('Failed to start steam:', error)
      alert('Failed to start steam. Please try again.')
    }
  }

  const handleStartFlush = async () => {
    try {
      if (isDemoMode) {
        demoService.simulateFlush()
      } else {
        await bluetoothService.startFlush()
      }
      setShowConfirm(null)
    } catch (error) {
      console.error('Failed to start flush:', error)
    }
  }

  const handleStartWater = async () => {
    try {
      if (isDemoMode) {
        // Demo water not implemented yet
      } else {
        await bluetoothService.startWater()
      }
      setShowConfirm(null)
    } catch (error) {
      console.error('Failed to start water:', error)
    }
  }

  const handleSetTemperature = async () => {
    try {
      await bluetoothService.setTemperature(targetTemp)
      alert(`Target temperature set to ${targetTemp}°C`)
    } catch (error) {
      console.error('Failed to set temperature:', error)
      alert('Failed to set temperature. Please try again.')
    }
  }

  // Allow espresso from idle, warming, or ready states (machine needs to be warmed up first)
  const canStartEspresso = (state?.state === 'idle' || state?.state === 'warming' || state?.state === 'ready') && !isActive

  return (
    <div className="p-4 space-y-4">
      {/* Header */}
      <div className="bg-gray-800 rounded-lg p-4">
        <h1 className="text-2xl font-bold text-white mb-2">Machine Control</h1>
        <p className="text-gray-400 text-sm">
          Direct control of all machine functions
        </p>
      </div>

      {/* Active Recipe Display */}
      {activeRecipe && (
        <div className="bg-gradient-to-r from-decent-blue/20 to-transparent border border-decent-blue/50 rounded-lg p-4">
          <div className="text-sm text-gray-400 mb-1">Active Recipe</div>
          <div className="text-lg font-semibold text-white">{activeRecipe.name}</div>
          {activeRecipe.description && (
            <div className="text-sm text-gray-300 mt-1">{activeRecipe.description}</div>
          )}
        </div>
      )}

      {/* Primary Controls */}
      <div className="bg-gray-800 rounded-lg p-4 space-y-3">
        <h2 className="font-semibold text-white mb-3">Primary Functions</h2>

        {/* Start Espresso */}
        <button
          onClick={() => setShowConfirm('espresso')}
          disabled={!canStartEspresso}
          className="w-full py-4 bg-green-600 hover:bg-green-700 disabled:bg-gray-700 disabled:text-gray-500 text-white rounded-lg font-medium transition-colors flex items-center justify-center gap-2"
        >
          <Play className="w-5 h-5" />
          {isActive ? 'Brewing in Progress' : 'Start Espresso'}
        </button>

        {/* Stop */}
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
      <div className="bg-gray-800 rounded-lg p-4 space-y-3">
        <h2 className="font-semibold text-white mb-3">Other Functions</h2>

        <div className="grid grid-cols-2 gap-3">
          <ControlButton
            icon={Wind}
            label="Steam"
            onClick={() => setShowConfirm('steam')}
            disabled={isActive}
          />
          <ControlButton
            icon={Droplets}
            label="Flush"
            onClick={handleStartFlush}
            disabled={isActive}
          />
          <ControlButton
            icon={Droplets}
            label="Hot Water"
            onClick={handleStartWater}
            disabled={isActive}
          />
          <ControlButton
            icon={Power}
            label="Sleep Mode"
            onClick={() => setShowConfirm('sleep')}
            disabled={false}
          />
        </div>
      </div>

      {/* Temperature Control */}
      <div className="bg-gray-800 rounded-lg p-4 space-y-4">
        <h2 className="font-semibold text-white flex items-center gap-2">
          <Thermometer className="w-5 h-5" />
          Temperature Control
        </h2>

        <div className="space-y-2">
          <div className="flex justify-between text-sm">
            <span className="text-gray-400">Target Temperature</span>
            <span className="text-white font-medium">{targetTemp}°C</span>
          </div>

          <input
            type="range"
            min="85"
            max="100"
            step="0.5"
            value={targetTemp}
            onChange={(e) => setTargetTemp(parseFloat(e.target.value))}
            className="w-full accent-decent-blue"
          />

          <div className="flex justify-between text-xs text-gray-500">
            <span>85°C</span>
            <span>100°C</span>
          </div>
        </div>

        <button
          onClick={handleSetTemperature}
          className="w-full py-3 bg-decent-blue hover:bg-blue-700 text-white rounded-lg font-medium transition-colors"
        >
          Set Temperature
        </button>
      </div>

      {/* Machine Status */}
      {state && (
        <div className="bg-gray-800 rounded-lg p-4 space-y-2">
          <h2 className="font-semibold text-white mb-3">Current Status</h2>
          <StatusRow label="State" value={state.state.toUpperCase()} />
          <StatusRow label="Temperature" value={`${state.temperature.mix.toFixed(1)}°C`} />
          <StatusRow label="Pressure" value={`${state.pressure.toFixed(1)} bar`} />
          <StatusRow label="Flow" value={`${state.flow.toFixed(1)} ml/s`} />
        </div>
      )}

      {/* Confirmation Dialog */}
      {showConfirm && (
        <ConfirmDialog
          action={showConfirm}
          onConfirm={() => {
            if (showConfirm === 'espresso') handleStartEspresso()
            else if (showConfirm === 'steam') handleStartSteam()
            else if (showConfirm === 'sleep') bluetoothService.sendCommand(6) // SLEEP command
          }}
          onCancel={() => setShowConfirm(null)}
        />
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
      className="py-4 bg-gray-700 hover:bg-gray-600 disabled:bg-gray-900 disabled:text-gray-600 text-white rounded-lg font-medium transition-colors flex flex-col items-center justify-center gap-2"
    >
      <Icon className="w-6 h-6" />
      <span className="text-sm">{label}</span>
    </button>
  )
}

function StatusRow({ label, value }: { label: string; value: string }) {
  return (
    <div className="flex justify-between py-2 border-b border-gray-700 last:border-0">
      <span className="text-gray-400 text-sm">{label}</span>
      <span className="text-white font-medium text-sm">{value}</span>
    </div>
  )
}

interface ConfirmDialogProps {
  action: string
  onConfirm: () => void
  onCancel: () => void
}

function ConfirmDialog({ action, onConfirm, onCancel }: ConfirmDialogProps) {
  const actionLabels: Record<string, { title: string; description: string }> = {
    espresso: {
      title: 'Start Espresso?',
      description: 'This will begin the espresso extraction process.',
    },
    steam: {
      title: 'Start Steam?',
      description: 'The machine will enter steam mode for milk frothing.',
    },
    sleep: {
      title: 'Enter Sleep Mode?',
      description: 'The machine will power down to save energy.',
    },
  }

  const { title, description } = actionLabels[action] || { title: 'Confirm', description: '' }

  return (
    <div className="fixed inset-0 bg-black/80 flex items-center justify-center p-4 z-50">
      <div className="bg-gray-800 rounded-lg p-6 max-w-sm w-full space-y-4">
        <div className="flex items-start gap-3">
          <AlertTriangle className="w-6 h-6 text-yellow-500 flex-shrink-0" />
          <div>
            <h3 className="text-lg font-semibold text-white">{title}</h3>
            <p className="text-gray-400 text-sm mt-1">{description}</p>
          </div>
        </div>

        <div className="flex gap-3">
          <button
            onClick={onCancel}
            className="flex-1 py-3 bg-gray-700 hover:bg-gray-600 text-white rounded-lg font-medium transition-colors"
          >
            Cancel
          </button>
          <button
            onClick={onConfirm}
            className="flex-1 py-3 bg-decent-blue hover:bg-blue-700 text-white rounded-lg font-medium transition-colors"
          >
            Confirm
          </button>
        </div>
      </div>
    </div>
  )
}
