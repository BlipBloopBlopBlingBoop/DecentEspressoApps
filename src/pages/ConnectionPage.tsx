import { useState } from 'react'
import { useNavigate } from 'react-router-dom'
import { useConnectionStore } from '../stores/connectionStore'
import { bluetoothService } from '../services/bluetoothService'
import { demoService } from '../services/demoService'
import {
  Wifi,
  AlertCircle,
  Loader2,
  CheckCircle2,
  HelpCircle,
  Bluetooth,
  Beaker,
} from 'lucide-react'

export default function ConnectionPage() {
  const navigate = useNavigate()
  const { connected, connecting, error, deviceName } = useConnectionStore()
  const [showTroubleshooting, setShowTroubleshooting] = useState(false)

  const handleConnect = async () => {
    try {
      await bluetoothService.connect()
      navigate('/dashboard')
    } catch (error) {
      console.error('Connection failed:', error)
    }
  }

  const handleDemoMode = async () => {
    try {
      await demoService.startDemo()
      navigate('/dashboard')
    } catch (error) {
      console.error('Demo mode failed:', error)
    }
  }

  const handleDisconnect = async () => {
    if (demoService.isActive()) {
      demoService.stopDemo()
    } else {
      await bluetoothService.disconnect()
    }
  }

  if (connected) {
    return (
      <div className="flex flex-col items-center justify-center min-h-full p-6">
        <div className="max-w-md w-full space-y-6">
          <div className="text-center">
            <CheckCircle2 className="w-16 h-16 text-green-500 mx-auto mb-4" />
            <h1 className="text-2xl font-bold text-white mb-2">Connected</h1>
            <p className="text-gray-400">{deviceName}</p>
          </div>

          <div className="bg-gray-800 rounded-lg p-6 space-y-4">
            <div className="flex items-center justify-between">
              <span className="text-gray-300">Status</span>
              <span className="text-green-400">Active</span>
            </div>
            <div className="flex items-center justify-between">
              <span className="text-gray-300">Device</span>
              <span className="text-gray-200">{deviceName}</span>
            </div>
          </div>

          <button
            onClick={handleDisconnect}
            className="w-full py-3 bg-red-600 hover:bg-red-700 text-white rounded-lg font-medium transition-colors"
          >
            Disconnect
          </button>
        </div>
      </div>
    )
  }

  return (
    <div className="flex flex-col min-h-full">
      <div className="flex-1 flex flex-col items-center justify-center p-6">
        <div className="max-w-md w-full space-y-6">
          {/* Header */}
          <div className="text-center">
            <Bluetooth className="w-16 h-16 text-decent-blue mx-auto mb-4" />
            <h1 className="text-2xl font-bold text-white mb-2">
              Connect to Decent Machine
            </h1>
            <p className="text-gray-400">
              Make sure your machine is powered on and Bluetooth is enabled
            </p>
          </div>

          {/* Requirements Checklist */}
          <div className="bg-gray-800 rounded-lg p-6 space-y-3">
            <h2 className="font-semibold text-white mb-3">Before connecting:</h2>
            <ChecklistItem text="Machine is powered on" />
            <ChecklistItem text="Machine is in range (within 10 meters)" />
            <ChecklistItem text="Bluetooth is enabled on your device" />
            <ChecklistItem text="No other app is connected to the machine" />
          </div>

          {/* Error Display */}
          {error && (
            <div className="bg-red-900/30 border border-red-800 rounded-lg p-4 flex items-start gap-3">
              <AlertCircle className="w-5 h-5 text-red-500 flex-shrink-0 mt-0.5" />
              <div className="flex-1">
                <p className="text-red-300 text-sm">{error}</p>
              </div>
            </div>
          )}

          {/* Connect Button */}
          <button
            onClick={handleConnect}
            disabled={connecting}
            className="w-full py-4 bg-decent-blue hover:bg-blue-700 disabled:bg-gray-700 disabled:cursor-not-allowed text-white rounded-lg font-medium transition-colors flex items-center justify-center gap-2"
          >
            {connecting ? (
              <>
                <Loader2 className="w-5 h-5 animate-spin" />
                Connecting...
              </>
            ) : (
              <>
                <Wifi className="w-5 h-5" />
                Connect via Bluetooth
              </>
            )}
          </button>

          {/* Demo Mode Button */}
          <button
            onClick={handleDemoMode}
            disabled={connecting}
            className="w-full py-4 bg-purple-600 hover:bg-purple-700 disabled:bg-gray-700 disabled:cursor-not-allowed text-white rounded-lg font-medium transition-colors flex items-center justify-center gap-2"
          >
            <Beaker className="w-5 h-5" />
            Try Demo Mode
          </button>

          {/* Demo Mode Info */}
          <div className="bg-purple-900/20 border border-purple-800 rounded-lg p-3 flex items-start gap-2">
            <Beaker className="w-5 h-5 text-purple-400 flex-shrink-0 mt-0.5" />
            <div className="text-sm text-purple-300">
              <strong>Demo Mode:</strong> Test all features without a physical machine.
              Simulates real espresso extraction with live data.
            </div>
          </div>

          {/* Troubleshooting */}
          <button
            onClick={() => setShowTroubleshooting(!showTroubleshooting)}
            className="w-full py-3 border border-gray-700 hover:border-gray-600 text-gray-300 rounded-lg font-medium transition-colors flex items-center justify-center gap-2"
          >
            <HelpCircle className="w-5 h-5" />
            Troubleshooting
          </button>

          {showTroubleshooting && <TroubleshootingSection />}
        </div>
      </div>
    </div>
  )
}

