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
  {
    id: 'green-tea',
    name: 'Green Tea',
    description: 'Delicate green tea brewing at 75-80°C with gentle water flow. Perfect for Japanese sencha, Chinese dragon well, and other green teas. Preserves delicate flavors and prevents bitterness.',
    author: 'DeSpresso',
    createdAt: Date.now(),
    updatedAt: Date.now(),
    favorite: false,
    usageCount: 0,
    targetWeight: 200,
    steps: [
      {
        name: 'Gentle Infusion',
        temperature: 78,
        pressure: 0,  // No pressure - flow mode only
        flow: 3.5,    // Gentle flow for tea
        transition: 'smooth',
        exit: { type: 'time', value: 60 }  // 60 seconds for ~200ml
      }
    ],
    metadata: {
      coffee: 'Green tea leaves',
      notes: 'Use 2-3g tea per 200ml water. Water temp: 75-80°C'
    }
  },
  {
    id: 'black-tea',
    name: 'Black Tea',
    description: 'Full-bodied black tea brewing at 90°C with moderate flow. Ideal for English breakfast, Earl Grey, Assam, and Ceylon teas. Brings out rich, robust flavors.',
    author: 'DeSpresso',
    createdAt: Date.now(),
    updatedAt: Date.now(),
    favorite: false,
    usageCount: 0,
    targetWeight: 200,
    steps: [
      {
        name: 'Full Infusion',
        temperature: 90,
        pressure: 0,  // No pressure - flow mode only
        flow: 3.5,
        transition: 'smooth',
        exit: { type: 'time', value: 60 }
      }
    ],
    metadata: {
      coffee: 'Black tea leaves',
      notes: 'Use 2-3g tea per 200ml water. Water temp: 85-95°C'
    }
  },
  {
    id: 'white-tea',
    name: 'White Tea',
    description: 'Ultra-delicate white tea brewing at 70-75°C with very gentle flow. For silver needle, white peony, and premium white teas. Preserves subtle, sweet notes.',
    author: 'DeSpresso',
    createdAt: Date.now(),
    updatedAt: Date.now(),
    favorite: false,
    usageCount: 0,
    targetWeight: 200,
    steps: [
      {
        name: 'Delicate Infusion',
        temperature: 73,
        pressure: 0,  // No pressure - flow mode only
        flow: 3.0,    // Very gentle for delicate tea
        transition: 'smooth',
        exit: { type: 'time', value: 75 }  // Longer steep for white tea
      }
    ],
    metadata: {
      coffee: 'White tea leaves',
      notes: 'Use 3-4g tea per 200ml water. Water temp: 70-75°C'
    }
  },
  {
    id: 'oolong-tea',
    name: 'Oolong Tea',
    description: 'Semi-oxidized oolong tea brewing at 85°C with balanced flow. Perfect for Ti Kuan Yin, Da Hong Pao, and other oolongs. Brings out complex floral and fruity notes.',
    author: 'DeSpresso',
    createdAt: Date.now(),
    updatedAt: Date.now(),
    favorite: false,
    usageCount: 0,
    targetWeight: 200,
    steps: [
      {
        name: 'Balanced Infusion',
        temperature: 85,
        pressure: 0,  // No pressure - flow mode only
        flow: 3.5,
        transition: 'smooth',
        exit: { type: 'time', value: 65 }
      }
    ],
    metadata: {
      coffee: 'Oolong tea leaves',
      notes: 'Use 3-4g tea per 200ml water. Water temp: 80-90°C'
    }
  }
]
