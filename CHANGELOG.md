# Changelog

## 0.1.0-mvp0 - 2026-05-02

Initial experimental MVP0 release.

This version is intended for integration review and early adopter testing. Public
APIs may change before `1.0`.

### Browser notation / print-quality hardening

- Added MusicXML `64th` note and rest support through the SDK parser, layout,
  SMuFL glyph selection, standalone flags, and four-level beams. Previously
  these values fell back to generic black noteheads without flags; Toccata and
  Fugue in D Minor now retains its written 64th-note rhythm in Web A4 output.

- Made rest glyph footprints part of SDK layout geometry. SMuFL rest size now
  drives its `ElementLayout` frame, onset envelopes, dotted-rest clearance,
  and measure-edge insets, preventing short rests in Toccata from painting
  outside their start or end barlines.

- Fixed Web A4 spacing for rest-containing measures. Measure-width planning and
  note/rest onset placement now share a duration-sensitive visual envelope, so
  rest glyphs follow their written rhythmic values, remain inside the barline,
  and no longer collapse multiple half/whole rests onto a single measure
  centre. Existing compact spacing for pure beamed short-note groups is
  unchanged.

- Hardened SDK print pagination to assign systems from their full notation
  bounds rather than only their staff frames. Tuplet brackets, articulations,
  fermatas, lyrics, dynamics, hairpins, ledger lines, and grand-staff braces
  now reserve their actual vertical overhang at a page boundary; a conflicting
  system moves intact to the following page instead of painting into the prior
  page.

- Improved the Web A4 engraving profile for large piano scores: MusicXML
  composer credits render beneath the centered title, two-staff systems receive
  a brace plus inter-staff barline connectors, and below-staff expression lanes
  reserve additional vertical clearance. The Web-only profile leaves iOS and
  PDF defaults untouched.

- Reworked loopback Web import so a large MusicXML/MXL score returns only its
  original SDK layout initially. The local service keeps the upload in memory
  for ten minutes and renders a selected `-6...+5` transposition on demand,
  preventing a full set of duplicate score plans from delaying first display.

- Added note-linked ledger-line palette metadata to the SDK Web Render Plan so
  coloured staff mode also colours C4 and other ledger lines with the written
  note's pitch-class family. Web score zoom now uses an editable 50–200%
  numeric field with 10% controls, and Previous/Next use hollow navigation
  icons distinct from the filled Play icon. Black and white keyboard colour
  bands now share the same 8pt inset geometry.

- Replaced the Web transport's percentage tempo cycle with an editable 30–300
  BPM field seeded from the SDK-exported event tempo, moved Previous/Next beside
  Reset, and normalized black-key palette bands to the same inset edge rendering
  used by white keys. The Web-only time-signature profile now adds one more point
  of numerator/denominator separation toward the staff centre; iOS/PDF defaults
  remain unchanged. MXL import now posts a fixed byte payload to the loopback
  SDK converter, avoiding browser-specific streamed-upload behavior.

- Added loopback-only MusicXML/MXL upload support to DoReMi Palette Web through
  `Examples/WebCanvasViewer/server.py`. The server delegates every import to
  `DoReMiRendererWebExport`, returns only the SDK-built Web Render Bundle, and
  discards the temporary upload after the response; browser JavaScript still
  does not parse MusicXML or generate notation geometry.
- Refined Web keyboard guidance: the next pitch is now a pale circular marker
  with a darker pitch-colour outline, while the current pitch remains filled.
  Black-key scale colouring uses a flat top/bottom band equal to roughly 5% of
  key height. The later BPM control scales both event timing and exported
  written sound windows; Previous/Next now sit immediately after Reset, and
  the toolbar adopts the iOS app icon.
- Matched DoReMi Palette Web generated audio to the iOS `SimpleToneAudioEngine`:
  the browser now uses the same three-harmonic wave, 80% velocity mapping,
  low-pitch boost, and 10ms fade envelope. The SDK exports per-pitch sound
  windows, so quarter, half, whole, dotted, and unequal chord tones retain their
  written durations instead of sharing one event-length sound.
- Moved the Web note-colour control into the palette as a check control, added a
  visually distinct dashed next-note keyboard guide, made black-key colour
  markers flat at both top and bottom positions, and reduced original-scale
  reset to a natural-sign control. Web plans now label only the leftmost measure
  of each grand staff/system.
- Reworked the SDK-owned Web Canvas reading profile without changing the iOS or
  PDF defaults: notation now uses a 12pt shared scale, compact measure joins,
  readable grand-staff spacing, rhythmic placement for dense short-note groups,
  repeated context prefixes at wrapped starts, and separate expression lanes.
- Reduced Web title emphasis relative to body notation and tightened closing
  repeat bars so they no longer dominate the staff at reader scale.
- Overlapped stems slightly into their notehead frames and strengthened their
  stroke width to prevent visible Canvas/SMuFL seams while retaining the same
  layout coordinate source for Web, iOS, and PDF rendering.
- Hid `Ped.` labels and enlarged Web-reader noteheads by 2pt without changing
  iOS/PDF defaults. Explicitly beamed chords now suppress sibling flags and
  extend every simultaneous stem to the shared beam. Same-measure 1./2. volta
  endings now draw closed brackets at both hooks.
- Set the Web reader to a 90pt upper/lower-staff gap, while retaining 20pt
  additional horizontal content margins and a 120pt title-to-first-system
  reservation. Web-only time-signature digits use a fixed 36pt size and inset
  each numerator/denominator digit 4pt toward the staff centre; iOS/PDF
  defaults remain unchanged.
