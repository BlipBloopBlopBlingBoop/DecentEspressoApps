import React, { useState } from 'react'
import { motion, Reorder } from 'framer-motion'
import { Plus, Trash2, GripVertical, Save, Sparkles } from 'lucide-react'
import { ProfileStep, Recipe, ExitCondition } from '../types/decent'
import { GlassCard } from './ui/GlassCard'
import { GradientButton } from './ui/GradientButton'
import { Line } from 'react-chartjs-2'

interface RecipeBuilderProps {
  recipe?: Recipe
  onSave: (recipe: Recipe) => void
  onCancel: () => void
}

export const RecipeBuilder: React.FC<RecipeBuilderProps> = ({
  recipe,
  onSave,
  onCancel
}) => {
  const [name, setName] = useState(recipe?.name || '')
  const [description, setDescription] = useState(recipe?.description || '')
  const [steps, setSteps] = useState<ProfileStep[]>(recipe?.steps || [
    {
      name: 'Pre-infusion',
      temperature: 93,
      pressure: 2,
      flow: 2,
      transition: 'smooth',
      exit: { type: 'time', value: 5 }
    }
  ])
  const [metadata, setMetadata] = useState(recipe?.metadata || {})

  const addStep = () => {
    const newStep: ProfileStep = {
      name: `Step ${steps.length + 1}`,
      temperature: 93,
      pressure: 9,
      flow: 2.5,
      transition: 'smooth',
      exit: { type: 'time', value: 10 }
    }
    setSteps([...steps, newStep])
  }

  const deleteStep = (index: number) => {
    setSteps(steps.filter((_, i) => i !== index))
  }

  const updateStep = (index: number, updates: Partial<ProfileStep>) => {
    setSteps(steps.map((step, i) => i === index ? { ...step, ...updates } : step))
  }

  const handleSave = () => {
    const newRecipe: Recipe = {
      id: recipe?.id || `recipe-${Date.now()}`,
      name,
      description,
      steps,
      metadata,
      createdAt: recipe?.createdAt || Date.now(),
      updatedAt: Date.now(),
      author: recipe?.author || 'User',
      favorite: recipe?.favorite || false,
      usageCount: recipe?.usageCount || 0
    }
    onSave(newRecipe)
  }

  // Generate preview chart data
  const getChartData = () => {
    let time = 0
    const pressureData: number[] = []
    const flowData: number[] = []
    const timeLabels: number[] = []

    steps.forEach(step => {
      const duration = step.exit.type === 'time' ? step.exit.value : 10
      for (let i = 0; i <= duration; i++) {
        timeLabels.push(time + i)
        pressureData.push(step.pressure)
        flowData.push(step.flow)
      }
      time += duration
    })

    return {
      labels: timeLabels,
      datasets: [
        {
          label: 'Pressure (bar)',
          data: pressureData,
          borderColor: 'rgb(239, 68, 68)',
          backgroundColor: 'rgba(239, 68, 68, 0.1)',
          yAxisID: 'y',
        },
        {
          label: 'Flow (ml/s)',
          data: flowData,
          borderColor: 'rgb(59, 130, 246)',
          backgroundColor: 'rgba(59, 130, 246, 0.1)',
          yAxisID: 'y1',
        }
      ]
    }
  }

  const chartOptions = {
    responsive: true,
    maintainAspectRatio: false,
    interaction: {
      mode: 'index' as const,
      intersect: false,
    },
    scales: {
      y: {
        type: 'linear' as const,
        position: 'left' as const,
        title: {
          display: true,
          text: 'Pressure (bar)',
          color: 'rgb(239, 68, 68)'
        },
        grid: {
          color: 'rgba(255, 255, 255, 0.1)'
        },
        ticks: { color: 'rgba(255, 255, 255, 0.7)' }
      },
      y1: {
        type: 'linear' as const,
        position: 'right' as const,
        title: {
          display: true,
          text: 'Flow (ml/s)',
          color: 'rgb(59, 130, 246)'
        },
        grid: {
          drawOnChartArea: false,
        },
        ticks: { color: 'rgba(255, 255, 255, 0.7)' }
      },
      x: {
        title: {
          display: true,
          text: 'Time (s)',
          color: 'rgba(255, 255, 255, 0.7)'
        },
        grid: {
          color: 'rgba(255, 255, 255, 0.1)'
        },
        ticks: { color: 'rgba(255, 255, 255, 0.7)' }
      }
    },
    plugins: {
      legend: {
        labels: {
          color: 'rgba(255, 255, 255, 0.9)'
        }
      }
    }
  }

  return (
    <div className="max-w-6xl mx-auto p-6 space-y-6">
      <GlassCard>
        <div className="flex items-center justify-between mb-6">
          <h2 className="text-3xl font-bold text-white flex items-center gap-2">
            <Sparkles className="w-8 h-8 text-coffee-light" />
            Recipe Builder
          </h2>
          <div className="flex gap-2">
            <button
              onClick={onCancel}
              className="px-4 py-2 bg-gray-600 hover:bg-gray-700 text-white rounded-lg transition"
            >
              Cancel
            </button>
            <GradientButton
              onClick={handleSave}
              variant="espresso"
              icon={<Save className="w-5 h-5" />}
            >
              Save Recipe
            </GradientButton>
          </div>
        </div>

        {/* Basic Info */}
        <div className="grid grid-cols-1 md:grid-cols-2 gap-4 mb-6">
          <div>
            <label className="block text-sm font-medium text-white/80 mb-2">
              Recipe Name
            </label>
            <input
              type="text"
              value={name}
              onChange={(e) => setName(e.target.value)}
              className="w-full bg-white/10 border border-white/20 rounded-lg px-4 py-2 text-white"
              placeholder="My Espresso Recipe"
            />
          </div>
          <div>
            <label className="block text-sm font-medium text-white/80 mb-2">
              Coffee Type
            </label>
            <input
              type="text"
              value={metadata.coffee || ''}
              onChange={(e) => setMetadata({ ...metadata, coffee: e.target.value })}
              className="w-full bg-white/10 border border-white/20 rounded-lg px-4 py-2 text-white"
              placeholder="e.g., Ethiopian Yirgacheffe"
            />
          </div>
        </div>

        <div className="mb-6">
          <label className="block text-sm font-medium text-white/80 mb-2">
            Description
          </label>
          <textarea
            value={description}
            onChange={(e) => setDescription(e.target.value)}
            className="w-full bg-white/10 border border-white/20 rounded-lg px-4 py-2 text-white"
            rows={3}
            placeholder="Describe your recipe..."
          />
        </div>

        {/* Preview Chart */}
        <div className="mb-6 h-64 bg-black/30 rounded-xl p-4">
          <Line data={getChartData()} options={chartOptions} />
        </div>
      </GlassCard>

      {/* Steps Editor */}
      <GlassCard>
        <div className="flex items-center justify-between mb-4">
          <h3 className="text-xl font-bold text-white">Profile Steps</h3>
          <GradientButton
            onClick={addStep}
            variant="primary"
            size="sm"
            icon={<Plus className="w-4 h-4" />}
          >
            Add Step
          </GradientButton>
        </div>

        <Reorder.Group axis="y" values={steps} onReorder={setSteps} className="space-y-4">
          {steps.map((step, index) => (
            <Reorder.Item key={index} value={step}>
              <StepEditor
                step={step}
                index={index}
                onUpdate={(updates) => updateStep(index, updates)}
                onDelete={() => deleteStep(index)}
              />
            </Reorder.Item>
          ))}
        </Reorder.Group>
      </GlassCard>
    </div>
  )
}

