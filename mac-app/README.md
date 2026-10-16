# ShareSafe

A native, offline Mac workspace for reviewing sensitive details before sharing a document. Built with SwiftUI, AppKit, Vision, NaturalLanguage and CoreGraphics. Requires macOS 14 or newer.

## Try the app

Open `dist/ShareSafe.app`, then choose **Explore with a fictional sample**. Review each suggestion, add exact text matches or draw masks, confirm each page, and export a separate copy. The File menu also includes a plain-text sample.

The workspace uses a Pinterest-inspired red accent, rounded adaptive surfaces, a left navigation rail, a central document toolbar, and a focused review inspector. Documents remain in memory for the session; preferences alone persist.

## Build and verify

```sh
swift test
bash scripts/build-app.sh
```

The build script creates an ad-hoc signed, sandboxed app with hardened runtime and selected-file read/write access. It grants no network entitlement. Open `Package.swift` in Xcode to develop the project. No third-party dependencies are needed.

See [the scan and regression verification report](docs/SCAN-VERIFICATION-2026-10-16.md) for the latest 47-test run, native UI checks, and remaining validation.

## Import scanning

Imports show the current page with a warm scanning beam while local recognition runs. The page counter follows the actual PDF page being processed. Cancel stops the import at the next processing checkpoint; Reduce Motion uses a static frame. Fast imports finish immediately without an artificial animation delay.

See [the October feature research](docs/FEATURE-RESEARCH-2026-10.md) for the proposed recognition-quality review, visual privacy suggestions, batch queue, and export inspection report. These roadmap features are not implemented yet.

## Supported workflow

- PDF, single-frame images, and UTF-8 plain text import; embedded PDF text extraction plus language-aware local OCR.
- Email, Indian/international phones, PAN/Aadhaar candidates, UPI handles, Luhn-checked payment cards, US identity-number patterns, labeled bank/passport/birth-date/address fields personal profile links and contextual name suggestions.
- Per-finding Keep/Redact decisions, exact custom matching, drawn image masks and per-page review gates.
- Optional, on-device face-region suggestions for PDFs and images. ShareSafe marks candidate regions for human review and does not identify people.
- Manual rectangular or round (elliptical) masks, with shape-preserving previews and exports. Choose either shape while drawing.
- Custom opaque mask colors and adjustable Gaussian blur. Blur is visual concealment only and may leave details recognizable; choose Solid for sensitive exports.
- Undo/redo review edits, including mask appearance changes.
- Original/protected previews; deterministic aliases for plain-text AI sharing.
- Fresh image-only PDF and PNG exports; text replacements for plain text.
- Pixel-mask checks, page-count checks, SHA-256 receipts, atomic saves and original-file protection including symlinks and hardlinks.

Automatic detection is approximate. Names, handwriting, addresses and contextual identifiers may be missed. PDF export intentionally loses searchable text, vector detail, forms and signatures. PDFs containing annotations or forms offer an in-app review copy that renders visible appearances. Password-protected PDFs prompt for the password. Damaged or unsupported PDFs can still fail to decode; file and rendering limits remain enforced. Originals are never intentionally overwritten.

## Architecture and delivery status

See `docs/PRODUCT-AND-ARCHITECTURE.md` for product analysis and technical decisions, and `docs/VERIFICATION.md` for actual verification and remaining release gates.

This is a working local preview, not a notarized public release. Developer ID distribution, wider device/OS validation, accessibility audit, and independent redaction/security review remain release work.

Scanned-script support is limited by the installed macOS Vision models; see Settings → Text recognition for the actual languages on your Mac. On the tested macOS 15 system, Hindi and several Indian scripts are not available for scanned-image OCR. Embedded Unicode text is still used from digital PDFs. Reimport existing documents to use the new detector.

## Studio workspace

The left rail contains navigation and session files. Hover a filename to reveal its remove button; removal asks for confirmation and never deletes the source. The central toolbar keeps Undo/Redo, zoom, drawing and mask appearance close to the document. Original and Protected views remain available. Search and category filters help review suggestions in the rounded inspector.

Page Width toggles to Restore View while active and returns to the preceding zoom setting when switched off. The status bar also provides a 25–300% zoom slider. Keyboard controls: Command-minus to zoom out, Command-equals to zoom in, and Command-zero for 100%.

Every suggestion can be kept or redacted individually. Checking page review while suggestions remain undecided asks explicitly whether to keep those remaining details; Redact All is optional. Review changes remain undoable.
