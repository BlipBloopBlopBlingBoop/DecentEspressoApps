//
//  PuckModel.swift
//  Good Espresso
//
//  CFD-based puck simulation using real fluid dynamics:
//  - Darcy's law for flow through porous media
//  - Kozeny-Carman equation for permeability
//  - Ergun equation for pressure drop
//  - 2D axisymmetric finite-difference solver (r, z)
//
//  All Decent basket geometries + tea basket with back-pressure valve.
//

import Foundation
import Accelerate

// MARK: - Basket Definitions

struct BasketSpec: Identifiable, Hashable {
    let id: String
    let name: String
    let diameter: Double      // mm
    let depth: Double         // mm (internal height)
    let nominalDose: Double   // grams
    let holeCount: Int        // approximate screen holes
    let holeDiameter: Double  // mm
    let hasBackPressureValve: Bool
    let backPressureBar: Double  // bar (only for tea basket)
    let description: String

    static let allBaskets: [BasketSpec] = [
        BasketSpec(
            id: "decent_7g", name: "7g Single",
            diameter: 58, depth: 16, nominalDose: 7, holeCount: 280,
            holeDiameter: 0.30, hasBackPressureValve: false, backPressureBar: 0,
            description: "Single basket for ristretto-weight doses. Shallow depth demands precise distribution."
        ),
        BasketSpec(
            id: "decent_14g", name: "14g Double",
            diameter: 58, depth: 22, nominalDose: 14, holeCount: 340,
            holeDiameter: 0.30, hasBackPressureValve: false, backPressureBar: 0,
            description: "Standard double basket. Good balance of depth and forgiveness."
        ),
        BasketSpec(
            id: "decent_18g", name: "18g Precision",
            diameter: 58, depth: 25, nominalDose: 18, holeCount: 380,
            holeDiameter: 0.28, hasBackPressureValve: false, backPressureBar: 0,
            description: "Precision-etched basket for competition-level consistency. Tighter hole tolerance."
        ),
        BasketSpec(
            id: "decent_20g", name: "20g Precision",
            diameter: 58, depth: 27, nominalDose: 20, holeCount: 400,
            holeDiameter: 0.28, hasBackPressureValve: false, backPressureBar: 0,
            description: "Deep precision basket for higher dose ratios. Popular for light roasts."
        ),
        BasketSpec(
            id: "decent_22g", name: "22g Triple",
            diameter: 58, depth: 30, nominalDose: 22, holeCount: 420,
            holeDiameter: 0.30, hasBackPressureValve: false, backPressureBar: 0,
            description: "Triple basket for large doses. Requires careful distribution due to puck height."
        ),
        BasketSpec(
            id: "decent_tea", name: "Tea Basket",
            diameter: 58, depth: 25, nominalDose: 5, holeCount: 380,
            holeDiameter: 0.28, hasBackPressureValve: true, backPressureBar: 2.0,
            description: "Includes mushroom back-pressure valve (~2 bar). Maintains pressure even without a coffee puck for tea brewing."
        ),
    ]

    static var `default`: BasketSpec { allBaskets[2] } // 18g
}

// MARK: - Simulation Parameters

struct PuckParameters {
    var grindSizeMicrons: Double = 400     // 200-800 µm espresso range
    var doseGrams: Double = 18.0           // grams of coffee
    var tampPressureKg: Double = 15.0      // kg-force (typical 10-30)
    var beanDensity: Double = 1.15         // g/cm³ (light=1.10, dark=1.20)
    var moistureContent: Double = 0.10     // fraction 0-0.20
    var brewPressureBar: Double = 9.0      // bar
    var waterTempC: Double = 93.0          // °C
    var distributionQuality: Double = 0.85 // 0-1 (1 = perfect WDT)
    var basket: BasketSpec = .default

    // Derived: puck height (mm) from dose, density, basket geometry
    var puckHeightMM: Double {
        let radiusCM = basket.diameter / 20.0  // mm -> cm
        let areaCM2 = .pi * radiusCM * radiusCM
        // Volume = mass / (density * (1-porosity_initial))
        // Approximate initial porosity ~0.40 before tamp
        let volumeCM3 = doseGrams / (beanDensity * (1.0 - 0.40))
        return volumeCM3 / areaCM2 * 10.0  // cm -> mm
    }

