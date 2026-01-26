//
//  BluetoothService.swift
//  Good Espresso
//
//  CoreBluetooth service for communicating with Decent espresso machines
//

import Foundation
import CoreBluetooth
import SwiftUI

@MainActor
class BluetoothService: NSObject, ObservableObject {
    // MARK: - Published Properties
    @Published var isScanning: Bool = false
    @Published var discoveredDevices: [CBPeripheral] = []

    // MARK: - Core Bluetooth
    private var centralManager: CBCentralManager!
    private var connectedPeripheral: CBPeripheral?
    private var characteristics: [CBUUID: CBCharacteristic] = [:]

    // MARK: - Reference to Machine Store
    weak var machineStore: MachineStore?

    // MARK: - GATT Queue for sequential writes
    private var writeQueue: [() async -> Void] = []
    private var isProcessingQueue = false

    // MARK: - Initialization
    override init() {
        super.init()
        centralManager = CBCentralManager(delegate: self, queue: .main)
    }

    // MARK: - Public Methods

    /// Start scanning for Decent espresso machines
    func startScanning() {
        guard centralManager.state == .poweredOn else {
            machineStore?.setConnectionError("Bluetooth is not available")
            return
        }

        discoveredDevices.removeAll()
        isScanning = true
        centralManager.scanForPeripherals(
            withServices: [DecentUUIDs.serviceUUID],
            options: [CBCentralManagerScanOptionAllowDuplicatesKey: false]
        )

        // Also scan without service filter to catch devices that don't advertise the service
        centralManager.scanForPeripherals(
            withServices: nil,
            options: [CBCentralManagerScanOptionAllowDuplicatesKey: false]
        )

        // Stop scanning after 10 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 10) { [weak self] in
            self?.stopScanning()
        }
    }

    /// Stop scanning
    func stopScanning() {
        centralManager.stopScan()
        isScanning = false
    }

    /// Connect to a specific peripheral
    func connect(to peripheral: CBPeripheral) {
        stopScanning()
        machineStore?.setConnecting(true)

        connectedPeripheral = peripheral
        peripheral.delegate = self
        centralManager.connect(peripheral, options: nil)
    }

    /// Disconnect from the current peripheral
    func disconnect() {
        if let peripheral = connectedPeripheral {
            centralManager.cancelPeripheralConnection(peripheral)
        }
        connectedPeripheral = nil
        characteristics.removeAll()
        machineStore?.reset()
    }

    /// Send a command to the machine
    func sendCommand(_ command: DecentCommand, data: Data? = nil) async throws {
        guard let characteristic = characteristics[DecentUUIDs.requestedState] else {
            throw BluetoothError.characteristicNotFound
        }

        var commandData = Data([command.rawValue])
        if let additionalData = data {
            commandData.append(additionalData)
        }

        try await writeValue(commandData, for: characteristic)
        print("[BluetoothService] Command sent: \(command)")
    }

    /// Start espresso extraction
    func startEspresso() async throws {
        // Upload active profile first if available
        if let recipe = machineStore?.activeRecipe {
            try await uploadProfile(recipe)
        }

        try await sendCommand(.espresso)

        // Start shot recording
        await MainActor.run {
            machineStore?.startShot(
                profileName: machineStore?.activeRecipe?.name ?? "Manual",
                profileId: machineStore?.activeRecipe?.id
            )
        }
    }

    /// Stop current operation
    func stop() async throws {
        try await sendCommand(.idle)

        await MainActor.run {
            if machineStore?.isRecording == true {
                machineStore?.endShot()
            }
        }
    }

    /// Start steam mode
    func startSteam() async throws {
        try await sendCommand(.steam)
    }

    /// Start flush/rinse
    func startFlush() async throws {
        try await sendCommand(.hotWaterRinse)
    }

    /// Start hot water dispense
    func startHotWater() async throws {
        try await sendCommand(.hotWater)
    }

    // MARK: - Profile Upload

    /// Upload a complete profile to the machine
    func uploadProfile(_ profile: Recipe) async throws {
        guard let headerChar = characteristics[DecentUUIDs.headerWrite],
              let frameChar = characteristics[DecentUUIDs.frameWrite] else {
            throw BluetoothError.characteristicNotFound
        }

        print("[BluetoothService] Uploading profile: \(profile.name)")

        // Write header
        let headerData = encodeProfileHeader(profile)
        try await writeValue(headerData, for: headerChar)
        print("[BluetoothService] Header written")

        // Write each frame
        for (index, step) in profile.steps.enumerated() {
            let frameData = encodeProfileFrame(step, frameNumber: index)
            try await writeValue(frameData, for: frameChar)
            print("[BluetoothService] Frame \(index) written")
        }

        // Write tail
        let tailData = encodeProfileTail(frameCount: profile.steps.count)
        try await writeValue(tailData, for: frameChar)
        print("[BluetoothService] Tail written - Profile upload complete")
    }

    // MARK: - Profile Encoding

    private func encodeProfileHeader(_ profile: Recipe) -> Data {
        var data = Data(count: 5)

        // Byte 0: Header version
        data[0] = 0x01

        // Byte 1: Number of frames
        data[1] = UInt8(min(profile.steps.count, 255))

        // Byte 2: Number of preinfusion frames
        var preinfuseFrames: UInt8 = 0
        if let firstStep = profile.steps.first {
            if firstStep.pressure <= 4 && firstStep.flow <= 3 {
                preinfuseFrames = 1
            }
        }
        data[2] = preinfuseFrames

        // Byte 3: Minimum pressure (0 = no minimum)
        data[3] = 0x00

        // Byte 4: Maximum flow (6.0 ml/s * 16 = 96)
        data[4] = UInt8(min(6.0 * 16, 255))

        return data
    }

    private func encodeProfileFrame(_ step: ProfileStep, frameNumber: Int) -> Data {
        var data = Data(count: 8)

        // Byte 0: Frame number
        data[0] = UInt8(frameNumber)

        // Byte 1: Flags
        let isFlowControl = step.pressure == 0 && step.flow > 0
        var flag: UInt8 = 0x00

        if isFlowControl {
            flag |= 0x01  // CtrlF - Flow priority
        }

        flag |= 0x10  // TMixTemp - Target mixer temperature

        if step.transition == "smooth" {
            flag |= 0x20  // Interpolate
        }

        flag |= 0x40  // IgnoreLimit

        // Exit condition flags
        var triggerVal: UInt8 = 0
        switch step.exit.type {
        case .pressure:
            flag |= 0x02  // DoCompare
            flag |= 0x04  // DC_GT
            triggerVal = UInt8(min(step.exit.value * 16, 255))
        case .flow:
            flag |= 0x02  // DoCompare
            flag |= 0x04  // DC_GT
            flag |= 0x08  // DC_CompF
            triggerVal = UInt8(min(step.exit.value * 16, 255))
        default:
            break
        }

        data[1] = flag

        // Byte 2: SetVal (pressure or flow)
        let setVal = isFlowControl ? step.flow : step.pressure
        data[2] = UInt8(min(setVal * 16, 255))

        // Byte 3: Temperature (scaled * 2)
        data[3] = UInt8(min(step.temperature * 2, 255))

        // Byte 4: Frame duration (F8_1_7 format)
        var duration = step.exit.value
        if step.exit.type == .weight {
            // Estimate time from weight
            duration = estimateTimeFromWeight(step.exit.value, flow: step.flow)
        } else if step.exit.type == .pressure || step.exit.type == .flow {
            duration = 60  // Max timeout
        }
        data[4] = convertToF8_1_7(duration)

        // Byte 5: Trigger value
        data[5] = triggerVal

        // Bytes 6-7: Max volume (0 = no limit)
        data[6] = 0x00
        data[7] = 0x00

        return data
    }

    private func encodeProfileTail(frameCount: Int) -> Data {
        var data = Data(count: 8)
        data[0] = UInt8(frameCount)
        // Remaining bytes are 0 (padding)
        return data
    }

    private func estimateTimeFromWeight(_ weight: Double, flow: Double) -> Double {
        guard flow > 0 else { return 30 }
        let baseTime = weight / flow
        return max(baseTime * 1.3, 15)
    }

    private func convertToF8_1_7(_ value: Double) -> UInt8 {
        if value >= 12.75 {
            let intVal = min(Int(round(value)), 127)
            return UInt8(intVal | 128)
        } else {
            return UInt8(min(Int(round(value * 10)), 127))
        }
    }

    // MARK: - Low-level Write

    private func writeValue(_ data: Data, for characteristic: CBCharacteristic) async throws {
        guard let peripheral = connectedPeripheral else {
            throw BluetoothError.notConnected
        }

        return try await withCheckedThrowingContinuation { continuation in
            peripheral.writeValue(data, for: characteristic, type: .withResponse)
            // Note: In a production app, you'd want to track the write completion
            // through peripheral(_:didWriteValueFor:error:) delegate method
            // For simplicity, we'll just wait a short time
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                continuation.resume()
            }
        }
    }

    // MARK: - Data Parsing

    private func parseShotSample(_ data: Data) -> (pressure: Double, flow: Double, mixTemp: Double, headTemp: Double, steamTemp: Double) {
        guard data.count >= 19 else {
            return (0, 0, 0, 0, 0)
        }

        let pressure = Double(UInt16(data[2]) << 8 | UInt16(data[3])) / 4096.0
        let flow = Double(UInt16(data[4]) << 8 | UInt16(data[5])) / 4096.0
        let mixTemp = Double(UInt16(data[6]) << 8 | UInt16(data[7])) / 256.0

        // Head temp is 3 bytes
        let headTempRaw = (UInt32(data[8]) << 16) | (UInt32(data[9]) << 8) | UInt32(data[10])
        let headTemp = Double(headTempRaw) / 256.0

        let steamTemp = Double(data[18])

        return (pressure, flow, mixTemp, headTemp, steamTemp)
    }

    private func parseStateInfo(_ data: Data) -> (state: UInt8, substate: UInt8) {
        guard data.count >= 2 else {
            return (0, 0)
        }
        return (data[0], data[1])
    }

    private func mapStateToType(_ state: UInt8) -> MachineStateType {
        switch state {
        case 0x00, 0x01: return .sleep
        case 0x02: return .idle
        case 0x03: return .warming
        case 0x04: return .brewing
        case 0x05: return .steam
        case 0x06: return .flush
        case 0x0A: return .cleaning
        case 0x0B: return .error
        default: return .idle
        }
    }
}

