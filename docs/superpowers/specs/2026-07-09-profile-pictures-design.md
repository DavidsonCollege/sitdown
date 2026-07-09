# Profile Pictures — Design

**Date:** 2026-07-09
**Scope:** Aesthetic only. A profile picture for the user ("me") and for each
person in the 1-on-1s list. Photos never leave the device and are not used by
transcription, sync, or export.

## Storage

- Photos live as JPEG files in `Documents/photos/` (sibling of `audio/`).
- `Person` gains `photoFileName: String?`; `Store` gains `myPhotoFileName:
  String?` (persisted in `Persisted`). Optional fields keep existing
  `store.json` files decoding unchanged.
- Every new photo is written under a fresh UUID filename and the old file is
  deleted, so SwiftUI image caching can never show a stale picture.
- Images are downscaled to a max dimension of 512 px and encoded as JPEG
  (quality 0.8) before writing — avatars are small, so full-resolution photos
  would be wasted disk.
- `deletePerson` also removes the person's photo file.

Rejected alternatives:
- Base64 image data inside `store.json` — bloats a file rewritten on every save.
- Filename-by-UUID convention with no model field — no `@Observable` change
  notification when a photo changes, and cache-busting gets awkward.

## UI

- `AvatarView` (new file `App/Sources/Views/AvatarView.swift`): a circular
  avatar that shows the photo if the file exists, otherwise an initials
  monogram on a tinted circle. Takes `fileName`, `name`, `size`.
- `PeopleListView`: each person row shows a 40 pt avatar before the name.
- `PersonDetailView`: an 88 pt avatar header above the record button; tapping
  it opens `PhotosPicker`, and a context menu offers **Remove Photo**.
- `MyVoiceView`: the "Your name" section shows a 56 pt avatar next to the name
  field, wrapped in the same picker/remove treatment.
- Picking uses the system `PhotosPicker` (out-of-process; no photo-library
  permission or Info.plist entry needed).

## Error handling

Photo load/decode failures fall back silently to the monogram — this is a
purely aesthetic feature, so no alerts.

## Testing

No LuxiconKit changes; app target has no unit-test target. Verification is a
clean `xcodebuild` of the Luxicon scheme after `xcodegen generate`.
