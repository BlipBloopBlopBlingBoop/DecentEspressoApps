import React from 'react'
import Plot from 'react-plotly.js'
import { ShotData } from '../../types/decent'
import { GlassCard } from '../ui/GlassCard'

interface CorrelationHeatmapProps {
  shots: ShotData[]
}

export const CorrelationHeatmap: React.FC<CorrelationHeatmapProps> = ({ shots }) => {
  // Calculate correlation matrix
  const calculateCorrelation = (x: number[], y: number[]): number => {
    const n = Math.min(x.length, y.length)
    if (n === 0) return 0

    const meanX = x.reduce((a, b) => a + b, 0) / n
    const meanY = y.reduce((a, b) => a + b, 0) / n

    let numerator = 0
    let denomX = 0
    let denomY = 0

    for (let i = 0; i < n; i++) {
      const dx = x[i] - meanX
      const dy = y[i] - meanY
      numerator += dx * dy
      denomX += dx * dx
      denomY += dy * dy
    }

    if (denomX === 0 || denomY === 0) return 0
    return numerator / Math.sqrt(denomX * denomY)
  }

  // Extract all data points for each parameter
  const extractAllValues = (param: 'pressure' | 'temperature' | 'flow') => {
    return shots.flatMap(shot => shot.dataPoints.map(p => p[param]))
  }

  const pressure = extractAllValues('pressure')
  const temperature = extractAllValues('temperature')
  const flow = extractAllValues('flow')
  const ratings = shots.flatMap(shot => {
    const rating = shot.rating || 3
    return Array(shot.dataPoints.length).fill(rating)
  })
  const durations = shots.flatMap(shot => {
    const duration = shot.duration / 1000
    return Array(shot.dataPoints.length).fill(duration)
  })

  const params = {
    'Pressure': pressure,
    'Temperature': temperature,
    'Flow': flow,
    'Rating': ratings,
    'Duration': durations
  }

  const paramNames = Object.keys(params)
  const correlationMatrix: number[][] = []

  paramNames.forEach((param1) => {
    const row: number[] = []
    paramNames.forEach((param2) => {
      const corr = calculateCorrelation(
        params[param1 as keyof typeof params],
        params[param2 as keyof typeof params]
      )
      row.push(corr)
    })
    correlationMatrix.push(row)
  })

  const data = [{
    type: 'heatmap' as const,
    z: correlationMatrix,
    x: paramNames,
    y: paramNames,
    colorscale: [
      [0, '#3b82f6'],      // Blue for negative correlation
      [0.5, '#ffffff'],    // White for no correlation
      [1, '#ef4444']       // Red for positive correlation
    ] as [number, string][],
    zmid: 0,
    colorbar: {
      title: { text: 'Correlation' },
      thickness: 15,
      len: 0.7,
      tickfont: { color: 'white' }
    },
    hoverongaps: false,
    hovertemplate: '%{y} vs %{x}<br>Correlation: %{z:.3f}<extra></extra>',
  }]

  // Add annotations for correlation values
  const annotations: any[] = []
  correlationMatrix.forEach((row, i) => {
    row.forEach((value, j) => {
      annotations.push({
        x: paramNames[j],
        y: paramNames[i],
        text: value.toFixed(2),
        showarrow: false,
        font: {
          color: Math.abs(value) > 0.5 ? 'white' : 'black',
          size: 12,
          weight: 'bold'
        }
      })
    })
  })

  const layout = {
    paper_bgcolor: 'rgba(0,0,0,0)',
    plot_bgcolor: 'rgba(0,0,0,0)',
    xaxis: {
      side: 'bottom' as const,
      tickfont: { color: 'white' },
      gridcolor: 'rgba(255, 255, 255, 0.1)'
    },
    yaxis: {
      tickfont: { color: 'white' },
      gridcolor: 'rgba(255, 255, 255, 0.1)'
    },
    annotations,
    margin: { l: 80, r: 80, t: 40, b: 80 },
    font: {
      color: 'rgba(255, 255, 255, 0.9)'
    }
  }

  const config = {
    displayModeBar: true,
    displaylogo: false,
    modeBarButtonsToRemove: ['sendDataToCloud'] as any[]
  }

  return (
    <GlassCard className="h-[500px]">
      <div className="mb-4">
        <h3 className="text-xl font-bold text-white mb-2">Parameter Correlations</h3>
        <p className="text-white/60 text-sm">
          Discover relationships between different shot parameters
        </p>
      </div>
      <div className="h-[400px]">
        <Plot
          data={data}
          layout={layout}
          config={config}
          style={{ width: '100%', height: '100%' }}
          useResizeHandler={true}
        />
      </div>
    </GlassCard>
  )
}

export default CorrelationHeatmap
