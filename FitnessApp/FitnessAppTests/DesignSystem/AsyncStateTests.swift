// Feature: app-redesign-exercise-hub, Property 45: Eksklusivitas Async_State
//
// Property 45 (Eksklusivitas Async_State):
//   For any AsyncState value, exactly one of the cases `loading`, `loaded`,
//   `empty`, or `error` applies (mutually exclusive and exhaustive).
//   Validates: Requirements 19.1, 19.7
//
// NOTE ON FRAMEWORK: The spec's testing convention calls for SwiftCheck, but
// SwiftCheck is not configured in this project (the Xcode project declares no
// Swift Package / remote package dependencies). Per the task guidance, this
// test follows the project's existing test framework (XCTest) and expresses
// the property using a randomized generator loop that runs well over the
// required minimum of 100 iterations.

import XCTest
@testable import FitnessApp

final class AsyncStateTests: XCTestCase {

    /// Number of randomized iterations for the property (≥100 per convention).
    private let iterations = 200

    // MARK: - Generator

    /// Produces a uniformly-random `AsyncState<Int>` across all four cases,
    /// with randomized associated payloads, to exercise the full input space.
    private func randomState(using rng: inout some RandomNumberGenerator) -> AsyncState<Int> {
        switch Int.random(in: 0...3, using: &rng) {
        case 0:
            return .loading
        case 1:
            return .loaded(Int.random(in: Int.min...Int.max, using: &rng))
        case 2:
            return .empty
        default:
            let length = Int.random(in: 0...32, using: &rng)
            let message = String((0..<length).map { _ in
                "abcdefghijklmnopqrstuvwxyz ".randomElement(using: &rng)!
            })
            return .error(message: message)
        }
    }

    // MARK: - Classification helpers

    /// Returns the four mutually-exclusive case predicates for a given state.
    private func casePredicates(for state: AsyncState<Int>) -> [Bool] {
        let isLoading: Bool = { if case .loading = state { return true } else { return false } }()
        let isLoaded: Bool = { if case .loaded = state { return true } else { return false } }()
        let isEmpty: Bool = { if case .empty = state { return true } else { return false } }()
        let isError: Bool = { if case .error = state { return true } else { return false } }()
        return [isLoading, isLoaded, isEmpty, isError]
    }

    // MARK: - Property 45

    /// For any generated `AsyncState`, exactly one case predicate is true
    /// (mutual exclusivity + exhaustiveness).
    func testProperty45_asyncStateIsInExactlyOneCase() {
        var rng = SystemRandomNumberGenerator()

        for iteration in 0..<iterations {
            let state = randomState(using: &rng)
            let matches = casePredicates(for: state)
            let trueCount = matches.filter { $0 }.count

            XCTAssertEqual(
                trueCount,
                1,
                "AsyncState must match exactly one case. Iteration \(iteration) "
                    + "produced \(trueCount) matching cases for state \(state)."
            )
        }
    }

    /// Exhaustiveness sanity check: each of the four declared cases is itself
    /// classified as exactly one case (covers all branches deterministically).
    func testProperty45_eachDeclaredCaseMatchesItselfExclusively() {
        let samples: [AsyncState<Int>] = [
            .loading,
            .loaded(0),
            .loaded(42),
            .empty,
            .error(message: ""),
            .error(message: "network failure")
        ]

        for state in samples {
            let trueCount = casePredicates(for: state).filter { $0 }.count
            XCTAssertEqual(trueCount, 1, "State \(state) must match exactly one case.")
        }
    }
}
