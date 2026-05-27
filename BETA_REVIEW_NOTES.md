# Beta Review Notes

Build: `0.1.1 (2)`
Bundle ID: `com.doremipalette.app`

DoReMi Palette is a piano practice app for viewing MusicXML / MXL scores with
colored notes, keyboard guidance, generated-tone playback, practice stepping,
transpose, a metronome, and basic repeat playback.

No login is required.

Suggested review flow:

1. Launch the app. It opens `Ode to Joy Easy Variation`.
2. Tap Library to open the bundled learning samples: `Ode to Joy Easy
   Variation` and `Fur Elise - Beginner Piano`.
3. Use Play / Stop / Reset to verify generated-tone playback.
4. Use Previous / Next and the measure field to move through the score.
5. Toggle Keyboard and confirm the on-screen keyboard follows the current note.
6. Enable the Metronome and confirm it follows the displayed meter.
7. Open the palette drawer to switch all-note / line coloring and individual
   note-color groups.
8. Use the key picker to transpose the displayed score and generated playback.
9. Use Import to open a user-owned MusicXML / MXL file from Files.
10. Open Diagnostics to view warnings for intentionally unsupported notation in
    the current score.

Privacy and content notes:

- The app does not require an account.
- The app does not include ads, analytics, or tracking.
- User-selected MusicXML / MXL files are processed on device and are not
  uploaded by the app.
- Library / Recent file metadata is stored on device.
- The bundled music samples are the current two-song learning set recorded in
  `ASSET_LICENSES.md`.
- `Happy Birthday To You Piano` was excluded from the TestFlight bundle after
  rights review because its MusicXML metadata names an arranger and has no
  embedded rights grant.
- Redistribution rights for all score arrangements/exports should be
  reconfirmed before external App Store release.
- Bravura 1.392 is bundled under the SIL Open Font License for SMuFL music glyph
  rendering.

Known beta limitations:

- Notation rendering is MVP quality.
- Some advanced MusicXML constructs are diagnostic-only.
- Complex repeat/jump combinations are limited.
- Metronome and playback timing are suitable for practice checks, not
  DAW-grade timing.
- No MIDI input, microphone scoring, cloud sync, account system, or background
  audio.