- Expanded the Web Canvas example into DoReMi Palette Web: its toolbar opens
  SDK-generated Web Render Plan JSON, the pitch-class palette recolours stable
  note anchors, staff-line colour metadata comes directly from ScoreLayout, and
  the on-screen piano keyboard selects the same exported MIDI-backed note IDs.
  The browser still never parses MusicXML or recomputes score coordinates.
- Aligned the Web palette with iOS `defaultEducationalPalette`: noteheads,
  clef-aware staff lines, and keyboard keys now share the C/C#, D/D#, E, F/F#,
  G/G#, A/A#, and B colour groups and one 12-pitch-class enable state. Web
  defaults now match the app: note and keyboard colour on, staff-line colour
  off.
- Added iOS-parity Web transport and controls: `ScoreWebRenderBundle` carries
  SDK-generated display-transpose layouts (-12...+12) and an expanded playback
  timeline. DoReMi Palette Web now provides display/playback transpose,
  Web-Audio Play/Stop, current-note anchor following, Previous/Next, and direct
  measure Jump without MusicXML parsing or browser-side layout calculation.
- Updated the Web-only time-signature glyph size to 36pt. iOS and PDF defaults
  remain unchanged.
- Refined DoReMi Palette Web palette and transport behavior: staff-line colour
  guides now draw over ordinary staff ink but below notation, existing SMuFL notehead glyph commands are
  recoloured instead of receiving substitute ellipse overlays, and a cyan guide
  spans the current SDK-defined grand staff. Web vertical follow now changes
  only when playback enters another system.
- Updated Web scale labels to `C / Am` form, added an original-scale reset
  button, iOS-like keyboard/palette/open icons, palette check controls, a
  top/bottom keyboard colour position switch, and an optional dashed next-note
  guide. Browser anchors now carry their written diatonic pitch class, keeping
  B-flat in F major in the B colour family while the physical keyboard still
  uses the actual B-flat/A-sharp key.
- Replaced the browser's separate "transpose score" switch with one
  scale-name selector. It always selects an SDK-generated transposed layout,
  including the original major/minor key label, and staff/keyboard colouring is
  limited to that scale while out-of-scale played notes keep their pitch-class
  guide colour. Added score-only zoom controls and icon-led toolbar actions.
- Centered half and whole rests within their measure for the Web profile and
  placed whole rests against the second staff line. Browser stems overlap
  noteheads by an additional 2pt, adjacent chord seconds reflect the lower
  notehead around the shared stem axis, and repeat-barline thin/thick strokes
  now use a fixed 4pt separation. Volta brackets consistently draw both closing
  hooks, including start-only MusicXML endings.

### Playback timing hardening

- Changed DoReMi Palette playback scheduling to use a monotonic absolute
  schedule instead of chaining each event from the previous wake-up time, so a
  delayed UI frame or audio start does not accumulate tempo drift.
- Added app-side audio buffer prewarming before playback to keep generated-tone
  engine startup and first-use buffer generation out of the note onset path.
- Added DEBUG-only playback timing instrumentation and an autoplay launch
  harness for Simulator timing checks.
- Rechecked Canon in D, Mozart Piano Sonata No. 16, Fur Elise, The Entertainer,
  and Twinkle in the iPad Simulator. Timing logs are saved under
  `/tmp/DoReMiPaletteQA/playback-timing/`.
- Fixed TestFlight critical regressions found after the performance pass:
  CoreGraphics/UIKit static-canvas SMuFL text now compensates for the flipped
  context so clefs, noteheads, rests, flags, accidentals, and text markers draw
  upright; current-note follow now uses raw current playback note IDs plus
  lightweight measure anchors so large scores follow again without reintroducing
  all-note geometry work; and metronome time signatures are carried forward by
  measure.
- Fixed the remaining metronome meter-sync regression by replacing the
  event-local beat phase with a measure-based click plan generated from the
  expanded playback sequence. Every 3/4 and 4/4 measure occurrence now anchors
  beat 0 as the strong click, pickup measures do not drift following measures,
  and turning the metronome ON mid-playback starts from the next planned click
  instead of restarting a local beat cycle.
- Fixed A4 repeat-end barline spacing so the thin and thick closing-repeat
  lines remain visually separated at small staff sizes, including Fur Elise
  measure 8, and prevented a duplicate normal right barline from stacking on
  backward repeat measures.
- Adjusted volta bracket hook rendering so the Fur Elise first ending can stay
  open on the left at the closing repeat, while the second ending start remains
  open on the right when MusicXML marks the ending as `discontinue`.
- Parsed MusicXML `<beam>` tags into the domain model and use explicit beam
  begin/continue/end markings for layout when present. Fur Elise now follows the
  source beam grouping more closely, while files without beam tags still use the
  existing safe inferred grouping and mixed natural stem directions remain split.
- Parsed MusicXML mid-measure clef changes with onset timing, carry effective
  clefs into following measures, and render smaller clef-change glyphs at the
  corresponding musical position. Fur Elise measure 13 now places the lower
  staff treble-clef change near the fourth beat instead of treating it as a
  measure-start clef.
- Expanded measure width calculation for in-measure clef changes and trailing
  flagged notes so dense measures can reserve extra horizontal space instead of
  letting the clef/flag cluster spill toward the next measure.
- Reduced bundled Ode to Joy / Fur Elise MusicXML diagnostics by retaining
  basic `<tied>` notation, simple `<metronome>` tempo marks, explicit safe
  `<stem>` directions, common `<bar-style>` values, and basic `<pedal>` text
  layout. These features now flow through parser/domain/layout/painter instead
  of being reported as unsupported direct notation warnings.
