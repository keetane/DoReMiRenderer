# Notation Support Matrix

This matrix records the current DoReMiRendererKit / DoReMi Palette status for common notation symbols. It is based on the self-authored `notation_coverage_grand_staff.musicxml` sample and the current SDK architecture.

Status meanings:

- `supported`: parsed, retained, laid out, rendered, and visible in the app at MVP quality.
- `partial`: some stages are supported, but rendering, engraving quality, playback interpretation, or advanced cases remain limited.
- `diagnostic-only`: recognized as unsupported or limited and reported through diagnostics, but not rendered.
- `unsupported`: not currently represented in a reliable way.

| Symbol | Parser | Layout | Renderer | App visible | Status | Notes |
|---|---|---|---|---|---|---|
| Whole notehead | Supported | Supported | Supported | Yes | partial | Core Graphics MVP hollow notehead, no stem. SMuFL replacement is planned later. |
| Half notehead | Supported | Supported | Supported | Yes | partial | Core Graphics MVP hollow notehead with stem. |
| Quarter notehead | Supported | Supported | Supported | Yes | partial | Core Graphics MVP filled notehead with stem. |
| Eighth note / flag | Supported | Supported | Supported | Yes | partial | Isolated MVP flags are rendered. Beam grouping remains unsupported. |
| Note dots | Supported | Supported | Supported | Yes | supported | Dot count is retained and rendered at MVP quality. |
| Ledger lines | Supported | Supported | Supported | Yes | supported | Layout bounds include ledger lines; collision quality remains limited. |
| Treble clef | Supported | Supported | Supported | Yes | partial | Rendered as an MVP text glyph from layout. Full engraving/font quality is not a goal yet. |
| Bass clef | Supported | Supported | Supported | Yes | partial | Rendered as an MVP text glyph from layout. Grand staff brace/grouping is not rendered. |
| Key signature | Supported | Supported | Supported | Yes | partial | Treble/bass placement exists for basic fifths. Key-aware note coloring is still future work. |
| Time signature | Supported | Supported | Supported | Yes | partial | Rendered from layout as simple numeric text. Common/cut-time symbols are not implemented. |
| Accidental | Supported | Supported | Supported | Yes | supported | Sharp/flat/natural are rendered from layout elements. |
| Whole rest | Supported | Supported | Supported | Yes | partial | MVP rest glyph/shape only, not publication-quality engraving. |
| Half rest | Supported | Supported | Supported | Yes | partial | MVP rest glyph/shape only. |
| Quarter rest | Supported | Supported | Supported | Yes | partial | MVP rest glyph/shape only. |
| Eighth rest | Supported | Supported | Supported | Yes | partial | MVP rest glyph/shape only. |
| Tie | Supported for playback `<tie>` | Not rendered as arc | Not rendered as arc | Continuation highlight only | partial | Tie data is used for playback continuation and weak continuation highlighting. MusicXML notation `<tied>` may still be reported/treated as unsupported for arc rendering. |
| Slur | Diagnostic | Not rendered | Not rendered | No | diagnostic-only | Emits `unsupported.slur.rendering`; visual slur support is planned separately. |
| Dotted note | Supported | Supported | Supported | Yes | supported | Dot count is retained and dot elements are rendered. Multiple-dot engraving remains basic. |
| Chord | Supported | Supported | Supported | Yes | partial | Chord tones share onset and render as stacked noteheads. Collision avoidance remains basic. |
| Repeat start | Supported | Supported | Supported | Yes | partial | Repeat barline is visible. Playback repeat expansion remains unsupported and diagnostic-backed. |
| Repeat end | Supported | Supported | Supported | Yes | partial | Repeat barline is visible. Playback repeat expansion remains unsupported and diagnostic-backed. |
| Current-note highlight | Playback/App state | Overlay | Supported | Yes | supported | Attack notes use strong highlight; tied continuations use weaker secondary highlight in the app. |
| Dynamic text | Recognized but ignored | Not retained | Not rendered | No | unsupported | Dynamic elements such as `p`/`mf` are not rendered yet and should be promoted to diagnostics in a future hardening pass. |
| Tempo text | Metadata only for `<sound tempo>` | Not rendered | Not rendered | No | partial | `<sound tempo="">` can affect playback metadata. Visual tempo words rendering is not implemented; `<words>` text is not retained as visible tempo text. |
| Double/final barline | Diagnostic | Basic barline only | Basic barline only | Partial | partial | Standard barlines are visible. `bar-style` variants are not retained yet. |
| Beam grouping | Parsed as limited/ignored | Not grouped | Not rendered as beams | No | unsupported | Eighth notes use MVP flags. Beam grouping is future engraving work. |
| Tuplets | Diagnostic | Not implemented | Not rendered | No | diagnostic-only | Tuplets can affect duration/onset, so unsupported tuplets are diagnostic-backed. |
| Ornaments | Diagnostic | Not implemented | Not rendered | No | diagnostic-only | Decorative ornaments are intentionally deferred. |
| Grace notes | Diagnostic | Excluded from playback | Not rendered | No | diagnostic-only | Grace notes are not treated as normal notes. |
| First/second endings | Diagnostic | Not implemented | Not rendered | No | diagnostic-only | Repeat ending expansion and display are future work. |
| Transposition-aware display | Diagnostic | Not implemented | Not rendered | No | diagnostic-only | Written pitch is used for current rendering/coloring. |

## QA Sample

`Apps/DoReMiPalette/DoReMiPalette/Resources/Samples/notation_coverage_grand_staff.musicxml` is a self-authored grand staff sample for checking these symbols in the app. It intentionally includes both supported and diagnostic-only features so silent failures are easier to spot during QA.
