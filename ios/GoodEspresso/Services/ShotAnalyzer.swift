//
//  ShotAnalyzer.swift
//  Good Espresso
//
//  On-device ML-powered shot analysis using Accelerate framework.
//  Runs entirely on Apple Silicon — no cloud required.
//

import Foundation
import Accelerate

// MARK: - Analysis Result

struct ShotInsight: Identifiable {
    let id = UUID()
    let icon: String
    let title: String
    let detail: String
    let severity: Severity

    enum Severity {
        case good, warning, critical
    }
}

struct ShotAnalysis {
    let overallScore: Int            // 0-100
    let pressureStability: Double    // 0-1
    let flowConsistency: Double      // 0-1
    let temperatureControl: Double   // 0-1
    let extractionEfficiency: Double // 0-1
    let insights: [ShotInsight]
    let grindSuggestion: String?
    let channelingDetected: Bool
    let preinfusionQuality: Double   // 0-1
}

// MARK: - Analyzer

struct ShotAnalyzer {

    /// Analyze a completed shot using vectorized signal processing (Accelerate / vDSP).
    static func analyze(_ shot: ShotRecord) -> ShotAnalysis {
        let points = shot.dataPoints
        guard points.count >= 4 else {
            return emptyAnalysis
        }

        // Extract signal vectors
        var pressures = points.map { $0.pressure }
        var flows     = points.map { $0.flow }
        var temps     = points.map { $0.temperature }
        let n         = vDSP_Length(points.count)

        // ---- Pressure Stability (vDSP standard-deviation) ----
        // Only consider the "plateau" phase (after ramp-up: first data where pressure > 3 bar)
        let plateauPressures = pressures.drop(while: { $0 < 3.0 })
        let pressureStability: Double
        if plateauPressures.count >= 3 {
            var pArr = Array(plateauPressures)
            var mean: Double = 0
            vDSP_meanvD(&pArr, 1, &mean, vDSP_Length(pArr.count))
            var diff = [Double](repeating: 0, count: pArr.count)
            var negMean = -mean
            vDSP_vsaddD(&pArr, 1, &negMean, &diff, 1, vDSP_Length(pArr.count))
            var sumSq: Double = 0
            vDSP_dotprD(&diff, 1, &diff, 1, &sumSq, vDSP_Length(diff.count))
            let stdDev = sqrt(sumSq / Double(diff.count))
            // Perfect = 0 stdDev. Score drops as stdDev rises.
            pressureStability = max(0, 1.0 - stdDev / 3.0)
        } else {
            pressureStability = 0.5
        }

        // ---- Flow Consistency (coefficient of variation) ----
        let plateauFlows = flows.drop(while: { $0 < 0.5 })
        let flowConsistency: Double
        if plateauFlows.count >= 3 {
            var fArr = Array(plateauFlows)
            var mean: Double = 0
            vDSP_meanvD(&fArr, 1, &mean, vDSP_Length(fArr.count))
            if mean > 0.1 {
                var diff = [Double](repeating: 0, count: fArr.count)
                var negMean = -mean
                vDSP_vsaddD(&fArr, 1, &negMean, &diff, 1, vDSP_Length(fArr.count))
                var sumSq: Double = 0
                vDSP_dotprD(&diff, 1, &diff, 1, &sumSq, vDSP_Length(diff.count))
                let cv = sqrt(sumSq / Double(diff.count)) / mean
                flowConsistency = max(0, 1.0 - cv * 2.0)
            } else {
                flowConsistency = 0.3
            }
        } else {
            flowConsistency = 0.5
        }

        // ---- Temperature Control (max deviation from mean) ----
        var tempMean: Double = 0
        vDSP_meanvD(&temps, 1, &tempMean, n)
        var tempMax: Double = 0
        vDSP_maxvD(&temps, 1, &tempMax, n)
        var tempMin: Double = 0
        vDSP_minvD(&temps, 1, &tempMin, n)
        let tempRange = tempMax - tempMin
        let temperatureControl = max(0, 1.0 - tempRange / 5.0)  // 5°C range = 0 score

        // ---- Pre-infusion quality ----
        let preinfusionPoints = points.prefix(while: { $0.pressure < 3.0 })
        let preinfusionQuality: Double
        if preinfusionPoints.count >= 2 {
            let preinfDuration = (preinfusionPoints.last?.timestamp ?? 0) / 1000.0
            // Ideal pre-infusion: 4-8 seconds
            if preinfDuration >= 4 && preinfDuration <= 8 {
                preinfusionQuality = 1.0
            } else if preinfDuration >= 2 && preinfDuration <= 12 {
                preinfusionQuality = 0.7
            } else {
                preinfusionQuality = 0.4
            }
        } else {
            preinfusionQuality = 0.5
        }

        // ---- Channeling Detection (sudden flow spikes with pressure drops) ----
        var channelingDetected = false
        if flows.count >= 5 {
            for i in 2..<(flows.count - 2) {
                let flowJump = flows[i] - flows[i-1]
                let pressureDrop = pressures[i-1] - pressures[i]
                // Sudden flow increase > 1 ml/s with simultaneous pressure drop > 0.5 bar
                if flowJump > 1.0 && pressureDrop > 0.5 {
                    channelingDetected = true
                    break
                }
            }
        }

        // ---- Extraction efficiency (how close to 25-30s ideal) ----
        let duration = shot.duration > 0 ? shot.duration : (points.last?.timestamp ?? 0) / 1000.0
        let extractionEfficiency: Double
        if duration >= 24 && duration <= 32 {
            extractionEfficiency = 1.0
        } else if duration >= 18 && duration <= 40 {
            let deviation = min(abs(duration - 24), abs(duration - 32))
            extractionEfficiency = max(0, 1.0 - deviation / 12.0)
        } else {
            extractionEfficiency = max(0, 1.0 - abs(duration - 28) / 20.0)
        }

        // ---- Overall Score (weighted combination) ----
        let rawScore = pressureStability * 0.30
                     + flowConsistency * 0.25
                     + temperatureControl * 0.15
                     + extractionEfficiency * 0.20
                     + preinfusionQuality * 0.10
        let channelingPenalty: Double = channelingDetected ? 0.15 : 0
        let overallScore = Int(max(0, min(100, (rawScore - channelingPenalty) * 100)))

        // ---- Build insights ----
        var insights = [ShotInsight]()

        // Pressure
        if pressureStability > 0.85 {
            insights.append(ShotInsight(icon: "gauge.with.needle.fill", title: "Stable Pressure", detail: "Pressure held very steady during extraction", severity: .good))
        } else if pressureStability < 0.5 {
            insights.append(ShotInsight(icon: "gauge.with.needle.fill", title: "Pressure Fluctuation", detail: "Significant pressure variation detected — check puck prep", severity: .critical))
        } else {
            insights.append(ShotInsight(icon: "gauge.with.needle.fill", title: "Moderate Pressure Variance", detail: "Some pressure variation — consider finer distribution", severity: .warning))
        }

        // Flow
        if flowConsistency > 0.85 {
            insights.append(ShotInsight(icon: "drop.fill", title: "Consistent Flow", detail: "Even flow throughout the shot", severity: .good))
        } else if flowConsistency < 0.5 {
            insights.append(ShotInsight(icon: "drop.fill", title: "Erratic Flow", detail: "Flow rate varied significantly — possible channeling", severity: .critical))
        }

        // Temperature
        if temperatureControl > 0.8 {
            insights.append(ShotInsight(icon: "thermometer.medium", title: "Excellent Temp Control", detail: String(format: "Temperature held within %.1f\u{00B0}C", tempRange), severity: .good))
        } else if temperatureControl < 0.4 {
            insights.append(ShotInsight(icon: "thermometer.medium", title: "Temperature Drift", detail: String(format: "%.1f\u{00B0}C swing detected — allow more warm-up time", tempRange), severity: .critical))
        }

        // Channeling
        if channelingDetected {
            insights.append(ShotInsight(icon: "exclamationmark.triangle.fill", title: "Channeling Detected", detail: "Flow spike with pressure drop suggests water found a fast path through the puck", severity: .critical))
        }

        // Duration
        if duration < 20 {
            insights.append(ShotInsight(icon: "timer", title: "Fast Extraction", detail: String(format: "%.0fs is short — consider grinding finer", duration), severity: .warning))
        } else if duration > 38 {
            insights.append(ShotInsight(icon: "timer", title: "Slow Extraction", detail: String(format: "%.0fs is long — consider grinding coarser", duration), severity: .warning))
        } else {
            insights.append(ShotInsight(icon: "timer", title: "Good Timing", detail: String(format: "%.0fs is in the ideal range", duration), severity: .good))
        }

        // ---- Grind suggestion ----
        var pressureMean: Double = 0
        vDSP_meanvD(&pressures, 1, &pressureMean, n)
        var flowMean: Double = 0
        vDSP_meanvD(&flows, 1, &flowMean, n)

        let grindSuggestion: String?
        if flowMean > 3.5 && duration < 22 {
            grindSuggestion = "Try grinding 1-2 clicks finer to slow the flow and increase extraction."
        } else if flowMean < 1.2 && duration > 35 {
            grindSuggestion = "Try grinding 1-2 clicks coarser to increase flow and reduce bitterness."
        } else if channelingDetected {
            grindSuggestion = "Improve puck distribution (WDT) before adjusting grind size."
        } else {
            grindSuggestion = nil
        }

        return ShotAnalysis(
            overallScore: overallScore,
            pressureStability: pressureStability,
            flowConsistency: flowConsistency,
            temperatureControl: temperatureControl,
            extractionEfficiency: extractionEfficiency,
            insights: insights,
            grindSuggestion: grindSuggestion,
            channelingDetected: channelingDetected,
            preinfusionQuality: preinfusionQuality
        )
    }