interface StepEditorProps {
  step: ProfileStep
  index: number
  onUpdate: (updates: Partial<ProfileStep>) => void
  onDelete: () => void
}

const StepEditor: React.FC<StepEditorProps> = ({ step, index: _index, onUpdate, onDelete }) => {
  return (
    <motion.div
      initial={{ opacity: 0, y: 20 }}
      animate={{ opacity: 1, y: 0 }}
      exit={{ opacity: 0, y: -20 }}
      className="bg-white/5 border border-white/10 rounded-xl p-4"
    >
      <div className="flex items-start gap-4">
        <div className="cursor-move mt-2">
          <GripVertical className="w-5 h-5 text-white/40" />
        </div>

        <div className="flex-1 grid grid-cols-1 md:grid-cols-4 gap-4">
          <div>
            <label className="block text-xs font-medium text-white/60 mb-1">
              Step Name
            </label>
            <input
              type="text"
              value={step.name}
              onChange={(e) => onUpdate({ name: e.target.value })}
              className="w-full bg-white/10 border border-white/20 rounded px-3 py-1.5 text-white text-sm"
            />
          </div>

          <div>
            <label className="block text-xs font-medium text-white/60 mb-1">
              Temperature (°C)
            </label>
            <input
              type="number"
              value={step.temperature}
              onChange={(e) => onUpdate({ temperature: Number(e.target.value) })}
              className="w-full bg-white/10 border border-white/20 rounded px-3 py-1.5 text-white text-sm"
              min="85"
              max="105"
              step="0.5"
            />
          </div>

          <div>
            <label className="block text-xs font-medium text-white/60 mb-1">
              Pressure (bar)
            </label>
            <input
              type="number"
              value={step.pressure}
              onChange={(e) => onUpdate({ pressure: Number(e.target.value) })}
              className="w-full bg-white/10 border border-white/20 rounded px-3 py-1.5 text-white text-sm"
              min="0"
              max="12"
              step="0.1"
            />
          </div>

          <div>
            <label className="block text-xs font-medium text-white/60 mb-1">
              Flow (ml/s)
            </label>
            <input
              type="number"
              value={step.flow}
              onChange={(e) => onUpdate({ flow: Number(e.target.value) })}
              className="w-full bg-white/10 border border-white/20 rounded px-3 py-1.5 text-white text-sm"
              min="0"
              max="6"
              step="0.1"
            />
          </div>

          <div>
            <label className="block text-xs font-medium text-white/60 mb-1">
              Exit Condition
            </label>
            <select
              value={step.exit.type}
              onChange={(e) => onUpdate({
                exit: { ...step.exit, type: e.target.value as ExitCondition['type'] }
              })}
              className="w-full bg-white/10 border border-white/20 rounded px-3 py-1.5 text-white text-sm"
            >
              <option value="time">Time</option>
              <option value="pressure">Pressure</option>
              <option value="flow">Flow</option>
              <option value="weight">Weight</option>
            </select>
          </div>

          <div>
            <label className="block text-xs font-medium text-white/60 mb-1">
              Exit Value
            </label>
            <input
              type="number"
              value={step.exit.value}
              onChange={(e) => onUpdate({
                exit: { ...step.exit, value: Number(e.target.value) }
              })}
              className="w-full bg-white/10 border border-white/20 rounded px-3 py-1.5 text-white text-sm"
              step="0.1"
            />
          </div>

          <div>
            <label className="block text-xs font-medium text-white/60 mb-1">
              Transition
            </label>
            <select
              value={step.transition}
              onChange={(e) => onUpdate({ transition: e.target.value as 'fast' | 'smooth' })}
              className="w-full bg-white/10 border border-white/20 rounded px-3 py-1.5 text-white text-sm"
            >
              <option value="smooth">Smooth</option>
              <option value="fast">Fast</option>
            </select>
          </div>

          <div className="flex items-end">
            <button
              onClick={onDelete}
              className="w-full bg-red-600 hover:bg-red-700 text-white rounded px-3 py-1.5 text-sm flex items-center justify-center gap-2 transition"
            >
              <Trash2 className="w-4 h-4" />
              Delete
            </button>
          </div>
        </div>
      </div>
    </motion.div>
  )
}

export default RecipeBuilder
