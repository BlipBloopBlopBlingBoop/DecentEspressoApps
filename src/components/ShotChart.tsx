import { Line } from 'react-chartjs-2'
import {
  Chart as ChartJS,
  CategoryScale,
  LinearScale,
  PointElement,
  LineElement,
  Title,
  Tooltip,
  Legend,
  Filler,
} from 'chart.js'
import { ShotDataPoint } from '../types/decent'

ChartJS.register(
  CategoryScale,
  LinearScale,
  PointElement,
  LineElement,
  Title,
  Tooltip,
  Legend,
  Filler
)

interface ShotChartProps {
  data: ShotDataPoint[]
}

export default function ShotChart({ data }: ShotChartProps) {
  if (data.length === 0) {
    return (
      <div className="flex items-center justify-center h-64 text-gray-500">
        No data to display
      </div>
    )
  }

  const chartData = {
    labels: data.map((point) => (point.timestamp / 1000).toFixed(1)),
    datasets: [
      {
        label: 'Pressure (bar)',
        data: data.map((point) => point.pressure),
        borderColor: 'rgb(59, 130, 246)',
        backgroundColor: 'rgba(59, 130, 246, 0.1)',
        tension: 0.4,
        yAxisID: 'y-pressure',
      },
      {
        label: 'Flow (ml/s)',
        data: data.map((point) => point.flow),
        borderColor: 'rgb(34, 211, 238)',
        backgroundColor: 'rgba(34, 211, 238, 0.1)',
        tension: 0.4,
        yAxisID: 'y-flow',
      },
      {
        label: 'Temperature (°C)',
        data: data.map((point) => point.temperature),
        borderColor: 'rgb(251, 146, 60)',
        backgroundColor: 'rgba(251, 146, 60, 0.1)',
        tension: 0.4,
        yAxisID: 'y-temp',
      },
      {
        label: 'Weight (g)',
        data: data.map((point) => point.weight),
        borderColor: 'rgb(168, 85, 247)',
        backgroundColor: 'rgba(168, 85, 247, 0.1)',
        tension: 0.4,
        yAxisID: 'y-weight',
      },
    ],
  }

  const options = {
    responsive: true,
    maintainAspectRatio: false,
    interaction: {
      mode: 'index' as const,
      intersect: false,
    },
    plugins: {
      legend: {
        position: 'top' as const,
        labels: {
          color: '#d1d5db',
          font: {
            size: 11,
          },
          usePointStyle: true,
          padding: 10,
        },
      },
      tooltip: {
        backgroundColor: 'rgba(17, 24, 39, 0.95)',
        titleColor: '#ffffff',
        bodyColor: '#d1d5db',
        borderColor: '#374151',
        borderWidth: 1,
        padding: 12,
        displayColors: true,
        callbacks: {
          label: function (context: any) {
            let label = context.dataset.label || ''
            if (label) {
              label += ': '
            }
            if (context.parsed.y !== null) {
              label += context.parsed.y.toFixed(1)
            }
            return label
          },
        },
      },
    },
    scales: {
      x: {
        display: true,
        title: {
          display: true,
          text: 'Time (seconds)',
          color: '#9ca3af',
        },
        ticks: {
          color: '#9ca3af',
          maxTicksLimit: 10,
        },
        grid: {
          color: 'rgba(75, 85, 99, 0.3)',
        },
      },
      'y-pressure': {
        type: 'linear' as const,
        display: true,
        position: 'left' as const,
        title: {
          display: true,
          text: 'Pressure (bar)',
          color: 'rgb(59, 130, 246)',
        },
        ticks: {
          color: 'rgb(59, 130, 246)',
        },
        grid: {
          color: 'rgba(75, 85, 99, 0.2)',
        },
        min: 0,
        max: 12,
      },
      'y-flow': {
        type: 'linear' as const,
        display: false,
        position: 'left' as const,
        min: 0,
        max: 6,
      },
      'y-temp': {
        type: 'linear' as const,
        display: false,
        position: 'right' as const,
        min: 85,
        max: 100,
      },
      'y-weight': {
        type: 'linear' as const,
        display: false,
        position: 'right' as const,
        min: 0,
      },
    },
  }

  return (
    <div className="h-80">
      <Line data={chartData} options={options} />
    </div>
  )
}
