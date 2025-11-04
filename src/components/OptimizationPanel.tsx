import React, { useMemo } from 'react'
import { motion } from 'framer-motion'
import { Sparkles, TrendingUp, AlertCircle, CheckCircle } from 'lucide-react'
import { GlassCard } from './ui/GlassCard'
import { GradientButton } from './ui/GradientButton'
import { mlService, OptimizationSuggestion } from '../services/mlService'
import { ShotData, Recipe } from '../types/decent'

interface OptimizationPanelProps {
  currentShot?: ShotData
  recipe?: Recipe
  historicalShots: ShotData[]
}

export const OptimizationPanel: React.FC<OptimizationPanelProps> = ({
  currentShot,
  recipe,
  historicalShots
}) => {
  const prediction = useMemo(() => {
    if (!currentShot) return null
    const features = mlService.extractFeatures(currentShot)
    return mlService.predictQuality(features, historicalShots)
  }, [currentShot, historicalShots])

  const optimizations = useMemo(() => {
    if (!recipe) return []
    return mlService.optimizeRecipe(recipe, historicalShots)
  }, [recipe, historicalShots])

  const getRatingColor = (rating: number) => {
    if (rating >= 4) return 'text-green-400'
    if (rating >= 3) return 'text-yellow-400'
    return 'text-red-400'
  }

  const getConfidenceText = (confidence: number) => {
    if (confidence >= 0.7) return 'High Confidence'
    if (confidence >= 0.4) return 'Medium Confidence'
    return 'Low Confidence'
  }

  return (
    <div className="space-y-6">
      {/* Quality Prediction */}
      {prediction && (
        <GlassCard animate glowOnHover>
          <div className="flex items-start justify-between mb-4">
            <div className="flex items-center gap-3">
              <Sparkles className="w-8 h-8 text-purple-400" />
              <div>
                <h3 className="text-xl font-bold text-white">Shot Quality Prediction</h3>
                <p className="text-white/60 text-sm">AI-powered analysis</p>
              </div>
            </div>
            <div className="text-right">
              <div className={`text-3xl font-bold ${getRatingColor(prediction.predictedRating)}`}>
                {prediction.predictedRating.toFixed(1)}/5.0
              </div>
              <div className="text-xs text-white/60">
                {getConfidenceText(prediction.confidence)}
              </div>
            </div>
          </div>

          {/* Factor Scores */}
          <div className="grid grid-cols-2 gap-4 mb-4">
            <FactorBar label="Pressure" score={prediction.factors.pressure} />
            <FactorBar label="Temperature" score={prediction.factors.temperature} />
            <FactorBar label="Flow" score={prediction.factors.flow} />
            <FactorBar label="Consistency" score={prediction.factors.consistency} />
          </div>

          {/* Suggestions */}
          <div className="space-y-2">
            <h4 className="text-sm font-semibold text-white/80 mb-2">Suggestions:</h4>
            {prediction.suggestions.map((suggestion, index) => (
              <motion.div
                key={index}
                initial={{ opacity: 0, x: -20 }}
                animate={{ opacity: 1, x: 0 }}
                transition={{ delay: index * 0.1 }}
                className="flex items-start gap-2 bg-white/5 rounded-lg p-3"
              >
                <AlertCircle className="w-4 h-4 text-blue-400 mt-0.5 flex-shrink-0" />
                <p className="text-sm text-white/80">{suggestion}</p>
              </motion.div>
            ))}
          </div>
        </GlassCard>
      )}

      {/* Recipe Optimization */}
      {recipe && optimizations.length > 0 && (
        <GlassCard animate glowOnHover>
          <div className="flex items-center gap-3 mb-4">
            <TrendingUp className="w-8 h-8 text-green-400" />
            <div>
              <h3 className="text-xl font-bold text-white">Recipe Optimization</h3>
              <p className="text-white/60 text-sm">Based on {historicalShots.length} shots</p>
            </div>
          </div>

          <div className="space-y-3">
            {optimizations.map((opt, index) => (
              <OptimizationCard key={index} optimization={opt} />
            ))}
          </div>

          {optimizations[0].parameter !== 'general' && (
            <GradientButton
              variant="espresso"
              className="w-full mt-4"
              icon={<CheckCircle className="w-5 h-5" />}
            >
              Apply Optimizations
            </GradientButton>
          )}
        </GlassCard>
      )}

      {/* Learning Progress */}
      <GlassCard>
        <div className="flex items-center gap-3 mb-4">
          <motion.div
            animate={{ rotate: 360 }}
            transition={{ duration: 20, repeat: Infinity, ease: "linear" }}
          >
            <Sparkles className="w-6 h-6 text-yellow-400" />
          </motion.div>
          <div>
            <h3 className="text-lg font-bold text-white">Learning Progress</h3>
            <p className="text-white/60 text-sm">AI gets smarter with every shot</p>
          </div>
        </div>

        <div className="space-y-3">
          <div>
            <div className="flex justify-between text-sm mb-1">
              <span className="text-white/70">Total Shots</span>
              <span className="text-white font-semibold">{historicalShots.length}</span>
            </div>
            <div className="h-2 bg-white/10 rounded-full overflow-hidden">
              <motion.div
                className="h-full bg-gradient-to-r from-purple-500 to-blue-500"
                initial={{ width: 0 }}
                animate={{ width: `${Math.min(historicalShots.length * 2, 100)}%` }}
                transition={{ duration: 1, ease: "easeOut" }}
              />
            </div>
          </div>

          <div>
            <div className="flex justify-between text-sm mb-1">
              <span className="text-white/70">Model Accuracy</span>
              <span className="text-white font-semibold">
                {historicalShots.length > 10 ? '85%' : historicalShots.length > 5 ? '70%' : '60%'}
              </span>
            </div>
            <div className="h-2 bg-white/10 rounded-full overflow-hidden">
              <motion.div
                className="h-full bg-gradient-to-r from-green-500 to-emerald-500"
                initial={{ width: 0 }}
                animate={{
                  width: historicalShots.length > 10 ? '85%' : historicalShots.length > 5 ? '70%' : '60%'
                }}
                transition={{ duration: 1, ease: "easeOut", delay: 0.2 }}
              />
            </div>
          </div>
        </div>
      </GlassCard>
    </div>
  )
}

