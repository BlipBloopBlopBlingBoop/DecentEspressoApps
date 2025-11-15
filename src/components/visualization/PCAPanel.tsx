import React, { useMemo } from 'react'
import Plot from 'react-plotly.js'
import { ShotData } from '../../types/decent'
import { GlassCard } from '../ui/GlassCard'
import { Sparkles, TrendingUp } from 'lucide-react'

interface PCAPanelProps {
  shots: ShotData[]
}

// Simple PCA implementation
function performPCA(data: number[][]): {
  transformedData: number[][]
  eigenvalues: number[]
  eigenvectors: number[][]
  explainedVariance: number[]
  loadings: { [key: string]: number[] }
  featureNames: string[]
} {
  const n = data.length
  const m = data[0].length

  // Step 1: Standardize the data (mean=0, std=1)
  const means = new Array(m).fill(0)
  const stds = new Array(m).fill(0)

  // Calculate means
  for (let j = 0; j < m; j++) {
    for (let i = 0; i < n; i++) {
      means[j] += data[i][j]
    }
    means[j] /= n
  }

  // Calculate standard deviations
  for (let j = 0; j < m; j++) {
    for (let i = 0; i < n; i++) {
      stds[j] += Math.pow(data[i][j] - means[j], 2)
    }
    stds[j] = Math.sqrt(stds[j] / n)
    if (stds[j] === 0) stds[j] = 1 // Avoid division by zero
  }

  // Standardize data
  const standardizedData = data.map(row =>
    row.map((val, j) => (val - means[j]) / stds[j])
  )

  // Step 2: Calculate covariance matrix
  const covMatrix = Array(m).fill(0).map(() => Array(m).fill(0))
  for (let i = 0; i < m; i++) {
    for (let j = 0; j < m; j++) {
      let sum = 0
      for (let k = 0; k < n; k++) {
        sum += standardizedData[k][i] * standardizedData[k][j]
      }
      covMatrix[i][j] = sum / n
    }
  }

  // Step 3: Compute eigenvalues and eigenvectors using power iteration
  // Simplified: We'll use a basic approach for the first 2 principal components
  const eigenvalues: number[] = []
  const eigenvectors: number[][] = []

  // Power iteration for first eigenvector
  let v = Array(m).fill(1 / Math.sqrt(m))
  for (let iter = 0; iter < 100; iter++) {
    const Av = covMatrix.map(row =>
      row.reduce((sum, val, i) => sum + val * v[i], 0)
    )
    const norm = Math.sqrt(Av.reduce((sum, val) => sum + val * val, 0))
    v = Av.map(val => val / norm)
  }
  eigenvectors.push([...v])
  eigenvalues.push(v.reduce((sum, val, i) =>
    sum + val * covMatrix[i].reduce((s, cval, j) => s + cval * v[j], 0), 0
  ))

  // Deflate matrix and get second eigenvector
  const deflatedCov = covMatrix.map((row, i) =>
    row.map((val, j) =>
      val - eigenvalues[0] * eigenvectors[0][i] * eigenvectors[0][j]
    )
  )

  let v2 = Array(m).fill(1 / Math.sqrt(m))
  for (let iter = 0; iter < 100; iter++) {
    const Av = deflatedCov.map(row =>
      row.reduce((sum, val, i) => sum + val * v2[i], 0)
    )
    const norm = Math.sqrt(Av.reduce((sum, val) => sum + val * val, 0))
    v2 = Av.map(val => val / norm)
  }
  eigenvectors.push([...v2])
  eigenvalues.push(v2.reduce((sum, val, i) =>
    sum + val * deflatedCov[i].reduce((s, cval, j) => s + cval * v2[j], 0), 0
  ))

  // Step 4: Transform data to PC space
  const transformedData = standardizedData.map(row => [
    row.reduce((sum, val, i) => sum + val * eigenvectors[0][i], 0),
    row.reduce((sum, val, i) => sum + val * eigenvectors[1][i], 0)
  ])

  // Step 5: Calculate explained variance
  const totalVariance = eigenvalues.reduce((a, b) => a + b, 0)
  const explainedVariance = eigenvalues.map(ev => (ev / totalVariance) * 100)

  // Feature names
  const featureNames = ['Pressure', 'Temperature', 'Flow', 'Duration']

  // Loadings (correlation between original variables and PCs)
  const loadings: { [key: string]: number[] } = {}
  featureNames.forEach((name, i) => {
    loadings[name] = [
      eigenvectors[0][i] * Math.sqrt(eigenvalues[0]),
      eigenvectors[1][i] * Math.sqrt(eigenvalues[1])
    ]
  })

  return {
    transformedData,
    eigenvalues,
    eigenvectors,
    explainedVariance,
    loadings,
    featureNames
  }
}

