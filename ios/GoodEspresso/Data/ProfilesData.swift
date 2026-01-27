//
//  ProfilesData.swift
//  Good Espresso
//
//  Pre-built espresso and tea profiles matching Decent's protocol
//  Tea profiles use pulse brewing: fill basket, ramp pressure, fill/steep pulses
//

import Foundation

struct ProfilesData {
    static let allProfiles: [Recipe] = espressoProfiles + teaProfiles

    // MARK: - Espresso Profiles
    static let espressoProfiles: [Recipe] = [
        Recipe(
            id: "e61-classic",
            name: "E61 Classic",
            description: "Traditional E61 group head profile with steady 9 bar pressure and medium temperature. Perfect for medium roasts.",
            author: "Good Espresso",
            createdAt: Date(),
            updatedAt: Date(),
            favorite: true,
            usageCount: 0,
            targetWeight: 36,
            steps: [
                ProfileStep(
                    name: "Preinfusion",
                    temperature: 93,
                    pressure: 3,
                    flow: 2,
                    transition: "smooth",
                    exit: ExitCondition(type: .time, value: 8)
                ),
                ProfileStep(
                    name: "Extraction",
                    temperature: 93,
                    pressure: 9,
                    flow: 4,
                    transition: "smooth",
                    exit: ExitCondition(type: .weight, value: 36)
                )
            ],
            coffeeType: "Medium Roast",
            notes: "Classic 1:2 ratio, 18g dose",
            dose: 18
        ),

        Recipe(
            id: "e61-high-temp",
            name: "E61 High Temperature",
            description: "Higher temperature E61 profile for light roasts. Brings out brighter, more acidic notes.",
            author: "Good Espresso",
            createdAt: Date(),
            updatedAt: Date(),
            favorite: false,
            usageCount: 0,
            targetWeight: 40,
            steps: [
                ProfileStep(
                    name: "Preinfusion",
                    temperature: 96,
                    pressure: 3,
                    flow: 2,
                    transition: "smooth",
                    exit: ExitCondition(type: .time, value: 8)
                ),
                ProfileStep(
                    name: "Extraction",
                    temperature: 96,
                    pressure: 9,
                    flow: 4,
                    transition: "smooth",
                    exit: ExitCondition(type: .weight, value: 40)
                )
            ],
            coffeeType: "Light Roast",
            notes: "Higher extraction for light roasts",
            dose: 18
        ),

        Recipe(
            id: "lever-blooming",
            name: "Lever Machine - Blooming",
            description: "Classic lever machine profile with long preinfusion bloom, declining pressure curve. Mimics spring lever behavior.",
            author: "Good Espresso",
            createdAt: Date(),
            updatedAt: Date(),
            favorite: false,
            usageCount: 0,
            targetWeight: 36,
            steps: [
                ProfileStep(
                    name: "Bloom",
                    temperature: 93,
                    pressure: 2,
                    flow: 1.5,
                    transition: "smooth",
                    exit: ExitCondition(type: .time, value: 15)
                ),
                ProfileStep(
                    name: "Peak Pressure",
                    temperature: 93,
                    pressure: 9,
                    flow: 3,
                    transition: "fast",
                    exit: ExitCondition(type: .time, value: 5)
                ),
                ProfileStep(
                    name: "Declining Pressure",
                    temperature: 93,
                    pressure: 6,
                    flow: 2.5,
                    transition: "smooth",
                    exit: ExitCondition(type: .weight, value: 36)
                )
            ],
            coffeeType: "Any Roast",
            notes: "Mimics manual lever machines",
            dose: 18
        ),

        Recipe(
            id: "turbo-shot",
            name: "Turbo Shot",
            description: "Modern turbo shot profile with high flow and shorter extraction time. Great for sweet, clean shots with coarser grinds.",
            author: "Good Espresso",
            createdAt: Date(),
            updatedAt: Date(),
            favorite: true,
            usageCount: 0,
            targetWeight: 40,
            steps: [
                ProfileStep(
                    name: "Rapid Preinfusion",
                    temperature: 93,
                    pressure: 4,
                    flow: 3,
                    transition: "fast",
                    exit: ExitCondition(type: .time, value: 3)
                ),
                ProfileStep(
                    name: "High Flow",
                    temperature: 93,
                    pressure: 6,
                    flow: 6,
                    transition: "smooth",
                    exit: ExitCondition(type: .weight, value: 40)
                )
            ],
            coffeeType: "Any Roast",
            notes: "Use coarser grind, fast extraction",
            dose: 18
        ),

        Recipe(
            id: "pressure-profiling",
            name: "Advanced Pressure Profile",
            description: "Complex pressure profiling with ramp up, plateau, and decline. Highlights complex flavors in specialty coffee.",
            author: "Good Espresso",
            createdAt: Date(),
            updatedAt: Date(),
            favorite: false,
            usageCount: 0,
            targetWeight: 38,
            steps: [
                ProfileStep(
                    name: "Gentle Start",
                    temperature: 93,
                    pressure: 2,
                    flow: 1.5,
                    transition: "smooth",
                    exit: ExitCondition(type: .time, value: 8)
                ),
                ProfileStep(
                    name: "Ramp Up",
                    temperature: 93,
                    pressure: 9,
                    flow: 3,
                    transition: "smooth",
                    exit: ExitCondition(type: .time, value: 12)
                ),
                ProfileStep(
                    name: "Plateau",
                    temperature: 93,
                    pressure: 9,
                    flow: 3.5,
                    transition: "smooth",
                    exit: ExitCondition(type: .time, value: 10)
                ),
                ProfileStep(
                    name: "Decline",
                    temperature: 93,
                    pressure: 5,
                    flow: 2,
                    transition: "smooth",
                    exit: ExitCondition(type: .weight, value: 38)
                )
            ],
            coffeeType: "Specialty",
            notes: "For complex single origins",
            dose: 18
        ),

        Recipe(
            id: "ristretto",
            name: "Ristretto",
            description: "Short, concentrated shot with high pressure and low yield. Intense, syrupy body with minimal bitterness.",
            author: "Good Espresso",
            createdAt: Date(),
            updatedAt: Date(),
            favorite: false,
            usageCount: 0,
            targetWeight: 28,
            steps: [
                ProfileStep(
                    name: "Preinfusion",
                    temperature: 94,
                    pressure: 3,
                    flow: 1.5,
                    transition: "smooth",
                    exit: ExitCondition(type: .time, value: 6)
                ),
                ProfileStep(
                    name: "Extraction",
                    temperature: 94,
                    pressure: 9,
                    flow: 2.5,
                    transition: "smooth",
                    exit: ExitCondition(type: .weight, value: 28)
                )
            ],
            coffeeType: "Medium-Dark Roast",
            notes: "Concentrated 1:1.5 ratio",
            dose: 18
        ),

        Recipe(
            id: "slayer-style",
            name: "Slayer Style",
            description: "Long, gentle preinfusion followed by full pressure. Inspired by Slayer espresso machines for balanced extraction.",
            author: "Good Espresso",
            createdAt: Date(),
            updatedAt: Date(),
            favorite: false,
            usageCount: 0,
            targetWeight: 40,
            steps: [
                ProfileStep(
                    name: "Long Preinfusion",
                    temperature: 93,
                    pressure: 2,
                    flow: 1,
                    transition: "smooth",
                    exit: ExitCondition(type: .time, value: 20)
                ),
                ProfileStep(
                    name: "Full Pressure",
                    temperature: 93,
                    pressure: 9,
                    flow: 4,
                    transition: "fast",
                    exit: ExitCondition(type: .weight, value: 40)
                )
            ],
            coffeeType: "Light-Medium Roast",
            notes: "Extended preinfusion for clarity",
            dose: 18
        ),

        Recipe(
            id: "allonge",
            name: "Allonge",
            description: "Extended lungo-style shot with declining pressure. Produces a longer, more delicate drink similar to filter coffee.",
            author: "Good Espresso",
            createdAt: Date(),
            updatedAt: Date(),
            favorite: false,
            usageCount: 0,
            targetWeight: 60,
            steps: [
                ProfileStep(
                    name: "Preinfusion",
                    temperature: 92,
                    pressure: 3,
                    flow: 2,
                    transition: "smooth",
                    exit: ExitCondition(type: .time, value: 8)
                ),
                ProfileStep(
                    name: "First Phase",
                    temperature: 92,
                    pressure: 6,
                    flow: 3,
                    transition: "smooth",
                    exit: ExitCondition(type: .weight, value: 35)
                ),
                ProfileStep(
                    name: "Second Phase",
                    temperature: 92,
                    pressure: 4,
                    flow: 2.5,
                    transition: "smooth",
                    exit: ExitCondition(type: .weight, value: 60)
                )
            ],
            coffeeType: "Any Roast",
            notes: "Long shot, filter-like clarity",
            dose: 18
        ),

        Recipe(
            id: "dark-roast-low-temp",
            name: "Dark Roast - Low Temperature",
            description: "Lower temperature profile designed for dark roasts. Reduces bitterness and highlights sweetness.",
            author: "Good Espresso",
            createdAt: Date(),
            updatedAt: Date(),
            favorite: false,
            usageCount: 0,
            targetWeight: 36,
            steps: [
                ProfileStep(
                    name: "Preinfusion",
                    temperature: 88,
                    pressure: 2.5,
                    flow: 2,
                    transition: "smooth",
                    exit: ExitCondition(type: .time, value: 8)
                ),
                ProfileStep(
                    name: "Extraction",
                    temperature: 88,
                    pressure: 8,
                    flow: 3.5,
                    transition: "smooth",
                    exit: ExitCondition(type: .weight, value: 36)
                )
            ],
            coffeeType: "Dark Roast",
            notes: "Lower temp reduces bitterness",
            dose: 18
        ),

        Recipe(
            id: "light-roast-extended",
            name: "Light Roast - Extended",
            description: "High temperature, extended profile for light roasts. Maximizes extraction to bring out fruit and floral notes.",
            author: "Good Espresso",
            createdAt: Date(),
            updatedAt: Date(),
            favorite: false,
            usageCount: 0,
            targetWeight: 45,
            steps: [
                ProfileStep(
                    name: "Warm Preinfusion",
                    temperature: 96,
                    pressure: 3,
                    flow: 2,
                    transition: "smooth",
                    exit: ExitCondition(type: .time, value: 10)
                ),
                ProfileStep(
                    name: "High Extraction",
                    temperature: 96,
                    pressure: 9,
                    flow: 4,
                    transition: "smooth",
                    exit: ExitCondition(type: .weight, value: 45)
                )
            ],
            coffeeType: "Light Roast",
            notes: "Extended 1:2.5 ratio for light roasts",
            dose: 18
        ),

        Recipe(
            id: "flow-profiling",
            name: "Flow Profile - Adaptive",
            description: "Flow-based profiling that adapts to puck resistance. Maintains consistent flow rate for even extraction.",
            author: "Good Espresso",
            createdAt: Date(),
            updatedAt: Date(),
            favorite: false,
            usageCount: 0,
            targetWeight: 38,
            steps: [
                ProfileStep(
                    name: "Gentle Wetting",
                    temperature: 93,
                    pressure: 0,  // Flow-only mode
                    flow: 1.5,
                    transition: "smooth",
                    exit: ExitCondition(type: .time, value: 10),
                    limiterValue: 4,
                    limiterRange: 0.5
                ),
                ProfileStep(
                    name: "Steady Flow",
                    temperature: 93,
                    pressure: 0,  // Flow-only mode
                    flow: 3.5,
                    transition: "smooth",
                    exit: ExitCondition(type: .weight, value: 38),
                    limiterValue: 9,
                    limiterRange: 0.5
                )
            ],
            coffeeType: "Any Roast",
            notes: "Flow-based for consistent extraction",
            dose: 18
        )
    ]