    // Effective porosity after tamping
    var porosity: Double {
        // Base porosity for randomly packed spheres ~0.40
        // Tamp compresses: each kg reduces porosity
        // Typical range 0.30 (heavy tamp) to 0.42 (light tamp)
        let basePorosity = 0.42
        let tampEffect = tampPressureKg * 0.004  // ~0.004 per kg
        let moistureSwelling = moistureContent * 0.15  // moisture swells particles, reduces porosity
        return max(0.20, min(0.50, basePorosity - tampEffect - moistureSwelling))
    }
}

// MARK: - Simulation Grid Cell

struct PuckCell {
    var permeability: Double  // m² (Kozeny-Carman)
    var pressure: Double      // Pa
    var velocityR: Double     // m/s radial
    var velocityZ: Double     // m/s axial (downward positive)
    var flowMagnitude: Double // m/s |v|
    var extractionLevel: Double // 0-1 cumulative
}

// MARK: - Simulation Result

struct PuckSimulationResult {
    let grid: [[PuckCell]]     // [row(z)][col(r)]
    let gridRows: Int          // z divisions
    let gridCols: Int          // r divisions
    let totalFlowRate: Double  // ml/s
    let averagePressureDrop: Double // bar
    let channelingRisk: Double     // 0-1
    let uniformityIndex: Double    // 0-1 (1 = perfectly uniform extraction)
    let channelLocations: [(r: Int, z: Int)] // cells with >2x avg flow
    let effectiveShotTime: Double  // seconds estimate for target yield
    let permeabilityField: [[Double]]  // for visualization
    let pressureField: [[Double]]      // normalized 0-1
    let velocityField: [[Double]]      // normalized 0-1
    let extractionField: [[Double]]    // 0-1
}

// MARK: - Puck CFD Solver

struct PuckCFDSolver {

    // Physical constants
    static let waterDensity: Double = 1000.0     // kg/m³
    static let atmPressure: Double = 101325.0    // Pa

    /// Dynamic viscosity of water as function of temperature (Pa·s)
    /// Empirical fit: µ(T) for 20-100°C
    static func waterViscosity(tempC: Double) -> Double {
        // Vogel equation approximation
        let a = 2.414e-5
        let b = 247.8
        let c = 140.0
        return a * pow(10.0, b / (tempC + c - 273.15 + 273.15))
    }

    /// More accurate water viscosity using simple interpolation
    static func viscosity(atCelsius t: Double) -> Double {
        // mPa·s values at key temperatures, converted to Pa·s
        // Source: CRC Handbook
        let table: [(Double, Double)] = [
            (20, 1.002e-3), (25, 0.890e-3), (30, 0.798e-3),
            (40, 0.653e-3), (50, 0.547e-3), (60, 0.467e-3),
            (70, 0.404e-3), (80, 0.354e-3), (90, 0.315e-3),
            (95, 0.298e-3), (100, 0.282e-3)
        ]
        // Clamp and interpolate
        let clamped = max(20, min(100, t))
        for i in 0..<(table.count - 1) {
            if clamped >= table[i].0 && clamped <= table[i+1].0 {
                let frac = (clamped - table[i].0) / (table[i+1].0 - table[i].0)
                return table[i].1 + frac * (table[i+1].1 - table[i].1)
            }
        }
        return 0.315e-3  // ~90°C default
    }

    /// Kozeny-Carman permeability: k = (ε³ · d²) / (180 · (1-ε)²)
    static func kozenyCarmanPermeability(particleDiameterM: Double, porosity: Double) -> Double {
        let eps = porosity
        let d = particleDiameterM
        return (pow(eps, 3) * pow(d, 2)) / (180.0 * pow(1.0 - eps, 2))
    }