function ChecklistItem({ text }: { text: string }) {
  return (
    <div className="flex items-center gap-2">
      <div className="w-2 h-2 rounded-full bg-decent-blue" />
      <span className="text-gray-300 text-sm">{text}</span>
    </div>
  )
}

function TroubleshootingSection() {
  const troubleshootingSteps = [
    {
      title: 'Machine not appearing',
      solutions: [
        'Ensure the machine is fully powered on (not in sleep mode)',
        'Move closer to the machine (within 10 meters)',
        'Restart the machine by turning it off and on again',
        'Check if Bluetooth is enabled in your device settings',
      ],
    },
    {
      title: 'Connection fails immediately',
      solutions: [
        'Close any other apps that might be connected to the machine',
        'Restart Bluetooth on your device',
        'Clear browser cache and reload the page',
        'Try using a different browser (Chrome or Edge recommended)',
      ],
    },
    {
      title: 'Web Bluetooth not supported',
      solutions: [
        'Use a supported browser (Chrome, Edge, or Opera)',
        'Update your browser to the latest version',
        'Enable experimental web platform features in chrome://flags',
        'On iOS, use the Bluefy browser app',
      ],
    },
    {
      title: 'Connection drops frequently',
      solutions: [
        'Move closer to the machine',
        'Remove obstacles between your device and the machine',
        'Check for wireless interference from other devices',
        'Ensure your device has sufficient battery',
      ],
    },
  ]

  return (
    <div className="bg-gray-800 rounded-lg p-6 space-y-6">
      <h2 className="font-semibold text-white flex items-center gap-2">
        <HelpCircle className="w-5 h-5" />
        Troubleshooting Guide
      </h2>

      {troubleshootingSteps.map((step, index) => (
        <div key={index} className="space-y-2">
          <h3 className="text-white font-medium text-sm">{step.title}</h3>
          <ul className="space-y-1.5 ml-4">
            {step.solutions.map((solution, sIndex) => (
              <li key={sIndex} className="text-gray-400 text-xs flex gap-2">
                <span className="text-gray-600">•</span>
                <span>{solution}</span>
              </li>
            ))}
          </ul>
        </div>
      ))}

      <div className="pt-4 border-t border-gray-700">
        <p className="text-xs text-gray-500">
          Still having issues? Check that your browser supports Web Bluetooth API.
          Visit{' '}
          <a
            href="https://caniuse.com/web-bluetooth"
            target="_blank"
            rel="noopener noreferrer"
            className="text-decent-blue hover:underline"
          >
            caniuse.com/web-bluetooth
          </a>
          {' '}for compatibility information.
        </p>
      </div>
    </div>
  )
}