- Added release-polish controls before App Store rollout: Settings now exposes
  a visible reset action for display/playback preferences, loading and import
  failure states provide clearer guidance, and Diagnostics now includes a score
  summary with source name, part/measure/note counts, playback event count,
  layout mode, canvas size, and current BPM.
- Refined the first-use guide flow: the former display-settings step is now a
  Coloring step, a separate Layout step was added, the measure-jump guide
  anchors to the measure input box, and the previous/next guide now highlights
  the Next control directly.
- Retained symbolic MusicXML jump directions (`<segno/>`, `<coda/>`) and
  Unicode Segno/Coda words such as `To 𝄌` and `D.S. al 𝄌`, so clear
  D.S./Coda scores can render markers and expand playback without falling back
  to unsupported diagnostics.
- Retained MusicXML `<credit>` title metadata and `<sound>` jump attributes
  (`segno`, `coda`, `tocoda`, `dalsegno`, `dacapo`, `fine`) so exported files
  that omit work/movement titles or encode D.C./D.S./Coda behavior in sound
  attributes keep clearer titles and jump-only playback expansion.
- Prepared and uploaded the next TestFlight train as `1.1 (2)` with only the
  Ode to Joy and Fur Elise bundled samples. Track-mode bars now use the same
  scheduled durations as the playback visual timeline, keeping the falling bars
  and keyboard highlight aligned.
- Hardened MusicXML/MXL import by rejecting empty supported files and supported
  files larger than 50 MB before parsing. Failed empty/oversized imports keep the
  current score and bundled Library metadata intact.

### SMuFL glyph rendering

- Added Bravura 1.392 as a bundled SDK resource under the SIL Open Font
  License 1.1.
- Added Core Text font registration and an internal SMuFL glyph map for clefs,
  accidentals, rests, repeat dots, time-signature digits, noteheads, and flags.
- Updated `ScorePainter` to render those notation symbols with SMuFL glyphs
  while preserving `ScoreLayout`, `NoteID`, `ScoreElementID`, hit testing,
  color rules, playback events, and app-level responsibilities.
- Tuned SMuFL glyph readability with SDK-internal category sizing for
  noteheads, accidentals, rests, flags, clefs, repeat dots, and time-signature
  digits, plus matching layout frames to reduce clipping and hit-test drift.
- Rebalanced the SMuFL sizing pass after visual QA: whole/half/black
  noteheads now use a closer visual scale, accidentals are slightly smaller,
  rest sizing is consistent, and flags are anchored to the Core Graphics stem
  end instead of floating from the notehead.
- Retuned the SMuFL visual balance after iPad QA: common noteheads are larger,
  stems are shorter and overlap the notehead edge, flags attach closer to the
  stem end, note accidentals sit closer to the notehead, and rest glyphs use a
  more consistent readable size.
- Follow-up SMuFL tuning enlarges black/quarter noteheads again for learning
  readability, shortens stems further, restores down-stem flag glyph selection,
  tightens flag anchors to the stem end, and moves note accidentals closer to
  noteheads.
- Increased clef / key signature / time signature prefix spacing so the
  Notation Coverage Sample exposes clef, key, and time symbols without overlap.
- Added Phase S6 MVP notation refinement: same-system tie/slur curve rendering,
  safe simple beam grouping, basic triplet bracket/number rendering, and the
  self-authored `S6 Notation Refinement Sample` as the current default launch
  sample for QA.
- Fixed the S6 follow-up notation QA issues: tie/slur curves now use the
  opposite-stem side, beams are drawn from the first stem tip to the last stem
  tip, and the S6 sample includes mixed eighth/sixteenth beaming for regression
  checks.
- Added Phase S7 Repeat Playback Expansion MVP: simple forward/backward repeat
  sections now expand in the playback sequence for two passes while preserving
  the original score, layout, note IDs, and playback events.
- Added diagnostics for repeat fallback and unsupported repeat structures such
  as backward repeat without a start, unmatched starts, nested repeats, and
  repeat counts outside the MVP two-pass behavior.
- Added the self-authored `S7 Repeat Playback Sample` grand-staff fixture and
  registered it in the DoReMi Palette Library as the current default launch
  sample for Phase S7 QA. The S6 notation refinement sample remains available
  from Library.
- Added Phase S8 Advanced Repeat / Playback Hardening MVP: first/second ending
  playback expansion, jump-marker parsing/diagnostics, and limited D.C. al Fine
  expansion for jump-only scores while preserving the original score, layout,
  note IDs, and playback events.
- Added the self-authored `S8 Repeat Endings Sample` grand-staff fixture and
  registered it as the current default launch sample for Phase S8 QA.
- Added a piano-focused transpose MVP in DoReMi Palette: `transposeSemitones`
  persists in app settings, playback MIDI pitches are transposed just before
  audio output, keyboard highlights follow sounding pitches, and current-note /
  key text can show written versus sounding values. Score rendering remains
  written-pitch.
- Added Phase T2 Score Display Transpose / MusicXML Transpose Hardening:
  DoReMi Palette can now transpose the rendered score layout while preserving
  the original `ScoreDocument`, `NoteID`, and
  playback event identity. The SDK layout engine applies display-only pitch,
  key-signature, and accidental MVP recalculation from layout options, while
  MusicXML `<transpose>` metadata is parsed and surfaced as diagnostics rather
  than silently ignored.
- Added self-authored T2 samples for key transpose, accidental transpose, and
  MusicXML transpose diagnostic QA.
