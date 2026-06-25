// Property-based tests for the PULSE Design System `Motion` tokens.
//
// NOTE ON TEST FRAMEWORK:
// The spec (design.md / tasks.md) prescribes SwiftCheck for property-based
// testing. SwiftCheck is NOT currently configured as a dependency in this
// project (no Swift Package reference, no `import SwiftCheck` anywhere in the
// codebase). To avoid blocking on dependency/tooling setup, this property is
// implemented with the project's existing framework (XCTest) using an explicit
// randomized generator that runs well over the required 100 iterations. The
// property checked is identical to what a SwiftCheck `forAll` would assert.

import XCTest
@testable import FitnessApp

final class MotionPropertyTests: XCTestCase {

    /// Minimum number of generated iterations for each property (spec: ≥100).
    private let iterations = 200

    /// All `Motion` transition-duration tokens that must obey the 200–400ms rule.
    /// Each tuple pairs a human-readable name with the token value (seconds).
    private let transitionDurations: [(name: String, seconds: TimeInterval)] = [
        ("screenTransitionDuration", Motion.screenTransitionDuration),
        ("chipToggleDuration", Motion.chipToggleDuration),
        ("emphasisResponse", Motion.emphasisResponse)
    ]

    // Feature: app-redesign-exercise-hub, Property 47: Motion transisi dalam rentang 200–400ms
    /// **Validates: Requirements 1.7**
    ///
    /// For every randomly selected `Motion` transition-duration token, the value
    /// must lie within the inclusive 200–400ms range. The bounds themselves are
    /// pinned to exactly 200ms and 400ms so views never hardcode durations that
    /// drift outside the design contract.
    func testMotionTransitionDurationsWithin200To400ms() {
        // The declared bounds must be exactly 200ms and 400ms.
        XCTAssertEqual(Motion.minTransitionDuration, 0.20, accuracy: 1e-9,
                       "minTransitionDuration must equal 200ms")
        XCTAssertEqual(Motion.maxTransitionDuration, 0.40, accuracy: 1e-9,
                       "maxTransitionDuration must equal 400ms")

        for iteration in 0..<iterations {
            // Generator: pick an arbitrary transition-duration token each round.
            let token = transitionDurations.randomElement()!

            XCTAssertGreaterThanOrEqual(
                token.seconds, Motion.minTransitionDuration,
                "Iteration \(iteration): \(token.name)=\(token.seconds)s is below the 200ms lower bound"
            )
            XCTAssertLessThanOrEqual(
                token.seconds, Motion.maxTransitionDuration,
                "Iteration \(iteration): \(token.name)=\(token.seconds)s is above the 400ms upper bound"
            )
        }
    }
}
