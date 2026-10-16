# ShareSafe — product and engineering specification

Approved for implementation 9 October 2026. This specification precedes implementation. Working name; trademark clearance remains a release task.

## Product decision

ShareSafe is a local document preparation workspace for consultants and small agencies. Its primary job is to create a reviewed copy before sharing client material. Secondary use: prepare anonymized plain text for AI analysis. The product is not a legal compliance certification or an automatic guarantee that all sensitive information has been discovered.

Journey: import → detect locally → review each suggestion and every page → add manual masks or exact-text rules → preview the output → export a separate, verified copy. Originals never change. Documents and findings remain in session memory, not a history database. Quit or remove a document to discard the session; exported files remain under the user's control.

MVP: PDF, PNG/JPEG/HEIC and UTF-8 TXT/MD; email, phone, payment-card, US SSN and person-name suggestions; custom exact-text rules; redact/keep decisions; manual rectangular image/PDF masks; page navigation; original/protected preview; explicit review acknowledgement; rebuilt image-only PDF, clean PNG and redacted/anonymized text exports; local export checks; native open/save panels; drag and drop; keyboard commands; preferences and privacy information. Built-in fictional sample is explicitly marked.

V1 after pilot: evaluated multilingual detection, reviewed accessibility, import and export performance across a fixture corpus, customizable policy persistence, signed/notarized distribution, independent security review. Later: DOCX structure-aware handling, batch policy workflows, App Intents, organization policy administration. Cloud services and subscriptions are deferred until they provide actual ongoing value.

## Competitive position

Public documentation reviewed on 9 October 2026; availability means advertised, not independently benchmarked. Unknown means not verified, rather than missing. No superiority claim is earned before testing.

| Capability | ShareSafe build scope | Apple Preview | Hushmark | Acrobat Pro | PDF Expert | CleanShot X |
|---|---|---|---|---|---|---|
| PDF redaction | Rebuilt raster PDF | Available | Advertised | Available | Advertised | Not a general PDF editor |
| Local sensitive-content suggestions | Patterns, names, exact rules | Not documented in reviewed guide | Advertised | Search/pattern tools | Search/redact | Capture-oriented |
| Hidden PDF source content discarded | Rebuild from page pixels | TOC redaction caveat documented | Unknown here | Sanitization documented | Unknown here | Not applicable |
| Explicit per-finding decisions | Required | Manual selection | Review advertised | Review workflow | Manual/search workflow | Manual capture editing |
| Consistent text aliases | Plain text only | Not documented | Unknown here | Unknown here | Unknown here | Not applicable |
| Manual masks | Available | Available | Unknown here | Available | Available | Available |
| Session-only source retention | Design choice | File based | Local processing advertised | File based | File based | History varies |

References: https://hushmark.shrikar.dev/ ; https://helpx.adobe.com/acrobat/desktop/protect-documents/redact-pdfs/sanitize.html ; https://pdfexpert.com/features/search-pdf-mac ; https://support.apple.com/en-euro/guide/preview/prvw11580/mac ; https://cleanshot.com/pricing .

Candidate advantages to validate: a focused review queue; explicit unsupported cases; session-only retention; consistent text aliases; clean-room raster exports; human review gates; no network dependency. These are differentiators to test, not proven moats. Hushmark already overlaps heavily. Proposed $59–99 perpetual pricing requires interviews and willingness-to-pay tests. No payment screen or fake purchase flow in this build.

## Apple capability combination

| Apple capability | Role in ShareSafe |
|---|---|
| Finder / native Open and Save panels | Explicit user-selected input and separate output |
| Quick Look / Preview conventions | Familiar page canvas, zoom, comparison and review |
| Vision | Offline OCR with located text ranges |
| NaturalLanguage | Optional local person-name suggestions; never authoritative |
| Core Graphics / ImageIO | Normalize orientation, raster masks, fresh image/PDF output |
| SwiftUI / AppKit | Native window, toolbar, menus, sidebar, keyboard access |
| Shortcuts / App Intents | V1 integration; does not bypass required review |

Apple Intelligence is not required. The installed Xcode 16.4 / macOS 15 SDK cannot supply later Foundation Models APIs. Core workflows target macOS 14+ using public APIs and no third-party packages.

## Architecture

Swift package with a reusable ShareSafeCore library and ShareSafeApp executable, packaged as a real .app by a reproducible script. SwiftUI handles the scene, review workspace and inspector; AppKit provides native panels and application lifecycle. No web view. Core models use value types. Import and export run outside the main actor. MainActor workspace state owns selection, async task cancellation and review changes.

Core pipeline: immutable input bytes → bounded rendering/OCR → page images and located findings → review decisions/manual masks → export snapshot → fresh output generation → structure/pixel/content checks → atomic save. Source URL is retained only to prevent overwriting the source. SHA-256 output receipt is shown in memory; no sensitive sidecar is exported automatically.