- Fixed the T2 display-transpose follow-up QA issues: prefix notation now uses
  the standard `clef -> key signature -> time signature` order with expanded
  collision-safe spacing, and note accidentals now resolve to the same pitch
  color as their associated displayed note when note colors are enabled.
  Key-signature accidentals also use pitch-class coloring when note colors are
  enabled.
- Updated the transpose UI so score display transpose is always enabled by
  default and the control uses a key picker (`C`, `C#`, `D`, ...) instead of
  semitone +/- buttons.
- Added a DoReMi Palette Palette Editor MVP. The toolbar palette button opens a
  sheet with 12 pitch-class ON/OFF controls, all-on / all-off reset actions, a
  generated C2-C6 score preview, and a C2-C6 keyboard preview. Disabled pitch
  classes fall back to neutral ink while preserving layout, playback,
  transpose, repeat, Practice Mode, and Library behavior.
- Removed the visible preset pattern picker from the palette sheet and adjusted
  the preview layout so the C2-C6 score preview is visible in the sheet.
- Added an app setting for measure-number display. DoReMi Palette enables it by
  default and renders only odd-numbered measures to keep the score readable.
- Prepared Phase 17B TestFlight readiness: fixed the TestFlight-facing Library
  to bundled learning MXL samples, kept historical S6/S7/S8/S9/S10/T2
  QA coverage as development/test fixture responsibility rather than
  user-facing Library entries, aligned the app version to `0.1.0` / build `1`,
  and added release, privacy, and beta-review checklist documents for
  pre-TestFlight review.
- Replaced the DoReMi Palette bundled sample scores with user-provided MXL
  files from `sample/`. The default launch score is now `Ode to Joy Easy
  Variation`; `Happy Birthday To You Piano` is excluded from the TestFlight app
  bundle after the rights review because its MusicXML metadata names an
  arranger and has no embedded rights grant. `12 Variations of Twinkle Twinkle
  Little Star`, `Canon in D`, and `The Entertainer` are also excluded from the
  app sample catalog.
- Trimmed the TestFlight-facing bundled Library to only `Ode to Joy Easy
  Variation` and `Fur Elise - Beginner Piano`; `美女と野獣`,
  `Articulation & Dynamics Coverage Sample`, and `D.S. / Coda Behavior Sample`
  are no longer copied into the app bundle.
- Bumped the next TestFlight candidate to `1.1 (1)` so it uses a new
  pre-release train after the prior `1.0` App Store Connect version.
- Added a DoReMi Palette Metronome MVP. The app now has a persisted
  metronome ON/OFF setting, starts generated strong/weak clicks with Play,
  stops them on Pause / Stop / Reset / playback end, and follows the current
  playback BPM without adding audio responsibilities to DoReMiRendererKit.
- Fixed mid-playback metronome enable sync so turning the metronome ON during
  playback waits for the next beat boundary instead of starting a new beat cycle
  at the toggle moment.
- Updated the metronome to follow parsed MusicXML time signatures for its beat
  cycle, so 3/4 scores accent every three clicks instead of using a fixed 4/4
  pattern.
- Added Metronome Advanced MVP controls: compound-meter large-beat/subdivision
  modes for 6/8, 9/8, and 12/8, strong/medium/weak accent patterns, tap tempo,
  and generated click sound styles without adding audio responsibilities to
  DoReMiRendererKit.
- Added a measure navigation MVP in DoReMi Palette. The transport row now
  shows the current score measure and total measure count between Previous and
  Next, with an inline field for moving to a validated measure number. Jumps
  reuse the expanded playback event list, update current note /
  keyboard / scroll follow state, pause active playback for safety, and keep
  Practice Mode in sync.
- Normalized SDK measure widths so one-note pickup measures no longer collapse
  to their content width. `ScoreLayoutEngine` now applies an absolute minimum
  width, a normal-measure minimum width, and a first-measure pickup ratio while
  preserving rhythmic spacing, beam grouping, prefix spacing, stable IDs, and
  playback events.
- Hardened measure layout with trailing incomplete-measure minimum widths,
  non-final system justification, multi-voice duration/onset-aware spacing, and
  compact short-note spacing that avoids stretching beamed groups across a
  widened bar. Fur Elise-style sixteenth passages now keep readable visual gaps
  and stay anchored near their rhythmic onset instead of becoming left-flush or
  artificially centered inside normalized measures.
- Added app-side pinch zoom for DoReMi Palette score viewing. The score now
  uses a persisted continuous `0.8x...3.0x` scale and keeps hit testing and
  current-note scroll follow tied to unchanged `ScoreLayout` coordinates.
  Loading a different score or reloading the bundled sample resets the visible
  scale to `1.0x`; Settings keeps the layout selector plus slider and Reset
  Zoom action, while the main screen no longer shows the layout switcher or
  zoom percentage.
- Added a first-use guide for DoReMi Palette. Coach marks step through the
  Settings button, display settings, current-note/keyboard feedback, measure
  jump, Previous/Next, Play/Stop, and key/transpose controls with Back / Next /
  Skip / Done actions. Completion is persisted locally, and Settings includes a
  replay action for the guide.
- Refreshed TestFlight readiness notes after the first-use guide and latest
  bundled-sample set: the default launch sample is `Ode to Joy Easy Variation`,
  release config is `0.1.0` / build `1`, and beta/privacy notes now reflect
  on-device processing plus local-only guide and settings persistence.
- Stabilized large-score playback performance before TestFlight by separating
  static score drawing from playback cursor updates, adding visible-rect
  culling and CoreText/SMuFL text caching, throttling current-note UI updates,
  suppressing per-note scroll follow in large playback layouts, caching
  generated audio buffers, and tolerating duplicate structural `ScoreElementID`
  values in layout lookup maps.
