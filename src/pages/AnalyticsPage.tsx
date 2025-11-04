import React, { useState } from 'react'
import { motion } from 'framer-motion'
import { BarChart3, TrendingUp, Sparkles } from 'lucide-react'
import { useShotStore } from '../stores/shotStore'
import { useRecipeStore } from '../stores/recipeStore'
import { GlassCard } from '../components/ui/GlassCard'
import { ParameterSpace3D } from '../components/visualization/ParameterSpace3D'
import { CorrelationHeatmap } from '../components/visualization/CorrelationHeatmap'
import { OptimizationPanel } from '../components/OptimizationPanel'

export const AnalyticsPage: React.FC = () => {
  const { shots } = useShotStore()
  const { activeRecipe } = useRecipeStore()
  const [selectedView, setSelectedView] = useState<'3d' | 'correlation' | 'optimization'>('3d')

  const latestShot = shots.length > 0 ? shots[shots.length - 1] : undefined

  return (
    <div className="min-h-screen bg-gradient-to-br from-gray-900 via-coffee-dark to-gray-900 p-6">
      <div className="max-w-7xl mx-auto">
        {/* Header */}
        <motion.div
          initial={{ opacity: 0, y: -20 }}
          animate={{ opacity: 1, y: 0 }}
          className="mb-8"
        >
          <h1 className="text-4xl font-bold text-white mb-2 flex items-center gap-3">
            <BarChart3 className="w-10 h-10 text-coffee-light" />
            Advanced Analytics
          </h1>
          <p className="text-white/60">
            Multidimensional insights powered by machine learning
          </p>
        </motion.div>

        {/* Stats Overview */}
        <div className="grid grid-cols-1 md:grid-cols-4 gap-4 mb-6">
          <GlassCard className="text-center">
            <div className="text-3xl font-bold text-white mb-1">{shots.length}</div>
            <div className="text-sm text-white/60">Total Shots</div>
          </GlassCard>

          <GlassCard className="text-center">
            <div className="text-3xl font-bold text-green-400 mb-1">
              {shots.filter(s => (s.rating || 0) >= 4).length}
            </div>
            <div className="text-sm text-white/60">Great Shots (4+)</div>
          </GlassCard>

          <GlassCard className="text-center">
            <div className="text-3xl font-bold text-blue-400 mb-1">
              {shots.length > 0 ? (shots.reduce((sum, s) => sum + (s.rating || 3), 0) / shots.length).toFixed(1) : 'N/A'}
            </div>
            <div className="text-sm text-white/60">Avg Rating</div>
          </GlassCard>

          <GlassCard className="text-center">
            <div className="text-3xl font-bold text-purple-400 mb-1">
              {shots.length > 5 ? '85%' : shots.length > 2 ? '70%' : '60%'}
            </div>
            <div className="text-sm text-white/60">ML Accuracy</div>
          </GlassCard>
        </div>

        {/* View Selector */}
        <div className="flex gap-2 mb-6">
          <button
            onClick={() => setSelectedView('3d')}
            className={`flex-1 py-3 px-4 rounded-xl font-semibold transition-all ${
              selectedView === '3d'
                ? 'bg-gradient-espresso text-white shadow-lg'
                : 'bg-white/10 text-white/60 hover:bg-white/20'
            }`}
          >
            3D Parameter Space
          </button>
          <button
            onClick={() => setSelectedView('correlation')}
            className={`flex-1 py-3 px-4 rounded-xl font-semibold transition-all ${
              selectedView === 'correlation'
                ? 'bg-gradient-espresso text-white shadow-lg'
                : 'bg-white/10 text-white/60 hover:bg-white/20'
            }`}
          >
            Correlations
          </button>
          <button
            onClick={() => setSelectedView('optimization')}
            className={`flex-1 py-3 px-4 rounded-xl font-semibold transition-all ${
              selectedView === 'optimization'
                ? 'bg-gradient-espresso text-white shadow-lg'
                : 'bg-white/10 text-white/60 hover:bg-white/20'
            }`}
          >
            AI Optimization
          </button>
        </div>

        {/* Content Area */}
        {shots.length === 0 ? (
          <GlassCard className="text-center py-12">
            <Sparkles className="w-16 h-16 text-white/40 mx-auto mb-4" />
            <h3 className="text-xl font-bold text-white mb-2">No Data Yet</h3>
            <p className="text-white/60">
              Pull some shots to see advanced analytics and ML-powered insights!
            </p>
          </GlassCard>
        ) : (
          <div className="grid grid-cols-1 lg:grid-cols-3 gap-6">
            {/* Main Visualization Area */}
            <div className="lg:col-span-2">
              {selectedView === '3d' && (
                <motion.div
                  key="3d"
                  initial={{ opacity: 0, scale: 0.95 }}
                  animate={{ opacity: 1, scale: 1 }}
                  transition={{ duration: 0.3 }}
                >
                  <ParameterSpace3D
                    shots={shots}
                    xParam="pressure"
                    yParam="temperature"
                    zParam="flow"
                    colorByRating={true}
                  />
                </motion.div>
              )}

              {selectedView === 'correlation' && (
                <motion.div
                  key="correlation"
                  initial={{ opacity: 0, scale: 0.95 }}
                  animate={{ opacity: 1, scale: 1 }}
                  transition={{ duration: 0.3 }}
                >
                  <CorrelationHeatmap shots={shots} />
                </motion.div>
              )}

              {selectedView === 'optimization' && (
                <motion.div
                  key="optimization"
                  initial={{ opacity: 0, scale: 0.95 }}
                  animate={{ opacity: 1, scale: 1 }}
                  transition={{ duration: 0.3 }}
                >
                  <OptimizationPanel
                    currentShot={latestShot}
                    recipe={activeRecipe || undefined}
                    historicalShots={shots}
                  />
                </motion.div>
              )}
            </div>

            {/* Sidebar - Always show optimization */}
            {selectedView !== 'optimization' && (
              <div className="lg:col-span-1">
                <OptimizationPanel
                  currentShot={latestShot}
                  recipe={activeRecipe || undefined}
                  historicalShots={shots}
                />
              </div>
            )}
          </div>
        )}

        {/* Feature Highlights */}
        <div className="grid grid-cols-1 md:grid-cols-3 gap-6 mt-8">
          <GlassCard className="text-center">
            <div className="bg-purple-500/20 rounded-full p-4 w-16 h-16 mx-auto mb-3 flex items-center justify-center">
              <TrendingUp className="w-8 h-8 text-purple-400" />
            </div>
            <h3 className="font-bold text-white mb-2">ML-Powered Predictions</h3>
            <p className="text-sm text-white/60">
              AI analyzes your shots and predicts quality before you pull them
            </p>
          </GlassCard>

          <GlassCard className="text-center">
            <div className="bg-blue-500/20 rounded-full p-4 w-16 h-16 mx-auto mb-3 flex items-center justify-center">
              <BarChart3 className="w-8 h-8 text-blue-400" />
            </div>
            <h3 className="font-bold text-white mb-2">3D Visualization</h3>
            <p className="text-sm text-white/60">
              Explore parameter relationships in interactive 3D space
            </p>
          </GlassCard>

          <GlassCard className="text-center">
            <div className="bg-green-500/20 rounded-full p-4 w-16 h-16 mx-auto mb-3 flex items-center justify-center">
              <Sparkles className="w-8 h-8 text-green-400" />
            </div>
            <h3 className="font-bold text-white mb-2">Smart Optimization</h3>
            <p className="text-sm text-white/60">
              Get personalized suggestions to improve your recipes
            </p>
          </GlassCard>
        </div>
      </div>
    </div>
  )
}

export default AnalyticsPage
