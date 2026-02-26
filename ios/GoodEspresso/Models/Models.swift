//
//  Models.swift
//  Good Espresso
//
//  Core data models for the Decent espresso machine controller
//

import Foundation
import CoreBluetooth
import SwiftUI

// MARK: - Navigation Tab
enum NavigationTab: String, CaseIterable, Hashable, Identifiable {
    case home = "Home"
    case profiles = "Profiles"
    case control = "Control"
    case history = "History"
    case analytics = "Analytics"
    case settings = "Settings"

    var id: String { rawValue }

    var label: String { rawValue }

    var systemImage: String {
        switch self {
        case .home: return "house.fill"
        case .profiles: return "list.bullet.rectangle.portrait.fill"
        case .control: return "dial.medium.fill"
        case .history: return "clock.fill"
        case .analytics: return "brain.head.profile.fill"
        case .settings: return "gearshape.fill"
        }
    }
}

// MARK: - Cross-Platform Colors
extension Color {
    #if canImport(UIKit)
    static let systemGroupedBg = Color(.systemGroupedBackground)
    static let secondarySystemGroupedBg = Color(.secondarySystemGroupedBackground)
    static let tertiarySystemGroupedBg = Color(.tertiarySystemGroupedBackground)
    static let systemBg = Color(uiColor: .systemBackground)
    #elseif canImport(AppKit)
    static let systemGroupedBg = Color(nsColor: .windowBackgroundColor)
    static let secondarySystemGroupedBg = Color(nsColor: .controlBackgroundColor)
    static let tertiarySystemGroupedBg = Color(nsColor: .underPageBackgroundColor)
    static let systemBg = Color(nsColor: .windowBackgroundColor)
    #else
    static let systemGroupedBg = Color(white: 0.0)
    static let secondarySystemGroupedBg = Color(white: 0.11)
    static let tertiarySystemGroupedBg = Color(white: 0.17)
    static let systemBg = Color(white: 0.0)
    #endif
}

// MARK: - Cross-Platform List Style
extension View {
    @ViewBuilder
    func insetGroupedListStyleCompat() -> some View {
        #if os(iOS)
        self.listStyle(.insetGrouped)
        #else
        self.listStyle(.sidebar)
        #endif
    }
}

// MARK: - Cross-Platform onChange (iOS 16 compat + macOS 14 deprecation)
extension View {
    @ViewBuilder
    func onChangeCompat<V: Equatable>(of value: V, perform action: @escaping () -> Void) -> some View {
        if #available(iOS 17.0, macOS 14.0, *) {
            self.onChange(of: value) { _, _ in
                action()
            }
        } else {
            self.onChange(of: value) { _ in
                action()
            }
        }
    }

    @ViewBuilder
    func onChangeCompat<V: Equatable>(of value: V, perform action: @escaping (V) -> Void) -> some View {
        if #available(iOS 17.0, macOS 14.0, *) {
            self.onChange(of: value) { _, newValue in
                action(newValue)
            }
        } else {
            self.onChange(of: value) { newValue in
                action(newValue)
            }
        }
    }
}

// MARK: - Cross-Platform Navigation
extension View {
    @ViewBuilder
    func inlineNavigationBarTitle() -> some View {
        #if os(iOS)
        self.navigationBarTitleDisplayMode(.inline)
        #else
        self
        #endif
    }
}

extension ToolbarItemPlacement {
    static var topBarTrailingCompat: ToolbarItemPlacement {
        #if os(iOS)
        .topBarTrailing
        #else
        .automatic
        #endif
    }

    static var topBarLeadingCompat: ToolbarItemPlacement {
        #if os(iOS)
        .topBarLeading
        #else
        .automatic
        #endif
    }
}

// MARK: - Decent Service UUIDs
struct DecentUUIDs {
    static let serviceUUID = CBUUID(string: "0000A000-0000-1000-8000-00805F9B34FB")

    // Characteristics
    static let version = CBUUID(string: "0000A001-0000-1000-8000-00805F9B34FB")
    static let requestedState = CBUUID(string: "0000A002-0000-1000-8000-00805F9B34FB")
    static let readFromMMR = CBUUID(string: "0000A005-0000-1000-8000-00805F9B34FB")
    static let writeToMMR = CBUUID(string: "0000A006-0000-1000-8000-00805F9B34FB")
    static let fwMapRequest = CBUUID(string: "0000A009-0000-1000-8000-00805F9B34FB")
    static let temperatures = CBUUID(string: "0000A00A-0000-1000-8000-00805F9B34FB")
    static let shotSettings = CBUUID(string: "0000A00B-0000-1000-8000-00805F9B34FB")
    static let shotSample = CBUUID(string: "0000A00D-0000-1000-8000-00805F9B34FB")
    static let stateInfo = CBUUID(string: "0000A00E-0000-1000-8000-00805F9B34FB")
    static let headerWrite = CBUUID(string: "0000A00F-0000-1000-8000-00805F9B34FB")
    static let frameWrite = CBUUID(string: "0000A010-0000-1000-8000-00805F9B34FB")
    static let waterLevels = CBUUID(string: "0000A011-0000-1000-8000-00805F9B34FB")
    static let calibration = CBUUID(string: "0000A012-0000-1000-8000-00805F9B34FB")
}

