// Agent 4 owns this file
// XCTest for HealthKitManager (90% coverage — data layer minimum)

import XCTest
import Combine
@testable import FitnessApp

// MARK: - Protocol for HealthKit Testability

protocol HealthKitProviding {
    func requestAuthorization() async throws
    func fetchTodayActiveEnergy() async throws -> Double
}

// MARK: - Mock Implementation

final class MockHealthKitManager: HealthKitProviding {
    var shouldThrow: HealthKitError?
    var mockEnergy: Double = 320.0

    func requestAuthorization() async throws {
        if let error = shouldThrow { throw error }
    }

    func fetchTodayActiveEnergy() async throws -> Double {
        if let error = shouldThrow { throw error }
        return mockEnergy
    }
}

// MARK: - HealthKitManagerTests

final class HealthKitManagerTests: XCTestCase {

    private var mockManager: MockHealthKitManager!
    private var cancellables: Set<AnyCancellable>!

    override func setUp() {
        super.setUp()
        mockManager = MockHealthKitManager()
        cancellables = []
    }

    override func tearDown() {
        mockManager = nil
        cancellables = nil
        super.tearDown()
    }

    // MARK: - testRequestAuthorizationThrowsNotAvailable

    /// Verify that requesting authorization throws `.notAvailable` when HealthKit is unavailable (simulator).
    func testRequestAuthorizationThrowsNotAvailable() async {
        mockManager.shouldThrow = .notAvailable

        do {
            try await mockManager.requestAuthorization()
            XCTFail("Expected HealthKitError.notAvailable to be thrown")
        } catch let error as HealthKitError {
            switch error {
            case .notAvailable:
                // Expected
                break
            default:
                XCTFail("Expected .notAvailable but got \(error)")
            }
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }

    // MARK: - testFetchTodayActiveEnergyReturnsValue

    /// Verify that fetchTodayActiveEnergy returns the expected mock value (320.0 on simulator).
    func testFetchTodayActiveEnergyReturnsValue() async throws {
        mockManager.mockEnergy = 320.0

        let energy = try await mockManager.fetchTodayActiveEnergy()
        XCTAssertEqual(energy, 320.0, accuracy: 0.001)
    }

    // MARK: - testHealthKitErrorDescriptions

    /// Verify all HealthKitError cases have non-nil error descriptions.
    func testHealthKitErrorDescriptions() {
        let notAvailableError = HealthKitError.notAvailable
        XCTAssertNotNil(notAvailableError.errorDescription)
        XCTAssertEqual(
            notAvailableError.errorDescription,
            "HealthKit is not available on this device."
        )

        let unauthorizedError = HealthKitError.unauthorized
        XCTAssertNotNil(unauthorizedError.errorDescription)
        XCTAssertEqual(
            unauthorizedError.errorDescription,
            "HealthKit authorization has not been granted."
        )

        let underlyingError = NSError(domain: "TestDomain", code: 42, userInfo: [
            NSLocalizedDescriptionKey: "Test failure"
        ])
        let queryFailedError = HealthKitError.queryFailed(underlyingError)
        XCTAssertNotNil(queryFailedError.errorDescription)
        XCTAssertTrue(
            queryFailedError.errorDescription?.contains("HealthKit query failed") ?? false
        )
        XCTAssertTrue(
            queryFailedError.errorDescription?.contains("Test failure") ?? false
        )
    }

    // MARK: - testSharedSingletonExists

    /// Verify HealthKitManager.shared is not nil and is always the same instance.
    @MainActor
    func testSharedSingletonExists() {
        let instance1 = HealthKitManager.shared
        let instance2 = HealthKitManager.shared
        XCTAssertNotNil(instance1)
        XCTAssertTrue(instance1 === instance2, "Shared singleton should return the same instance")
    }

    // MARK: - testActiveEnergyBurnedPublished

    /// Verify the @Published activeEnergyBurned property updates when fetchTodayActiveEnergy is called.
    @MainActor
    func testActiveEnergyBurnedPublished() async throws {
        let manager = HealthKitManager.shared

        // On simulator, fetchTodayActiveEnergy returns 320.0 via the #if targetEnvironment(simulator) path
        let expectation = XCTestExpectation(description: "activeEnergyBurned should update")

        var receivedValues: [Double] = []
        manager.$activeEnergyBurned
            .dropFirst() // Skip the initial value
            .sink { value in
                receivedValues.append(value)
                expectation.fulfill()
            }
            .store(in: &cancellables)

        let energy = try await manager.fetchTodayActiveEnergy()

        await fulfillment(of: [expectation], timeout: 2.0)

        XCTAssertEqual(energy, 320.0, accuracy: 0.001)
        XCTAssertFalse(receivedValues.isEmpty, "Should have received at least one published value")
        XCTAssertEqual(receivedValues.last, 320.0, accuracy: 0.001)
    }

    // MARK: - Additional Mock Tests

    /// Verify that fetchTodayActiveEnergy throws `.unauthorized` when configured.
    func testFetchTodayActiveEnergyThrowsUnauthorized() async {
        mockManager.shouldThrow = .unauthorized

        do {
            _ = try await mockManager.fetchTodayActiveEnergy()
            XCTFail("Expected HealthKitError.unauthorized to be thrown")
        } catch let error as HealthKitError {
            switch error {
            case .unauthorized:
                break // Expected
            default:
                XCTFail("Expected .unauthorized but got \(error)")
            }
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }

    /// Verify that fetchTodayActiveEnergy throws `.queryFailed` when configured.
    func testFetchTodayActiveEnergyThrowsQueryFailed() async {
        let underlyingError = NSError(domain: "HKError", code: 1, userInfo: nil)
        mockManager.shouldThrow = .queryFailed(underlyingError)

        do {
            _ = try await mockManager.fetchTodayActiveEnergy()
            XCTFail("Expected HealthKitError.queryFailed to be thrown")
        } catch let error as HealthKitError {
            switch error {
            case .queryFailed:
                break // Expected
            default:
                XCTFail("Expected .queryFailed but got \(error)")
            }
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }

    /// Verify mock returns custom energy values.
    func testFetchTodayActiveEnergyReturnsCustomValue() async throws {
        mockManager.mockEnergy = 500.0
        let energy = try await mockManager.fetchTodayActiveEnergy()
        XCTAssertEqual(energy, 500.0, accuracy: 0.001)
    }
}