- Prepared the formal App Store release candidate by aligning the app target to
  version `1.0` with build number `3`, keeping the internal TestFlight
  `0.1.1 (2)` build history separate, and updating release metadata/checklists
  for App Store submission.
- Added Articulation / Dynamics MVP support. MusicXML staccato, accent, tenuto,
  strong-accent/marcato, fermata, dynamic marks, and crescendo/decrescendo
  wedges are parsed into domain data, laid out as score elements, and rendered
  from `ScoreLayout` coordinates. Playback events now carry expression metadata
  so DoReMi Palette can make staccato notes shorter, tenuto notes fuller, accent
  / marcato notes louder, and dynamics / same-measure hairpins affect generated
  tone velocity without changing event timing, `NoteID`, or `PlaybackEvent`
  identity.
- Tuned the Articulation / Dynamics MVP after user review: staccato dots,
  tenuto lines, and fermatas sit closer to their notes, dynamic text and
  hairpins keep a small vertical separation, normal generated tones sustain
  longer, and dynamics / hairpin velocity changes are more pronounced.
- Hardened expression handling: below-staff fermatas now use the proper
  inverted fermata glyph for upward-stem flagged notes, fermata events extend
  generated playback duration with a bounded scheduler-safe clamp, and
  cross-measure hairpins can span within a system or split at system breaks.
- Added a stronger expression collision pass in `ScoreLayoutEngine`: note
  articulations are placed after beams so they can avoid beam/flag/stem frames,
  dynamic marks can escape both horizontally and vertically from notation,
  lyrics, fingerings, and articulations, and hairpins choose collision-minimized
  vertical lanes with expanded A4 grand-staff checks.
- Added the self-authored `Articulation & Dynamics Coverage Sample` for
  display and playback QA, with licensing recorded in `ASSET_LICENSES.md`.
- Kept Core Graphics fallback rendering for font lookup or registration failure.
- Advanced dynamic carry-forward, ornaments, advanced beams, complex tuplets,
  and full multi-voice collision-aware engraving remain future work.

### Phase 17A real iPad QA start

- Confirmed a physical `iPad Pro 2nd` running iPadOS `26.4.2` is visible to
  `xcrun xctrace` and `xcodebuild -showdestinations`.
- Confirmed the DoReMi Palette Debug build succeeds for the real iPad
  destination with bundle identifier `com.doremipalette.app`.
- Recorded the current QA blocker: Codex-side `devicectl` install / launch is
  blocked by a local CoreDeviceService initialization timeout, so runtime,
  audio, file-import, and settings QA still need Xcode Run or a recovered
  CoreDevice environment.
- Added the Phase 17A real-device QA checklist and device runbook. No app code,
  SDK code, signing setting, public API, or asset changes were made.

### Added

- Swift Package `DoReMiRendererKit`.
- Added a Print MVP for DoReMi Palette: the app can generate a PDF from the
  current `ScoreLayout` and open the standard iOS print sheet. The SDK exposes
  a small `ScoreGraphicsRenderer` CGContext drawing entry point so printing can
  reuse `ScorePainter` without app-side MusicXML parsing or coordinate
  recalculation.
- Added a score layout switcher for DoReMi Palette. Users can toggle between
  the existing horizontal one-row layout (`横一段`) and an A4-width layout (`A4`)
  that wraps measures into systems; printing always uses the A4 layout.
- Added a DoReMi Palette track layout (`トラック`) that visualizes playback
  events as keyboard-aligned falling bars for DTM/piano-roll style practice
  while keeping PDF printing on the existing A4 layout. Track mode now forces
  the keyboard visible and keeps the falling-note timeline moving from the play
  start clock instead of resetting at every note change; track lanes and current
  bars share the same key-frame geometry and current-pitch source as the
  on-screen keyboard highlight.
- Domain model for score documents, measures, notes, pitch, time, clefs, staves,
  score elements, diagnostics, and color rules.
- Minimal MusicXML `score-partwise` parser with diagnostics.
- MXL loading through standard `META-INF/container.xml` rootfile resolution.
- Minimal score layout engine with deterministic IDs and layout lookup tables.
- SwiftUI Canvas renderer through `ScoreCanvasView`.
- Styling and color resolution through `ScoreStyle`, `ColorRule`,
  `ColorContext`, and `ScoreColorResolver`.
- Hit testing from `ScoreLayout` coordinates.
- Playback event sequence generation without audio playback.
- iOS example app for parse, layout, render, color toggles, tap selection, and
  playback-event stepping.
- MVP0 legal, asset, third-party, and limitation notes.
- Phase 11A iOS Simulator snapshot tests for basic rendering regression
  coverage, including melody, grand staff, chords/rests, accidentals, ledger
  lines, current-note highlight, and note/staff color combinations.
- Phase 11B zoom and scroll coordinate conversion through
  `ScoreViewportTransform` and scaled `ScoreCanvasView` rendering.
- Phase 11D current-note scroll follow target calculation through
  `ScoreScrollFollower`, with `ScoreCanvasView` support for following
  `currentNoteID` changes.
- Phase 11F advanced MusicXML compatibility:
  - local/private diagnostics collection executable and compatibility report
  - lyric and fingering parsing, layout, rendering, hit testing, and snapshots
  - key signature layout elements for treble/bass staves
  - tempo and repeat metadata parsing without audio or repeat expansion
  - specific diagnostics for tuplets, slurs, ornaments, grace notes,
    transposition, beams, cross-staff notation, and voice collision limits
