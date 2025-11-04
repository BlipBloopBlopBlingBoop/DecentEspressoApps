# Decent Espresso Bluetooth Protocol Documentation

**Extracted from official Decent TCL source files**

## Primary Service

**Service UUID**: `0000A000-0000-1000-8000-00805F9B34FB`

## Characteristics

| UUID | Name | Access | Purpose |
|------|------|--------|---------|
| 0000A001 | Version | Read | Firmware version info |
| **0000A002** | **RequestedState** | Write | **Send commands (start/stop)** |
| 0000A005 | ReadFromMMR | Read | Memory-mapped register read |
| 0000A006 | WriteToMMR | Write | Memory-mapped register write |
| 0000A009 | FWMapRequest | Read/Write | Firmware map request |
| 0000A00A | Temperatures | Read | Temperature readings |
| 0000A00B | ShotSettings | Read | Current shot configuration |
| 0000A00C | DeprecatedShotDesc | Deprecated | Old shot descriptor |
| **0000A00D** | **ShotSample** | **Notify** | **Real-time shot data** |
| **0000A00E** | **StateInfo** | **Notify** | **Machine state changes** |
| 0000A00F | HeaderWrite | Write | Profile header write |
| 0000A010 | FrameWrite | Write | Profile frame write |
| 0000A011 | WaterLevels | Read | Water tank levels |
| 0000A012 | Calibration | Read/Write | Calibration settings |

## Critical Characteristics for Real-Time Control

###  1. ShotSample (0000A00D) - ENABLE NOTIFICATIONS

**Purpose**: Provides real-time sensor data during operation

**Data Format** (19 bytes, Big-Endian):

```
Offset | Size | Type    | Name             | Conversion          | Units
-------|------|---------|------------------|---------------------|-------
0      | 2    | uint16  | SampleTime       | raw                 | ticks
2      | 2    | uint16  | GroupPressure    | value / 4096.0      | bar
4      | 2    | uint16  | GroupFlow        | value / 4096.0      | ml/s
6      | 2    | uint16  | MixTemp          | value / 256.0       | °C
8      | 3    | uint24  | HeadTemp         | special (see below) | °C
11     | 2    | uint16  | SetMixTemp       | value / 256.0       | °C
13     | 2    | uint16  | SetHeadTemp      | value / 256.0       | °C
15     | 1    | uint8   | SetGroupPressure | value / 16.0        | bar
16     | 1    | uint8   | SetGroupFlow     | value / 16.0        | ml/s
17     | 1    | uint8   | FrameNumber      | raw                 | #
18     | 1    | uint8   | SteamTemp        | raw                 | °C
```

**HeadTemp Decoding** (24-bit):
```typescript
const byte1 = dataView.getUint8(8);
const byte2 = dataView.getUint8(9);
const byte3 = dataView.getUint8(10);
const headTempRaw = (byte1 << 16) | (byte2 << 8) | byte3;
const headTemp = headTempRaw / 256.0;
```

**Update Frequency**: ~100-120 Hz during operation (line frequency * 2)

### 2. StateInfo (0000A00E) - ENABLE NOTIFICATIONS

**Purpose**: Notifies state changes

**Data Format** (2 bytes):

```
Offset | Size | Type  | Name     | Values
-------|------|-------|----------|------------------
0      | 1    | uint8 | State    | See State Enum
1      | 1    | uint8 | SubState | See SubState Enum
```

**State Enum**:
```typescript
enum MachineState {
  Sleep = 0,
  GoingToSleep = 1,
  Idle = 2,
  Busy = 3,
  Espresso = 4,
  Steam = 5,
  HotWater = 6,
  ShortCal = 7,
  SelfTest = 8,
  LongCal = 9,
  Descale = 10,
  FatalError = 11,
  Init = 12,
  NoRequest = 13,
  SkipToNext = 14,
  HotWaterRinse = 15,
  SteamRinse = 16,
  Refill = 17,
  Clean = 18,
  InBootLoader = 19,
  AirPurge = 20,
  SchedIdle = 21
}
```