// MARK: - CBCentralManagerDelegate
extension BluetoothService: CBCentralManagerDelegate {
    nonisolated func centralManagerDidUpdateState(_ central: CBCentralManager) {
        Task { @MainActor in
            switch central.state {
            case .poweredOn:
                print("[BluetoothService] Bluetooth powered on")
            case .poweredOff:
                machineStore?.setConnectionError("Bluetooth is turned off")
            case .unauthorized:
                machineStore?.setConnectionError("Bluetooth permission denied")
            case .unsupported:
                machineStore?.setConnectionError("Bluetooth not supported on this device")
            default:
                break
            }
        }
    }

    nonisolated func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral,
                        advertisementData: [String: Any], rssi RSSI: NSNumber) {
        Task { @MainActor in
            // Filter for Decent machines by name
            if let name = peripheral.name, name.hasPrefix("DE1") {
                if !discoveredDevices.contains(where: { $0.identifier == peripheral.identifier }) {
                    discoveredDevices.append(peripheral)
                    print("[BluetoothService] Discovered: \(name)")
                }
            }
        }
    }

    nonisolated func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        Task { @MainActor in
            print("[BluetoothService] Connected to: \(peripheral.name ?? "Unknown")")
            peripheral.discoverServices([DecentUUIDs.serviceUUID])
        }
    }

    nonisolated func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        Task { @MainActor in
            machineStore?.setConnectionError(error?.localizedDescription ?? "Failed to connect")
        }
    }

    nonisolated func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        Task { @MainActor in
            print("[BluetoothService] Disconnected from: \(peripheral.name ?? "Unknown")")
            machineStore?.reset()
        }
    }
}

