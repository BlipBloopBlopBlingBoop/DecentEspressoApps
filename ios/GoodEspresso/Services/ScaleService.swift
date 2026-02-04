//
//  ScaleService.swift
//  Good Espresso
//
//  BLE Scale service supporting multiple scale brands:
//  - Bookoo (Ultra, Mini, etc.)
//  - Acaia (Lunar, Pearl, Pyxis)
//  - Felicita (Arc, Incline)
//  - Decent Scale
//  - Hiroia Jimmy
//  - Timemore Black Mirror
//  - Generic BLE scales
//

import Foundation
import CoreBluetooth

// MARK: - Scale Protocol Definitions

enum ScaleBrand: String, CaseIterable, Codable {
    case bookoo = "Bookoo"
    case acaia = "Acaia"
    case felicita = "Felicita"
    case decent = "Decent"
    case hiroia = "Hiroia"
    case timemore = "Timemore"
    case skale = "Skale"
    case generic = "Generic"

    var namePrefix: [String] {
        switch self {
        case .bookoo: return ["Bookoo", "BOOKOO", "BK-"]
        case .acaia: return ["ACAIA", "LUNAR", "PEARL", "PYXIS", "Acaia"]
        case .felicita: return ["FELICITA", "Felicita", "Arc"]
        case .decent: return ["DE1-SCALE", "Decent Scale"]
        case .hiroia: return ["HIROIA", "JIMMY", "Jimmy"]
        case .timemore: return ["Timemore", "TIMEMORE", "Black Mirror"]
        case .skale: return ["SKALE", "Skale"]
        case .generic: return []
        }
    }
}

// MARK: - Scale UUIDs

struct ScaleUUIDs {
    // Bookoo Ultra
    struct Bookoo {
        static let service = CBUUID(string: "FFF0")
        static let weight = CBUUID(string: "FFF4")
        static let command = CBUUID(string: "FFF1")
        // Alternative UUIDs some Bookoo scales use
        static let serviceAlt = CBUUID(string: "181D")  // Weight Scale service
        static let weightAlt = CBUUID(string: "2A9D")   // Weight Measurement
    }

    // Acaia
    struct Acaia {
        static let service = CBUUID(string: "00001820-0000-1000-8000-00805F9B34FB")
        static let weight = CBUUID(string: "00002A80-0000-1000-8000-00805F9B34FB")
        static let command = CBUUID(string: "00002A80-0000-1000-8000-00805F9B34FB")
        // Newer Acaia scales (Lunar 2021+)
        static let serviceNew = CBUUID(string: "49535343-FE7D-4AE5-8FA9-9FAFD205E455")
        static let weightNew = CBUUID(string: "49535343-1E4D-4BD9-BA61-23C647249616")
    }

    // Felicita
    struct Felicita {
        static let service = CBUUID(string: "FFE0")
        static let weight = CBUUID(string: "FFE1")
    }

    // Decent Scale
    struct Decent {
        static let service = CBUUID(string: "0000FFF0-0000-1000-8000-00805F9B34FB")
        static let weight = CBUUID(string: "0000FFF4-0000-1000-8000-00805F9B34FB")
        static let command = CBUUID(string: "36F5")
    }

    // Hiroia Jimmy
    struct Hiroia {
        static let service = CBUUID(string: "181D")
        static let weight = CBUUID(string: "2A9D")
    }

    // Timemore Black Mirror
    struct Timemore {
        static let service = CBUUID(string: "0000FF08-0000-1000-8000-00805F9B34FB")
        static let weight = CBUUID(string: "0000FF0A-0000-1000-8000-00805F9B34FB")
        static let command = CBUUID(string: "0000FF09-0000-1000-8000-00805F9B34FB")
    }

    // Generic Weight Scale (Bluetooth SIG standard)
    struct Generic {
        static let service = CBUUID(string: "181D")       // Weight Scale Service
        static let weight = CBUUID(string: "2A9D")        // Weight Measurement
        static let feature = CBUUID(string: "2A9E")       // Weight Scale Feature
    }
}

// MARK: - Scale Data

struct ScaleData {
    var weight: Double = 0           // grams
    var unit: WeightUnit = .grams
    var isStable: Bool = false
    var batteryLevel: Int?
    var flowRate: Double?            // g/s (calculated)
    var timestamp: Date = Date()
}