    /// Analyze trends across multiple shots.
    static func analyzeTrend(_ shots: [ShotRecord]) -> TrendAnalysis {
        guard shots.count >= 2 else {
            return TrendAnalysis(scores: [], trend: .stable, averageScore: 0, shotCount: shots.count)
        }

        let analyses = shots.prefix(20).map { analyze($0) }
        let scores = analyses.map { $0.overallScore }

        var scoresD = scores.map { Double($0) }
        var mean: Double = 0
        vDSP_meanvD(&scoresD, 1, &mean, vDSP_Length(scoresD.count))

        // Simple linear regression for trend direction
        let trend: TrendDirection
        if scores.count >= 3 {
            let recentAvg = Double(scores.prefix(3).reduce(0, +)) / 3.0
            let olderAvg  = Double(scores.suffix(3).reduce(0, +)) / 3.0
            let diff = recentAvg - olderAvg
            if diff > 5 {
                trend = .improving
            } else if diff < -5 {
                trend = .declining
            } else {
                trend = .stable
            }
        } else {
            trend = .stable
        }

        return TrendAnalysis(
            scores: scores,
            trend: trend,
            averageScore: Int(mean),
            shotCount: shots.count
        )
    }

    private static var emptyAnalysis: ShotAnalysis {
        ShotAnalysis(
            overallScore: 0,
            pressureStability: 0,
            flowConsistency: 0,
            temperatureControl: 0,
            extractionEfficiency: 0,
            insights: [ShotInsight(icon: "info.circle", title: "Not Enough Data", detail: "Need more data points for analysis", severity: .warning)],
            grindSuggestion: nil,
            channelingDetected: false,
            preinfusionQuality: 0
        )
    }
}

