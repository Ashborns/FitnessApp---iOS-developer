import Foundation

/// Centralized asynchronous view state used by all data-driven ViewModels.
///
/// A screen is always in exactly one of these states at any moment, giving a
/// single source of truth for loading / loaded / empty / error rendering
/// (see `AsyncStateView`). Conforms to `Equatable` so SwiftUI can diff state
/// changes and so the value can be asserted in tests.
///
/// - `loading`: data is being fetched for the first time.
/// - `loaded(Value)`: data is available and ready to display.
/// - `empty`: the request succeeded but produced no displayable content.
/// - `error(message:)`: the request failed; `message` is a user-facing,
///   descriptive explanation suitable for display alongside a retry control.
///
/// _Requirements: 19.1, 19.7_
enum AsyncState<Value: Equatable>: Equatable {
    case loading
    case loaded(Value)
    case empty
    case error(message: String)
}