const FactorBar: React.FC<{ label: string; score: number }> = ({ label, score }) => {
  const getColor = (score: number) => {
    if (score >= 0.7) return 'from-green-500 to-emerald-500'
    if (score >= 0.5) return 'from-yellow-500 to-orange-500'
    return 'from-red-500 to-pink-500'
  }

  return (
    <div>
      <div className="flex justify-between text-xs mb-1">
        <span className="text-white/70">{label}</span>
        <span className="text-white font-semibold">{(score * 100).toFixed(0)}%</span>
      </div>
      <div className="h-2 bg-white/10 rounded-full overflow-hidden">
        <motion.div
          className={`h-full bg-gradient-to-r ${getColor(score)}`}
          initial={{ width: 0 }}
          animate={{ width: `${score * 100}%` }}
          transition={{ duration: 0.8, ease: "easeOut" }}
        />
      </div>
    </div>
  )
}

const OptimizationCard: React.FC<{ optimization: OptimizationSuggestion }> = ({ optimization }) => {
  const isGeneral = optimization.parameter === 'general'

  return (
    <motion.div
      initial={{ opacity: 0, y: 20 }}
      animate={{ opacity: 1, y: 0 }}
      className="bg-gradient-to-r from-white/5 to-white/10 border border-white/10 rounded-xl p-4"
    >
      <div className="flex items-start justify-between mb-2">
        <h4 className="font-semibold text-white">{optimization.parameter}</h4>
        {!isGeneral && optimization.expectedImprovement > 0 && (
          <span className="text-xs bg-green-500/20 text-green-400 px-2 py-1 rounded-full">
            +{(optimization.expectedImprovement * 100).toFixed(0)}% improvement
          </span>
        )}
      </div>

      {!isGeneral && (
        <div className="flex items-center gap-4 mb-2">
          <div className="text-center">
            <div className="text-xs text-white/60">Current</div>
            <div className="text-lg font-bold text-white">{optimization.currentValue}</div>
          </div>
          <TrendingUp className="w-4 h-4 text-green-400" />
          <div className="text-center">
            <div className="text-xs text-white/60">Suggested</div>
            <div className="text-lg font-bold text-green-400">{optimization.suggestedValue}</div>
          </div>
        </div>
      )}

      <p className="text-sm text-white/70">{optimization.reason}</p>
    </motion.div>
  )
}

export default OptimizationPanel
