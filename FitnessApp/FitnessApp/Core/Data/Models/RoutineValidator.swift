import Foundation

// MARK: - RoutineValidator
// Requirements: 12.1, 12.3, 12.4, 12.5, 13.8, 13.9
// Single source-of-truth validation for Routine drafts. The stricter
// persistence ranges (13.3) are used so no value can pass the UI yet be
// rejected at save time. `validate(name:items:)` is pure: it returns a list of
// errors identifying the offending field (and item index where applicable)
// WITHOUT mutating its input.

enum RoutineValidator {
    // MARK: Single source-of-truth constants

    /// Allowed number of sets per item (Requirement 13.3).
    static let setsRange = 1...99
    /// Allowed number of reps per item (Requirement 13.3).
    static let repsRange = 1...999
    /// Allowed rest in seconds per item (Requirement 13.3).
    static let restRange = 0...3600
    /// Allowed Routine name length after trimming (Requirement 12.1, 13.2).
    static let nameLength = 1...100
    /// Allowed number of items in a Routine (Requirement 12.1).
    static let itemCount = 1...50

    // MARK: Validation errors

    /// Errors identify the field and, where relevant, the item index.
    /// Equatable so callers (and tests) can compare results deterministically.
    enum ValidationError: Equatable {
        case emptyName
        case noItems
        case setsOutOfRange(index: Int)
        case repsOutOfRange(index: Int)
        case restOutOfRange(index: Int)
    }

    // MARK: Validation

    /// Validate a Routine draft. Returns an empty array when valid.
    ///
    /// The input is treated as read-only; no mutation occurs. Per-item errors
    /// reference the item's position in `items` so the UI can surface the exact
    /// field that needs correction (Requirements 12.4, 12.5, 13.8, 13.9).
    static func validate(name: String, items: [RoutineItemDraft]) -> [ValidationError] {
        var errors: [ValidationError] = []

        // Requirement 12.5 / 13.8: name required (after trimming whitespace).
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        if !nameLength.contains(trimmedName.count) {
            errors.append(.emptyName)
        }

        // Requirement 12.5: at least one item (and at most itemCount.upperBound).
        if !itemCount.contains(items.count) {
            errors.append(.noItems)
        }

        // Requirement 12.4 / 13.9: per-item range checks, identifying index.
        for (index, item) in items.enumerated() {
            if !setsRange.contains(item.sets) {
                errors.append(.setsOutOfRange(index: index))
            }
            if !repsRange.contains(item.reps) {
                errors.append(.repsOutOfRange(index: index))
            }
            if !restRange.contains(item.restSeconds) {
                errors.append(.restOutOfRange(index: index))
            }
        }

        return errors
    }

    /// Convenience: validate a whole draft.
    static func validate(_ draft: RoutineDraft) -> [ValidationError] {
        validate(name: draft.name, items: draft.items)
    }
}