- Phase 12 DoReMi Palette iOS/iPadOS app integration:
  - separate SwiftUI app target under `Apps/DoReMiPalette`
  - bundled self-authored sample loading
  - `ScoreCanvasView` integration with color toggles, tap selection, zoom,
    current-note scroll follow, and Previous / Next stepping
  - simple piano keyboard highlight from public `ScoreLayout` pitch lookup
  - `.musicxml`, `.xml`, and `.mxl` file import through the SDK facade
  - Japanese diagnostics panel and lightweight display settings persistence

### Changed

- Phase 9 public API shrink moved parser, MXL loader errors, layout engine,
  painter, drawing adapters, playback builder, and future interaction handler
  implementation details behind the facade.
- Low-level layout, hit-test, and playback records remain publicly readable, but
  direct initializers are internal. Apps should obtain these values from
  `DoReMiRenderer`, `ScoreLayout`, and `ScoreCanvasView`.

### Known Limitations

- Experimental `0.x` API surface.
- Minimal MusicXML coverage.
- MXL support is limited to standard unencrypted rootfile flow.
- Publishing-quality engraving, complex collision avoidance, complex selection,
  and audio playback are not implemented.
- Snapshot coverage is limited to basic MVP0 rendering cases and does not
  guarantee full MusicXML display quality.
- Advanced MusicXML support remains partial; complex notation often produces
  diagnostics rather than full engraving.
- Pinch zoom, inertial scroll tuning, horizontal page navigation, and advanced
  automatic viewport management are not implemented.
- DoReMi Palette app integration is MVP quality; audio playback, advanced file
  library management, and iPhone-specific polish are not implemented.

## Roadmap Update - 2026-05-06

Added a Phase 13+ roadmap entry in `ROADMAP.md` and linked it from the README,
development notes, integration boundary, MVP limitation notes, and this
changelog. The roadmap now clearly separates:

- Phase 13: app QA, real import verification, and UI tuning
- Phase 14: library, recent files, and persistence
- Phase 15: audio playback
- Phase 16: practice mode
- Phase 17: real iPad and TestFlight preparation

The roadmap also records the feedback loop that sends real app gaps back into
the SDK when needed.

## Phase 13 Part 1 - App QA Start

Added the first Phase 13 app-readiness updates:

- `APP_QA_CHECKLIST.md` for iPad, iPhone, import, diagnostics, keyboard, and
  settings QA tracking
- self-authored import fixtures for `.musicxml`, `.xml`, `.mxl`, invalid
  MusicXML, and unsupported-extension checks
- DoReMi Palette app loader tests for supported import formats, failure
  handling, current-note reset, and existing-score preservation
- small SwiftUI layout polish for iPad readability and minimum iPhone
  reachability

Phase 13 part 1 retry confirmed iPhone launch, bundled sample visibility,
reachable controls, diagnostics sheet display, keyboard setting reachability,
and `1.0x` score visibility. Manual invalid-file selection through the iPad
Files picker remains tracked because the local fixtures still need to be made
available inside the Simulator Files app; app loader tests cover the invalid
and unsupported import paths.

## Phase 13 Part 2 - Keyboard / Settings / Diagnostics QA

Expanded the second Phase 13 app-readiness pass:

- keyboard pitch-mapping tests for natural notes, accidentals, current-note
  changes, chord highlighting, rest/missing-note, and out-of-range behavior
- app regression tests for tap selection, keyboard visibility state, zoom
  coordinate conversion, settings key persistence, diagnostics presentation,
  and color-setting layout/playback invariance
- Japanese diagnostics presentation helper for summary, severity, unsupported
  feature, repeat, and location text
- iPad/iPhone Simulator screenshots for keyboard, diagnostics, and settings QA

Phase 13 remains an app QA phase only. It does not add audio playback, library
persistence, or SDK public API changes.

## Phase 14 Part 1 - Library / Recent Files Foundation

Started the app-side Library / Recent files foundation without changing SDK
public API:

- internal DoReMi Palette library metadata model for sample and imported scores
- local JSON persistence for imported metadata only
- diagnostic-summary, last-current-note, and zoom-scale metadata fields
- bundled sample represented as a sample library item
- successful imports add or update an imported library item
- duplicate imports update the existing recent item
- failed imports keep the current score and do not add library metadata
- app tests for Codable round trips, corrupt store recovery, duplicate update,
  import success, and import failure behavior

Recent files UI, complete security-scoped bookmark restore, missing-file UI, and
remove-from-recent actions remain Phase 14 back-half work.

## Phase 14 Part 2 - Recent Files UI / Persistence / Missing File Handling

Completed the app-side Library / Recent files MVP without changing SDK public
API:

- Library sheet for bundled samples and recent imported files
- sample and imported rows with last-opened date and diagnostics summary
- tap-to-open for samples and recent imported files
- remove-from-recent action for imported items
- minimal bookmark metadata save/resolve path for imported files
- missing-file and failed-reload handling that keeps the current score intact
- app tests for reload success/failure, nil bookmark, bookmark metadata update,
  remove-from-recent, and metadata-only persistence

Security-scoped bookmark behavior remains provider-dependent, and raw MusicXML /
MXL contents are still not persisted by the library.

## Phase 15 - Audio Playback / Playback Runtime

Added MVP app-side playback runtime and generated-tone audio:

- app-side playback state for Play / Pause / Stop / Reset
- event-index based automatic playback over existing `PlaybackEvent` arrays
- tempo selection with clamped BPM handling and parsed tempo metadata fallback
- synchronized `currentNoteID`, score highlight, keyboard highlight, and scroll
  follow through existing app state
