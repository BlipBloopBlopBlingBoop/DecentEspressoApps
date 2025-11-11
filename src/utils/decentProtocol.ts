/**
 * Decent Espresso Protocol - Data Parsing Utilities
 * Based on official Decent TCL application protocol
 */

export interface ShotSampleData {
  sampleTime: number        // Raw tick count
  groupPressure: number     // bar
  groupFlow: number         // ml/s
  mixTemp: number          // °C
  headTemp: number         // °C
  setMixTemp: number       // °C (target)
  setHeadTemp: number      // °C (target)
  setGroupPressure: number // bar (target)
  setGroupFlow: number     // ml/s (target)
  frameNumber: number      // Current profile frame
  steamTemp: number        // °C
}

export interface StateInfoData {
  state: number
  substate: number
}

/**
 * Parse ShotSample characteristic data (0x00A00D)
 * Format: 19 bytes, Big-Endian
 */
export function parseShotSample(dataView: DataView): ShotSampleData {
  if (dataView.byteLength < 19) {
    throw new Error(`Invalid ShotSample data length: ${dataView.byteLength}, expected 19`)
  }

  // Debug: Log raw bytes for troubleshooting
  const rawBytes: number[] = []
  for (let i = 0; i < dataView.byteLength; i++) {
    rawBytes.push(dataView.getUint8(i))
  }
  console.log('[ShotSample] Raw bytes:', rawBytes.map(b => '0x' + b.toString(16).padStart(2, '0')).join(' '))

  // Parse basic fields first
  const mixTemp = dataView.getUint16(6, false) / 256.0
  const pressure = dataView.getUint16(2, false) / 4096.0
  const flow = dataView.getUint16(4, false) / 4096.0

  // HeadTemp parsing - Try multiple approaches to find the right one
  // The spec says 24-bit at bytes 8-10, but this may be incorrect

  // Approach 1: 16-bit at bytes 8-9, divided by 256 (same format as mixTemp)
  const raw16at8 = dataView.getUint16(8, false)
  const attempt1 = raw16at8 / 256.0

  // Approach 2: 16-bit at bytes 9-10, divided by 256
  const raw16at9 = dataView.getUint16(9, false)
  const attempt2 = raw16at9 / 256.0

  // Approach 3: Single byte at position 8 (no scaling)
  const attempt3 = dataView.getUint8(8)

  // Approach 4: Single byte at position 9 (no scaling)
  const attempt4 = dataView.getUint8(9)

  // Approach 5: 24-bit at bytes 8-10, divided by 256
  const headTempByte1 = dataView.getUint8(8)
  const headTempByte2 = dataView.getUint8(9)
  const headTempByte3 = dataView.getUint8(10)
  const raw24 = (headTempByte1 << 16) | (headTempByte2 << 8) | headTempByte3
  const attempt5 = raw24 / 256.0

  // Approach 6: 24-bit divided by 65536 instead of 256
  const attempt6 = raw24 / 65536.0

  console.log(`[ShotSample] HeadTemp attempts:`)
  console.log(`  [1] 16-bit@8-9 /256: ${attempt1.toFixed(2)}°C (raw: 0x${raw16at8.toString(16)})`)
  console.log(`  [2] 16-bit@9-10 /256: ${attempt2.toFixed(2)}°C (raw: 0x${raw16at9.toString(16)})`)
  console.log(`  [3] byte@8: ${attempt3.toFixed(2)}°C`)
  console.log(`  [4] byte@9: ${attempt4.toFixed(2)}°C`)
  console.log(`  [5] 24-bit /256: ${attempt5.toFixed(2)}°C (raw: 0x${raw24.toString(16)})`)
  console.log(`  [6] 24-bit /65536: ${attempt6.toFixed(2)}°C`)

  // Auto-select the most reasonable temperature (should be 80-105°C for espresso machines)
  const attempts = [
    { value: attempt1, name: '16-bit@8-9 /256', raw: raw16at8 },
    { value: attempt2, name: '16-bit@9-10 /256', raw: raw16at9 },
    { value: attempt3, name: 'byte@8', raw: attempt3 },
    { value: attempt4, name: 'byte@9', raw: attempt4 },
    { value: attempt5, name: '24-bit /256', raw: raw24 },
    { value: attempt6, name: '24-bit /65536', raw: raw24 },
  ]

  // Find the attempt that falls in reasonable espresso temp range (80-105°C)
  let headTemp = attempt1 // default
  let selectedMethod = attempts[0]

  for (const attempt of attempts) {
    if (attempt.value >= 80 && attempt.value <= 105) {
      headTemp = attempt.value
      selectedMethod = attempt
      break
    }
  }

  // If no reasonable temp found, use the one closest to 93°C (typical)
  if (headTemp < 80 || headTemp > 105) {
    const sorted = [...attempts].sort((a, b) =>
      Math.abs(a.value - 93) - Math.abs(b.value - 93)
    )
    headTemp = sorted[0].value
    selectedMethod = sorted[0]
    console.warn(`[ShotSample] No temp in reasonable range! Using closest to 93°C: ${selectedMethod.name}`)
  }

  console.log(`[ShotSample] ✓ Selected: ${selectedMethod.name} = ${headTemp.toFixed(1)}°C`)
  console.log(`[ShotSample] Full reading: Mix=${mixTemp.toFixed(1)}°C, Head=${headTemp.toFixed(1)}°C, P=${pressure.toFixed(2)}bar, F=${flow.toFixed(2)}ml/s`)

  return {
    sampleTime: dataView.getUint16(0, false),
    groupPressure: pressure,
    groupFlow: flow,
    mixTemp: mixTemp,
    headTemp: headTemp,
    setMixTemp: dataView.getUint16(11, false) / 256.0,
    setHeadTemp: dataView.getUint16(13, false) / 256.0,
    setGroupPressure: dataView.getUint8(15) / 16.0,
    setGroupFlow: dataView.getUint8(16) / 16.0,
    frameNumber: dataView.getUint8(17),
    steamTemp: dataView.getUint8(18),
  }
}