export const PCAPanel: React.FC<PCAPanelProps> = ({ shots }) => {
  const pcaResults = useMemo(() => {
    if (shots.length < 3) return null

    // Extract features from shots
    const data = shots.map(shot => {
      const points = shot.dataPoints || []
      if (points.length === 0) return [0, 0, 0, shot.duration]

      const avgPressure = points.reduce((acc, p) => acc + p.pressure, 0) / points.length
      const avgTemp = points.reduce((acc, p) => acc + p.temperature, 0) / points.length
      const avgFlow = points.reduce((acc, p) => acc + p.flow, 0) / points.length

      return [avgPressure, avgTemp, avgFlow, shot.duration]
    })

    return performPCA(data)
  }, [shots])

  if (!pcaResults || shots.length < 3) {
    return (
      <GlassCard className="p-6 text-center">
        <Sparkles className="w-16 h-16 text-white/40 mx-auto mb-4" />
        <h3 className="text-xl font-bold text-white mb-2">Insufficient Data</h3>
        <p className="text-white/60">
          Pull at least 3 shots to see PCA analysis
        </p>
      </GlassCard>
    )
  }

  // Prepare colors based on ratings
  const colors = shots.map(shot => {
    const rating = shot.rating || 3
    if (rating >= 4.5) return '#10B981' // Green for excellent
    if (rating >= 4.0) return '#60A5FA' // Blue for good
    if (rating >= 3.0) return '#F59E0B' // Yellow for average
    return '#EF4444' // Red for poor
  })

  // Scree plot data
  const screePlotData = [
    {
      x: ['PC1', 'PC2'],
      y: pcaResults.explainedVariance,
      type: 'bar' as const,
      marker: {
        color: ['#8B5CF6', '#EC4899'],
        line: { color: '#FFFFFF', width: 1 }
      },
      text: pcaResults.explainedVariance.map(v => `${v.toFixed(1)}%`),
      textposition: 'outside' as const,
      textfont: { color: '#FFFFFF' }
    }
  ]

  const screePlotLayout = {
    title: {
      text: 'Scree Plot: Explained Variance',
      font: { color: '#FFFFFF', size: 18 }
    },
    xaxis: { title: { text: 'Principal Component' }, color: '#FFFFFF', gridcolor: '#374151' },
    yaxis: { title: { text: 'Variance Explained (%)' }, color: '#FFFFFF', gridcolor: '#374151' },
    paper_bgcolor: 'rgba(0,0,0,0)',
    plot_bgcolor: 'rgba(0,0,0,0.2)',
    font: { color: '#FFFFFF' },
    margin: { t: 50, b: 50, l: 60, r: 20 },
    height: 300
  }

  // Biplot data (scores + loadings)
  const pc1 = pcaResults.transformedData.map(d => d[0])
  const pc2 = pcaResults.transformedData.map(d => d[1])

  const biplotData: any[] = [
    {
      x: pc1,
      y: pc2,
      type: 'scatter',
      mode: 'markers',
      name: 'Shots',
      marker: {
        size: 12,
        color: colors,
        line: { color: '#FFFFFF', width: 1 }
      },
      text: shots.map((s, i) => `Shot ${i + 1}<br>Rating: ${s.rating || 'N/A'}`),
      hovertemplate: '%{text}<br>PC1: %{x:.2f}<br>PC2: %{y:.2f}<extra></extra>'
    }
  ]

  // Add loading vectors
  Object.entries(pcaResults.loadings).forEach(([name, [pc1Load, pc2Load]]) => {
    biplotData.push({
      x: [0, pc1Load * 3],
      y: [0, pc2Load * 3],
      type: 'scatter',
      mode: 'lines+text',
      name: name,
      line: { color: '#FBBF24', width: 3 },
      text: ['', name],
      textposition: 'top center',
      textfont: { color: '#FFFFFF', size: 12, family: 'monospace' },
      showlegend: true
    })
  })

  const biplotLayout = {
    title: {
      text: 'PCA Biplot: Scores & Loadings',
      font: { color: '#FFFFFF', size: 18 }
    },
    xaxis: {
      title: { text: `PC1 (${pcaResults.explainedVariance[0].toFixed(1)}%)` },
      color: '#FFFFFF',
      gridcolor: '#374151',
      zeroline: true,
      zerolinecolor: '#6B7280',
      zerolinewidth: 2
    },
    yaxis: {
      title: { text: `PC2 (${pcaResults.explainedVariance[1].toFixed(1)}%)` },
      color: '#FFFFFF',
      gridcolor: '#374151',
      zeroline: true,
      zerolinecolor: '#6B7280',
      zerolinewidth: 2
    },
    paper_bgcolor: 'rgba(0,0,0,0)',
    plot_bgcolor: 'rgba(0,0,0,0.2)',
    font: { color: '#FFFFFF' },
    legend: { font: { color: '#FFFFFF' } },
    margin: { t: 50, b: 50, l: 60, r: 20 },
    height: 500
  }

  return (
    <div className="space-y-6">
      {/* Summary Stats */}
      <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
        <GlassCard className="text-center p-4">
          <TrendingUp className="w-8 h-8 text-purple-400 mx-auto mb-2" />
          <div className="text-2xl font-bold text-white">
            {pcaResults.explainedVariance[0].toFixed(1)}%
          </div>
          <div className="text-xs text-white/60">PC1 Variance</div>
        </GlassCard>

        <GlassCard className="text-center p-4">
          <TrendingUp className="w-8 h-8 text-pink-400 mx-auto mb-2" />
          <div className="text-2xl font-bold text-white">
            {pcaResults.explainedVariance[1].toFixed(1)}%
          </div>
          <div className="text-xs text-white/60">PC2 Variance</div>
        </GlassCard>

        <GlassCard className="text-center p-4">
          <Sparkles className="w-8 h-8 text-blue-400 mx-auto mb-2" />
          <div className="text-2xl font-bold text-white">
            {(pcaResults.explainedVariance[0] + pcaResults.explainedVariance[1]).toFixed(1)}%
          </div>
          <div className="text-xs text-white/60">Total Explained</div>
        </GlassCard>
      </div>

      {/* Scree Plot */}
      <GlassCard className="p-4">
        <Plot
          data={screePlotData}
          layout={screePlotLayout}
          config={{ responsive: true, displayModeBar: false }}
          style={{ width: '100%' }}
        />
      </GlassCard>

      {/* Biplot */}
      <GlassCard className="p-4">
        <Plot
          data={biplotData}
          layout={biplotLayout}
          config={{ responsive: true, displayModeBar: false }}
          style={{ width: '100%' }}
        />
      </GlassCard>

      {/* Loadings Table */}
      <GlassCard className="p-4">
        <h3 className="text-lg font-bold text-white mb-3">Principal Component Loadings</h3>
        <div className="overflow-x-auto">
          <table className="w-full text-sm">
            <thead>
              <tr className="border-b border-white/20">
                <th className="text-left py-2 px-3 text-white/80">Feature</th>
                <th className="text-right py-2 px-3 text-white/80">PC1</th>
                <th className="text-right py-2 px-3 text-white/80">PC2</th>
                <th className="text-left py-2 px-3 text-white/80">Interpretation</th>
              </tr>
            </thead>
            <tbody>
              {Object.entries(pcaResults.loadings).map(([name, [pc1, pc2]]) => (
                <tr key={name} className="border-b border-white/10">
                  <td className="py-2 px-3 text-white font-medium">{name}</td>
                  <td className="py-2 px-3 text-right text-white font-mono">
                    {pc1.toFixed(3)}
                  </td>
                  <td className="py-2 px-3 text-right text-white font-mono">
                    {pc2.toFixed(3)}
                  </td>
                  <td className="py-2 px-3 text-white/60 text-xs">
                    {Math.abs(pc1) > 0.5 ? `Strong PC1 ${pc1 > 0 ? '+' : '-'}` : ''}
                    {Math.abs(pc2) > 0.5 ? ` Strong PC2 ${pc2 > 0 ? '+' : '-'}` : ''}
                    {Math.abs(pc1) < 0.5 && Math.abs(pc2) < 0.5 ? 'Weak contribution' : ''}
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>

        <div className="mt-4 p-3 bg-purple-500/10 border border-purple-500/30 rounded-lg">
          <p className="text-xs text-purple-200">
            <strong>PCA Interpretation:</strong> Arrow direction shows which variables contribute to each PC.
            Arrow length indicates strength. Shots are colored by rating (🟢 Excellent, 🔵 Good, 🟡 Average, 🔴 Poor).
            Use this to identify which parameters drive shot quality.
          </p>
        </div>
      </GlassCard>
    </div>
  )
}