- generated sine-tone audio engine using AVFoundation only in the app target
- chord playback by mixing all event MIDI pitches
- rest and tie-continuation events do not trigger new audio
- mock-audio tests for runtime transitions, rest/chord/tie behavior, audio
  startup failure, tempo duration, and layout identity preservation

No SDK public API changes, external audio assets, or new dependencies were
added.

### Fixed

- Fixed a DoReMi Palette crash when changing tempo from the playback control.
  Tempo changes now safely clamp BPM, avoid reentrant SwiftUI state mutation,
  silence current audio, and restart playback scheduling from the current event
  when changed during playback.

## Phase 16 - Practice Mode MVP

- Added app-side Practice Mode for one-event-at-a-time score practice.
- Added written note-name and solfege display for the current practice step.
- Added Practice Mode controls for ON/OFF, Next, Previous, and Reset.
- Added a minimal color palette selector that does not mutate layout or playback
  identity.
- Defined PlaybackRuntime interoperability: Practice Mode stops playback, and
  Play exits Practice Mode for normal tempo-driven playback.
- Added app tests for practice state, note-name formatting, palette invariance,
  and playback/practice coexistence.

## Playback note gate and rhythm sample

- Added app-side `noteGateRatio` for generated-tone playback. Event scheduling
  still uses full `PlaybackEvent` duration, while sound duration defaults to 85%.
- Silenced the current generated tone before each new pitched event so repeated
  same-pitch notes are articulated separately.
- Added the self-authored `rhythm_values_sample.musicxml` bundled sample for
  whole, half, quarter, eighth, rest, repeated-note, and simple chord playback QA.
- Added tests for gate-ratio clamping, sound-duration calculation, repeated same
  pitch playback, and rhythm-value sample parsing.

## Note value rendering fix

- Added MusicXML `<type>` and `<dot>` propagation into the domain and layout
  models so note values are not inferred by the app or renderer.
- Render whole notes as hollow noteheads without stems, half notes as hollow
  noteheads with stems, quarter notes as filled noteheads with stems, and eighth
  notes as filled noteheads with stems and flags.
- Added layout/rendering support for note dots and basic rest-value drawing.
- Added parser, layout, renderer, app sample, and snapshot coverage for rhythm
  value rendering.
- Hotfixed Core Graphics stem geometry so single-voice notes below the middle
  staff line use upward stems and notes on or above the middle line use downward
  stems, while whole notes remain stemless.
- Fixed chord stem direction so chord tones in the same
  part/measure/staff/voice/onset share one MVP stem direction instead of mixing
  up and down stems inside a single chord.
- Fixed current-note scroll follow to avoid recentering every nearby playback or
  practice step. `ScoreCanvasView` now keeps layout-coordinate note anchors and
  only scrolls again when the current note leaves the viewport margin.

## Notation coverage sample and symbol audit

- Added the self-authored `notation_coverage_grand_staff.musicxml` bundled
  sample for checking treble/bass clefs, time and key signatures, accidentals,
  rest values, dots, ties, slurs, repeats, chords, ledger lines, and tempo /
  dynamic diagnostics in one app-visible score.
- Added MVP layout and rendering for clef, time signature, basic barline, and
  repeat barline elements from `ScoreLayout`.
- Added `NOTATION_SUPPORT_MATRIX.md` to distinguish supported, partial,
  diagnostic-only, and unsupported notation symbols.

## SMuFL integration planning

- Added `SMUFL_INTEGRATION_PLAN.md` for the future Bravura-first SMuFL
  rendering track.
- Recorded the license, architecture, QA, snapshot, and stop-condition policy
  for using SMuFL glyphs as symbol shapes while keeping MusicXML parsing,
  layout coordinates, IDs, hit testing, color resolution, and playback in
  DoReMiRendererKit.
- Added roadmap phases S1-S6 for preparation, font registration,
  clef/accidental/rest glyphs, repeat/dynamics/time signatures, notehead/flag
  glyphs, and tie/slur/beam refinement.
- No font files, renderer code, Info.plist entries, snapshot baselines, public
  APIs, or external dependencies were changed in this planning step.

## Playback follow / bounds / audio reliability fix

- Expanded `ScoreLayout.canvasSize` from rendered element union bounds within
  the normal page margins so high/low notes, stems, flags, ledger lines, rests,
  clefs, and barlines are less likely to clip at the top or bottom of the canvas.
- Stabilized `ScoreCanvasView` current-note follow heuristics so playback,
  step, practice, and tap-driven current-note changes can resume after rests and
  follow far-enough notes without snapping every nearby event back to center.
- Added a minimum audible generated-tone duration for short pitched playback
  events while preserving the original event scheduling duration.
- Added regression tests for layout bounds, scroll follow heuristics, and
  repeated/short-note audio paths.

## Tie continuation highlight distinction

- Split DoReMi Palette current-note display into attack and tie-continuation
  highlight states using `PlaybackEvent.noteIDs`, `PlaybackEvent.midiPitches`,
  and public layout pitch lookup.
- Added weaker secondary score highlighting for tied continuations while keeping
  the strong current-note highlight for newly sounding notes.
- Added keyboard highlight styling that distinguishes newly sounding pitches
  from tied continuation pitches.
- Added regression tests for mixed attack/continuation events, continuation-only
  tie events, rest events, and keyboard highlight priority.

## Layout bounds / scroll follow / audio reliability follow-up

- Kept SDK layout bounds stable while adding ScoreCanvasView scroll-content
  padding so edge notes, stems, flags, and ledger lines have room inside the
  scrollable viewport.
