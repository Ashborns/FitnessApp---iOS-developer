import Foundation

/// Immutable description of the active filtering state for the Exercise Library.
///
/// `FilterCriteria` captures the free-text search query plus the selected values for each
/// filterable category (`target`, `equipment`, `bodyPart`). It is a pure value type with no
/// framework dependencies so it can be persisted with a screen's navigation state and
/// unit-/property-tested in isolation (R9.1, R9.3–R9.5, R9.8).
struct FilterCriteria: Equatable {
    /// Free-text search query matched case-insensitively against `ExerciseItem.name`.
    var searchText: String = ""
    /// Selected target muscles. Empty means "no target constraint".
    var targets: Set<String> = []
    /// Selected equipment values. Empty means "no equipment constraint".
    var equipment: Set<String> = []
    /// Selected body parts. Empty means "no body part constraint".
    var bodyParts: Set<String> = []

    /// `true` when the trimmed search text is empty AND every category set is empty,
    /// i.e. the criteria impose no constraint and the full list should pass through unchanged.
    var isEmpty: Bool {
        searchText.trimmed.isEmpty
            && targets.isEmpty
            && equipment.isEmpty
            && bodyParts.isEmpty
    }
}

/// Pure filtering engine for the Exercise Library.
///
/// `ExerciseFilterEngine.apply` is a deterministic, side-effect-free function:
/// - Text match is a case-insensitive substring on `ExerciseItem.name`; empty (trimmed) text
///   matches every item (R9.1).
/// - Category logic is **AND across categories** (target, equipment, bodyPart) and
///   **OR within a category's values** (an empty category set matches every item) (R9.3).
/// - Text and category constraints combine with AND (R9.4).
/// - When `criteria.isEmpty`, the full list is returned unchanged and in the same order
///   (R9.5, R9.8).
enum ExerciseFilterEngine {
    /// Returns the subset of `items` satisfying `criteria`, preserving the original order.
    ///
    /// - Parameters:
    ///   - items: The source exercises to filter.
    ///   - criteria: The active filter state.
    /// - Returns: The matching exercises in their original relative order. When `criteria.isEmpty`
    ///   the input is returned unchanged.
    static func apply(_ items: [ExerciseItem], _ criteria: FilterCriteria) -> [ExerciseItem] {
        // Empty criteria → full list, unchanged order.
        guard !criteria.isEmpty else { return items }

        let query = criteria.searchText.trimmed

        return items.filter { item in
            let textOK = query.isEmpty
                || item.name.range(of: query, options: .caseInsensitive) != nil
            let targetOK = criteria.targets.isEmpty || criteria.targets.contains(item.target)
            let equipOK = criteria.equipment.isEmpty || criteria.equipment.contains(item.equipment)
            let bodyOK = criteria.bodyParts.isEmpty || criteria.bodyParts.contains(item.bodyPart)
            // AND across categories; OR within each category is handled by `contains`.
            return textOK && targetOK && equipOK && bodyOK
        }
    }
}

private extension String {
    /// The string with leading/trailing whitespace and newlines removed.
    var trimmed: String {
        trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