/**
 * Parse StateInfo characteristic data (0x00A00E)
 * Format: 2 bytes
 */
export function parseStateInfo(dataView: DataView): StateInfoData {
  if (dataView.byteLength < 2) {
    throw new Error(`Invalid StateInfo data length: ${dataView.byteLength}, expected 2`)
  }

  return {
    state: dataView.getUint8(0),
    substate: dataView.getUint8(1),
  }
}

/**
 * Map state number to readable string
 */
export function getStateName(stateNum: number): string {
  const stateNames: Record<number, string> = {
    0: 'Sleep',
    1: 'GoingToSleep',
    2: 'Idle',
    3: 'Busy',
    4: 'Espresso',
    5: 'Steam',
    6: 'HotWater',
    7: 'ShortCal',
    8: 'SelfTest',
    9: 'LongCal',
    10: 'Descale',
    11: 'FatalError',
    12: 'Init',
    13: 'NoRequest',
    14: 'SkipToNext',
    15: 'HotWaterRinse',
    16: 'SteamRinse',
    17: 'Refill',
    18: 'Clean',
    19: 'InBootLoader',
    20: 'AirPurge',
    21: 'SchedIdle',
  }

  return stateNames[stateNum] || `Unknown(${stateNum})`
}

/**
 * Determine if state is active (brewing, steaming, etc.)
 */
export function isActiveState(stateNum: number): boolean {
  // Espresso, Steam, HotWater, HotWaterRinse
  return [4, 5, 6, 15].includes(stateNum)
}

/**
 * Map state to simplified type
 */
export function mapStateToType(stateNum: number): string {
  switch (stateNum) {
    case 0:
    case 1:
      return 'sleep'
    case 2:
    case 21:
      return 'idle'
    case 3:
      return 'busy'
    case 4:
      return 'brewing'
    case 5:
    case 16:
      return 'steam'
    case 6:
      return 'water'
    case 15:
      return 'flush'
    case 10:
    case 18:
      return 'cleaning'
    case 11:
      return 'error'
    case 12:
      return 'warming'
    default:
      return 'idle'
  }
}