- Changed current-note follow to use measured note bounds and edge anchors
  instead of suppressing follow after user scroll or always returning to center.
- Updated playback audio triggering so any event with `midiPitches` plays those
  attack pitches, even when the same visual event also contains tied
  continuation notes.
- Added regression coverage for measured-bounds follow anchors, layout element
  bounds, and mixed tie-continuation/new-attack audio.
- Follow-up fix: moved scroll padding inside the Canvas coordinate system so
  top-edge notation is not clipped by the Canvas itself.
- Restored manual scrolling by keeping measured note-frame updates as data only;
  scroll execution now happens on current-note / zoom / layout changes, not on
  every geometry preference update.
- Removed the extra ScrollView drag recognizer from the follow path so normal
  manual scrolling remains owned by SwiftUI's ScrollView.
- Restored follow for offscreen notes whose measured viewport frame is not yet
  available by falling back to the stable note anchor ID.

## Unreleased

- Added `DoReMiRendererPrintQA`, a command-line A4 print audit tool that renders
  bundled MusicXML/MXL samples to PDF and optional PNG previews with page-slice
  and spacing metrics.
- Added SDK-owned A4 print pages through `ScoreLayout.pages`,
  `ScoreLayoutPage`, and `ScoreLayout.pageLayout(for:)` so DoReMi Palette can
  print page-bounded layouts without app-side score coordinate slicing.
- Split screen A4 from print A4: the on-screen A4 layout keeps the practice
  display scale, while generated PDFs use SDK page assignments with six
  grand-staff systems as the default density and a four-system page fallback
  when rendered bounds would otherwise exceed the page.
- Added manual system/page break inputs to `LayoutOptions` so parsed or
  future-edited break decisions can stay in the SDK layout model.
- Added an oversized-system print fallback that slices tall source windows by
  visual grand-staff rows instead of scaling the entire score to page height.
- Fixed bottom-system clipping in six-system A4 print pages by separating
  unpadded fit checks from padded page clip frames and deriving page
  `contentFrame` values from relocated rendered system bounds.
- Kept iOS/PDF print page vertical margins at 36pt, print grand-staff
  upper/lower staff whitespace at 36pt, and restored the established 68pt
  fixed print-system gap. The gap is now a `LayoutOptions` presentation value,
  so Web tuning cannot change iOS/PDF output.
- Tuned the Web Canvas profile independently to use a 10pt staff space, 64pt
  system spacing, and 8pt measure spacing. Notes, clefs, flags, accidentals,
  and staff geometry continue to scale from the same `staffSpace` source.
- Reserved the first print page's first grand-staff slot for title/composer
  space when a score title is present, so the first page carries five systems
  by default and falls back if rendered bounds require more vertical room.
- Kept print grand-staff system gaps stable on pages with fewer than six
  systems so short final pages leave unused space at the bottom instead of
  spreading systems evenly across the page.
- Tightened A4-only print staff spacing and added page-level top/bottom safety
  margins so generated PDFs avoid cutting through normal grand-staff systems.
- Hardened print page slicing against duplicate `MeasureID` values and
  measure-less notation elements when importing broader MusicXML samples.

## Phase 16.5 - Notation / Playback Stabilization

- Added a formal stabilization gate before Phase 17 for notation display,
  layout bounds, scroll follow, generated-tone playback, and Practice/Playback
  coexistence.
- Added SDK layout-origin compensation for extreme high notation whose rendered
  element bounds would otherwise extend above the canvas origin.
- Added regression coverage for high notes, upward stems, flags, and ledger
  lines staying inside positive canvas bounds.
- Synchronized Practice Mode step movement with `PalettePlaybackRuntime` so
  pressing Play after practice stepping resumes from the practiced event.

## Phase S9 - Advanced Repeat Visuals / Jump Marker Hardening MVP

- Added first/second ending visual bracket layout and Core Graphics rendering
  from `ScoreLayout` elements, including ending numbers and bracket hooks.
- Added `S9 Repeat Visuals Sample` as the default bundled QA sample while
  keeping S6, S7, S8, notation coverage, rhythm values, and the original sample
  available from Library.
- Kept S8 first/second ending playback expansion unchanged and added regression
  coverage that S9 playback order remains intro, repeated body, first ending,
  repeated body, second ending, and outro.
- Strengthened QA/docs around diagnostic-only jump markers such as D.S., Segno,
  Coda, and To Coda. The S9 sample includes a D.S. marker to verify diagnostics
  are visible without changing playback.

## Phase S10 - Complete Repeat Symbols Before TestFlight

- Added jump-only playback expansion for D.S. al Fine, D.C. al Coda, and
  D.S. al Coda while preserving the existing D.C. al Fine path.
- Added explicit repeat-count handling for simple repeats up to four passes,
  with invalid/excessive counts diagnosed rather than silently ignored.
- Added loop-prevention limits for jump/repeat expansion and diagnostics for
  unsafe mixed repeat+jump structures, multiple Segno/Coda markers, nested
  repeats, and third endings.
- Added MVP visual marker layout/rendering for Fine, D.C., D.S., Segno, Coda,
  and To Coda as `ScoreLayout` elements consumed by `ScorePainter`.
- Added five self-authored S10 QA samples for D.C. al Fine, D.S. al Fine,
  D.C. al Coda, D.S. al Coda, and diagnostic repeat/jump cases.
- Added `S10 All Repeat Symbols Sample` so manual QA can inspect repeat
  start/end, first/second endings, Segno, To Coda, Fine, D.C., D.C. al Fine,
  D.C. al Coda, D.S., D.S. al Fine, Coda, and D.S. al Coda in one score.
