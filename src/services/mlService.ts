import { ShotData, Recipe, ProfileStep } from '../types/decent'

/**
 * Machine Learning Service for Coffee Optimization
 * Implements basic ML algorithms for shot quality prediction and recipe optimization
 */

export interface ShotFeatures {
  avgPressure: number
  avgTemperature: number
  avgFlow: number
  duration: number
  pressureVariance: number
  temperatureVariance: number
  flowVariance: number
  peakPressure: number
  peakFlow: number
  extractionYield?: number
  brewRatio?: number
}

export interface QualityPrediction {
  predictedRating: number
  confidence: number
  factors: {
    pressure: number
    temperature: number
    flow: number
    consistency: number
  }
  suggestions: string[]
}

export interface OptimizationSuggestion {
  parameter: string
  currentValue: number
  suggestedValue: number
  expectedImprovement: number
  reason: string
}

class MLService {
  /**
   * Extract features from a shot for ML analysis
   */
  extractFeatures(shot: ShotData): ShotFeatures {
    const pressures = shot.dataPoints.map(p => p.pressure)
    const temperatures = shot.dataPoints.map(p => p.temperature)
    const flows = shot.dataPoints.map(p => p.flow)

    const avg = (arr: number[]) => arr.reduce((a, b) => a + b, 0) / arr.length
    const variance = (arr: number[]) => {
      const mean = avg(arr)
      return arr.reduce((sum, val) => sum + Math.pow(val - mean, 2), 0) / arr.length
    }

    return {
      avgPressure: avg(pressures),
      avgTemperature: avg(temperatures),
      avgFlow: avg(flows),
      duration: shot.duration / 1000,
      pressureVariance: variance(pressures),
      temperatureVariance: variance(temperatures),
      flowVariance: variance(flows),
      peakPressure: Math.max(...pressures),
      peakFlow: Math.max(...flows),
      extractionYield: shot.metadata?.yield,
      brewRatio: shot.metadata?.dose && shot.metadata?.yield
        ? shot.metadata.yield / shot.metadata.dose
        : undefined
    }
  }

  /**
   * Predict shot quality based on parameters
   * Uses a simple weighted scoring model
   */
  predictQuality(features: ShotFeatures, historicalShots: ShotData[]): QualityPrediction {
    // Ideal ranges based on coffee science
    const idealPressure = 9.0
    const idealTemperature = 93.0
    const idealFlow = 2.5
    const idealDuration = 28.0

    // Calculate individual factor scores (0-1)
    const pressureScore = 1 - Math.min(Math.abs(features.avgPressure - idealPressure) / 5, 1)
    const temperatureScore = 1 - Math.min(Math.abs(features.avgTemperature - idealTemperature) / 10, 1)
    const flowScore = 1 - Math.min(Math.abs(features.avgFlow - idealFlow) / 3, 1)

    // Consistency score (lower variance is better)
    const consistencyScore = 1 - Math.min(
      (features.pressureVariance + features.temperatureVariance + features.flowVariance) / 10,
      1
    )

    // Duration score
    const durationScore = 1 - Math.min(Math.abs(features.duration - idealDuration) / 20, 1)

    // Weighted overall score
    const overallScore = (
      pressureScore * 0.25 +
      temperatureScore * 0.20 +
      flowScore * 0.20 +
      consistencyScore * 0.20 +
      durationScore * 0.15
    )

    const predictedRating = 1 + overallScore * 4 // Scale to 1-5

    // Generate suggestions
    const suggestions: string[] = []

    if (pressureScore < 0.7) {
      if (features.avgPressure < idealPressure) {
        suggestions.push(`Increase pressure to ~${idealPressure.toFixed(1)} bar for better extraction`)
      } else {
        suggestions.push(`Decrease pressure to ~${idealPressure.toFixed(1)} bar to avoid over-extraction`)
      }
    }

    if (temperatureScore < 0.7) {
      if (features.avgTemperature < idealTemperature) {
        suggestions.push(`Increase temperature to ~${idealTemperature.toFixed(1)}°C for fuller flavor`)
      } else {
        suggestions.push(`Decrease temperature to ~${idealTemperature.toFixed(1)}°C to reduce bitterness`)
      }
    }

    if (flowScore < 0.7) {
      if (features.avgFlow < idealFlow) {
        suggestions.push(`Increase flow rate or grind coarser for better extraction speed`)
      } else {
        suggestions.push(`Decrease flow rate or grind finer to prevent channeling`)
      }
    }

    if (consistencyScore < 0.6) {
      suggestions.push('Reduce parameter variations for more consistent extraction')
    }

    if (durationScore < 0.7) {
      if (features.duration < idealDuration) {
        suggestions.push('Extend shot time by grinding finer or reducing flow')
      } else {
        suggestions.push('Reduce shot time by grinding coarser or increasing flow')
      }
    }

    // Calculate confidence based on historical data similarity
    const confidence = this.calculateConfidence(features, historicalShots)

    return {
      predictedRating,
      confidence,
      factors: {
        pressure: pressureScore,
        temperature: temperatureScore,
        flow: flowScore,
        consistency: consistencyScore
      },
      suggestions: suggestions.length > 0 ? suggestions : ['Parameters look good! Keep experimenting.']
    }
  }