enum WeightUnit: String, Codable {
    case grams = "g"
    case ounces = "oz"
}

// MARK: - Scale Service

@MainActor
class ScaleService: NSObject, ObservableObject {
    // MARK: - Published Properties
    @Published var isScanning: Bool = false
    @Published var discoveredScales: [CBPeripheral] = []
    @Published var connectedScale: CBPeripheral?
    @Published var scaleData: ScaleData = ScaleData()
    @Published var isConnected: Bool = false
    @Published var connectionError: String?
    @Published var detectedBrand: ScaleBrand = .generic

    // MARK: - Flow Rate Calculation
    private var lastWeight: Double = 0
    private var lastWeightTime: Date = Date()
    private var flowRateHistory: [Double] = []

    // MARK: - Core Bluetooth
    private var centralManager: CBCentralManager!
    private var characteristics: [CBUUID: CBCharacteristic] = [:]

    // MARK: - Callbacks
    var onWeightUpdate: ((Double) -> Void)?

    // MARK: - Initialization
    override init() {
        super.init()
        centralManager = CBCentralManager(delegate: self, queue: .main)
    }

    // MARK: - Public Methods

    func startScanning() {
        guard centralManager.state == .poweredOn else {
            connectionError = "Bluetooth is not available"
            return
        }

        discoveredScales.removeAll()
        isScanning = true
        print("[ScaleService] Starting scan for BLE scales...")

        // Scan for all services since scales use various UUIDs
        centralManager.scanForPeripherals(
            withServices: nil,
            options: [CBCentralManagerScanOptionAllowDuplicatesKey: false]
        )

        // Stop after 15 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 15) { [weak self] in
            if self?.isScanning == true {
                self?.stopScanning()
            }
        }
    }

    func stopScanning() {
        centralManager.stopScan()
        isScanning = false
    }

    func connect(to peripheral: CBPeripheral) {
        stopScanning()
        connectedScale = peripheral
        peripheral.delegate = self
        centralManager.connect(peripheral, options: nil)
        print("[ScaleService] Connecting to: \(peripheral.name ?? "Unknown")")
    }

    func disconnect() {
        if let scale = connectedScale {
            centralManager.cancelPeripheralConnection(scale)
        }
        connectedScale = nil
        characteristics.removeAll()
        isConnected = false
        scaleData = ScaleData()
    }

    func tare() {
        sendCommand(.tare)
    }

    func startTimer() {
        sendCommand(.startTimer)
    }

    func stopTimer() {
        sendCommand(.stopTimer)
    }

    func resetTimer() {
        sendCommand(.resetTimer)
    }

    // MARK: - Scale Commands

    private enum ScaleCommand {
        case tare
        case startTimer
        case stopTimer
        case resetTimer
        case setUnit(WeightUnit)

        func data(for brand: ScaleBrand) -> Data? {
            switch brand {
            case .bookoo:
                return bookooCommand()
            case .acaia:
                return acaiaCommand()
            case .felicita:
                return felicitaCommand()
            case .decent:
                return decentCommand()
            case .timemore:
                return timemoreCommand()
            default:
                return genericCommand()
            }
        }

        private func bookooCommand() -> Data? {
            switch self {
            case .tare:
                return Data([0x07, 0x00])  // Tare command
            case .startTimer:
                return Data([0x08, 0x00])
            case .stopTimer:
                return Data([0x09, 0x00])
            case .resetTimer:
                return Data([0x0A, 0x00])
            case .setUnit(let unit):
                return Data([0x0B, unit == .grams ? 0x00 : 0x01])
            }
        }

        private func acaiaCommand() -> Data? {
            // Acaia uses a more complex protocol with headers
            switch self {
            case .tare:
                return Data([0xEF, 0xDD, 0x04, 0x00, 0x00, 0x00, 0x00, 0x00])
            case .startTimer:
                return Data([0xEF, 0xDD, 0x0D, 0x00, 0x00, 0x00, 0x00, 0x00])
            case .stopTimer:
                return Data([0xEF, 0xDD, 0x0D, 0x02, 0x00, 0x00, 0x00, 0x00])
            case .resetTimer:
                return Data([0xEF, 0xDD, 0x0D, 0x01, 0x00, 0x00, 0x00, 0x00])
            case .setUnit(let unit):
                return Data([0xEF, 0xDD, 0x0B, unit == .grams ? 0x02 : 0x05, 0x00, 0x00, 0x00, 0x00])
            }
        }

        private func felicitaCommand() -> Data? {
            switch self {
            case .tare:
                return Data([0x54])  // 'T' for tare
            case .startTimer:
                return Data([0x52])  // 'R' for run timer
            case .stopTimer:
                return Data([0x53])  // 'S' for stop
            case .resetTimer:
                return Data([0x43])  // 'C' for clear
            case .setUnit:
                return nil  // Not supported via command
            }
        }

        private func decentCommand() -> Data? {
            switch self {
            case .tare:
                return Data([0x07])
            case .startTimer:
                return Data([0x0D, 0x00])
            case .stopTimer:
                return Data([0x0D, 0x02])
            case .resetTimer:
                return Data([0x0D, 0x01])
            case .setUnit:
                return nil
            }
        }

        private func timemoreCommand() -> Data? {
            switch self {
            case .tare:
                return Data([0x03, 0x0A, 0x01, 0x00, 0x00, 0x08])
            case .startTimer:
                return Data([0x03, 0x0A, 0x04, 0x00, 0x00, 0x0B])
            case .stopTimer:
                return Data([0x03, 0x0A, 0x05, 0x00, 0x00, 0x0C])
            case .resetTimer:
                return Data([0x03, 0x0A, 0x06, 0x00, 0x00, 0x0D])
            case .setUnit:
                return nil
            }
        }

        private func genericCommand() -> Data? {
            // Generic scales may not support commands
            return nil
        }
    }

    private func sendCommand(_ command: ScaleCommand) {
        guard let commandChar = findCommandCharacteristic(),
              let data = command.data(for: detectedBrand),
              let peripheral = connectedScale else {
            print("[ScaleService] Cannot send command - no command characteristic or peripheral")
            return
        }

        peripheral.writeValue(data, for: commandChar, type: .withResponse)
        print("[ScaleService] Sent command: \(command)")
    }

    private func findCommandCharacteristic() -> CBCharacteristic? {
        switch detectedBrand {
        case .bookoo:
            return characteristics[ScaleUUIDs.Bookoo.command]
        case .acaia:
            return characteristics[ScaleUUIDs.Acaia.command] ?? characteristics[ScaleUUIDs.Acaia.weightNew]
        case .felicita:
            return characteristics[ScaleUUIDs.Felicita.weight]  // Felicita uses same char for read/write
        case .decent:
            return characteristics[ScaleUUIDs.Decent.command]
        case .timemore:
            return characteristics[ScaleUUIDs.Timemore.command]
        default:
            return nil
        }
    }

    // MARK: - Weight Parsing

    private func parseWeight(from data: Data) {
        var weight: Double = 0
        var isStable = false

        switch detectedBrand {
        case .bookoo:
            (weight, isStable) = parseBookooWeight(data)
        case .acaia:
            (weight, isStable) = parseAcaiaWeight(data)
        case .felicita:
            (weight, isStable) = parseFelicitaWeight(data)
        case .decent:
            (weight, isStable) = parseDecentWeight(data)
        case .hiroia:
            (weight, isStable) = parseHiroiaWeight(data)
        case .timemore:
            (weight, isStable) = parseTimemoreWeight(data)
        default:
            (weight, isStable) = parseGenericWeight(data)
        }

        // Calculate flow rate
        let now = Date()
        let timeDelta = now.timeIntervalSince(lastWeightTime)
        if timeDelta > 0.05 && timeDelta < 1.0 {  // 50ms to 1s
            let flowRate = (weight - lastWeight) / timeDelta
            flowRateHistory.append(flowRate)
            if flowRateHistory.count > 5 {
                flowRateHistory.removeFirst()
            }
            scaleData.flowRate = flowRateHistory.reduce(0, +) / Double(flowRateHistory.count)
        }

        lastWeight = weight
        lastWeightTime = now

        scaleData.weight = weight
        scaleData.isStable = isStable
        scaleData.timestamp = now

        // Callback for integration with machine store
        onWeightUpdate?(weight)
    }

    private func parseBookooWeight(_ data: Data) -> (Double, Bool) {
        // BOOKOO Ultra protocol on FFF4 characteristic:
        // Byte 0: Message type header (0x03 = weight data)
        // Byte 1: Sign (0x00 = positive, 0x01 = negative)
        // Byte 2: Weight low byte  (little-endian)
        // Byte 3: Weight high byte (little-endian)
        // Byte 4: Unit indicator
        // Byte 5: Stability flags
        guard data.count >= 6 else { return (0, false) }

        // Only parse weight notifications (header 0x03);
        // ignore battery, timer, and other notification types
        guard data[0] == 0x03 else { return (scaleData.weight, scaleData.isStable) }

        let sign: Double = data[1] == 0x00 ? 1.0 : -1.0
        let weightRaw = UInt16(data[2]) | (UInt16(data[3]) << 8)  // Little-endian
        let weight = sign * Double(weightRaw) / 10.0
        let isStable = (data[5] & 0x01) != 0

        return (weight, isStable)
    }

    private func parseAcaiaWeight(_ data: Data) -> (Double, Bool) {
        guard data.count >= 6 else { return (0, false) }

        // Acaia format: [header][type][weight bytes][unit][stable]
        // New format uses different structure
        if data[0] == 0xEF && data[1] == 0xDD {
            // Old Acaia protocol
            let weightRaw = Int(data[4]) << 8 | Int(data[5])
            let weight = Double(weightRaw) / 10.0
            let isStable = (data[2] & 0x01) != 0
            return (weight, isStable)
        } else {
            // Newer protocol (Lunar 2021+)
            guard data.count >= 7 else { return (0, false) }
            let weightRaw = Int(data[3]) << 16 | Int(data[4]) << 8 | Int(data[5])
            var weight = Double(weightRaw) / 100.0
            if (data[6] & 0x02) != 0 {
                weight = -weight
            }
            let isStable = (data[6] & 0x01) != 0
            return (weight, isStable)
        }
    }

    private func parseFelicitaWeight(_ data: Data) -> (Double, Bool) {
        guard data.count >= 6 else { return (0, false) }

        // Felicita sends ASCII weight string
        let weightString = String(data: data.prefix(6), encoding: .ascii) ?? "0"
        let cleanedString = weightString.trimmingCharacters(in: .whitespaces)
        let weight = Double(cleanedString) ?? 0
        let isStable = data.count > 6 ? (data[6] == 0x53) : false  // 'S' for stable

        return (weight, isStable)
    }

    private func parseDecentWeight(_ data: Data) -> (Double, Bool) {
        guard data.count >= 2 else { return (0, false) }

        // Decent scale format
        let weightRaw = Int(data[0]) << 8 | Int(data[1])
        let weight = Double(weightRaw) / 10.0
        let isStable = data.count > 2 ? (data[2] & 0x01) != 0 : false

        return (weight, isStable)
    }

    private func parseHiroiaWeight(_ data: Data) -> (Double, Bool) {
        // Hiroia uses Bluetooth SIG standard weight measurement
        return parseGenericWeight(data)
    }

    private func parseTimemoreWeight(_ data: Data) -> (Double, Bool) {
        guard data.count >= 6 else { return (0, false) }

        // Timemore format: [header][weight_3][weight_2][weight_1][weight_0][flags]
        let weightRaw = Int(data[1]) << 24 | Int(data[2]) << 16 | Int(data[3]) << 8 | Int(data[4])
        var weight = Double(weightRaw) / 10.0

        // Check for negative
        if (data[5] & 0x80) != 0 {
            weight = -weight
        }
        let isStable = (data[5] & 0x01) != 0

        return (weight, isStable)
    }

    private func parseGenericWeight(_ data: Data) -> (Double, Bool) {
        // Bluetooth SIG Weight Measurement characteristic (0x2A9D)
        guard data.count >= 3 else { return (0, false) }

        let flags = data[0]
        let isImperial = (flags & 0x01) != 0

        // Weight is stored as uint16 in 0.005kg (5g) or 0.01lb units
        let weightRaw = UInt16(data[1]) | (UInt16(data[2]) << 8)
        var weight: Double

        if isImperial {
            weight = Double(weightRaw) * 0.01 * 453.592  // Convert lb to g
        } else {
            weight = Double(weightRaw) * 5.0  // 5g resolution, convert to g
        }

        // Check for finer resolution if available
        if data.count >= 5 {
            let fineWeight = UInt16(data[3]) | (UInt16(data[4]) << 8)
            weight = Double(fineWeight) / 10.0  // 0.1g resolution
        }

        let isStable = (flags & 0x20) != 0

        return (weight, isStable)
    }

    // MARK: - Brand Detection

    private func detectBrand(from peripheral: CBPeripheral) -> ScaleBrand {
        guard let name = peripheral.name?.uppercased() else { return .generic }

        for brand in ScaleBrand.allCases {
            for prefix in brand.namePrefix {
                if name.contains(prefix.uppercased()) {
                    return brand
                }
            }
        }

        return .generic
    }
}

