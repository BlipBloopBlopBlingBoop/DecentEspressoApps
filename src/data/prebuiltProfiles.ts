import { Recipe } from '../types/decent'

export const prebuiltProfiles: Recipe[] = [
  {
    id: 'e61-classic',
    name: 'E61 Classic',
    description: 'Traditional E61 group head profile with steady 9 bar pressure and medium temperature. Perfect for medium roasts.',
    author: 'DeSpresso',
    createdAt: Date.now(),
    updatedAt: Date.now(),
    favorite: false,
    usageCount: 0,
    targetWeight: 36,
    steps: [
      {
        name: 'Preinfusion',
        temperature: 93,
        pressure: 3,
        flow: 2,
        transition: 'smooth',
        exit: { type: 'time', value: 8 }
      },
      {
        name: 'Extraction',
        temperature: 93,
        pressure: 9,
        flow: 4,
        transition: 'smooth',
        exit: { type: 'weight', value: 36 }
      }
    ],
    metadata: {
      dose: 18
    }
  },
  {
    id: 'e61-high-temp',
    name: 'E61 High Temperature',
    description: 'Higher temperature E61 profile for light roasts. Brings out brighter, more acidic notes.',
    author: 'DeSpresso',
    createdAt: Date.now(),
    updatedAt: Date.now(),
    favorite: false,
    usageCount: 0,
    targetWeight: 40,
    steps: [
      {
        name: 'Preinfusion',
        temperature: 96,
        pressure: 3,
        flow: 2,
        transition: 'smooth',
        exit: { type: 'time', value: 8 }
      },
      {
        name: 'Extraction',
        temperature: 96,
        pressure: 9,
        flow: 4,
        transition: 'smooth',
        exit: { type: 'weight', value: 40 }
      }
    ],
    metadata: {
      dose: 18
    }
  },
  {
    id: 'lever-blooming',
    name: 'Lever Machine - Blooming',
    description: 'Classic lever machine profile with long preinfusion bloom, declining pressure curve. Mimics spring lever behavior.',
    author: 'DeSpresso',
    createdAt: Date.now(),
    updatedAt: Date.now(),
    favorite: false,
    usageCount: 0,
    targetWeight: 36,
    steps: [
      {
        name: 'Bloom',
        temperature: 93,
        pressure: 2,
        flow: 1.5,
        transition: 'smooth',
        exit: { type: 'time', value: 15 }
      },
      {
        name: 'Peak Pressure',
        temperature: 93,
        pressure: 9,
        flow: 3,
        transition: 'fast',
        exit: { type: 'time', value: 5 }
      },
      {
        name: 'Declining Pressure',
        temperature: 93,
        pressure: 6,
        flow: 2.5,
        transition: 'smooth',
        exit: { type: 'weight', value: 36 }
      }
    ],
    metadata: {
      dose: 18
    }
  },
  {
    id: 'lever-straight-9bar',
    name: 'Lever Machine - Straight 9 Bar',
    description: 'Manual lever profile with constant 9 bar pressure throughout extraction. Simulates experienced barista technique.',
    author: 'DeSpresso',
    createdAt: Date.now(),
    updatedAt: Date.now(),
    favorite: false,
    usageCount: 0,
    targetWeight: 40,
    steps: [
      {
        name: 'Preinfusion',
        temperature: 92,
        pressure: 2,
        flow: 1,
        transition: 'smooth',
        exit: { type: 'time', value: 10 }
      },
      {
        name: 'Full Pressure',
        temperature: 92,
        pressure: 9,
        flow: 3.5,
        transition: 'smooth',
        exit: { type: 'weight', value: 40 }
      }
    ],
    metadata: {
      dose: 18
    }
  },
  {
    id: 'turbo-shot',
    name: 'Turbo Shot',
    description: 'Modern turbo shot profile with high flow and shorter extraction time. Great for sweet, clean shots with coarser grinds.',
    author: 'DeSpresso',
    createdAt: Date.now(),
    updatedAt: Date.now(),
    favorite: false,
    usageCount: 0,
    targetWeight: 40,
    steps: [
      {
        name: 'Rapid Preinfusion',
        temperature: 93,
        pressure: 4,
        flow: 3,
        transition: 'fast',
        exit: { type: 'time', value: 3 }
      },
      {
        name: 'High Flow',
        temperature: 93,
        pressure: 6,
        flow: 6,
        transition: 'smooth',
        exit: { type: 'weight', value: 40 }
      }
    ],
    metadata: {
      dose: 18
    }
  },
  {
    id: 'pressure-profiling',
    name: 'Advanced Pressure Profile',
    description: 'Complex pressure profiling with ramp up, plateau, and decline. Highlights complex flavors in specialty coffee.',
    author: 'DeSpresso',
    createdAt: Date.now(),
    updatedAt: Date.now(),
    favorite: false,
    usageCount: 0,
    targetWeight: 38,
    steps: [
      {
        name: 'Gentle Start',
        temperature: 93,
        pressure: 2,
        flow: 1.5,
        transition: 'smooth',
        exit: { type: 'time', value: 8 }
      },
      {
        name: 'Ramp Up',
        temperature: 93,
        pressure: 9,
        flow: 3,
        transition: 'smooth',
        exit: { type: 'time', value: 12 }
      },
      {
        name: 'Plateau',
        temperature: 93,
        pressure: 9,
        flow: 3.5,
        transition: 'smooth',
        exit: { type: 'time', value: 10 }
      },
      {
        name: 'Decline',
        temperature: 93,
        pressure: 5,
        flow: 2,
        transition: 'smooth',
        exit: { type: 'weight', value: 38 }
      }
    ],
    metadata: {
      dose: 18
    }
  },
  {
    id: 'allonge',
    name: 'Allongé',
    description: 'Extended lungo-style shot with declining pressure. Produces a longer, more delicate drink similar to filter coffee.',
    author: 'DeSpresso',
    createdAt: Date.now(),
    updatedAt: Date.now(),
    favorite: false,
    usageCount: 0,
    targetWeight: 60,
    steps: [
      {
        name: 'Preinfusion',
        temperature: 92,
        pressure: 3,
        flow: 2,
        transition: 'smooth',
        exit: { type: 'time', value: 8 }
      },
      {
        name: 'First Phase',
        temperature: 92,
        pressure: 6,
        flow: 3,
        transition: 'smooth',
        exit: { type: 'weight', value: 35 }
      },
      {
        name: 'Second Phase',
        temperature: 92,
        pressure: 4,
        flow: 2.5,
        transition: 'smooth',
        exit: { type: 'weight', value: 60 }
      }
    ],
    metadata: {
      dose: 18
    }
  },
  {
    id: 'ristretto',
    name: 'Ristretto',
    description: 'Short, concentrated shot with high pressure and low yield. Intense, syrupy body with minimal bitterness.',
    author: 'DeSpresso',
    createdAt: Date.now(),
    updatedAt: Date.now(),
    favorite: false,
    usageCount: 0,
    targetWeight: 28,
    steps: [
      {
        name: 'Preinfusion',
        temperature: 94,
        pressure: 3,
        flow: 1.5,
        transition: 'smooth',
        exit: { type: 'time', value: 6 }
      },
      {
        name: 'Extraction',
        temperature: 94,
        pressure: 9,
        flow: 2.5,
        transition: 'smooth',
        exit: { type: 'weight', value: 28 }
      }
    ],
    metadata: {
      dose: 18
    }
  },
  {
    id: 'slayer-style',
    name: 'Slayer Style',
    description: 'Long, gentle preinfusion followed by full pressure. Inspired by Slayer espresso machines for balanced extraction.',
    author: 'DeSpresso',
    createdAt: Date.now(),
    updatedAt: Date.now(),
    favorite: false,
    usageCount: 0,
    targetWeight: 40,
    steps: [
      {
        name: 'Long Preinfusion',
        temperature: 93,
        pressure: 2,
        flow: 1,
        transition: 'smooth',
        exit: { type: 'time', value: 20 }
      },
      {
        name: 'Full Pressure',
        temperature: 93,
        pressure: 9,
        flow: 4,
        transition: 'fast',
        exit: { type: 'weight', value: 40 }
      }
    ],
    metadata: {
      dose: 18
    }
  },
  {
    id: 'flow-profiling',
    name: 'Flow Profile - Adaptive',
    description: 'Flow-based profiling that adapts to puck resistance. Maintains consistent flow rate for even extraction.',
    author: 'DeSpresso',
    createdAt: Date.now(),
    updatedAt: Date.now(),
    favorite: false,
    usageCount: 0,
    targetWeight: 38,
    steps: [
      {
        name: 'Gentle Wetting',
        temperature: 93,
        pressure: 9,
        flow: 1.5,
        transition: 'smooth',
        exit: { type: 'time', value: 10 },
        limiter: { value: 4, range: 0.5 }
      },
      {
        name: 'Steady Flow',
        temperature: 93,
        pressure: 9,
        flow: 3.5,
        transition: 'smooth',
        exit: { type: 'weight', value: 38 },
        limiter: { value: 9, range: 0.5 }
      }
    ],
    metadata: {
      dose: 18
    }
  },
  {
    id: 'dark-roast-low-temp',
    name: 'Dark Roast - Low Temperature',
    description: 'Lower temperature profile designed for dark roasts. Reduces bitterness and highlights sweetness.',
    author: 'DeSpresso',
    createdAt: Date.now(),
    updatedAt: Date.now(),
    favorite: false,
    usageCount: 0,
    targetWeight: 36,
    steps: [
      {
        name: 'Preinfusion',
        temperature: 88,
        pressure: 2.5,
        flow: 2,
        transition: 'smooth',
        exit: { type: 'time', value: 8 }
      },
      {
        name: 'Extraction',
        temperature: 88,
        pressure: 8,
        flow: 3.5,
        transition: 'smooth',
        exit: { type: 'weight', value: 36 }
      }
    ],
    metadata: {
      dose: 18
    }
  },
  {
    id: 'light-roast-extended',
    name: 'Light Roast - Extended',
    description: 'High temperature, extended profile for light roasts. Maximizes extraction to bring out fruit and floral notes.',
    author: 'DeSpresso',
    createdAt: Date.now(),
    updatedAt: Date.now(),
    favorite: false,
    usageCount: 0,
    targetWeight: 45,
    steps: [
      {
        name: 'Warm Preinfusion',
        temperature: 96,
        pressure: 3,
        flow: 2,
        transition: 'smooth',
        exit: { type: 'time', value: 10 }
      },
      {
        name: 'High Extraction',
        temperature: 96,
        pressure: 9,
        flow: 4,
        transition: 'smooth',
        exit: { type: 'weight', value: 45 }
      }
    ],
    metadata: {
      dose: 18
    }
  },
  // =============================================================================
  // TEA PROFILES - Decent-style Pulse Brewing
  // =============================================================================
  // Tea profiles use pulsed brewing pattern: basket fills, pressure ramps to
  // open the valve, then fills and steeps repeatedly in pulses (not continuous flow).
  // This mimics traditional gongfu brewing and allows better extraction control.
  // =============================================================================

  {
    id: 'green-tea',
    name: 'Green Tea - Pulse Brew',
    description: 'Delicate green tea with Decent-style pulse brewing at 75-80°C. Basket fills, pressure opens valve, then repeated fill/steep cycles. Perfect for sencha, dragon well, gyokuro. Preserves umami and prevents bitterness.',
    author: 'DeSpresso',
    createdAt: Date.now(),
    updatedAt: Date.now(),
    favorite: false,
    usageCount: 0,
    targetWeight: 200,
    steps: [
      // Step 1: Initial basket fill - gentle flow to wet leaves
      {
        name: 'Initial Fill',
        temperature: 78,
        pressure: 0,    // Flow-only mode
        flow: 4.0,      // Quick initial fill
        transition: 'fast',
        exit: { type: 'time', value: 5 }  // 5 seconds to fill basket
      },
      // Step 2: Pressure ramp to open valve - creates backpressure
      {
        name: 'Valve Open',
        temperature: 78,
        pressure: 1.5,  // Low pressure to open valve gently
        flow: 2.0,
        transition: 'smooth',
        exit: { type: 'time', value: 3 }  // Brief pressure ramp
      },
      // Step 3: First steep - let tea infuse (no flow)
      {
        name: 'Steep 1',
        temperature: 78,
        pressure: 0,
        flow: 0,        // No flow - steeping
        transition: 'fast',
        exit: { type: 'time', value: 8 }  // 8 second steep
      },
      // Step 4: Pulse 1 - gentle extraction
      {
        name: 'Pulse 1',
        temperature: 78,
        pressure: 0.8,
        flow: 3.0,
        transition: 'smooth',
        exit: { type: 'time', value: 6 }
      },
      // Step 5: Second steep
      {
        name: 'Steep 2',
        temperature: 78,
        pressure: 0,
        flow: 0,
        transition: 'fast',
        exit: { type: 'time', value: 8 }
      },
      // Step 6: Pulse 2
      {
        name: 'Pulse 2',
        temperature: 78,
        pressure: 0.8,
        flow: 3.0,
        transition: 'smooth',
        exit: { type: 'time', value: 6 }
      },
      // Step 7: Third steep
      {
        name: 'Steep 3',
        temperature: 78,
        pressure: 0,
        flow: 0,
        transition: 'fast',
        exit: { type: 'time', value: 8 }
      },
      // Step 8: Final extraction - drain remaining
      {
        name: 'Final Drain',
        temperature: 78,
        pressure: 1.0,
        flow: 3.5,
        transition: 'smooth',
        exit: { type: 'weight', value: 200 }  // Stop at target weight
      }
    ],
    metadata: {
      coffee: 'Green tea leaves',
      notes: 'Use 3-5g tea per 200ml water. Pulse brewing extracts more flavor with less bitterness. Water temp: 75-80°C. Multiple infusions possible.',
      dose: 4
    }
  },
  {
    id: 'black-tea',
    name: 'Black Tea - Pulse Brew',
    description: 'Full-bodied black tea with Decent-style pulse brewing at 90°C. Higher temperature and longer steeps for robust extraction. Ideal for English breakfast, Earl Grey, Assam, Darjeeling.',
    author: 'DeSpresso',
    createdAt: Date.now(),
    updatedAt: Date.now(),
    favorite: false,
    usageCount: 0,
    targetWeight: 200,
    steps: [
      // Step 1: Initial basket fill
      {
        name: 'Initial Fill',
        temperature: 90,
        pressure: 0,
        flow: 4.5,      // Slightly faster for black tea
        transition: 'fast',
        exit: { type: 'time', value: 5 }
      },
      // Step 2: Pressure ramp to open valve
      {
        name: 'Valve Open',
        temperature: 90,
        pressure: 2.0,  // Slightly higher pressure for black tea
        flow: 2.5,
        transition: 'smooth',
        exit: { type: 'time', value: 3 }
      },
      // Step 3: First steep - longer for black tea
      {
        name: 'Steep 1',
        temperature: 90,
        pressure: 0,
        flow: 0,
        transition: 'fast',
        exit: { type: 'time', value: 12 }  // Longer steep for black tea
      },
      // Step 4: Pulse 1 - stronger extraction
      {
        name: 'Pulse 1',
        temperature: 90,
        pressure: 1.2,
        flow: 3.5,
        transition: 'smooth',
        exit: { type: 'time', value: 8 }
      },
      // Step 5: Second steep
      {
        name: 'Steep 2',
        temperature: 90,
        pressure: 0,
        flow: 0,
        transition: 'fast',
        exit: { type: 'time', value: 10 }
      },
      // Step 6: Pulse 2
      {
        name: 'Pulse 2',
        temperature: 90,
        pressure: 1.2,
        flow: 3.5,
        transition: 'smooth',
        exit: { type: 'time', value: 8 }
      },
      // Step 7: Final extraction
      {
        name: 'Final Drain',
        temperature: 90,
        pressure: 1.5,
        flow: 4.0,
        transition: 'smooth',
        exit: { type: 'weight', value: 200 }
      }
    ],
    metadata: {
      coffee: 'Black tea leaves',
      notes: 'Use 2-4g tea per 200ml water. Higher temp and longer steeps extract full body. Water temp: 85-95°C.',
      dose: 3
    }
  },
  {
    id: 'white-tea',
    name: 'White Tea - Pulse Brew',
    description: 'Ultra-delicate white tea with gentle pulse brewing at 70-75°C. Very low pressure and extended steeps preserve subtle sweetness. For silver needle, white peony, shou mei.',
    author: 'DeSpresso',
    createdAt: Date.now(),
    updatedAt: Date.now(),
    favorite: false,
    usageCount: 0,
    targetWeight: 200,
    steps: [
      // Step 1: Very gentle initial fill
      {
        name: 'Initial Fill',
        temperature: 73,
        pressure: 0,
        flow: 3.0,      // Slower fill for delicate leaves
        transition: 'smooth',
        exit: { type: 'time', value: 6 }
      },
      // Step 2: Minimal pressure valve open
      {
        name: 'Valve Open',
        temperature: 73,
        pressure: 1.0,  // Very gentle pressure
        flow: 1.5,
        transition: 'smooth',
        exit: { type: 'time', value: 3 }
      },
      // Step 3: Extended first steep - white tea needs time
      {
        name: 'Steep 1',
        temperature: 73,
        pressure: 0,
        flow: 0,
        transition: 'fast',
        exit: { type: 'time', value: 12 }  // Longer steep
      },
      // Step 4: Gentle pulse 1
      {
        name: 'Pulse 1',
        temperature: 73,
        pressure: 0.6,  // Very low pressure
        flow: 2.5,
        transition: 'smooth',
        exit: { type: 'time', value: 6 }
      },
      // Step 5: Second steep
      {
        name: 'Steep 2',
        temperature: 73,
        pressure: 0,
        flow: 0,
        transition: 'fast',
        exit: { type: 'time', value: 12 }
      },
      // Step 6: Gentle pulse 2
      {
        name: 'Pulse 2',
        temperature: 73,
        pressure: 0.6,
        flow: 2.5,
        transition: 'smooth',
        exit: { type: 'time', value: 6 }
      },
      // Step 7: Third steep
      {
        name: 'Steep 3',
        temperature: 73,
        pressure: 0,
        flow: 0,
        transition: 'fast',
        exit: { type: 'time', value: 10 }
      },
      // Step 8: Final gentle drain
      {
        name: 'Final Drain',
        temperature: 73,
        pressure: 0.8,
        flow: 3.0,
        transition: 'smooth',
        exit: { type: 'weight', value: 200 }
      }
    ],
    metadata: {
      coffee: 'White tea leaves',
      notes: 'Use 4-6g tea per 200ml water. Low temp preserves delicate flavors. Multiple infusions highly recommended. Water temp: 70-75°C.',
      dose: 5
    }
  },
  {
    id: 'oolong-tea',
    name: 'Oolong Tea - Pulse Brew',
    description: 'Semi-oxidized oolong with traditional gongfu-style pulse brewing at 85°C. Multiple short steeps build complexity. Perfect for Ti Kuan Yin, Da Hong Pao, Dong Ding, Oriental Beauty.',
    author: 'DeSpresso',
    createdAt: Date.now(),
    updatedAt: Date.now(),
    favorite: false,
    usageCount: 0,
    targetWeight: 200,
    steps: [
      // Step 1: Initial fill
      {
        name: 'Initial Fill',
        temperature: 85,
        pressure: 0,
        flow: 4.0,
        transition: 'fast',
        exit: { type: 'time', value: 5 }
      },
      // Step 2: Pressure ramp
      {
        name: 'Valve Open',
        temperature: 85,
        pressure: 1.8,
        flow: 2.0,
        transition: 'smooth',
        exit: { type: 'time', value: 3 }
      },
      // Step 3: First steep - gongfu style (shorter)
      {
        name: 'Steep 1',
        temperature: 85,
        pressure: 0,
        flow: 0,
        transition: 'fast',
        exit: { type: 'time', value: 8 }
      },
      // Step 4: Pulse 1
      {
        name: 'Pulse 1',
        temperature: 85,
        pressure: 1.0,
        flow: 3.0,
        transition: 'smooth',
        exit: { type: 'time', value: 6 }
      },
      // Step 5: Second steep - slightly longer
      {
        name: 'Steep 2',
        temperature: 85,
        pressure: 0,
        flow: 0,
        transition: 'fast',
        exit: { type: 'time', value: 10 }
      },
      // Step 6: Pulse 2
      {
        name: 'Pulse 2',
        temperature: 85,
        pressure: 1.0,
        flow: 3.0,
        transition: 'smooth',
        exit: { type: 'time', value: 6 }
      },
      // Step 7: Third steep
      {
        name: 'Steep 3',
        temperature: 85,
        pressure: 0,
        flow: 0,
        transition: 'fast',
        exit: { type: 'time', value: 8 }
      },
      // Step 8: Final extraction
      {
        name: 'Final Drain',
        temperature: 85,
        pressure: 1.2,
        flow: 3.5,
        transition: 'smooth',
        exit: { type: 'weight', value: 200 }
      }
    ],
    metadata: {
      coffee: 'Oolong tea leaves',
      notes: 'Use 5-7g tea per 200ml water. Gongfu-style pulses reveal layers of flavor. Excellent for multiple infusions. Water temp: 80-90°C.',
      dose: 6
    }
  },
  // Additional tea profile: Pu-erh (commonly requested)
  {
    id: 'puerh-tea',
    name: 'Pu-erh Tea - Pulse Brew',
    description: 'Aged pu-erh tea with vigorous pulse brewing at 95°C. High temperature and strong pulses extract deep, earthy flavors. For sheng (raw) and shou (ripe) pu-erh.',
    author: 'DeSpresso',
    createdAt: Date.now(),
    updatedAt: Date.now(),
    favorite: false,
    usageCount: 0,
    targetWeight: 200,
    steps: [
      // Step 1: Rinse/wake the leaves (pu-erh tradition)
      {
        name: 'Rinse',
        temperature: 95,
        pressure: 0,
        flow: 5.0,      // Fast rinse
        transition: 'fast',
        exit: { type: 'time', value: 3 }
      },
      // Step 2: Pressure ramp
      {
        name: 'Valve Open',
        temperature: 95,
        pressure: 2.5,  // Higher pressure for aged tea
        flow: 3.0,
        transition: 'smooth',
        exit: { type: 'time', value: 3 }
      },
      // Step 3: First steep - short for pu-erh
      {
        name: 'Steep 1',
        temperature: 95,
        pressure: 0,
        flow: 0,
        transition: 'fast',
        exit: { type: 'time', value: 6 }
      },
      // Step 4: Pulse 1 - strong extraction
      {
        name: 'Pulse 1',
        temperature: 95,
        pressure: 1.5,
        flow: 4.0,
        transition: 'smooth',
        exit: { type: 'time', value: 7 }
      },
      // Step 5: Second steep
      {
        name: 'Steep 2',
        temperature: 95,
        pressure: 0,
        flow: 0,
        transition: 'fast',
        exit: { type: 'time', value: 8 }
      },
      // Step 6: Pulse 2
      {
        name: 'Pulse 2',
        temperature: 95,
        pressure: 1.5,
        flow: 4.0,
        transition: 'smooth',
        exit: { type: 'time', value: 7 }
      },
      // Step 7: Third steep
      {
        name: 'Steep 3',
        temperature: 95,
        pressure: 0,
        flow: 0,
        transition: 'fast',
        exit: { type: 'time', value: 6 }
      },
      // Step 8: Final extraction
      {
        name: 'Final Drain',
        temperature: 95,
        pressure: 2.0,
        flow: 4.5,
        transition: 'smooth',
        exit: { type: 'weight', value: 200 }
      }
    ],
    metadata: {
      coffee: 'Pu-erh tea (sheng or shou)',
      notes: 'Use 5-8g tea per 200ml water. First rinse wakes the leaves. High temp extracts aged flavors. Can steep 10+ times. Water temp: 95-100°C.',
      dose: 7
    }
  },
  // Herbal/Tisane profile
  {
    id: 'herbal-tisane',
    name: 'Herbal Tisane - Pulse Brew',
    description: 'Herbal infusions with extended pulse brewing at 95°C. Longer steeps extract full herbal benefits. For chamomile, peppermint, rooibos, hibiscus, and herbal blends.',
    author: 'DeSpresso',
    createdAt: Date.now(),
    updatedAt: Date.now(),
    favorite: false,
    usageCount: 0,
    targetWeight: 200,
    steps: [
      // Step 1: Initial fill
      {
        name: 'Initial Fill',
        temperature: 95,
        pressure: 0,
        flow: 4.5,
        transition: 'fast',
        exit: { type: 'time', value: 5 }
      },
      // Step 2: Pressure ramp
      {
        name: 'Valve Open',
        temperature: 95,
        pressure: 2.0,
        flow: 2.5,
        transition: 'smooth',
        exit: { type: 'time', value: 3 }
      },
      // Step 3: Extended first steep - herbals need time
      {
        name: 'Steep 1',
        temperature: 95,
        pressure: 0,
        flow: 0,
        transition: 'fast',
        exit: { type: 'time', value: 15 }  // Long steep for herbals
      },
      // Step 4: Pulse 1
      {
        name: 'Pulse 1',
        temperature: 95,
        pressure: 1.0,
        flow: 3.5,
        transition: 'smooth',
        exit: { type: 'time', value: 8 }
      },
      // Step 5: Second steep
      {
        name: 'Steep 2',
        temperature: 95,
        pressure: 0,
        flow: 0,
        transition: 'fast',
        exit: { type: 'time', value: 12 }
      },
      // Step 6: Final extraction
      {
        name: 'Final Drain',
        temperature: 95,
        pressure: 1.5,
        flow: 4.0,
        transition: 'smooth',
        exit: { type: 'weight', value: 200 }
      }
    ],
    metadata: {
      coffee: 'Herbal blend / Tisane',
      notes: 'Use 2-4g dried herbs per 200ml water. Extended steeping extracts full flavor and benefits. Caffeine-free. Water temp: 95-100°C.',
      dose: 3
    }
  }
]