### 3. RequestedState (0000A002) - WRITE COMMANDS

**Purpose**: Send commands to control the machine

**Data Format**: Single byte command

**Commands**:
```typescript
enum DecentCommand {
  SLEEP = 0x00,
  GO_TO_SLEEP = 0x01,
  IDLE = 0x02,
  BUSY = 0x03,
  ESPRESSO = 0x04,      // Start espresso
  STEAM = 0x05,          // Start steam
  HOT_WATER = 0x06,      // Start hot water
  SHORT_CAL = 0x07,
  SELF_TEST = 0x08,
  LONG_CAL = 0x09,
  DESCALE = 0x0A,
  FATAL_ERROR = 0x0B,
  INIT = 0x0C,
  NO_REQUEST = 0x0D,
  SKIP_TO_NEXT = 0x0E,
  HOT_WATER_RINSE = 0x0F,  // Flush
  STEAM_RINSE = 0x10,
  REFILL = 0x11,
  CLEAN = 0x12,
  IN_BOOTLOADER = 0x13,
  AIR_PURGE = 0x14,
  SCHED_IDLE = 0x15
}
```

**Usage**:
```typescript
// Start espresso
await characteristic.writeValue(new Uint8Array([0x04]));

// Stop (go to idle)
await characteristic.writeValue(new Uint8Array([0x02]));

// Start steam
await characteristic.writeValue(new Uint8Array([0x05]));

// Flush
await characteristic.writeValue(new Uint8Array([0x0F]));
```

## Connection Sequence

1. **Connect to device** with name prefix `DE1`
2. **Get primary service**: `0000A000-0000-1000-8000-00805F9B34FB`
3. **Get characteristics**: A002 (commands), A00D (shot data), A00E (state)
4. **Enable notifications** on A00D and A00E
5. **Listen for updates** and parse according to formats above

## Data Parsing Example

```typescript
function parseShotSample(dataView: DataView) {
  return {
    sampleTime: dataView.getUint16(0, false), // big-endian
    groupPressure: dataView.getUint16(2, false) / 4096.0,
    groupFlow: dataView.getUint16(4, false) / 4096.0,
    mixTemp: dataView.getUint16(6, false) / 256.0,
    headTemp: parseHeadTemp(dataView),
    setMixTemp: dataView.getUint16(11, false) / 256.0,
    setHeadTemp: dataView.getUint16(13, false) / 256.0,
    setGroupPressure: dataView.getUint8(15) / 16.0,
    setGroupFlow: dataView.getUint8(16) / 16.0,
    frameNumber: dataView.getUint8(17),
    steamTemp: dataView.getUint8(18)
  };
}

function parseHeadTemp(dataView: DataView): number {
  const byte1 = dataView.getUint8(8);
  const byte2 = dataView.getUint8(9);
  const byte3 = dataView.getUint8(10);
  const rawValue = (byte1 << 16) | (byte2 << 8) | byte3;
  return rawValue / 256.0;
}

function parseStateInfo(dataView: DataView) {
  return {
    state: dataView.getUint8(0),
    substate: dataView.getUint8(1)
  };
}
```

## Important Notes

- **All multi-byte values are BIG-ENDIAN** (network byte order)
- **ShotSample updates at ~100-120 Hz** during active operations
- **Always enable notifications** on A00D and A00E for real-time updates
- **HeadTemp is 24-bit** (3 bytes) requiring special parsing
- **Commands are single bytes** written to A002 characteristic

## Source Files Analyzed

- `machine.tcl` - UUID definitions
- `binary.tcl` - Data structure specifications
- `de1_de1.tcl` - Parsing implementations
- `de1_comms.tcl` - Communication logic
- `bluetooth.tcl` - BLE operations

---

*Last Updated: 2025-11-04*
*Source: Decent Espresso Official TCL Application*
