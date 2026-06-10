import Foundation

/// Abstract destination for spoken text and stop actions.
///
/// The decision logic in `VoiceCoachDecision` talks only to this sink, never to
/// `AVSpeechSynthesizer` / `AVAudioSession`, so the speak/queue/interrupt/mute policy is fully
/// testable without audio hardware. The production `VoiceCoach` (task 3.5) provides a sink that
/// forwards `speak` / `stop` to a real `AVSpeechSynthesizer`; tests use `RecordingUtteranceSink`.
protocol UtteranceSink {
    /// Begin speaking the given text.
    mutating func speak(_ text: String)
    /// Stop any in-progress utterance immediately.
    mutating func stop()
}

/// An `UtteranceSink` that records the ordered speak/stop actions it receives.
///
/// Used by the pure decision logic and its property tests to assert exactly what would be spoken
/// without producing real audio.
struct RecordingUtteranceSink: UtteranceSink {
    /// A single recorded action.
    enum Action: Equatable {
        case speak(String)
        case stop
    }

    /// All actions in the order they occurred.
    private(set) var actions: [Action] = []

    /// The texts that were actually spoken, in order.
    var spokenTexts: [String] {
        actions.compactMap { action in
            if case let .speak(text) = action { return text }
            return nil
        }
    }

    mutating func speak(_ text: String) { actions.append(.speak(text)) }
    mutating func stop() { actions.append(.stop) }
}

/// Source of the current time, injected so the decision logic's timing is deterministic in tests.
///
/// The pure `VoiceCoachDecision` routines take an explicit `now: Date` argument; this clock lets the
/// production `VoiceCoach` source that value (`Date()`) while tests inject fixed timestamps.
protocol VoiceCoachClock {
    func now() -> Date
}

/// Wall-clock implementation backed by `Date()`.
struct SystemVoiceCoachClock: VoiceCoachClock {
    func now() -> Date { Date() }
}

/// The pure, deterministic speak-decision policy for voice coaching.
///
/// `VoiceCoachDecision` owns the entire decision routine described in the design's "VoiceCoach speak
/// policy": enabled check → `formCorrection` gating → interrupt-vs-queue by category. It holds no
/// audio dependencies and mutates only its own value-type state, driving an injected `UtteranceSink`.
///
/// Decision order for `handle(_:isEnabled:now:sink:)`:
/// 1. **Enabled check (R4.2 / R6.3):** when disabled, the event is dropped with no sink interaction.
/// 2. **`formCorrection` gating (R5.5 / R5.6):** a `formCorrection` is accepted only when it passes
///    BOTH gates below; otherwise it is dropped.
///    - (a) identical-text 3 s debounce: skip identical text spoken `< debounceInterval` (3 s) ago.
///    - (b) global 2.5 s spacing: skip ANY `formCorrection` when `now - lastAnyFormCorrectionAt
///      < formCorrectionInterval` (2.5 s), regardless of text.
///    On acceptance, BOTH `lastFormCorrection = (text, now)` and `lastAnyFormCorrectionAt = now`
///    are updated.
/// 3. **Interrupt-vs-queue (R4.4 / R4.5):** when idle, speak immediately; when speaking, a
///    `repAnnouncement` stops the current utterance and speaks now, while every other category is
///    appended to the queue and dequeued on `finishCurrentUtterance(sink:)`.
struct VoiceCoachDecision {

    /// Minimum interval between two spoken `formCorrection`s carrying the *same* text (R5.5).
    static let debounceInterval: TimeInterval = 3.0
    /// Minimum interval between any two spoken `formCorrection`s regardless of text (R5.6).
    static let formCorrectionInterval: TimeInterval = 2.5

    /// The result of handling a single event, useful for tests and downstream wiring.
    enum Outcome: Equatable {
        /// Dropped because voice is disabled or a `formCorrection` gate suppressed it.
        case dropped
        /// Spoken immediately because the synthesizer was idle.
        case spoke
        /// Interrupted the in-progress utterance (a `repAnnouncement` while speaking) and spoke now.
        case interrupted
        /// Appended to the queue to be spoken after the current utterance finishes.
        case queued
    }

    /// Whether an utterance is currently in progress.
    private(set) var isSpeaking: Bool = false
    /// Events waiting to be spoken after the current utterance finishes (FIFO).
    private(set) var queue: [CoachingEvent] = []
    /// Text and time of the most recently accepted `formCorrection` (identical-text debounce memory).
    private(set) var lastFormCorrection: (text: String, at: Date)?
    /// Time of the most recently accepted `formCorrection` of any text (global spacing memory).
    private(set) var lastAnyFormCorrectionAt: Date?

    init() {}

    /// Apply the speak-decision policy to a single event.
    ///
    /// - Parameters:
    ///   - event: The coaching event being requested.
    ///   - isEnabled: Current `VoicePreference`; when `false` the event is dropped (R4.2).
    ///   - now: The current time, used for the `formCorrection` gates (injected for determinism).
    ///   - sink: The utterance sink to drive (`speak` / `stop`).
    /// - Returns: The `Outcome` describing what was done.
    @discardableResult
    mutating func handle<Sink: UtteranceSink>(
        _ event: CoachingEvent,
        isEnabled: Bool,
        now: Date,
        sink: inout Sink
    ) -> Outcome {
        // 1. Enabled check — drop entirely when muted (R4.2 / R6.3).
        guard isEnabled else { return .dropped }

        // 2. formCorrection gating — must pass BOTH gates to be spoken (R5.5 / R5.6).
        if case .formCorrection = event {
            let text = event.text

            // (a) identical-text 3 s debounce.
            if let last = lastFormCorrection,
               last.text == text,
               now.timeIntervalSince(last.at) < Self.debounceInterval {
                return .dropped
            }

            // (b) global 2.5 s spacing, regardless of text.
            if let lastAny = lastAnyFormCorrectionAt,
               now.timeIntervalSince(lastAny) < Self.formCorrectionInterval {
                return .dropped
            }

            // Accepted — this correction will be spoken; record both gate timestamps.
            lastFormCorrection = (text, now)
            lastAnyFormCorrectionAt = now
        }

        // 3. Interrupt-vs-queue by category (R4.4 / R4.5).
        guard isSpeaking else {
            sink.speak(event.text)
            isSpeaking = true
            return .spoke
        }

        if event.interrupts {
            // repAnnouncement stops the in-progress utterance and speaks now to keep counts current.
            sink.stop()
            sink.speak(event.text)
            return .interrupted
        }

        // formCorrection / milestone / lifecycle events wait their turn.
        queue.append(event)
        return .queued
    }

    /// Signal that the current utterance finished, dequeuing and speaking the next event if any.
    ///
    /// Queued events were already gated at `handle` time, so no re-gating occurs here.
    /// - Parameter sink: The utterance sink to drive.
    /// - Returns: `true` if a queued event was dequeued and spoken, `false` if the queue was empty.
    @discardableResult
    mutating func finishCurrentUtterance<Sink: UtteranceSink>(sink: inout Sink) -> Bool {
        guard !queue.isEmpty else {
            isSpeaking = false
            return false
        }
        let next = queue.removeFirst()
        sink.speak(next.text)
        isSpeaking = true
        return true
    }

    /// Clear all pending speech state. Does not reset `formCorrection` gate timestamps so spacing
    /// guarantees survive a stop; use a fresh `VoiceCoachDecision` to reset gates entirely.
    mutating func clearQueue() {
        queue.removeAll()
        isSpeaking = false
    }
}
