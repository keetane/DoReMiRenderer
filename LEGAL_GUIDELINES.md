# Legal Guidelines

This document is a project hygiene checklist, not legal advice. Before selling,
publishing, or externally distributing DoReMiRendererKit as an SDK, have the
repository, sample assets, dependency notices, and license terms reviewed by a
qualified legal professional.

## Clean Implementation Policy

- Do not copy code from commercial or open source score rendering SDKs.
- Do not copy headers, type definitions, sample code, binaries, internal
  documentation, or implementation details from score rendering SDKs.
- Do not imitate API names, type names, or internal architecture from SeeScoreLib,
  OSMD, VexFlow, Verovio, MuseScore, or similar projects.
- Do not describe this project as compatible with, derived from, or equivalent to
  any third party score rendering SDK.
- Use public specifications and platform documentation as implementation
  references, including MusicXML and Apple platform APIs.

## Review Before External SDK Release

- Confirm all source files have an intentional license policy.
- Confirm all sample MusicXML and other assets are original, CC0, or explicitly
  licensed for the intended use.
- Confirm `THIRD_PARTY_NOTICES.md` lists every third party dependency and its
  license obligations.
- Confirm no external SDK API names, type names, sample code, or internal
  implementation structures have been copied.
- If any contributor has used trial, evaluation, or proprietary versions of a
  commercial score rendering SDK, obtain an independent clean-room review from a
  reviewer who has not accessed that SDK.

## MVP0 Status

MVP0 is an internal development milestone. It is not a final external SDK release.
