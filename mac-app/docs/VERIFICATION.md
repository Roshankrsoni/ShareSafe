# Verification — 9 October 2026

## Completed on this machine

Environment: Apple Silicon, macOS 15.7.4, Xcode 16.4 / Swift 6.1.2. Minimum deployment target: macOS 14.

- 25 XCTest cases passed with zero failures, including Unicode ranges, overlapping matches, repeated aliases, Luhn validation, review gates, source protection via symlinks and hardlinks, cancellation, invalid geometry and unsupported inputs.
- Export tests verify opaque pixel masks, fresh image metadata, PDF page count, removal of source text/annotations/author information, OCR re-import of the protected result, and unchanged source bytes.
- PDF fixtures cover rotated and cropped pages, encrypted inputs, and rejection of forms/comments.
- Release build succeeded. Strict ad-hoc code signature verification passed. App sandbox and selected-file access entitlements are included; no network entitlement is granted.
- Packaged app UI: loaded bundled fictional PDF, detected email/phone/card, added a custom name match, applied four redactions, completed review and exported using the native save dialog.
- Successful save receipt: every selected mask passed pixel checks; page count verified; fresh image-only PDF produced. Test output: `dist/Northstar · client brief-shared.pdf` (approximately 119 KB).
- Dark studio appearance visually inspected with the designed Northstar sample. No claim of exhaustive light/dark, accessibility or OS coverage.

An earlier idle observation showed 0.0% CPU and approximately 87 MB resident memory. This is a single-machine observation, not a performance benchmark. Imports and exports run off the main actor, with bounded input/render sizes and cancellation checkpoints.

## Release gates

1. Configure the product owner's Apple Developer identity, release bundle identity, Developer ID signing and notarization; verify distribution on a clean Mac. Current signing is local/ad-hoc only.
2. Test macOS 14 and newer on supported Intel and Apple Silicon hardware, multiple displays and accessibility settings, including VoiceOver and keyboard-only review.
3. Broaden the redaction corpus across real-world PDF producers, rotations/crops, unusual image color spaces and malformed inputs. Commission independent privacy/security review before marketing high-assurance guarantees.
4. Measure OCR recall/precision across intended languages, document classes and hardware. Current OCR is tuned for printed English and is explicitly advisory.
5. Validate privacy-manifest declarations and App Store/direct-distribution requirements against the final release feature set.
6. Add release automation and update/distribution infrastructure as needed. Billing, cloud accounts, collaboration, DOCX and licensing are outside this local preview.

## Known behavior

Image/PDF custom matching masks full OCR lines conservatively. PDF exports are rasterized, removing original text, links and attached object structures but also sacrificing searchability and vector quality. Re-review is required after decisions change. Session documents are not persisted; secure RAM erasure is not promised. Backups and destination permissions remain operating-system concerns.

## Minimal workspace and international detection update

- 32 automated tests pass. Added fixtures for PAN/Aadhaar candidates, Indian mobile and international phones, UPI, labeled bank/passport/DOB/address fields, Devanagari labels and nonbreaking spaces.
- Added rotated Indian-format PDF fixture and protected-output rescan; custom-color and Gaussian-blur PNG export tests; invalid appearance rejection.
- PDFKit text supplements Vision OCR using the same crop/rotation transform as the page renderer. OCR language auto-detection uses only languages actually supported by the installed Vision revision. No cloud service is used.
- Mask appearance applies per document and is undoable. Solid color replaces pixels; blur retains transformed source information and is explicitly labeled visual concealment in the editor, export sheet and receipt.
- Visual check: minimal light and dark workspace with fit-page preview, style popover, custom color selection and blur control. Appearance settings expose actual OCR language support.

References checked for this update:
- [Apple: automatic OCR language detection](https://developer.apple.com/documentation/vision/vnrecognizetextrequest/automaticallydetectslanguage)
- [Apple: supported recognition languages](https://developer.apple.com/documentation/vision/vnrecognizetextrequest/supportedrecognitionlanguages())
- [UIDAI: Aadhaar format](https://www.uidai.gov.in/en/my-aadhaar)
- [Income Tax Department: PAN](https://www.incometaxindia.gov.in/w/what-is-pan-)

PAN and Aadhaar regexes produce candidates for review. They do not authenticate documents or verify ownership/issuance. Label-based address matching covers one line; multi-line addresses, unlabeled fields, QR codes and portraits still require manual masks. No user-provided failing PDF was available for case-specific regression testing.

## Office-style layout update — 10 October 2026

Replaced the permanent session sidebar with horizontal document tabs and a top ribbon. Added optional page thumbnails, a collapsible review pane, and persistent status-bar zoom controls. Release build and signature verification passed; all 32 existing core tests passed.

Packaged-app checks confirmed Home/View ribbon switching, page navigation visibility, zoom-in from fit-page to 70%, zoom-out to 60%, actual-size 100%, slider adjustment to 105%, and fit-page reset. The dark Office-style workspace was visually inspected. Document processing and export algorithms were not changed in this layout update.

## Pinterest-inspired studio revision — 10 October 2026 (current)

- All 38 automated tests passed with zero failures. Release build and strict app signature verification passed.
- Added résumé regression checks using fictional contact data: contextual header names, profile URLs, email and phone detection, and rejection of technology words as person names.
- Added mixed Keep/Redact and all-Keep review cases, annotation preparation with unchanged source bytes, visible form widgets, encrypted PDFs with correct/incorrect passwords, and cropped/rotated annotation masking with protected-output OCR checks.
- Inspected the light studio UI in a separate QA app to preserve the user's existing session. Verified review confirmation with pending suggestions, all-Keep export eligibility, Page Width/Restore View returning to 100%, Original view, and confirmed session removal.
- The native file-picker automation did not complete the final live annotated-file import check. PDF recovery behavior is covered by automated integration tests; the dialog-to-import interaction remains a manual QA item.
- No actual failing résumé PDF was supplied for direct regression; the screenshot informed a fictional fixture. Detection remains advisory, with installed Vision language limits unchanged.

Current build: `dist/ShareSafe.app`. Previously open app processes must be restarted to load the new build; documents must be reimported to rerun detection. Sessions are memory-only, so export any needed work before restarting.
