# Verified ShareSafe feature inventory

Audit: October 11, 2026. Source paths below are relative to the native `ShareSafe/` directory (website is a separate subdirectory). “Implemented” means present in inspected code, not a guarantee for every input. No core app files were changed by this website task.

| Feature | Status | Benefit and limitation | Evidence |
|---|---|---|---|
| Native macOS 14+ app | Implemented | SwiftUI/AppKit, not a browser application. Build architecture/signing must be verified for distribution. | `Package.swift`; `Sources/ShareSafeApp/ShareSafeApp.swift` |
| PDF import/rendering | Implemented | Local PDFKit/CoreGraphics rendering. 40-page, 25MB and pixel budgets apply. Not all PDFs supported. | `Sources/ShareSafeCore/DocumentProcessor.swift:14`; `Models.swift` |
| Password and annotation review copies | Implemented | Password prompt; opt-in prepared copy for visible annotations/forms. Hidden comment bodies and interactivity are not preserved. | `DocumentProcessor.swift`; `Sources/ShareSafeApp/Workspace.swift`; `WorkspaceView.swift` |
| Images and text | Implemented | Single-frame PNG/JPEG/HEIC; UTF-8 TXT/MD. Images export PNG; text exports TXT. No DOCX import. | `DocumentProcessor.swift` |
| Local OCR + embedded PDF text | Implemented, coverage partial | Vision OCR and native text supplement one another. Scan quality and OS language availability limit recognition. No every-script guarantee. | `DocumentProcessor.swift:115,155`; app Settings |
| Sensitive-detail suggestions | Implemented, coverage partial | Emails, phones, profiles, card candidates, Aadhaar/PAN/UPI and contextual identifiers. Card Luhn filtering; contextual person-name rules. False positives/negatives remain. Not identity validation. | `Sources/ShareSafeCore/Detection.swift:8`; detection tests |
| Individual Redact / Keep | Implemented | Human decisions determine masking. | `Sources/ShareSafeApp/Workspace.swift`; `StudioWorkspace.swift` |
| Bulk current-page redaction | Implemented | Applies to suggestions on current page. Not folder batch processing. | `Workspace.swift`; `StudioWorkspace.swift` |
| Suggestion search | Implemented | Filters detected findings. Not general full-document PDF search. | `StudioWorkspace.swift` |
| Exact-text matching | Implemented | Adds case-insensitive exact string matches as findings where text is available. | `DocumentProcessor.swift:232`; `Detection.swift:97` |
| Manual rectangles | Implemented | Handles areas detection missed. User must accurately cover the content. | `DocumentCanvas.swift`; `Workspace.swift` |
| Solid mask color and blur | Implemented | Custom solid RGB and adjustable blur. Blur is visual concealment, not secure replacement for solid redaction. | `Sources/ShareSafeCore/MaskRenderer.swift`; `Models.swift` |
| Original / Protected, zoom and navigation | Implemented | Thumbnails, page navigation, zoom 25–300%, page-width toggle restores prior view. | `Sources/ShareSafeApp/DocumentCanvas.swift`; `StudioWorkspace.swift` |
| Undo / redo | Implemented | Reversible review decisions before export. Exported pixels cannot be restored by undo in the output file. | `Workspace.swift` |
| Multiple session files/removal | Implemented | Up to eight in-memory documents, confirmation before removing. Not durable session persistence. | `Workspace.swift`; `StudioWorkspace.swift`; `Models.swift` |
| Export-time review prompt | Implemented | Export opens a confirmation when review is incomplete. Confirmation keeps undecided suggestions and marks pages reviewed; it does not detect missing content. | `Workspace.swift:85–99`; `WorkspaceView.swift` |
| Fresh PDF export | Implemented | Applies masks to raster pages and writes a fresh image-only PDF; source text/link/attachment object graph not copied. Searchability, vector fidelity, forms and signature validity are lost. | `DocumentProcessor.swift:265–342` |
| PNG / text export | Implemented | Fresh PNG strips original image metadata; selected text becomes replacements or consistent AI-context aliases. | `SafeExporter`; `TextRedactor` |
| Original overwrite protection | Implemented | Separate save path; checks open sources including filesystem alias conflicts. | `DocumentProcessor.swift:371`; export tests |
| Export verification receipt | Implemented | Pixel/tile checks, PDF page count and SHA-256. No certification that all sensitive content was found. | `SafeExporter`; `Workspace.swift:258`; `DocumentCanvas.swift` |
| Local workflow | Implemented | macOS frameworks; sandbox with selected-file access, no network entitlement, no app analytics/upload service found. Later sharing, swap and backups outside scope. | `Resources/ShareSafe.entitlements`; app/core source audit |
| Indian-language OCR expansion | Planned | Current OS-supported language list only; further models/benchmarking not shipped. | `docs/FEATURE-RESEARCH-AND-PLAN.md` |
| Batch / reusable privacy policies | Planned | Not marketed as available. | `docs/FEATURE-RESEARCH-AND-PLAN.md` |
| Checkout / first-10 enforcement | Dodo hosted checkout linked; first-10 price change not enforced | Product is configured for $2 USD one-time; static checkout has no successful-purchase counter or automatic price change. | Dodo product `pdt_0NnhU4WmYU9pKWXnIILA7`; website `src/config.ts` |
| Public signed/notarized distribution, licence terms | Not launch-ready | Dodo digital-file delivery and licence fulfillment are not configured; public app delivery is not verified. | `scripts/`; `README.md`; `docs/launch-readiness.md` |

## Claim boundaries

Only selected solid masks replace sensitive pixels in exported images. Detection is advisory. Rebuilding prevents the old PDF objects from being copied, but visible unmasked content remains. No HIPAA/GDPR certification, independent audit, encryption guarantee, secure-memory erasure, lossless export or complete detection claim is justified.

## Screenshot provenance

17 originals were captured in the previous screenshot task from the real app with the fictional Northstar sample, October 10, 2026. Stored in `ShareSafe/public/images/product/`. This website reuses four distinct states and a review-panel crop, optimized into `website/public/images/product/`. No generated UI or customer documents were used. The screenshots retain real OS capture/window details; inactive controls may look muted. Capture session was isolated from the user's live documents.
