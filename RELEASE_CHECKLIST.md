# Release Checklist

Use this checklist before tagging or distributing DoReMiRendererKit.

## Versioning

- Confirm the release version and tag name.
- Confirm `Package.swift` dependency ranges are intentional.
- Update `CHANGELOG.md`.
- Update `README.md` examples and status notes.
- Update `API_STABILITY.md` if the public API changed.
- Update `MVP0_LIMITATIONS.md` if support status changed.

## Verification

- Run `swift test`.
- Build the example app:

```sh
xcodebuild build \
  -project Examples/DoReMiRendererExample/DoReMiRendererExample.xcodeproj \
  -scheme DoReMiRendererExample \
  -destination 'platform=iOS Simulator,name=iPad Pro 13-inch (M5),OS=26.4.1'
```

- Run `Scripts/check-licenses.sh`.
- Run `Scripts/build-docc.sh`.
- Confirm the DocC archive is generated at `/tmp/DoReMiRendererKit.doccarchive`
  or the configured `DOCC_OUTPUT_PATH`.

## Legal And Assets

- Review `LICENSE`.
- Review `THIRD_PARTY_NOTICES.md`.
- Review `ASSET_LICENSES.md`.
- Review `LEGAL_GUIDELINES.md`.
- Confirm ZIPFoundation remains listed with its MIT License.
- Confirm no GPL or LGPL dependency has been added.
- Confirm sample MusicXML and MXL fixtures are original or otherwise properly
  licensed.
- Obtain qualified legal review before external sale, publication, or SDK
  distribution.

## Release Artifacts

- Archive the source package at the release tag.
- Archive the DocC output if distributing documentation.
- Archive Example App screenshots if needed for release notes.
- Confirm artifact names include the release version.
- Confirm no local-only paths, credentials, or private files are included.

