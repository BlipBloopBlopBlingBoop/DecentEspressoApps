import { useConnectionStore } from '../stores/connectionStore'
import { useMachineStore } from '../stores/machineStore'
import { Wifi, WifiOff, Thermometer, Gauge } from 'lucide-react'

export default function StatusBar() {
  const { connected, deviceName } = useConnectionStore()
  const { state } = useMachineStore()

  return (
    <header
      className="bg-gray-900 border-b border-gray-800 px-4 py-2"
      role="banner"
      aria-label="Application status bar"
    >
      <div className="flex items-center justify-between">
        {/* Connection Status */}
        <div
          className="flex items-center gap-2"
          role="status"
          aria-live="polite"
          aria-label={connected ? `Connected to ${deviceName}` : 'Not connected to machine'}
        >
          {connected ? (
            <>
              <Wifi className="w-4 h-4 text-green-500" aria-hidden="true" />
              <span className="text-xs text-gray-300">{deviceName}</span>
            </>
          ) : (
            <>
              <WifiOff className="w-4 h-4 text-gray-500" aria-hidden="true" />
              <span className="text-xs text-gray-500">Not connected</span>
            </>
          )}
        </div>

        {/* Machine Status */}
        {connected && state && (
          <div className="flex items-center gap-4" role="region" aria-label="Machine sensors">
            <div
              className="flex items-center gap-1"
              role="status"
              aria-label={`Temperature: ${state.temperature.mix.toFixed(1)} degrees celsius`}
            >
              <Thermometer className="w-4 h-4 text-orange-500" aria-hidden="true" />
              <span className="text-xs text-gray-300">
                {state.temperature.mix.toFixed(1)}°C
              </span>
            </div>
            <div
              className="flex items-center gap-1"
              role="status"
              aria-label={`Pressure: ${state.pressure.toFixed(1)} bar`}
            >
              <Gauge className="w-4 h-4 text-blue-500" aria-hidden="true" />
              <span className="text-xs text-gray-300">
                {state.pressure.toFixed(1)} bar
              </span>
            </div>
          </div>
        )}

        {/* State Badge */}
        {connected && state && (
          <div
            className={`px-2 py-1 rounded text-xs font-medium ${getStateBadgeColor(state.state)}`}
            role="status"
            aria-live="assertive"
            aria-label={`Machine state: ${state.state}`}
          >
            {state.state.toUpperCase()}
          </div>
        )}
      </div>
    </header>
  )
}

function getStateBadgeColor(state: string): string {
  switch (state) {
    case 'brewing':
      return 'bg-green-900 text-green-300'
    case 'ready':
      return 'bg-blue-900 text-blue-300'
    case 'warming':
      return 'bg-yellow-900 text-yellow-300'
    case 'steam':
      return 'bg-orange-900 text-orange-300'
    case 'error':
      return 'bg-red-900 text-red-300'
    default:
      return 'bg-gray-800 text-gray-400'
  }
}
