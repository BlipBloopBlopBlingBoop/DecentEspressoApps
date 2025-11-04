import { useState, useEffect } from 'react'
import { databaseService } from '../services/databaseService'
import {
  Download,
  Upload,
  Database,
  Trash2,
  Info,
  Settings as SettingsIcon,
  AlertTriangle,
} from 'lucide-react'
import { formatFileSize } from '../utils/formatters'
import { useMachineStore } from '../stores/machineStore'

export default function SettingsPage() {
  const { settings, updateSettings } = useMachineStore()
  const [stats, setStats] = useState({
    totalRecipes: 0,
    totalShots: 0,
    favoriteRecipes: 0,
    databaseSize: 0,
  })

  useEffect(() => {
    loadStats()
  }, [])

  const loadStats = async () => {
    const dbStats = await databaseService.getStats()
    setStats(dbStats)
  }

  const handleExport = async () => {
    try {
      const jsonData = await databaseService.exportData()
      const blob = new Blob([jsonData], { type: 'application/json' })
      const url = URL.createObjectURL(blob)
      const a = document.createElement('a')
      a.href = url
      a.download = `decent-espresso-backup-${new Date().toISOString().split('T')[0]}.json`
      document.body.appendChild(a)
      a.click()
      document.body.removeChild(a)
      URL.revokeObjectURL(url)
      alert('Data exported successfully!')
    } catch (error) {
      console.error('Export failed:', error)
      alert('Failed to export data')
    }
  }

  const handleImport = async (event: React.ChangeEvent<HTMLInputElement>) => {
    const file = event.target.files?.[0]
    if (!file) return

    try {
      const text = await file.text()
      const result = await databaseService.importData(text)
      alert(`Import successful!\n${result.recipes} recipes and ${result.shots} shots imported.`)
      await loadStats()
    } catch (error) {
      console.error('Import failed:', error)
      alert('Failed to import data. Please check the file format.')
    }
  }

  const handleClearData = async () => {
    if (
      confirm(
        'Are you sure you want to clear ALL data? This action cannot be undone!\n\nThis will delete:\n- All recipes\n- All shot history\n- All settings'
      )
    ) {
      if (confirm('Really delete everything? This is your last chance!')) {
        await databaseService.clearAllData()
        await loadStats()
        alert('All data has been cleared')
      }
    }
  }

  return (
    <div className="p-4 space-y-4">
      {/* Header */}
      <div className="bg-gray-800 rounded-lg p-4">
        <h1 className="text-2xl font-bold text-white mb-2">Settings</h1>
        <p className="text-gray-400 text-sm">
          Configure your app and manage your data
        </p>
      </div>

      {/* Machine Settings */}
      <div className="bg-gray-800 rounded-lg p-4 space-y-4">
        <h2 className="text-lg font-semibold text-white flex items-center gap-2">
          <SettingsIcon className="w-5 h-5" />
          Machine Settings
        </h2>

        <div className="space-y-3">
          <SettingRow
            label="Target Espresso Temperature"
            value={`${settings.targetEspressoTemp}°C`}
          >
            <input
              type="range"
              min="85"
              max="100"
              step="0.5"
              value={settings.targetEspressoTemp}
              onChange={(e) =>
                updateSettings({ targetEspressoTemp: parseFloat(e.target.value) })
              }
              className="w-full accent-decent-blue"
            />
          </SettingRow>

          <SettingRow
            label="Target Steam Temperature"
            value={`${settings.targetSteamTemp}°C`}
          >
            <input
              type="range"
              min="130"
              max="170"
              step="5"
              value={settings.targetSteamTemp}
              onChange={(e) =>
                updateSettings({ targetSteamTemp: parseFloat(e.target.value) })
              }
              className="w-full accent-decent-blue"
            />
          </SettingRow>

          <SettingRow label="Sleep Timer" value={`${settings.sleepTime} minutes`}>
            <input
              type="range"
              min="5"
              max="60"
              step="5"
              value={settings.sleepTime}
              onChange={(e) =>
                updateSettings({ sleepTime: parseInt(e.target.value) })
              }
              className="w-full accent-decent-blue"
            />
          </SettingRow>

          <SettingRow label="Units">
            <select
              value={settings.units}
              onChange={(e) =>
                updateSettings({ units: e.target.value as 'metric' | 'imperial' })
              }
              className="px-3 py-2 bg-gray-900 border border-gray-700 rounded-lg text-white focus:outline-none focus:border-decent-blue"
            >
              <option value="metric">Metric</option>
              <option value="imperial">Imperial</option>
            </select>
          </SettingRow>
        </div>
      </div>

      {/* Database Statistics */}
      <div className="bg-gray-800 rounded-lg p-4 space-y-3">
        <h2 className="text-lg font-semibold text-white flex items-center gap-2">
          <Database className="w-5 h-5" />
          Database Statistics
        </h2>

        <div className="grid grid-cols-2 gap-3">
          <StatCard label="Total Recipes" value={stats.totalRecipes.toString()} />
          <StatCard label="Total Shots" value={stats.totalShots.toString()} />
          <StatCard label="Favorites" value={stats.favoriteRecipes.toString()} />
          <StatCard label="Database Size" value={formatFileSize(stats.databaseSize)} />
        </div>
      </div>

      {/* Data Management */}
      <div className="bg-gray-800 rounded-lg p-4 space-y-3">
        <h2 className="text-lg font-semibold text-white flex items-center gap-2">
          <Database className="w-5 h-5" />
          Data Management
        </h2>

        <button
          onClick={handleExport}
          className="w-full py-3 bg-decent-blue hover:bg-blue-700 text-white rounded-lg font-medium transition-colors flex items-center justify-center gap-2"
        >
          <Download className="w-5 h-5" />
          Export All Data
        </button>

        <label className="block">
          <input
            type="file"
            accept=".json"
            onChange={handleImport}
            className="hidden"
          />
          <div className="w-full py-3 bg-gray-700 hover:bg-gray-600 text-white rounded-lg font-medium transition-colors flex items-center justify-center gap-2 cursor-pointer">
            <Upload className="w-5 h-5" />
            Import Data
          </div>
        </label>

        <button
          onClick={handleClearData}
          className="w-full py-3 bg-red-900/30 hover:bg-red-900/50 border border-red-800 text-red-400 rounded-lg font-medium transition-colors flex items-center justify-center gap-2"
        >
          <Trash2 className="w-5 h-5" />
          Clear All Data
        </button>

        <div className="bg-yellow-900/20 border border-yellow-800 rounded-lg p-3 flex items-start gap-2">
          <AlertTriangle className="w-5 h-5 text-yellow-500 flex-shrink-0 mt-0.5" />
          <p className="text-yellow-300 text-sm">
            Export your data regularly to prevent data loss. The app stores data
            locally in your browser.
          </p>
        </div>
      </div>

      {/* App Information */}
      <div className="bg-gray-800 rounded-lg p-4 space-y-3">
        <h2 className="text-lg font-semibold text-white flex items-center gap-2">
          <Info className="w-5 h-5" />
          About
        </h2>

        <div className="space-y-2 text-sm">
          <InfoRow label="App Version" value="1.0.0" />
          <InfoRow label="Build" value={new Date().toISOString().split('T')[0]} />
          <InfoRow
            label="Browser"
            value={navigator.userAgent.includes('Chrome') ? 'Chrome' : 'Other'}
          />
          <InfoRow
            label="Bluetooth Support"
            value={'bluetooth' in navigator ? 'Yes' : 'No'}
          />
        </div>

        <div className="pt-3 border-t border-gray-700 text-xs text-gray-500">
          <p className="mb-2">
            Decent Espresso Control - Full-featured control toolkit for Decent
            espresso machines
          </p>
          <p>
            This app uses Web Bluetooth API to communicate with your machine. Make
            sure your browser supports it.
          </p>
        </div>
      </div>

      {/* Support */}
      <div className="bg-gray-800 rounded-lg p-4 space-y-2">
        <h2 className="text-lg font-semibold text-white">Support</h2>
        <p className="text-sm text-gray-400">
          For help and support, please visit the Decent Espresso forums or contact
          support.
        </p>
      </div>
    </div>
  )
}

function SettingRow({
  label,
  value,
  children,
}: {
  label: string
  value?: string
  children?: React.ReactNode
}) {
  return (
    <div className="space-y-2">
      <div className="flex justify-between items-center">
        <span className="text-gray-300 text-sm">{label}</span>
        {value && <span className="text-white font-medium text-sm">{value}</span>}
      </div>
      {children}
    </div>
  )
}

function StatCard({ label, value }: { label: string; value: string }) {
  return (
    <div className="bg-gray-900 rounded-lg p-3 text-center">
      <div className="text-2xl font-bold text-white">{value}</div>
      <div className="text-xs text-gray-400">{label}</div>
    </div>
  )
}

function InfoRow({ label, value }: { label: string; value: string }) {
  return (
    <div className="flex justify-between py-1">
      <span className="text-gray-400">{label}</span>
      <span className="text-white font-medium">{value}</span>
    </div>
  )
}
