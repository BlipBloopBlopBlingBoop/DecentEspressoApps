import React, { useState, useMemo } from 'react'
import Plot from 'react-plotly.js'
import { ShotData } from '../../types/decent'
import { GlassCard } from '../ui/GlassCard'
import { Activity, TrendingUp, Target } from 'lucide-react'

interface ControlChartsPanelProps {
  shots: ShotData[]
}

type ChartType = 'xbar-r' | 'i-mr' | 'cusum' | 'ewma'
type Metric = 'pressure' | 'temperature' | 'flow' | 'duration'

export const ControlChartsPanel: React.FC<ControlChartsPanelProps> = ({ shots }) => {
  const [chartType, setChartType] = useState<ChartType>('i-mr')
  const [metric, setMetric] = useState<Metric>('pressure')

  // Extract metric values from shots
  const metricValues = useMemo(() => {
    return shots.map(shot => {
      if (metric === 'duration') {
        return shot.duration
      }
      // Calculate average of metric across all data points
      const points = shot.dataPoints || []
      if (points.length === 0) return 0

      const sum = points.reduce((acc, p) => {
        if (metric === 'pressure') return acc + p.pressure
        if (metric === 'temperature') return acc + p.temperature
        if (metric === 'flow') return acc + p.flow
        return acc
      }, 0)

      return sum / points.length
    })
  }, [shots, metric])

  // Calculate statistics
  const stats = useMemo(() => {
    if (metricValues.length === 0) return null

    const mean = metricValues.reduce((a, b) => a + b, 0) / metricValues.length
    const variance = metricValues.reduce((acc, val) => acc + Math.pow(val - mean, 2), 0) / metricValues.length
    const stdDev = Math.sqrt(variance)

    // Calculate moving range for I-MR chart
    const movingRanges = []
    for (let i = 1; i < metricValues.length; i++) {
      movingRanges.push(Math.abs(metricValues[i] - metricValues[i - 1]))
    }
    const avgMovingRange = movingRanges.length > 0
      ? movingRanges.reduce((a, b) => a + b, 0) / movingRanges.length
      : 0

    // Control limits for I-MR chart (using d2=1.128 for n=2)
    const d2 = 1.128
    const sigma = avgMovingRange / d2
    const UCL = mean + 3 * sigma
    const LCL = mean - 3 * sigma

    // Range control limits
    const D4 = 3.267 // for n=2
    const D3 = 0 // for n=2
    const UCLR = D4 * avgMovingRange
    const LCLR = D3 * avgMovingRange

    // CUSUM
    const cusum = []
    let cumulativeSum = 0
    const k = 0.5 * stdDev // Reference value (typically 0.5σ)
    for (let i = 0; i < metricValues.length; i++) {
      cumulativeSum += (metricValues[i] - mean) - k
      cusum.push(cumulativeSum)
    }

    // EWMA (lambda = 0.2 for moderate sensitivity)
    const lambda = 0.2
    const ewma = [metricValues[0]]
    for (let i = 1; i < metricValues.length; i++) {
      ewma.push(lambda * metricValues[i] + (1 - lambda) * ewma[i - 1])
    }
    const ewmaUCL = mean + 3 * stdDev * Math.sqrt(lambda / (2 - lambda))
    const ewmaLCL = mean - 3 * stdDev * Math.sqrt(lambda / (2 - lambda))

    // Process Capability (assuming target and spec limits)
    const USL = mean + 3 * stdDev // Upper Spec Limit
    const LSL = mean - 3 * stdDev // Lower Spec Limit
    const Cp = (USL - LSL) / (6 * stdDev)
    const Cpk = Math.min((USL - mean) / (3 * stdDev), (mean - LSL) / (3 * stdDev))

    return {
      mean,
      stdDev,
      UCL,
      LCL,
      avgMovingRange,
      UCLR,
      LCLR,
      cusum,
      ewma,
      ewmaUCL,
      ewmaLCL,
      Cp,
      Cpk,
      movingRanges
    }
  }, [metricValues])

  if (!stats || metricValues.length < 2) {
    return (
      <GlassCard className="p-6 text-center">
        <Activity className="w-16 h-16 text-white/40 mx-auto mb-4" />
        <h3 className="text-xl font-bold text-white mb-2">Insufficient Data</h3>
        <p className="text-white/60">
          Pull at least 2 shots to see statistical process control charts
        </p>
      </GlassCard>
    )
  }

  const shotNumbers = Array.from({ length: metricValues.length }, (_, i) => i + 1)

  // Determine which chart to show
  let chartData: any[] = []
  let layout: any = {}

  if (chartType === 'i-mr') {
    // Individual-X and Moving Range Chart
    chartData = [
      {
        x: shotNumbers,
        y: metricValues,
        type: 'scatter',
        mode: 'lines+markers',
        name: 'Individual Values',
        line: { color: '#60A5FA', width: 2 },
        marker: { size: 8, color: '#60A5FA' }
      },
      {
        x: shotNumbers,
        y: Array(metricValues.length).fill(stats.mean),
        type: 'scatter',
        mode: 'lines',
        name: 'Mean',
        line: { color: '#10B981', width: 2, dash: 'dash' }
      },
      {
        x: shotNumbers,
        y: Array(metricValues.length).fill(stats.UCL),
        type: 'scatter',
        mode: 'lines',
        name: 'UCL',
        line: { color: '#EF4444', width: 2, dash: 'dot' }
      },
      {
        x: shotNumbers,
        y: Array(metricValues.length).fill(stats.LCL),
        type: 'scatter',
        mode: 'lines',
        name: 'LCL',
        line: { color: '#EF4444', width: 2, dash: 'dot' }
      }
    ]

    layout = {
      title: {
        text: `I-MR Chart: ${metric.charAt(0).toUpperCase() + metric.slice(1)}`,
        font: { color: '#FFFFFF', size: 18 }
      },
      xaxis: { title: { text: 'Shot Number' }, color: '#FFFFFF', gridcolor: '#374151' },
      yaxis: {
        title: {
          text: metric === 'duration' ? 'Duration (s)' :
                 metric === 'pressure' ? 'Pressure (bar)' :
                 metric === 'temperature' ? 'Temperature (°C)' : 'Flow (ml/s)'
        },
        color: '#FFFFFF',
        gridcolor: '#374151'
      },
      paper_bgcolor: 'rgba(0,0,0,0)',
      plot_bgcolor: 'rgba(0,0,0,0.2)',
      font: { color: '#FFFFFF' },
      legend: { font: { color: '#FFFFFF' } },
      margin: { t: 50, b: 50, l: 60, r: 20 }
    }
  } else if (chartType === 'cusum') {
    // CUSUM Chart
    chartData = [
      {
        x: shotNumbers,
        y: stats.cusum,
        type: 'scatter',
        mode: 'lines+markers',
        name: 'CUSUM',
        line: { color: '#8B5CF6', width: 2 },
        marker: { size: 8, color: '#8B5CF6' }
      },
      {
        x: shotNumbers,
        y: Array(metricValues.length).fill(0),
        type: 'scatter',
        mode: 'lines',
        name: 'Target',
        line: { color: '#10B981', width: 2, dash: 'dash' }
      }
    ]

    layout = {
      title: {
        text: `CUSUM Chart: ${metric.charAt(0).toUpperCase() + metric.slice(1)}`,
        font: { color: '#FFFFFF', size: 18 }
      },
      xaxis: { title: { text: 'Shot Number' }, color: '#FFFFFF', gridcolor: '#374151' },
      yaxis: { title: { text: 'Cumulative Sum' }, color: '#FFFFFF', gridcolor: '#374151' },
      paper_bgcolor: 'rgba(0,0,0,0)',
      plot_bgcolor: 'rgba(0,0,0,0.2)',
      font: { color: '#FFFFFF' },
      legend: { font: { color: '#FFFFFF' } },
      margin: { t: 50, b: 50, l: 60, r: 20 }
    }
  } else if (chartType === 'ewma') {
    // EWMA Chart
    chartData = [
      {
        x: shotNumbers,
        y: stats.ewma,
        type: 'scatter',
        mode: 'lines+markers',
        name: 'EWMA',
        line: { color: '#F59E0B', width: 2 },
        marker: { size: 8, color: '#F59E0B' }
      },
      {
        x: shotNumbers,
        y: Array(metricValues.length).fill(stats.mean),
        type: 'scatter',
        mode: 'lines',
        name: 'Mean',
        line: { color: '#10B981', width: 2, dash: 'dash' }
      },
      {
        x: shotNumbers,
        y: Array(metricValues.length).fill(stats.ewmaUCL),
        type: 'scatter',
        mode: 'lines',
        name: 'UCL',
        line: { color: '#EF4444', width: 2, dash: 'dot' }
      },
      {
        x: shotNumbers,
        y: Array(metricValues.length).fill(stats.ewmaLCL),
        type: 'scatter',
        mode: 'lines',
        name: 'LCL',
        line: { color: '#EF4444', width: 2, dash: 'dot' }
      }
    ]

    layout = {
      title: {
        text: `EWMA Chart: ${metric.charAt(0).toUpperCase() + metric.slice(1)} (λ=0.2)`,
        font: { color: '#FFFFFF', size: 18 }
      },
      xaxis: { title: { text: 'Shot Number' }, color: '#FFFFFF', gridcolor: '#374151' },
      yaxis: {
        title: {
          text: metric === 'duration' ? 'Duration (s)' :
                 metric === 'pressure' ? 'Pressure (bar)' :
                 metric === 'temperature' ? 'Temperature (°C)' : 'Flow (ml/s)'
        },
        color: '#FFFFFF',
        gridcolor: '#374151'
      },
      paper_bgcolor: 'rgba(0,0,0,0)',
      plot_bgcolor: 'rgba(0,0,0,0.2)',
      font: { color: '#FFFFFF' },
      legend: { font: { color: '#FFFFFF' } },
      margin: { t: 50, b: 50, l: 60, r: 20 }
    }
  } else if (chartType === 'xbar-r') {
    // Moving Range Chart (for R in X-bar/R)
    const mrShotNumbers = Array.from({ length: stats.movingRanges.length }, (_, i) => i + 2)

    chartData = [
      {
        x: mrShotNumbers,
        y: stats.movingRanges,
        type: 'scatter',
        mode: 'lines+markers',
        name: 'Moving Range',
        line: { color: '#EC4899', width: 2 },
        marker: { size: 8, color: '#EC4899' }
      },
      {
        x: mrShotNumbers,
        y: Array(stats.movingRanges.length).fill(stats.avgMovingRange),
        type: 'scatter',
        mode: 'lines',
        name: 'R̄',
        line: { color: '#10B981', width: 2, dash: 'dash' }
      },
      {
        x: mrShotNumbers,
        y: Array(stats.movingRanges.length).fill(stats.UCLR),
        type: 'scatter',
        mode: 'lines',
        name: 'UCL',
        line: { color: '#EF4444', width: 2, dash: 'dot' }
      }
    ]

    layout = {
      title: {
        text: `Moving Range Chart: ${metric.charAt(0).toUpperCase() + metric.slice(1)}`,
        font: { color: '#FFFFFF', size: 18 }
      },
      xaxis: { title: { text: 'Shot Number' }, color: '#FFFFFF', gridcolor: '#374151' },
      yaxis: { title: { text: 'Moving Range' }, color: '#FFFFFF', gridcolor: '#374151' },
      paper_bgcolor: 'rgba(0,0,0,0)',
      plot_bgcolor: 'rgba(0,0,0,0.2)',
      font: { color: '#FFFFFF' },
      legend: { font: { color: '#FFFFFF' } },
      margin: { t: 50, b: 50, l: 60, r: 20 }
    }
  }

  return (
    <div className="space-y-6">
      {/* Process Capability Metrics */}
      <div className="grid grid-cols-1 md:grid-cols-4 gap-4">
        <GlassCard className="text-center p-4">
          <Target className="w-8 h-8 text-green-400 mx-auto mb-2" />
          <div className="text-2xl font-bold text-white">{stats.Cp.toFixed(2)}</div>
          <div className="text-xs text-white/60">Cp (Capability)</div>
          <div className="text-xs text-white/40 mt-1">
            {stats.Cp >= 1.33 ? '✓ Capable' : stats.Cp >= 1.0 ? '⚠ Marginal' : '✗ Incapable'}
          </div>
        </GlassCard>

        <GlassCard className="text-center p-4">
          <Target className="w-8 h-8 text-blue-400 mx-auto mb-2" />
          <div className="text-2xl font-bold text-white">{stats.Cpk.toFixed(2)}</div>
          <div className="text-xs text-white/60">Cpk (Centered)</div>
          <div className="text-xs text-white/40 mt-1">
            {stats.Cpk >= 1.33 ? '✓ Capable' : stats.Cpk >= 1.0 ? '⚠ Marginal' : '✗ Incapable'}
          </div>
        </GlassCard>

        <GlassCard className="text-center p-4">
          <TrendingUp className="w-8 h-8 text-purple-400 mx-auto mb-2" />
          <div className="text-2xl font-bold text-white">{stats.mean.toFixed(2)}</div>
          <div className="text-xs text-white/60">Process Mean (μ)</div>
        </GlassCard>

        <GlassCard className="text-center p-4">
          <Activity className="w-8 h-8 text-orange-400 mx-auto mb-2" />
          <div className="text-2xl font-bold text-white">{stats.stdDev.toFixed(3)}</div>
          <div className="text-xs text-white/60">Std Dev (σ)</div>
        </GlassCard>
      </div>

      {/* Controls */}
      <GlassCard className="p-4">
        <div className="grid grid-cols-2 gap-4">
          <div>
            <label className="block text-sm font-medium text-white/80 mb-2">Chart Type</label>
            <select
              value={chartType}
              onChange={(e) => setChartType(e.target.value as ChartType)}
              className="w-full bg-black/30 border border-white/20 rounded-lg px-3 py-2 text-white focus:outline-none focus:ring-2 focus:ring-blue-500"
            >
              <option value="i-mr">I-MR (Individual & Moving Range)</option>
              <option value="xbar-r">X̄-R (Moving Range)</option>
              <option value="cusum">CUSUM (Cumulative Sum)</option>
              <option value="ewma">EWMA (Exponential Weighted)</option>
            </select>
          </div>

          <div>
            <label className="block text-sm font-medium text-white/80 mb-2">Metric</label>
            <select
              value={metric}
              onChange={(e) => setMetric(e.target.value as Metric)}
              className="w-full bg-black/30 border border-white/20 rounded-lg px-3 py-2 text-white focus:outline-none focus:ring-2 focus:ring-blue-500"
            >
              <option value="pressure">Pressure (bar)</option>
              <option value="temperature">Temperature (°C)</option>
              <option value="flow">Flow (ml/s)</option>
              <option value="duration">Shot Duration (s)</option>
            </select>
          </div>
        </div>
      </GlassCard>

      {/* Chart */}
      <GlassCard className="p-4">
        <Plot
          data={chartData}
          layout={layout}
          config={{ responsive: true, displayModeBar: false }}
          style={{ width: '100%', height: '500px' }}
        />
      </GlassCard>

      {/* Statistical Info */}
      <GlassCard className="p-4">
        <h3 className="text-lg font-bold text-white mb-3">Statistical Process Control Info</h3>
        <div className="grid grid-cols-2 md:grid-cols-4 gap-4 text-sm">
          <div>
            <div className="text-white/60">UCL (Upper)</div>
            <div className="text-white font-mono">{stats.UCL.toFixed(3)}</div>
          </div>
          <div>
            <div className="text-white/60">LCL (Lower)</div>
            <div className="text-white font-mono">{stats.LCL.toFixed(3)}</div>
          </div>
          <div>
            <div className="text-white/60">Avg Moving Range</div>
            <div className="text-white font-mono">{stats.avgMovingRange.toFixed(3)}</div>
          </div>
          <div>
            <div className="text-white/60">Sample Size</div>
            <div className="text-white font-mono">{metricValues.length}</div>
          </div>
        </div>
        <div className="mt-4 p-3 bg-blue-500/10 border border-blue-500/30 rounded-lg">
          <p className="text-xs text-blue-200">
            <strong>Pharma-Grade SPC:</strong> Control charts use ±3σ limits based on moving range estimates.
            Cp ≥ 1.33 indicates a capable process. Cpk accounts for centering.
            Points outside control limits indicate special cause variation.
          </p>
        </div>
      </GlassCard>
    </div>
  )
}
