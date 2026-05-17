# TestFlight Checklist

## Internal Testing Scope

- Open the default `DoReMi Palette Sample`.
- Open QA samples from Library:
  - Rhythm Values Sample
  - Notation Coverage Sample
  - S6 Notation Refinement Sample
  - S7 Repeat Playback Sample
  - S8 Repeat Endings Sample
  - S9 Repeat Visuals Sample
  - S10 repeat / jump samples
  - T2 transpose samples
- Verify Playback: Play, Pause, Stop, Reset, tempo picker, repeat/jump order,
  tied continuation behavior, and no stuck notes.
- Verify Practice Mode stepping, current-note marker, next-note marker, and
  keyboard highlight.
- Verify transpose key picker and display-transposed score.
- Verify palette drawer, seven-note color controls, line/all mode, keyboard
  color setting, and persistence.
- Verify MusicXML / MXL import, invalid-file diagnostics, Library / Recent
  reload, and missing-file handling.

## Known Limitations To Tell Testers

- Engraving is MVP quality, not publishing quality.
- Complex MusicXML may show diagnostics or partial rendering.
- Third endings, nested repeats, and complex jump mixtures remain limited.
- Full transposing-instrument concert pitch handling is diagnostic-only.
- Palette editing is note-class based; arbitrary RGB/HEX editing is not
  available.
- No account, cloud sync, iCloud library, MIDI input, microphone scoring, or
  background audio.

## Screenshot Folder

Use `/tmp/DoReMiPaletteQA/phase-17b/` for Phase 17B manual screenshots.

