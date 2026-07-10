# Off the Record — design

**Date:** 2026-07-09
**Status:** Approved (design), pending implementation plan
**Area:** iOS app (`App/`) — recording screen + `Recorder`

## Summary

Add an **Off the record** control to the active recording screen. Tapping it
stops audio capture entirely (nothing is recorded, buffered, or written to
disk for the paused span) and transforms the recording screen into a visually
distinct, calm "paused" state that makes it unmistakable — to the recorder and
to anyone glancing at the phone — that the conversation is private right now.
Tapping **Resume recording** restarts capture and returns to the normal screen.

This serves a 1-on-1 meeting recorder: a manager and a report should be able to
step off the record for a candid moment without ending the session, and trust
that that moment leaves no trace.

## Behavior

### Capture (the privacy guarantee — "fully discarded")

While off the record:

- **No samples reach disk, the sample tally, or the live captioner.** The gap
  simply does not exist in the resulting WAV. Because `duration` is derived from
  `sampleTally` (`Recorder.duration`, [Recorder.swift:58](../../../App/Sources/Recorder.swift#L58)),
  not a wall clock, skipping the paused samples keeps duration and the on-disk
  file consistent for free — the recording behaves as if the off-record minutes
  never happened.
- **Capture genuinely stops at the engine.** Pausing tears down the input tap and
  stops the `AVAudioEngine` (reusing the existing `startEngine()`/tap-removal
  machinery), and deactivates the iOS audio session so the **system microphone
  indicator turns off**. That orange dot going dark is a real, OS-level signal
  that nothing is listening — worth more than any in-app copy. Resume reactivates
  the session and calls `startEngine()` (the same path route-changes and
  interruptions already use to rewire capture).

### Interaction with existing pause paths (important)

The `Recorder` already has an *involuntary* pause concept: phone-call/Siri
interruptions and audio-route changes set `isInterrupted` and auto-resume via
`resumeCapture()` ([Recorder.swift:151](../../../App/Sources/Recorder.swift#L151),
[:202](../../../App/Sources/Recorder.swift#L202)). The user-initiated off-record
pause must take precedence:

- **While off the record, `resumeCapture()` is a no-op.** If a phone call arrives
  mid-off-record and ends, the recorder must *stay* paused — it must not silently
  resume capturing. Only the user's **Resume recording** tap restarts capture.
- Off-record is a distinct state from `isInterrupted`; the UI shows the
  off-record screen, not the involuntary-interruption banner.

### Screen states

| State | Screen |
|-------|--------|
| Recording | Existing `RecordSheetView`: timer, level meter, consent reminder, live caption panel, **Stop & Transcribe**, and a new **Go off the record** control beneath Stop. |
| Off the record | Full-screen transformed state (see Visual design). Capture stopped. A single **Resume recording** button. |

- The elapsed **timer freezes** at its value when off-record began (it is not a
  wall clock, so it naturally stops advancing while no samples arrive). The paused
  state surfaces that frozen value ("Paused at 04:12").
- Stopping/discarding the whole session while off the record is still possible
  (via Resume → Stop, at minimum; a direct Stop from the paused state is optional
  and can be decided in planning). Whatever was captured *before* going off the
  record is preserved and saved normally.

## Visual design

Chosen direction: **"Just between us"** — leans into the 1-on-1 confidentiality
of the context rather than a generic "paused."

- **Committed dark treatment.** The paused screen uses a deep blue-black vertical
  gradient (~`#10233a → #060d17`) **regardless of the system light/dark setting**,
  so the shift from the normal screen is unmistakable. This is the one screen that
  deliberately ignores system appearance.
- **Imagery:** two person figures with a small closed padlock centered between
  them — the confidentiality-between-two-people metaphor — in a cool accent blue
  (~`#6fb0ff`).
- **Copy:**
  - Eyebrow label: **OFF THE RECORD** (uppercase, tracked, accent blue).
  - Headline: **"This stays between you two."**
  - Subtext: **"No audio is being recorded or saved. Paused at 04:12"** — weaving
    in the person's name where it reads naturally (e.g. "This stays between you and
    Priya") since a 1-on-1 always has one.
- **Transition:** a gentle ~0.3s cross-fade into and out of the paused state, not
  an instant cut — reads as intentional and calm.
- **Entry control** (normal screen): a bordered, low-emphasis **"Go off the
  record"** button with a small lock glyph, placed *below* the prominent red
  **Stop & Transcribe** button so it never competes with Stop.
- **Resume control** (paused screen): a single prominent accent-blue **Resume
  recording** button.

Styling follows the app's existing conventions (SF Symbols, semantic colors, no
new asset catalog entries beyond what's needed) — see the note in CLAUDE.md that
there is no design-token file; the paused screen's committed colors are defined
inline in the view.

### Live Activity / lock screen

The recording Live Activity (`RecordingActivityController`) should reflect the
off-record state too, so the pause is legible with the phone face-down or locked
(e.g. "Off the record — paused"). Exact copy/layout to be confirmed against the
current activity attributes during planning; if the activity's content model
can't express it cleanly, this degrades gracefully (the activity keeps showing the
session as active) and is not a blocker for the core feature.

## Components & touch points

- **`Recorder`** ([App/Sources/Recorder.swift](../../../App/Sources/Recorder.swift)) —
  new user-pause API: `pause()` / `resume()` (names TBD in plan) plus an
  `isPaused` flag (lock-guarded, like `isInterrupted`). `pause()` stops the
  engine/tap and deactivates the session; `resume()` reactivates and rewires.
  `resumeCapture()` gains an `isPaused` guard so involuntary resume can't override
  a user pause. `consume()` already won't run once the tap is removed, so no
  sample-dropping branch is needed if we stop the engine (vs. merely gating
  `consume`).
- **`RecordSheetView`** ([App/Sources/Views/RecordSheetView.swift](../../../App/Sources/Views/RecordSheetView.swift)) —
  new `@State isOffRecord`; the entry button; conditional rendering of the paused
  overlay/state with the cross-fade; freeze the timer display; pause/resume the
  `LiveCaptioner` alongside the recorder (no audio ⇒ no captions).
- **`LiveCaptioner`** — stop feeding / clear partial caption while off the record;
  resume on return. (It's driven by `recorder.onSamples`, which stops naturally
  when the tap is removed; ensure any in-flight partial is cleared so stale text
  doesn't linger.)
- **`RecordingActivityController`** — optional off-record state (see above).

## Out of scope / non-goals

- No "captured but excluded" or transcript-marker modes — off the record means
  the audio never exists. (Considered and explicitly rejected in brainstorming.)
- No change to the sync protocol, Store persistence schema, or export models —
  a session that used off-record is an ordinary session with a shorter recording.
- No multi-party / group-recording semantics; this is a 1-on-1 feature.

## Testing

Per CLAUDE.md, tests cover LuxiconKit only and there is no app-target test
bundle; `Recorder` lives in the app target, so the capture behavior is verified
by building to a device and confirming:

1. Going off the record stops the timer, blanks the level meter, freezes/clears
   the live caption, and turns off the system mic indicator.
2. Resuming restarts capture; the final saved WAV contains audio from before and
   after the off-record span but **nothing** from during it, and its duration
   equals the sum of the two active spans.
3. A phone call during an off-record span does **not** silently resume recording.
4. Discard and normal Stop still behave correctly after an off-record span.

Any logic that can be factored into LuxiconKit (unlikely here, since it's
capture/UI) would get offline unit tests; the pause gating itself is device-verified.

## Open questions (resolve in planning)

- Exact `Recorder` API names (`pause()`/`resume()` vs. `setPaused(_:)`).
- Whether to expose a direct **Stop** from the paused state or require Resume first.
- Final Live Activity copy/layout, pending the current activity model.
