import AVFoundation
import Foundation

/// Production voice-coaching singleton.
///
/// Mirrors the `HapticManager.shared` pattern: a `@MainActor` `ObservableObject` singleton with
/// intent-based methods. `VoiceCoach` owns the audio plumbing only — an `AVSpeechSynthesizer`, the
/// `AVAudioSession`, and interruption handling — while the speak/queue/interrupt/mute *policy* lives
/// in the pure, fully-testable `VoiceCoachDecision`. Events flow through the decision logic, which
/// drives a `SynthesizerSink` that forwards `speak` / `stop` to the real synthesizer (R4.1).
@MainActor
final class VoiceCoach: NSObject, ObservableObject {

    /// Shared instance, matching `HapticManager.shared`.
    static let shared = VoiceCoach()

    /// The system speech synthesizer that produces spoken audio.
    private let synthesizer = AVSpeechSynthesizer()

    /// Pure decision policy (debounce / interrupt / queue). Holds no audio dependencies (R4.4 / R4.5).
    private var decision = VoiceCoachDecision()

    /// Time source for the decision logic's `formCorrection` gates.
    private let clock: VoiceCoachClock = SystemVoiceCoachClock()

    /// Current voice preference (`VoicePreference`). Missing value defaults to enabled (R6.4).
    var isEnabled: Bool {
        UserDefaults.standard.object(forKey: "voiceCoachEnabled") as? Bool ?? true
    }

    private override init() {
        super.init()
        synthesizer.delegate = self
        configureAudioSession()          // R7.1
        registerInterruptionObserver()   // R7.4 / R7.5
    }

    // MARK: - Public API

    /// Request that a coaching event be spoken, applying the full speak policy (R4.1 / R4.4 / R4.5).
    ///
    /// Dropped entirely when voice is disabled (R4.2 / R6.3) or a `formCorrection` gate suppresses it
    /// (R5.5 / R5.6). Otherwise spoken immediately when idle, interrupting on `repAnnouncement`, or
    /// queued behind the current utterance for other categories.
    func speak(_ event: CoachingEvent) {
        var sink = SynthesizerSink(synthesizer: synthesizer)
        decision.handle(event, isEnabled: isEnabled, now: clock.now(), sink: &sink)
    }

    /// Stop any in-progress utterance immediately and clear pending speech (R6.3 mute, R7.4).
    func stop() {
        synthesizer.stopSpeaking(at: .immediate)
        decision.clearQueue()
    }

    /// Deactivate the audio session, notifying other apps so they can resume (R7.6).
    func deactivateSession() {
        do {
            try AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        } catch {
            print("VoiceCoach: failed to deactivate audio session: \(error.localizedDescription)")
        }
    }

    // MARK: - Audio session

    /// Configure the shared audio session for spoken coaching that ducks other audio (R7.1 / R7.3).
    private func configureAudioSession() {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .spokenAudio, options: .duckOthers)
        } catch {
            // Non-fatal: skip configuration and log; coaching simply won't duck/play if this fails.
            print("VoiceCoach: failed to configure audio session: \(error.localizedDescription)")
        }
    }

    /// Activate the shared audio session, used when resuming after an interruption (R7.5).
    private func activateAudioSession() {
        do {
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("VoiceCoach: failed to activate audio session: \(error.localizedDescription)")
        }
    }

    // MARK: - Interruption handling

    /// Observe audio-session interruptions so coaching yields to phone calls etc. (R7.4 / R7.5).
    private func registerInterruptionObserver() {
        NotificationCenter.default.addObserver(
            forName: AVAudioSession.interruptionNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            // The block is delivered on the main queue. Extract Sendable primitives here so the
            // non-Sendable Notification is not captured into the @MainActor task below.
            let info = notification.userInfo
            let typeValue = info?[AVAudioSessionInterruptionTypeKey] as? UInt
            let optionsValue = info?[AVAudioSessionInterruptionOptionKey] as? UInt
            Task { @MainActor [weak self] in
                self?.handleInterruption(typeValue: typeValue, optionsValue: optionsValue)
            }
        }
    }

    /// Stop on interruption begin; stay ready (reactivate) on end when the system says we may resume.
    private func handleInterruption(typeValue: UInt?, optionsValue: UInt?) {
        guard
            let typeValue,
            let type = AVAudioSession.InterruptionType(rawValue: typeValue)
        else { return }

        switch type {
        case .began:
            // R7.4: another audio source took over — stop coaching immediately.
            stop()
        case .ended:
            // R7.5: stay ready; reactivate only when the system indicates we should resume.
            if let optionsValue {
                let options = AVAudioSession.InterruptionOptions(rawValue: optionsValue)
                if options.contains(.shouldResume) {
                    activateAudioSession()
                }
            }
        @unknown default:
            break
        }
    }
}

// MARK: - UtteranceSink bridge

extension VoiceCoach {

    /// Forwards the decision logic's `speak` / `stop` actions to the real `AVSpeechSynthesizer`.
    ///
    /// Holds only a reference to the synthesizer (a class), so its `mutating` methods take effect on
    /// the shared synthesizer regardless of the struct's value semantics.
    private struct SynthesizerSink: UtteranceSink {
        let synthesizer: AVSpeechSynthesizer

        mutating func speak(_ text: String) {
            let utterance = AVSpeechUtterance(string: text)
            utterance.rate = AVSpeechUtteranceDefaultSpeechRate                       // R4.3
            // Current-language voice with system-default fallback when unavailable (R4.3).
            if let voice = AVSpeechSynthesisVoice(language: AVSpeechSynthesisVoice.currentLanguageCode()) {
                utterance.voice = voice
            }
            synthesizer.speak(utterance)
        }

        mutating func stop() {
            synthesizer.stopSpeaking(at: .immediate)
        }
    }
}

// MARK: - AVSpeechSynthesizerDelegate

extension VoiceCoach: AVSpeechSynthesizerDelegate {

    /// Dequeue and speak the next queued event when the current utterance finishes (R4.5).
    nonisolated func speechSynthesizer(
        _ synthesizer: AVSpeechSynthesizer,
        didFinish utterance: AVSpeechUtterance
    ) {
        Task { @MainActor in
            var sink = SynthesizerSink(synthesizer: self.synthesizer)
            self.decision.finishCurrentUtterance(sink: &sink)
        }
    }
}
