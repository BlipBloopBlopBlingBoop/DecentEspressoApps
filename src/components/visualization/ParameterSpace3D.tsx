import React from 'react'
import Plot from 'react-plotly.js'
import { ShotData } from '../../types/decent'
import { GlassCard } from '../ui/GlassCard'

interface ParameterSpace3DProps {
  shots: ShotData[]
  xParam?: 'pressure' | 'temperature' | 'flow' | 'time'
  yParam?: 'pressure' | 'temperature' | 'flow' | 'time'
  zParam?: 'pressure' | 'temperature' | 'flow' | 'time'
  colorByRating?: boolean
}

export const ParameterSpace3D: React.FC<ParameterSpace3DProps> = ({
  shots,
  xParam = 'pressure',
  yParam = 'temperature',
  zParam = 'flow',
  colorByRating = true
}) => {
  const extractParameter = (shot: ShotData, param: string): number[] => {
    switch (param) {
      case 'pressure':
        return shot.dataPoints.map(p => p.pressure)
      case 'temperature':
        return shot.dataPoints.map(p => p.temperature)
      case 'flow':
        return shot.dataPoints.map(p => p.flow)
      case 'time':
        return shot.dataPoints.map(p => p.timestamp / 1000)
      default:
        return []
    }
  }

  const average = (arr: number[]) => arr.reduce((a, b) => a + b, 0) / arr.length

  // Prepare 3D scatter data
  const x: number[] = []
  const y: number[] = []
  const z: number[] = []
  const colors: number[] = []
  const text: string[] = []

  shots.forEach(shot => {
    const xData = extractParameter(shot, xParam)
    const yData = extractParameter(shot, yParam)
    const zData = extractParameter(shot, zParam)

    if (xData.length > 0 && yData.length > 0 && zData.length > 0) {
      x.push(average(xData))
      y.push(average(yData))
      z.push(average(zData))
      colors.push(shot.rating || 3)
      text.push(`
        ${shot.profileName}<br>
        Rating: ${shot.rating || 'N/A'}<br>
        Duration: ${(shot.duration / 1000).toFixed(1)}s<br>
        ${xParam}: ${average(xData).toFixed(2)}<br>
        ${yParam}: ${average(yData).toFixed(2)}<br>
        ${zParam}: ${average(zData).toFixed(2)}
      `)
    }
  })

  const data = [{
    type: 'scatter3d' as const,
    mode: 'markers' as const,
    x,
    y,
    z,
    text,
    hoverinfo: 'text' as const,
    marker: {
      size: 8,
      color: colorByRating ? colors : undefined,
      colorscale: colorByRating ? 'Viridis' : undefined,
      showscale: colorByRating,
      colorbar: colorByRating ? {
        title: { text: 'Rating' },
        thickness: 15,
        len: 0.7,
        tickfont: { color: 'white' }
      } : undefined,
      line: {
        color: 'rgba(255, 255, 255, 0.3)',
        width: 1
      }
    }
  }]

  const layout = {
    paper_bgcolor: 'rgba(0,0,0,0)',
    plot_bgcolor: 'rgba(0,0,0,0)',
    scene: {
      xaxis: {
        title: { text: xParam.charAt(0).toUpperCase() + xParam.slice(1) },
        gridcolor: 'rgba(255, 255, 255, 0.1)',
        color: 'rgba(255, 255, 255, 0.7)'
      },
      yaxis: {
        title: { text: yParam.charAt(0).toUpperCase() + yParam.slice(1) },
        gridcolor: 'rgba(255, 255, 255, 0.1)',
        color: 'rgba(255, 255, 255, 0.7)'
      },
      zaxis: {
        title: { text: zParam.charAt(0).toUpperCase() + zParam.slice(1) },
        gridcolor: 'rgba(255, 255, 255, 0.1)',
        color: 'rgba(255, 255, 255, 0.7)'
      },
      bgcolor: 'rgba(0,0,0,0.3)'
    },
    margin: { l: 0, r: 0, t: 0, b: 0 },
    font: {
      color: 'rgba(255, 255, 255, 0.9)'
    }
  }

  const config = {
    displayModeBar: true,
    displaylogo: false,
    modeBarButtonsToRemove: ['sendDataToCloud', 'autoScale2d'] as any[]
  }

  return (
    <GlassCard className="h-[600px]">
      <div className="mb-4">
        <h3 className="text-xl font-bold text-white mb-2">3D Parameter Space</h3>
        <p className="text-white/60 text-sm">
          Explore the relationship between {xParam}, {yParam}, and {zParam} across your shots
        </p>
      </div>
      <div className="h-[500px]">
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

export default ParameterSpace3D