    // MARK: - Tea Profiles (Pulse Brewing)
    // Tea profiles use Decent-style pulse brewing:
    // 1. Basket fills with water (initial fill)
    // 2. Pressure ramps to open the valve
    // 3. Fill and steep repeatedly in pulses (not continuous flow)

    // MARK: - Tea Profiles
    // All tea profiles use proper single-mode control:
    // - Flow control (flow > 0, pressure = 0): For fill and pulse steps
    // - Pressure control (pressure > 0, flow = 0): For valve open steps
    // - Pause/Steep (pressure = 0, flow = 0): For steeping

    static let teaProfiles: [Recipe] = [
        // MARK: - Green Tea
        Recipe(
            id: "green-tea",
            name: "Green Tea - Pulse Brew",
            description: "Delicate green tea with Decent-style pulse brewing at 75-80C. Basket fills, pressure opens valve, then repeated fill/steep cycles. Perfect for sencha, dragon well, gyokuro.",
            author: "Good Espresso",
            createdAt: Date(),
            updatedAt: Date(),
            favorite: false,
            usageCount: 0,
            targetWeight: 200,
            steps: [
                ProfileStep(
                    name: "Initial Fill",
                    temperature: 78,
                    pressure: 0,
                    flow: 4.0,  // Flow control - fill basket
                    transition: "fast",
                    exit: ExitCondition(type: .time, value: 5)
                ),
                ProfileStep(
                    name: "Valve Open",
                    temperature: 78,
                    pressure: 1.5,  // Pressure control - open valve
                    flow: 0,
                    transition: "smooth",
                    exit: ExitCondition(type: .time, value: 3)
                ),
                ProfileStep(
                    name: "Steep 1",
                    temperature: 78,
                    pressure: 0,
                    flow: 0,  // Pause - steep
                    transition: "fast",
                    exit: ExitCondition(type: .time, value: 8)
                ),
                ProfileStep(
                    name: "Pulse 1",
                    temperature: 78,
                    pressure: 0,
                    flow: 3.0,  // Flow control - pulse
                    transition: "smooth",
                    exit: ExitCondition(type: .time, value: 6)
                ),
                ProfileStep(
                    name: "Steep 2",
                    temperature: 78,
                    pressure: 0,
                    flow: 0,
                    transition: "fast",
                    exit: ExitCondition(type: .time, value: 8)
                ),
                ProfileStep(
                    name: "Pulse 2",
                    temperature: 78,
                    pressure: 0,
                    flow: 3.0,
                    transition: "smooth",
                    exit: ExitCondition(type: .time, value: 6)
                ),
                ProfileStep(
                    name: "Steep 3",
                    temperature: 78,
                    pressure: 0,
                    flow: 0,
                    transition: "fast",
                    exit: ExitCondition(type: .time, value: 8)
                ),
                ProfileStep(
                    name: "Final Drain",
                    temperature: 78,
                    pressure: 0,
                    flow: 3.5,  // Flow control - drain
                    transition: "smooth",
                    exit: ExitCondition(type: .weight, value: 200)
                )
            ],
            coffeeType: "Green tea leaves",
            notes: "Use 3-5g tea per 200ml water. Pulse brewing extracts more flavor with less bitterness. Water temp: 75-80C.",
            dose: 4
        ),

        // MARK: - Black Tea
        Recipe(
            id: "black-tea",
            name: "Black Tea - Pulse Brew",
            description: "Full-bodied black tea with Decent-style pulse brewing at 90C. Higher temperature and longer steeps for robust extraction. Ideal for English breakfast, Earl Grey, Assam.",
            author: "Good Espresso",
            createdAt: Date(),
            updatedAt: Date(),
            favorite: false,
            usageCount: 0,
            targetWeight: 200,
            steps: [
                ProfileStep(
                    name: "Initial Fill",
                    temperature: 90,
                    pressure: 0,
                    flow: 4.5,  // Flow control - fill
                    transition: "fast",
                    exit: ExitCondition(type: .time, value: 5)
                ),
                ProfileStep(
                    name: "Valve Open",
                    temperature: 90,
                    pressure: 2.0,  // Pressure control - open valve
                    flow: 0,
                    transition: "smooth",
                    exit: ExitCondition(type: .time, value: 3)
                ),
                ProfileStep(
                    name: "Steep 1",
                    temperature: 90,
                    pressure: 0,
                    flow: 0,  // Pause - steep
                    transition: "fast",
                    exit: ExitCondition(type: .time, value: 12)
                ),
                ProfileStep(
                    name: "Pulse 1",
                    temperature: 90,
                    pressure: 0,
                    flow: 3.5,  // Flow control - pulse
                    transition: "smooth",
                    exit: ExitCondition(type: .time, value: 8)
                ),
                ProfileStep(
                    name: "Steep 2",
                    temperature: 90,
                    pressure: 0,
                    flow: 0,
                    transition: "fast",
                    exit: ExitCondition(type: .time, value: 10)
                ),
                ProfileStep(
                    name: "Pulse 2",
                    temperature: 90,
                    pressure: 0,
                    flow: 3.5,
                    transition: "smooth",
                    exit: ExitCondition(type: .time, value: 8)
                ),
                ProfileStep(
                    name: "Final Drain",
                    temperature: 90,
                    pressure: 0,
                    flow: 4.0,  // Flow control - drain
                    transition: "smooth",
                    exit: ExitCondition(type: .weight, value: 200)
                )
            ],
            coffeeType: "Black tea leaves",
            notes: "Use 2-4g tea per 200ml water. Higher temp and longer steeps extract full body. Water temp: 85-95C.",
            dose: 3
        ),

        // MARK: - White Tea
        Recipe(
            id: "white-tea",
            name: "White Tea - Pulse Brew",
            description: "Ultra-delicate white tea with gentle pulse brewing at 70-75C. Very low pressure and extended steeps preserve subtle sweetness. For silver needle, white peony.",
            author: "Good Espresso",
            createdAt: Date(),
            updatedAt: Date(),
            favorite: false,
            usageCount: 0,
            targetWeight: 200,
            steps: [
                ProfileStep(
                    name: "Initial Fill",
                    temperature: 73,
                    pressure: 0,
                    flow: 3.0,  // Flow control - gentle fill
                    transition: "smooth",
                    exit: ExitCondition(type: .time, value: 6)
                ),
                ProfileStep(
                    name: "Valve Open",
                    temperature: 73,
                    pressure: 1.0,  // Pressure control - gentle valve open
                    flow: 0,
                    transition: "smooth",
                    exit: ExitCondition(type: .time, value: 3)
                ),
                ProfileStep(
                    name: "Steep 1",
                    temperature: 73,
                    pressure: 0,
                    flow: 0,  // Pause - steep
                    transition: "fast",
                    exit: ExitCondition(type: .time, value: 12)
                ),
                ProfileStep(
                    name: "Pulse 1",
                    temperature: 73,
                    pressure: 0,  // Flow control only
                    flow: 2.5,
                    transition: "smooth",
                    exit: ExitCondition(type: .time, value: 6)
                ),
                ProfileStep(
                    name: "Steep 2",
                    temperature: 73,
                    pressure: 0,
                    flow: 0,
                    transition: "fast",
                    exit: ExitCondition(type: .time, value: 12)
                ),
                ProfileStep(
                    name: "Pulse 2",
                    temperature: 73,
                    pressure: 0,  // Flow control only
                    flow: 2.5,
                    transition: "smooth",
                    exit: ExitCondition(type: .time, value: 6)
                ),
                ProfileStep(
                    name: "Steep 3",
                    temperature: 73,
                    pressure: 0,
                    flow: 0,
                    transition: "fast",
                    exit: ExitCondition(type: .time, value: 10)
                ),
                ProfileStep(
                    name: "Final Drain",
                    temperature: 73,
                    pressure: 0,  // Flow control only
                    flow: 3.0,
                    transition: "smooth",
                    exit: ExitCondition(type: .weight, value: 200)
                )
            ],
            coffeeType: "White tea leaves",
            notes: "Use 4-6g tea per 200ml water. Low temp preserves delicate flavors. Water temp: 70-75C.",
            dose: 5
        ),

        // MARK: - Oolong Tea (Pulse Brew)
        // Pattern: Fill (flow) -> Valve Open (pressure) -> Steep (pause) -> Pulse (flow) -> repeat
        Recipe(
            id: "oolong-tea",
            name: "Oolong Tea - Pulse Brew",
            description: "Semi-oxidized oolong with traditional gongfu-style pulse brewing at 85C. Multiple short steeps build complexity. Perfect for Ti Kuan Yin, Da Hong Pao.",
            author: "Good Espresso",
            createdAt: Date(),
            updatedAt: Date(),
            favorite: false,
            usageCount: 0,
            targetWeight: 200,
            steps: [
                ProfileStep(
                    name: "Initial Fill",
                    temperature: 85,
                    pressure: 0,
                    flow: 4.0,  // Flow control - fill basket
                    transition: "fast",
                    exit: ExitCondition(type: .time, value: 5)
                ),
                ProfileStep(
                    name: "Valve Open",
                    temperature: 85,
                    pressure: 2.0,  // Pressure control - open valve
                    flow: 0,
                    transition: "smooth",
                    exit: ExitCondition(type: .time, value: 3)
                ),
                ProfileStep(
                    name: "Steep 1",
                    temperature: 85,
                    pressure: 0,  // No pressure
                    flow: 0,     // No flow - pause/steep
                    transition: "fast",
                    exit: ExitCondition(type: .time, value: 8)
                ),
                ProfileStep(
                    name: "Pulse 1",
                    temperature: 85,
                    pressure: 0,
                    flow: 3.5,  // Flow control - gentle pulse
                    transition: "smooth",
                    exit: ExitCondition(type: .time, value: 6)
                ),
                ProfileStep(
                    name: "Steep 2",
                    temperature: 85,
                    pressure: 0,
                    flow: 0,
                    transition: "fast",
                    exit: ExitCondition(type: .time, value: 10)
                ),
                ProfileStep(
                    name: "Pulse 2",
                    temperature: 85,
                    pressure: 0,
                    flow: 3.5,
                    transition: "smooth",
                    exit: ExitCondition(type: .time, value: 6)
                ),
                ProfileStep(
                    name: "Steep 3",
                    temperature: 85,
                    pressure: 0,
                    flow: 0,
                    transition: "fast",
                    exit: ExitCondition(type: .time, value: 8)
                ),
                ProfileStep(
                    name: "Final Drain",
                    temperature: 85,
                    pressure: 0,
                    flow: 4.0,  // Flow control - drain
                    transition: "smooth",
                    exit: ExitCondition(type: .weight, value: 200)
                )
            ],
            coffeeType: "Oolong tea leaves",
            notes: "Use 5-7g tea per 200ml water. Gongfu-style pulses reveal layers of flavor. Water temp: 80-90C.",
            dose: 6
        ),

        // MARK: - Pu-erh Tea (Pulse Brew)
        Recipe(
            id: "puerh-tea",
            name: "Pu-erh Tea - Pulse Brew",
            description: "Aged pu-erh tea with vigorous pulse brewing at 95C. High temperature and strong pulses extract deep, earthy flavors. For sheng and shou pu-erh.",
            author: "Good Espresso",
            createdAt: Date(),
            updatedAt: Date(),
            favorite: false,
            usageCount: 0,
            targetWeight: 200,
            steps: [
                ProfileStep(
                    name: "Rinse",
                    temperature: 95,
                    pressure: 0,
                    flow: 5.0,  // Flow control - quick rinse
                    transition: "fast",
                    exit: ExitCondition(type: .time, value: 3)
                ),
                ProfileStep(
                    name: "Valve Open",
                    temperature: 95,
                    pressure: 2.5,  // Pressure control - open valve
                    flow: 0,
                    transition: "smooth",
                    exit: ExitCondition(type: .time, value: 3)
                ),
                ProfileStep(
                    name: "Steep 1",
                    temperature: 95,
                    pressure: 0,
                    flow: 0,  // Pause - steep
                    transition: "fast",
                    exit: ExitCondition(type: .time, value: 6)
                ),
                ProfileStep(
                    name: "Pulse 1",
                    temperature: 95,
                    pressure: 0,
                    flow: 4.0,  // Flow control - pulse
                    transition: "smooth",
                    exit: ExitCondition(type: .time, value: 7)
                ),
                ProfileStep(
                    name: "Steep 2",
                    temperature: 95,
                    pressure: 0,
                    flow: 0,
                    transition: "fast",
                    exit: ExitCondition(type: .time, value: 8)
                ),
                ProfileStep(
                    name: "Pulse 2",
                    temperature: 95,
                    pressure: 0,
                    flow: 4.0,
                    transition: "smooth",
                    exit: ExitCondition(type: .time, value: 7)
                ),
                ProfileStep(
                    name: "Steep 3",
                    temperature: 95,
                    pressure: 0,
                    flow: 0,
                    transition: "fast",
                    exit: ExitCondition(type: .time, value: 6)
                ),
                ProfileStep(
                    name: "Final Drain",
                    temperature: 95,
                    pressure: 0,
                    flow: 4.5,  // Flow control - drain
                    transition: "smooth",
                    exit: ExitCondition(type: .weight, value: 200)
                )
            ],
            coffeeType: "Pu-erh tea (sheng or shou)",
            notes: "Use 5-8g tea per 200ml water. First rinse wakes the leaves. Can steep 10+ times. Water temp: 95-100C.",
            dose: 7
        ),

        // MARK: - Herbal Tisane (Pulse Brew)
        Recipe(
            id: "herbal-tisane",
            name: "Herbal Tisane - Pulse Brew",
            description: "Herbal infusions with extended pulse brewing at 95C. Longer steeps extract full herbal benefits. For chamomile, peppermint, rooibos, hibiscus.",
            author: "Good Espresso",
            createdAt: Date(),
            updatedAt: Date(),
            favorite: false,
            usageCount: 0,
            targetWeight: 200,
            steps: [
                ProfileStep(
                    name: "Initial Fill",
                    temperature: 95,
                    pressure: 0,
                    flow: 4.5,  // Flow control - fill
                    transition: "fast",
                    exit: ExitCondition(type: .time, value: 5)
                ),
                ProfileStep(
                    name: "Valve Open",
                    temperature: 95,
                    pressure: 2.0,  // Pressure control - open valve
                    flow: 0,
                    transition: "smooth",
                    exit: ExitCondition(type: .time, value: 3)
                ),
                ProfileStep(
                    name: "Steep 1",
                    temperature: 95,
                    pressure: 0,
                    flow: 0,  // Pause - steep
                    transition: "fast",
                    exit: ExitCondition(type: .time, value: 15)
                ),
                ProfileStep(
                    name: "Pulse 1",
                    temperature: 95,
                    pressure: 0,
                    flow: 3.5,  // Flow control - pulse
                    transition: "smooth",
                    exit: ExitCondition(type: .time, value: 8)
                ),
                ProfileStep(
                    name: "Steep 2",
                    temperature: 95,
                    pressure: 0,
                    flow: 0,  // Pause - steep
                    transition: "fast",
                    exit: ExitCondition(type: .time, value: 12)
                ),
                ProfileStep(
                    name: "Final Drain",
                    temperature: 95,
                    pressure: 0,
                    flow: 4.0,  // Flow control - drain
                    transition: "smooth",
                    exit: ExitCondition(type: .weight, value: 200)
                )
            ],
            coffeeType: "Herbal blend / Tisane",
            notes: "Use 2-4g dried herbs per 200ml water. Extended steeping extracts full flavor. Caffeine-free. Water temp: 95-100C.",
            dose: 3
        )
    ]
}