// MARK: - CBCentralManagerDelegate

extension ScaleService: CBCentralManagerDelegate {
    nonisolated func centralManagerDidUpdateState(_ central: CBCentralManager) {
        Task { @MainActor in
            switch central.state {
            case .poweredOn:
                print("[ScaleService] Bluetooth powered on")
            case .poweredOff:
                connectionError = "Bluetooth is turned off"
            case .unauthorized:
                connectionError = "Bluetooth permission denied"
            case .unsupported:
                connectionError = "Bluetooth not supported"
            default:
                break
            }
        }
    }

    nonisolated func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral,
                                    advertisementData: [String: Any], rssi RSSI: NSNumber) {
        Task { @MainActor in
            guard let name = peripheral.name else { return }

            // Check if it's a known scale brand
            let brand = detectBrand(from: peripheral)
            if brand != .generic {
                print("[ScaleService] ✓ Found \(brand.rawValue) scale: \(name)")
                if !discoveredScales.contains(where: { $0.identifier == peripheral.identifier }) {
                    discoveredScales.append(peripheral)
                }
                return
            }

            // Also check advertised services for generic weight scale service
            let services = advertisementData[CBAdvertisementDataServiceUUIDsKey] as? [CBUUID] ?? []
            if services.contains(ScaleUUIDs.Generic.service) ||
               services.contains(ScaleUUIDs.Bookoo.service) ||
               services.contains(ScaleUUIDs.Acaia.service) {
                print("[ScaleService] ✓ Found scale by service: \(name)")
                if !discoveredScales.contains(where: { $0.identifier == peripheral.identifier }) {
                    discoveredScales.append(peripheral)
                }
            }
        }
    }

    nonisolated func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        Task { @MainActor in
            print("[ScaleService] Connected to: \(peripheral.name ?? "Unknown")")
            detectedBrand = detectBrand(from: peripheral)
            print("[ScaleService] Detected brand: \(detectedBrand.rawValue)")

            // Discover services
            peripheral.discoverServices(nil)
        }
    }

    nonisolated func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        Task { @MainActor in
            connectionError = error?.localizedDescription ?? "Failed to connect"
            isConnected = false
        }
    }

    nonisolated func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        Task { @MainActor in
            print("[ScaleService] Disconnected from: \(peripheral.name ?? "Unknown")")
            isConnected = false
            connectedScale = nil
        }
    }
}

// MARK: - CBPeripheralDelegate

extension ScaleService: CBPeripheralDelegate {
    nonisolated func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        Task { @MainActor in
            guard let services = peripheral.services else { return }

            for service in services {
                print("[ScaleService] Found service: \(service.uuid)")
                peripheral.discoverCharacteristics(nil, for: service)
            }
        }
    }

    nonisolated func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        Task { @MainActor in
            guard let characteristics = service.characteristics else { return }

            for char in characteristics {
                self.characteristics[char.uuid] = char
                print("[ScaleService] Found characteristic: \(char.uuid)")

                // Subscribe to weight notifications
                if char.properties.contains(.notify) {
                    peripheral.setNotifyValue(true, for: char)
                    print("[ScaleService] Subscribed to: \(char.uuid)")
                }
            }

            isConnected = true
            connectionError = nil
        }
    }

    nonisolated func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        Task { @MainActor in
            guard let data = characteristic.value, !data.isEmpty else { return }

            // Parse weight data
            parseWeight(from: data)
        }
    }
}