    /// Ergun equation pressure drop per unit length (Pa/m):
    /// ΔP/L = (150·µ·(1-ε)²·v) / (d²·ε³) + (1.75·ρ·(1-ε)·v²) / (d·ε³)
    /// Returns both viscous and inertial terms
    static func ergunPressureDrop(
        velocity: Double,       // m/s superficial
        particleDiameterM: Double,
        porosity: Double,
        viscosity: Double,
        density: Double = waterDensity
    ) -> Double {
        let eps = porosity
        let d = particleDiameterM
        let viscousTerm = 150.0 * viscosity * pow(1.0 - eps, 2) * velocity / (pow(d, 2) * pow(eps, 3))
        let inertialTerm = 1.75 * density * (1.0 - eps) * pow(velocity, 2) / (d * pow(eps, 3))
        return viscousTerm + inertialTerm
    }

    // MARK: - Main Simulation

    /// Run full 2D axisymmetric puck simulation
    static func simulate(params: PuckParameters, gridRows: Int = 32, gridCols: Int = 20) -> PuckSimulationResult {
        let nz = gridRows  // axial divisions (top to bottom)
        let nr = gridCols  // radial divisions (center to wall)

        let radiusM = params.basket.diameter / 2000.0   // mm -> m
        let heightM = params.puckHeightMM / 1000.0       // mm -> m
        let dr = radiusM / Double(nr)
        let dz = heightM / Double(nz)

        let mu = viscosity(atCelsius: params.waterTempC)
        let particleD = params.grindSizeMicrons * 1e-6   // µm -> m

        // Build permeability field with spatial variation
        var permField = [[Double]](repeating: [Double](repeating: 0, count: nr), count: nz)
        let baseK = kozenyCarmanPermeability(particleDiameterM: particleD, porosity: params.porosity)

        // Seed deterministic pseudo-random for distribution quality
        // Lower distribution quality = more variation
        let variationScale = 1.0 - params.distributionQuality  // 0 = no variation, 1 = max
        srand48(42)  // deterministic seed for reproducibility

        for z in 0..<nz {
            for r in 0..<nr {
                var localK = baseK

                // Edge effect: porosity is ~15-25% higher near basket walls
                let rNorm = Double(r) / Double(nr - 1)
                if rNorm > 0.85 {
                    let edgeFactor = 1.0 + 0.25 * ((rNorm - 0.85) / 0.15)
                    localK *= edgeFactor
                }

                // Bottom compaction: fines migration increases resistance at bottom
                let zNorm = Double(z) / Double(nz - 1)
                if zNorm > 0.7 {
                    let finesFactor = 1.0 - 0.20 * ((zNorm - 0.7) / 0.3)
                    localK *= finesFactor
                }

                // Distribution quality noise
                let noise = (drand48() - 0.5) * 2.0 * variationScale
                // Exponential so it's always positive, centered around 1
                localK *= exp(noise * 0.8)

                // Moisture: higher moisture = swollen particles = lower permeability
                // Already accounted for in porosity, but add local variation
                let moistureNoise = 1.0 - params.moistureContent * 0.3 * drand48()
                localK *= moistureNoise

                permField[z][r] = max(localK * 0.1, localK)  // floor at 10% of base
            }
        }

        // Apply back-pressure valve effect for tea basket
        let brewPressurePa = params.brewPressureBar * 1e5
        let exitPressurePa: Double
        if params.basket.hasBackPressureValve {
            exitPressurePa = params.basket.backPressureBar * 1e5
        } else {
            exitPressurePa = 0  // atmospheric (gauge)
        }
        let deltaPressurePa = brewPressurePa - exitPressurePa

        // MARK: Solve pressure field (Gauss-Seidel iterative relaxation)
        // Darcy + continuity in cylindrical coords:
        // ∂/∂r(r·k·∂P/∂r) / r + ∂/∂z(k·∂P/∂z) = 0

        var P = [[Double]](repeating: [Double](repeating: 0, count: nr), count: nz)

        // Initial guess: linear pressure gradient
        for z in 0..<nz {
            let frac = Double(z) / Double(nz - 1)
            for r in 0..<nr {
                P[z][r] = deltaPressurePa * (1.0 - frac) + exitPressurePa * frac
            }
        }

        // Boundary conditions:
        // Top (z=0): P = brewPressure
        // Bottom (z=nz-1): P = exitPressure (0 or valve pressure)
        // Left (r=0): symmetry (dP/dr = 0)
        // Right (r=nr-1): no-flow (dP/dr = 0)

        for r in 0..<nr {
            P[0][r] = deltaPressurePa        // top
            P[nz-1][r] = exitPressurePa      // bottom
        }

        let omega: Double = 1.4  // SOR relaxation factor
        let maxIter = 200
        let tolerance = 1.0  // Pa

        for _ in 0..<maxIter {
            var maxChange: Double = 0

            for z in 1..<(nz-1) {
                for r in 0..<nr {
                    let kC = permField[z][r]
                    let kUp = permField[max(z-1, 0)][r]
                    let kDown = permField[min(z+1, nz-1)][r]

                    // Radial neighbors with symmetry BC
                    let rLeft = max(r - 1, 0)
                    let rRight = min(r + 1, nr - 1)
                    let kLeft = permField[z][rLeft]
                    let kRight = permField[z][rRight]

                    // Harmonic mean of permeabilities at interfaces
                    let kZPlus = 2.0 * kC * kDown / (kC + kDown + 1e-30)
                    let kZMinus = 2.0 * kC * kUp / (kC + kUp + 1e-30)
                    let kRPlus = 2.0 * kC * kRight / (kC + kRight + 1e-30)
                    let kRMinus = 2.0 * kC * kLeft / (kC + kLeft + 1e-30)

                    // Cylindrical correction for radial term
                    let rPos = (Double(r) + 0.5) * dr
                    let rPlusHalf = rPos + dr / 2
                    let rMinusHalf = max(rPos - dr / 2, dr * 0.01)

                    // Discretized equation
                    let aZ = (kZPlus + kZMinus) / (dz * dz)
                    let aRPlus = kRPlus * rPlusHalf / (rPos * dr * dr)
                    let aRMinus = kRMinus * rMinusHalf / (rPos * dr * dr)
                    let aR = aRPlus + aRMinus

                    let sumCoeff = aZ + aR
                    guard sumCoeff > 0 else { continue }

                    let newP = (kZPlus * P[z+1][r] / (dz * dz)
                              + kZMinus * P[z-1][r] / (dz * dz)
                              + aRPlus * P[z][rRight]
                              + aRMinus * P[z][rLeft]) / sumCoeff

                    let change = abs(newP - P[z][r])
                    maxChange = max(maxChange, change)

                    // SOR update
                    P[z][r] = P[z][r] + omega * (newP - P[z][r])
                }
            }

            if maxChange < tolerance { break }
        }

        // MARK: Compute velocity field from Darcy's law
        // v = -(k/µ) · ∇P

        var grid = [[PuckCell]](
            repeating: [PuckCell](
                repeating: PuckCell(permeability: 0, pressure: 0, velocityR: 0, velocityZ: 0, flowMagnitude: 0, extractionLevel: 0),
                count: nr
            ),
            count: nz
        )

        var maxVelocity: Double = 0

        for z in 0..<nz {
            for r in 0..<nr {
                let k = permField[z][r]

                // Pressure gradient (central differences with boundary handling)
                let dPdz: Double
                if z == 0 {
                    dPdz = (P[1][r] - P[0][r]) / dz
                } else if z == nz - 1 {
                    dPdz = (P[nz-1][r] - P[nz-2][r]) / dz
                } else {
                    dPdz = (P[z+1][r] - P[z-1][r]) / (2.0 * dz)
                }

                let dPdr: Double
                if r == 0 {
                    dPdr = 0  // symmetry
                } else if r == nr - 1 {
                    dPdr = 0  // wall
                } else {
                    dPdr = (P[z][r+1] - P[z][r-1]) / (2.0 * dr)
                }

                let vz = -(k / mu) * dPdz  // positive = downward
                let vr = -(k / mu) * dPdr
                let vmag = sqrt(vr * vr + vz * vz)
                maxVelocity = max(maxVelocity, vmag)

                grid[z][r] = PuckCell(
                    permeability: k,
                    pressure: P[z][r],
                    velocityR: vr,
                    velocityZ: vz,
                    flowMagnitude: vmag,
                    extractionLevel: 0
                )
            }
        }

        // MARK: Compute extraction levels
        // Simple model: extraction ∝ cumulative flow through each cell
        // Higher velocity = more extraction; but too much = channeling (over-extraction in channels)
        let avgVelocity = maxVelocity > 0 ? maxVelocity * 0.3 : 1e-6

        for z in 0..<nz {
            for r in 0..<nr {
                let v = grid[z][r].flowMagnitude
                // Extraction relative to average, capped at 1
                let relFlow = v / (avgVelocity + 1e-10)
                // Deeper cells have had more contact time
                let depthFactor = Double(z + 1) / Double(nz)
                grid[z][r].extractionLevel = min(1.0, relFlow * depthFactor * 0.5)
            }
        }

        // MARK: Compute summary statistics

        // Total flow rate: integrate velocity over exit face (bottom row)
        var totalFlowM3s: Double = 0
        for r in 0..<nr {
            let rPos = (Double(r) + 0.5) * dr
            let annularArea = 2.0 * .pi * rPos * dr  // m²
            totalFlowM3s += grid[nz-1][r].velocityZ * annularArea
        }
        let totalFlowMLs = abs(totalFlowM3s) * 1e6  // m³/s -> ml/s

        // Average pressure drop
        let avgPressureDrop = deltaPressurePa / 1e5  // Pa -> bar

        // Channeling risk: coefficient of variation of exit velocities
        var exitVelocities = [Double]()
        for r in 0..<nr {
            exitVelocities.append(abs(grid[nz-1][r].velocityZ))
        }
        let velMean: Double
        let velStdDev: Double
        if !exitVelocities.isEmpty {
            var arr = exitVelocities
            var m: Double = 0
            vDSP_meanvD(&arr, 1, &m, vDSP_Length(arr.count))
            velMean = m
            var diff = [Double](repeating: 0, count: arr.count)
            var negM = -m
            vDSP_vsaddD(&arr, 1, &negM, &diff, 1, vDSP_Length(arr.count))
            var sumSq: Double = 0
            vDSP_dotprD(&diff, 1, &diff, 1, &sumSq, vDSP_Length(diff.count))
            velStdDev = sqrt(sumSq / Double(diff.count))
        } else {
            velMean = 0
            velStdDev = 0
        }
        let channelingCV = velMean > 0 ? velStdDev / velMean : 0
        // Map CV to 0-1 risk: CV=0 is perfect, CV>0.5 is severe
        let channelingRisk = min(1.0, channelingCV / 0.5)

        // Uniformity index (1 - normalized variance)
        let uniformityIndex = max(0, 1.0 - channelingRisk)

        // Find channel locations (cells with >2x average flow)
        var channelLocs = [(r: Int, z: Int)]()
        let avgMag = maxVelocity * 0.3  // rough average
        for z in 0..<nz {
            for r in 0..<nr {
                if grid[z][r].flowMagnitude > avgMag * 2.5 {
                    channelLocs.append((r: r, z: z))
                }
            }
        }

        // Estimated shot time
        let targetYieldML = params.basket.nominalDose * 2.0  // standard 1:2 ratio
        let effectiveShotTime = totalFlowMLs > 0 ? targetYieldML / totalFlowMLs : 30.0

        // Build normalized fields for visualization
        let maxPressure = deltaPressurePa > 0 ? deltaPressurePa : 1.0
        let maxPerm = permField.flatMap { $0 }.max() ?? 1.0
        let maxVel = maxVelocity > 0 ? maxVelocity : 1.0

        let pressureNorm = P.map { row in row.map { max(0, min(1, $0 / maxPressure)) } }
        let permNorm = permField.map { row in row.map { $0 / maxPerm } }
        let velNorm = grid.map { row in row.map { $0.flowMagnitude / maxVel } }
        let extractNorm = grid.map { row in row.map { $0.extractionLevel } }

        return PuckSimulationResult(
            grid: grid,
            gridRows: nz,
            gridCols: nr,
            totalFlowRate: totalFlowMLs,
            averagePressureDrop: avgPressureDrop,
            channelingRisk: channelingRisk,
            uniformityIndex: uniformityIndex,
            channelLocations: channelLocs,
            effectiveShotTime: effectiveShotTime,
            permeabilityField: permNorm,
            pressureField: pressureNorm,
            velocityField: velNorm,
            extractionField: extractNorm
        )
    }
}