The PDF export deliberately discards the source object graph. It paints each page image and selected opaque masks, then puts only that raster image into a fresh PDF. Original metadata, attachments, annotations, actions, hidden text and incremental revisions are never copied. This removes searchability, forms, signatures and vector fidelity. Export explains this tradeoff. No PDFKit black rectangle annotation is treated as secure redaction.

Plain-text export operates on UTF-16 ranges, merges overlaps, and replaces selected values in reverse order. Alias assignment is deterministic by category and normalized value within a document. No alias map is written to disk. Images are re-encoded to PNG without copying original metadata. OCR is best effort; unrecognized text, handwriting, addresses and indirect identifiers require manual review.

## UX and visual system

Three regions: a compact document sidebar, generous neutral page canvas, and focused review inspector. Pinterest-inspired red accent, rounded surfaces, fine borders and native typography. Primary action hierarchy: add → review → export. No decorative dashboard, artificial metrics or subscription prompts. Window supports light/dark appearances. Standard window controls are appropriate for a document workspace.

Empty state introduces the workflow and a clearly fictional sample. Loading state reports pages and supports cancellation. Errors explain unsupported or oversized files without logging their contents; password-protected files prompt for a password, and annotated files offer a prepared review copy. Findings can be redacted or kept, with visible status. Export remains unavailable until all findings have decisions and every page is acknowledged as reviewed. Any change to findings or masks invalidates the affected review acknowledgement. Privacy and output limitations are available before import and during export. Preferences cover person-name suggestions and appearance; content never enters UserDefaults.

Accessibility: system font sizes, semantic controls, VoiceOver labels for masks/findings, full text-based finding review, keyboard commands, high-contrast decisions, reduced-motion compatible transitions. Manual geometric masking also has an exact-text route; nontext areas still require pointer interaction in this initial version and need further accessibility work.

## Performance and limits

One import/export operation at a time; no periodic polling, network traffic or background indexing. OCR off the main thread, page-level autorelease pools and cancellation checkpoints. Inputs limited to 25 MB, 40 PDF pages, 12 million pixels per rendered page and 60 million aggregate pixels. PDF rendering at up to 144 dpi with bounds. User-selected source data is read once. Target idle CPU near zero, no background work with an empty queue. These are design targets, not benchmark claims. Large documents are rejected clearly instead of silently partially scanned. Cap session queue and aggregate pixel storage.

## Security and release boundaries

No networking, analytics, third-party SDKs, auto-upload or secret logging. Store only nonsensitive preferences. Do not overwrite original, symlink to original, or an existing export without the native Save dialog confirmation. Export must be atomic and must fail rather than emit incomplete output. Cancelled jobs never write output. Untrusted PDFs and images use Apple parsers, bounded dimensions, and no script execution.

Local processing is not secure memory erasure; the OS may swap process memory or create crash diagnostics. Exported files inherit destination storage and backup behavior. Review is required even if zero findings are detected. Checks establish specific output properties, not anonymity or regulatory compliance.

For distribution: Developer ID signing, hardened runtime, notarization, privacy policy, support policy, icon/name clearance, clean-machine and physical Intel tests. No identity or paid developer account is assumed. The local build is ad-hoc signed and does not claim App Store acceptance or public-release readiness.

## Validation plan

Unit: Unicode ranges, overlapping matches, Luhn validation, duplicate aliases, review gating, masks and boundaries. Integration: generated PDFs with hidden text, annotations and metadata; raster-export text removal and masked pixels; rotated/cropped pages; images with metadata; invalid/encrypted PDFs; cancellation; size limits; preserve original bytes. UI smoke: import, decisions, page review, exact rules, masks, export, reset, settings; capture actual app for visual QA. Manual release matrix: light/dark, keyboard/VoiceOver, scale factors, macOS 14/15 and current release, Intel/Apple Silicon, denied access, disk full, sleep/wake, large files, installation/update/removal. Tests performed are recorded separately from release tasks still outstanding.

## Studio and PDF recovery revision — 10 October 2026

Name detection now requires plausible multiword values and surrounding contact or explicit label context, suppressing résumé technology tokens. OCR name detection runs on page context rather than isolated lines. Personal profile URLs have a dedicated category. These are conservative heuristics, not a measured guarantee of recall.

Visible PDF annotations and widget values can be rendered into a session review copy after an explicit choice. PDFKit appearances and CoreGraphics content share crop/rotation coordinates; annotation values also provide conservative full-annotation detection regions. The original bytes remain unchanged. Hidden comments, interactive content, attachments and signature validity are not preserved. Passwords are session-only. Export still rebuilds a raster document.

Pending suggestions can be kept in a single explicit confirmation when acknowledging a page. This does not bypass the export gate: every finding receives a decision and every page still needs review. File removal is separately confirmed. Page Width remembers and restores the previous zoom mode and percentage.