// MARK: - Machine Commands
enum DecentCommand: UInt8 {
    case sleep = 0x00
    case goToSleep = 0x01
    case idle = 0x02
    case busy = 0x03
    case espresso = 0x04
    case steam = 0x05
    case hotWater = 0x06
    case shortCal = 0x07
    case selfTest = 0x08
    case longCal = 0x09
    case descale = 0x0A
    case fatalError = 0x0B
    case initialize = 0x0C
    case noRequest = 0x0D
    case skipToNext = 0x0E
    case hotWaterRinse = 0x0F  // Flush
    case steamRinse = 0x10
    case refill = 0x11
    case clean = 0x12
    case inBootloader = 0x13
    case airPurge = 0x14
    case schedIdle = 0x15
}

// MARK: - Machine State
enum MachineStateType: String, Codable {
    case idle = "idle"
    case sleep = "sleep"
    case warming = "warming"
    case ready = "ready"
    case brewing = "brewing"
    case steam = "steam"
    case flush = "flush"
    case cleaning = "cleaning"
    case error = "error"
    case disconnected = "disconnected"

    var displayName: String {
        switch self {
        case .idle: return "Idle"
        case .sleep: return "Sleep"
        case .warming: return "Warming Up"
        case .ready: return "Ready"
        case .brewing: return "Brewing"
        case .steam: return "Steaming"
        case .flush: return "Flushing"
        case .cleaning: return "Cleaning"
        case .error: return "Error"
        case .disconnected: return "Disconnected"
        }
    }

    var color: String {
        switch self {
        case .idle: return "gray"
        case .sleep: return "purple"
        case .warming: return "orange"
        case .ready: return "green"
        case .brewing: return "blue"
        case .steam: return "red"
        case .flush: return "cyan"
        case .cleaning: return "yellow"
        case .error: return "red"
        case .disconnected: return "gray"
        }
    }
}

// MARK: - Temperature Data
struct TemperatureData: Codable {
    var mix: Double = 0
    var head: Double = 0
    var steam: Double = 0
    var target: Double = 93
}

// MARK: - Machine State
struct MachineState: Codable {
    var state: MachineStateType = .disconnected
    var substate: String = "0"
    var temperature: TemperatureData = TemperatureData()
    var pressure: Double = 0
    var flow: Double = 0
    var weight: Double = 0
    var timestamp: Date = Date()
}

// MARK: - Exit Condition
struct ExitCondition: Codable, Hashable {
    enum ExitType: String, Codable {
        case time
        case pressure
        case flow
        case weight
    }

    var type: ExitType
    var value: Double
}

// MARK: - Profile Step
struct ProfileStep: Codable, Hashable, Identifiable {
    var id = UUID()
    var name: String
    var temperature: Double
    var pressure: Double
    var flow: Double
    var transition: String  // "fast" or "smooth"
    var exit: ExitCondition
    var limiterValue: Double?
    var limiterRange: Double?

    enum CodingKeys: String, CodingKey {
        case name, temperature, pressure, flow, transition, exit, limiterValue, limiterRange
    }

    init(name: String, temperature: Double, pressure: Double, flow: Double,
         transition: String = "smooth", exit: ExitCondition,
         limiterValue: Double? = nil, limiterRange: Double? = nil) {
        self.name = name
        self.temperature = temperature
        self.pressure = pressure
        self.flow = flow
        self.transition = transition
        self.exit = exit
        self.limiterValue = limiterValue
        self.limiterRange = limiterRange
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.name = try container.decode(String.self, forKey: .name)
        self.temperature = try container.decode(Double.self, forKey: .temperature)
        self.pressure = try container.decode(Double.self, forKey: .pressure)
        self.flow = try container.decode(Double.self, forKey: .flow)
        self.transition = try container.decode(String.self, forKey: .transition)
        self.exit = try container.decode(ExitCondition.self, forKey: .exit)
        self.limiterValue = try container.decodeIfPresent(Double.self, forKey: .limiterValue)
        self.limiterRange = try container.decodeIfPresent(Double.self, forKey: .limiterRange)
    }
}

// MARK: - Recipe/Profile
struct Recipe: Codable, Identifiable, Hashable {
    var id: String
    var name: String
    var description: String
    var author: String
    var createdAt: Date
    var updatedAt: Date
    var favorite: Bool
    var usageCount: Int
    var targetWeight: Double
    var steps: [ProfileStep]
    var coffeeType: String?
    var notes: String?
    var dose: Double?

    static func == (lhs: Recipe, rhs: Recipe) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

// MARK: - Shot Data Point
struct ShotDataPoint: Codable, Identifiable {
    var id = UUID()
    var timestamp: TimeInterval  // Milliseconds from shot start
    var temperature: Double
    var pressure: Double
    var flow: Double
    var weight: Double

    enum CodingKeys: String, CodingKey {
        case timestamp, temperature, pressure, flow, weight
    }
}

// MARK: - Shot Record
struct ShotRecord: Codable, Identifiable {
    var id: String
    var profileId: String?
    var profileName: String
    var startTime: Date
    var endTime: Date?
    var duration: TimeInterval
    var dataPoints: [ShotDataPoint]
    var finalWeight: Double?
    var rating: Int?
    var notes: String?
    var coffeeType: String?
    var dose: Double?
    var yield: Double?
    var ratio: String?
}

// MARK: - Connection Status
struct ConnectionStatus {
    var connected: Bool = false
    var connecting: Bool = false
    var error: String?
    var lastConnected: Date?
    var deviceName: String?
}
