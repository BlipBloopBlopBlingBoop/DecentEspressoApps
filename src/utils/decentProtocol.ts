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

  // Parse 24-bit HeadTemp (bytes 8-10) - Big Endian, unsigned
  // The 24-bit value is spread across 3 bytes and needs proper masking
  const headTempByte1 = dataView.getUint8(8) & 0xFF
  const headTempByte2 = dataView.getUint8(9) & 0xFF
  const headTempByte3 = dataView.getUint8(10) & 0xFF
  const headTempRaw = (headTempByte1 << 16) | (headTempByte2 << 8) | headTempByte3
  // Ensure we don't overflow and scale correctly
  const headTemp = (headTempRaw & 0xFFFFFF) / 256.0

  return {
    sampleTime: dataView.getUint16(0, false),            // Big-endian
    groupPressure: dataView.getUint16(2, false) / 4096.0,
    groupFlow: dataView.getUint16(4, false) / 4096.0,
    mixTemp: dataView.getUint16(6, false) / 256.0,
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
