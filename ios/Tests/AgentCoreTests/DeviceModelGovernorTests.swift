import XCTest
@testable import AgentCore

final class DeviceModelGovernorTests: XCTestCase {
    private func conditions(
        thermal: DeviceThermalCondition = .nominal,
        memory: DeviceMemoryCondition = .normal,
        battery: Int? = 80, charging: Bool = false, lowPower: Bool = false
    ) -> DeviceModelConditions {
        .init(thermal: thermal, memory: memory, batteryPercent: battery,
              isCharging: charging, lowPowerMode: lowPower)
    }

    private func descriptor(_ memory: RuntimeMemoryClass,
                            kind: LocalModelExecutionKind = .local) -> LocalModelRuntimeDescriptor {
        .init(identifier: "synthetic", modelFamily: "synthetic", executionKind: kind,
              supportedCapabilities: [.classification], maximumDataSensitivity: .publicData,
              contextBudgetClass: .compact, memoryBudgetClass: memory)
    }

    func testDefaultBalancedRejectsHighMemory() {
        let budget = DeviceModelGovernor.budget(for: conditions())
        XCTAssertEqual(budget.effectiveProfile, .balanced)
        XCTAssertEqual(budget.admit(descriptor(.moderate)), .allowed)
        XCTAssertEqual(budget.admit(descriptor(.high)), .exceedsMemoryBudget(maximum: .moderate))
    }

    func testPerformanceRequiresChargingAndNominalConditions() {
        for input in [conditions(), conditions(thermal: .fair, charging: true)] {
            XCTAssertEqual(DeviceModelGovernor.budget(for: input, requestedProfile: .performance).maximumMemoryClass, .moderate)
        }
        let budget = DeviceModelGovernor.budget(for: conditions(charging: true), requestedProfile: .performance)
        XCTAssertEqual(budget.effectiveProfile, .performance)
        XCTAssertEqual(budget.admit(descriptor(.high)), .allowed)
    }

    func testResourceConstraintsOverridePerformance() {
        let constrained = [
            conditions(thermal: .serious, charging: true),
            conditions(thermal: .unknown, charging: true),
            conditions(memory: .warning, charging: true),
            conditions(memory: .unknown, charging: true),
            conditions(battery: 20), conditions(battery: nil),
            conditions(battery: -1), conditions(battery: 101),
            conditions(charging: true, lowPower: true)
        ]
        for input in constrained {
            let budget = DeviceModelGovernor.budget(for: input, requestedProfile: .performance)
            XCTAssertEqual(budget.effectiveProfile, .eco)
            XCTAssertEqual(budget.admit(descriptor(.low)), .allowed)
            XCTAssertEqual(budget.admit(descriptor(.moderate)), .exceedsMemoryBudget(maximum: .low))
        }
    }

    func testCriticalConditionsSuspendEvenSystemModels() {
        for input in [conditions(thermal: .critical), conditions(memory: .critical)] {
            for profile in DevicePerformanceProfile.allCases {
                let budget = DeviceModelGovernor.budget(for: input, requestedProfile: profile)
                XCTAssertNil(budget.maximumMemoryClass)
                XCTAssertEqual(budget.admit(descriptor(.low, kind: .system)), .suspended)
            }
        }
    }

    func testExplicitEcoAndDelegationBoundary() {
        let budget = DeviceModelGovernor.budget(for: conditions(charging: true), requestedProfile: .eco)
        XCTAssertEqual(budget.maximumMemoryClass, .low)
        XCTAssertEqual(budget.admit(descriptor(.low, kind: .delegated)), .notLocal)
    }

    func testBatteryBoundaryAndCharging() {
        XCTAssertEqual(DeviceModelGovernor.budget(for: conditions(battery: 21)).maximumMemoryClass, .moderate)
        XCTAssertEqual(DeviceModelGovernor.budget(for: conditions(battery: 0, charging: true)).maximumMemoryClass, .moderate)
        XCTAssertNil(conditions(battery: 101).batteryPercent)
    }
}