// MARK: - CBPeripheralDelegate
extension BluetoothService: CBPeripheralDelegate {
    nonisolated func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        Task { @MainActor in
            if let error = error {
                machineStore?.setConnectionError(error.localizedDescription)
                return
            }

            guard let services = peripheral.services else { return }

            for service in services {
                if service.uuid == DecentUUIDs.serviceUUID {
                    peripheral.discoverCharacteristics(nil, for: service)
                }
            }
        }
    }

    nonisolated func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        Task { @MainActor in
            if let error = error {
                machineStore?.setConnectionError(error.localizedDescription)
                return
            }

            guard let characteristics = service.characteristics else { return }

            for characteristic in characteristics {
                self.characteristics[characteristic.uuid] = characteristic

                // Subscribe to notifications
                if characteristic.uuid == DecentUUIDs.shotSample ||
                   characteristic.uuid == DecentUUIDs.stateInfo {
                    peripheral.setNotifyValue(true, for: characteristic)
                }
            }

            // Connection complete
            machineStore?.setConnected(true, deviceName: peripheral.name)
            print("[BluetoothService] Setup complete - \(self.characteristics.count) characteristics found")
        }
    }

    nonisolated func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        Task { @MainActor in
            guard error == nil, let data = characteristic.value else { return }

            if characteristic.uuid == DecentUUIDs.shotSample {
                let sample = parseShotSample(data)

                var state = machineStore?.machineState ?? MachineState()
                state.temperature.mix = sample.mixTemp
                state.temperature.head = sample.headTemp
                state.temperature.steam = sample.steamTemp
                state.pressure = sample.pressure
                state.flow = sample.flow
                state.timestamp = Date()

                machineStore?.updateMachineState(state)

                // Record data point if brewing
                if machineStore?.isRecording == true,
                   let startTime = machineStore?.activeShot?.startTime {
                    let dataPoint = ShotDataPoint(
                        timestamp: Date().timeIntervalSince(startTime) * 1000,
                        temperature: sample.mixTemp,
                        pressure: sample.pressure,
                        flow: sample.flow,
                        weight: 0
                    )
                    machineStore?.addDataPoint(dataPoint)
                }
            } else if characteristic.uuid == DecentUUIDs.stateInfo {
                let stateInfo = parseStateInfo(data)
                let stateType = mapStateToType(stateInfo.state)

                var state = machineStore?.machineState ?? MachineState()
                let previousState = state.state
                state.state = stateType
                state.substate = String(stateInfo.substate)
                state.timestamp = Date()

                machineStore?.updateMachineState(state)

                // Auto start/stop recording
                if stateType == .brewing && previousState != .brewing && machineStore?.isRecording != true {
                    machineStore?.startShot(
                        profileName: machineStore?.activeRecipe?.name ?? "Manual",
                        profileId: machineStore?.activeRecipe?.id
                    )
                } else if previousState == .brewing && stateType != .brewing && machineStore?.isRecording == true {
                    machineStore?.endShot()
                }
            }
        }
    }
}

// MARK: - Errors
enum BluetoothError: LocalizedError {
    case notConnected
    case characteristicNotFound
    case writeFailed

    var errorDescription: String? {
        switch self {
        case .notConnected:
            return "Not connected to machine"
        case .characteristicNotFound:
            return "Required characteristic not found"
        case .writeFailed:
            return "Failed to write to machine"
        }
    }
}