// MARK: - Trend Analysis

enum TrendDirection {
    case improving, stable, declining
}

struct TrendAnalysis {
    let scores: [Int]
    let trend: TrendDirection
    let averageScore: Int
    let shotCount: Int
}

// MARK: - Full Dashboard Analytics

struct DashboardAnalytics {
    let shotAnalyses: [(shot: ShotRecord, analysis: ShotAnalysis)]
    let scoreHistory: [(date: Date, score: Int)]
    let scoreDistribution: [Int]  // 10 buckets: 0-9, 10-19, ... 90-100
    let profilePerformance: [(name: String, avgScore: Int, count: Int)]
    let durationDistribution: [Int]  // 8 buckets: <15s, 15-20, 20-25, 25-30, 30-35, 35-40, 40-45, >45
    let channelingRate: Double  // 0-1
    let avgPressures: [Double]  // per-shot average pressures (most recent first)
    let avgFlows: [Double]      // per-shot average flows
    let avgTemps: [Double]      // per-shot average temps
    let bestShots: [(shot: ShotRecord, score: Int)]
    let weeklyAverages: [(week: String, score: Int)]
    let trend: TrendAnalysis
}

extension ShotAnalyzer {

    /// Full dashboard computation — runs everything on Accelerate-backed vDSP.
    static func computeDashboard(_ shots: [ShotRecord]) -> DashboardAnalytics {
        let capped = Array(shots.prefix(100))
        let pairs: [(shot: ShotRecord, analysis: ShotAnalysis)] = capped.map { ($0, analyze($0)) }

        // Score history (oldest first for chart)
        let scoreHistory: [(date: Date, score: Int)] = pairs.reversed().map {
            ($0.shot.startTime, $0.analysis.overallScore)
        }

        // Score distribution (10 buckets)
        var scoreDist = [Int](repeating: 0, count: 10)
        for (_, a) in pairs {
            let bucket = min(a.overallScore / 10, 9)
            scoreDist[bucket] += 1
        }

        // Profile performance
        var profileMap = [String: (total: Int, count: Int)]()
        for (s, a) in pairs {
            let name = s.profileName
            let existing = profileMap[name] ?? (0, 0)
            profileMap[name] = (existing.total + a.overallScore, existing.count + 1)
        }
        let profilePerf = profileMap.map { (name: $0.key, avgScore: $0.value.total / max($0.value.count, 1), count: $0.value.count) }
            .sorted { $0.avgScore > $1.avgScore }

        // Duration distribution (8 buckets)
        var durDist = [Int](repeating: 0, count: 8)
        for (s, _) in pairs {
            let d = s.duration
            let bucket: Int
            if d < 15 { bucket = 0 }
            else if d < 20 { bucket = 1 }
            else if d < 25 { bucket = 2 }
            else if d < 30 { bucket = 3 }
            else if d < 35 { bucket = 4 }
            else if d < 40 { bucket = 5 }
            else if d < 45 { bucket = 6 }
            else { bucket = 7 }
            durDist[bucket] += 1
        }

        // Channeling rate
        let channelingCount = pairs.filter { $0.analysis.channelingDetected }.count
        let channelingRate = pairs.isEmpty ? 0 : Double(channelingCount) / Double(pairs.count)

        // Per-shot averages (for overlay charts)
        let avgPressures = pairs.map { pair -> Double in
            let p = pair.shot.dataPoints.map(\.pressure)
            guard !p.isEmpty else { return 0 }
            var arr = p
            var m: Double = 0
            vDSP_meanvD(&arr, 1, &m, vDSP_Length(arr.count))
            return m
        }
        let avgFlows = pairs.map { pair -> Double in
            let f = pair.shot.dataPoints.map(\.flow)
            guard !f.isEmpty else { return 0 }
            var arr = f
            var m: Double = 0
            vDSP_meanvD(&arr, 1, &m, vDSP_Length(arr.count))
            return m
        }
        let avgTemps = pairs.map { pair -> Double in
            let t = pair.shot.dataPoints.map(\.temperature)
            guard !t.isEmpty else { return 0 }
            var arr = t
            var m: Double = 0
            vDSP_meanvD(&arr, 1, &m, vDSP_Length(arr.count))
            return m
        }

        // Best shots
        let best = pairs.sorted { $0.analysis.overallScore > $1.analysis.overallScore }
            .prefix(5)
            .map { (shot: $0.shot, score: $0.analysis.overallScore) }

        // Weekly averages
        let cal = Calendar.current
        var weekMap = [String: (total: Int, count: Int)]()
        let weekFmt = DateFormatter()
        weekFmt.dateFormat = "MMM d"
        for (s, a) in pairs {
            let weekStart = cal.dateInterval(of: .weekOfYear, for: s.startTime)?.start ?? s.startTime
            let key = weekFmt.string(from: weekStart)
            let existing = weekMap[key] ?? (0, 0)
            weekMap[key] = (existing.total + a.overallScore, existing.count + 1)
        }
        let weeklyAvgs = weekMap.map { (week: $0.key, score: $0.value.total / max($0.value.count, 1)) }
            .sorted { $0.week < $1.week }

        let trend = analyzeTrend(capped)

        return DashboardAnalytics(
            shotAnalyses: pairs,
            scoreHistory: scoreHistory,
            scoreDistribution: scoreDist,
            profilePerformance: profilePerf,
            durationDistribution: durDist,
            channelingRate: channelingRate,
            avgPressures: avgPressures,
            avgFlows: avgFlows,
            avgTemps: avgTemps,
            bestShots: best,
            weeklyAverages: weeklyAvgs,
            trend: trend
        )
    }
}
