# MusicXML Compatibility

Phase 11F expands MusicXML support while preserving layer boundaries.

## Supported Additions

- Basic `<lyric>` text and `<syllabic>` values are stored on notes, laid out as
  `.lyric` elements, drawn from `ScoreLayout`, and included in hit testing.
- Basic `<notations><technical><fingering>` text is stored on notes, laid out as
  `.fingering` elements, drawn from `ScoreLayout`, and included in hit testing.
- `<key><fifths>` and `<key><mode>` are parsed as `KeySignature`; layout emits
  `.keySignature` elements for visible staff key accidentals.
- `<sound tempo="">` is parsed as tempo metadata.
- Repeat barlines are parsed as metadata and produce diagnostics because repeat
  playback expansion is not implemented.

## Diagnostics First

Complex notation is not silently ignored. Phase 11F emits specific diagnostics
for tuplets, slurs, ornaments, grace notes, transposition, beams, cross-staff
notation, and complex voice collision cases when full rendering or playback
semantics are not implemented.

## Private Samples

Private or third-party MusicXML files should be scanned locally with the
diagnostics executable and kept out of source control. Public fixtures in this
repository are self-authored minimal reproductions.
