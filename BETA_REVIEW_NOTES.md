# Beta Review Notes Draft

DoReMi Palette is a piano practice app for viewing MusicXML scores with colored
notes, keyboard guidance, generated-tone playback, practice stepping,
transpose, and basic repeat playback.

No login is required.

Suggested review flow:

1. Launch the app. It opens `DoReMi Palette Sample`.
2. Tap Library to open additional bundled samples.
3. Use Play / Pause / Stop / Reset to verify generated-tone playback.
4. Open Practice Mode and use Next / Previous to step through notes.
5. Open the palette drawer to toggle note-color groups.
6. Use the key picker to transpose the displayed score and generated playback.
7. Open Diagnostics to view warnings for intentionally unsupported notation in
   QA samples.

The app does not upload imported files. User-selected MusicXML / MXL files are
processed on device. The bundled music samples are self-authored QA/demo
fixtures. Bravura 1.392 is bundled under the SIL Open Font License for SMuFL
music glyph rendering.

Known beta limitations:

- Notation rendering is MVP quality.
- Some advanced MusicXML constructs are diagnostic-only.
- Complex repeat/jump combinations are limited.
- No MIDI input, microphone scoring, cloud sync, account system, or background
  audio.