  /**
   * Calculate prediction confidence based on historical data
   */
  private calculateConfidence(features: ShotFeatures, historicalShots: ShotData[]): number {
    if (historicalShots.length === 0) return 0.5

    const historicalFeatures = historicalShots.map(shot => this.extractFeatures(shot))

    // Find most similar historical shots
    const similarities = historicalFeatures.map(hf => {
      const pressureDiff = Math.abs(hf.avgPressure - features.avgPressure)
      const tempDiff = Math.abs(hf.avgTemperature - features.avgTemperature)
      const flowDiff = Math.abs(hf.avgFlow - features.avgFlow)

      // Normalized distance (0 = identical, 1 = very different)
      const distance = (pressureDiff / 10 + tempDiff / 20 + flowDiff / 5) / 3
      return Math.max(0, 1 - distance)
    })

    // Average of top 3 similarities
    const topSimilarities = similarities.sort((a, b) => b - a).slice(0, 3)
    return topSimilarities.reduce((a, b) => a + b, 0) / topSimilarities.length
  }

  /**
   * Generate optimization suggestions for a recipe
   */
  optimizeRecipe(recipe: Recipe, historicalShots: ShotData[]): OptimizationSuggestion[] {
    const suggestions: OptimizationSuggestion[] = []

    // Analyze historical shots for this recipe
    const recipeShots = historicalShots.filter(
      shot => shot.profileId === recipe.id || shot.profileName === recipe.name
    )

    if (recipeShots.length < 3) {
      return [{
        parameter: 'general',
        currentValue: 0,
        suggestedValue: 0,
        expectedImprovement: 0,
        reason: 'Not enough historical data. Pull at least 3 shots to get personalized suggestions.'
      }]
    }

    // Calculate average features and ratings
    const avgRating = recipeShots.reduce((sum, shot) => sum + (shot.rating || 3), 0) / recipeShots.length
    const avgFeatures = this.extractFeatures(recipeShots[0]) // Simplified

    // Analyze each recipe step
    recipe.steps.forEach((step, index) => {
      // Temperature optimization
      if (avgRating < 4 && avgFeatures.avgTemperature !== step.temperature) {
        const optimalTemp = 93 // Based on coffee science
        const tempDiff = Math.abs(step.temperature - optimalTemp)

        if (tempDiff > 2) {
          suggestions.push({
            parameter: `Step ${index + 1} Temperature`,
            currentValue: step.temperature,
            suggestedValue: optimalTemp,
            expectedImprovement: 0.3,
            reason: `Adjust towards optimal extraction temperature (${optimalTemp}°C)`
          })
        }
      }

      // Pressure optimization
      if (avgRating < 4 && step.pressure !== 9) {
        const optimalPressure = 9
        const pressureDiff = Math.abs(step.pressure - optimalPressure)

        if (pressureDiff > 1) {
          suggestions.push({
            parameter: `Step ${index + 1} Pressure`,
            currentValue: step.pressure,
            suggestedValue: optimalPressure,
            expectedImprovement: 0.4,
            reason: 'Adjust to standard espresso pressure for balanced extraction'
          })
        }
      }

      // Flow optimization
      if (step.flow < 1.5 || step.flow > 3.5) {
        suggestions.push({
          parameter: `Step ${index + 1} Flow`,
          currentValue: step.flow,
          suggestedValue: 2.5,
          expectedImprovement: 0.25,
          reason: 'Adjust flow rate to optimal range (2-3 ml/s)'
        })
      }
    })

    return suggestions.length > 0 ? suggestions : [{
      parameter: 'general',
      currentValue: 0,
      suggestedValue: 0,
      expectedImprovement: 0,
      reason: 'Recipe is well optimized! Continue experimenting with grind size and dose.'
    }]
  }

  /**
   * Cluster shots using simple k-means for recipe recommendations
   */
  findSimilarShots(targetShot: ShotData, allShots: ShotData[], k: number = 5): ShotData[] {
    const targetFeatures = this.extractFeatures(targetShot)

    const distances = allShots
      .filter(shot => shot.id !== targetShot.id)
      .map(shot => {
        const features = this.extractFeatures(shot)
        const distance = Math.sqrt(
          Math.pow(features.avgPressure - targetFeatures.avgPressure, 2) +
          Math.pow(features.avgTemperature - targetFeatures.avgTemperature, 2) +
          Math.pow(features.avgFlow - targetFeatures.avgFlow, 2)
        )
        return { shot, distance }
      })
      .sort((a, b) => a.distance - b.distance)
      .slice(0, k)

    return distances.map(d => d.shot)
  }

  /**
   * Calculate optimal extraction parameters based on coffee characteristics
   */
  suggestParametersForCoffee(
    roastLevel: 'light' | 'medium' | 'dark',
    _origin: string
  ): Partial<ProfileStep> {
    const baseParams = {
      light: { temperature: 95, pressure: 8.5, flow: 2.8 },
      medium: { temperature: 93, pressure: 9.0, flow: 2.5 },
      dark: { temperature: 91, pressure: 9.5, flow: 2.2 }
    }

    return baseParams[roastLevel]
  }
}

export const mlService = new MLService()
