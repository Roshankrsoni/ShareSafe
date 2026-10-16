# ShareSafe: research and plan for two roadmap features

**Prepared:** 10 October 2026
**Status:** Product and engineering proposal; implementation has not started.

## Scope and recommendation

The existing product notes identify two planned capabilities: evaluated multilingual detection and batch policy workflows. This document turns those roadmap entries into buildable plans. The recommended order is to establish multilingual OCR quality and limits first, then add batch processing on top of the measured detector. Batch magnifies both throughput and detection mistakes, so its safety model depends on per-document review.

The recommendations below distinguish observed competitor capabilities from evidence of customer demand. Vendor pages establish that a feature is offered; they do not establish market size, retention, or willingness to pay.

## 1. Multilingual detection for scanned documents

### User problem and product outcome

Digital PDFs often expose selectable Unicode text to ShareSafe, while scanned pages depend on OCR. A scan can therefore omit a name or identifier even when the same printed document would be detected as a digital PDF. The product outcome should be: recognize supported scripts in scanned pages, show the recognized text in context, and place conservative, reviewable candidate masks over sensitive values. The UI must state which OCR languages are available on this Mac and must never imply complete coverage.

### Research findings

- Apple Vision exposes the supported-language list at runtime, language ordering, accurate/fast recognition levels, and language auto-detection. Apple’s 2025 document-processing session describes text recognition in 26 languages. These facts support an OS-native first pass, but do not prove that each Indic script is available on every supported macOS release. Availability must be queried on the installed OS and tested against ShareSafe’s actual minimum target. [Apple Vision OCR API](https://developer.apple.com/documentation/vision/vnrecognizetextrequest), [WWDC25: Read documents using Vision](https://developer.apple.com/videos/play/wwdc2025/272/)
- Apple’s WWDC26 session describes a newer OCR tool used with language-model sessions that reads more than 30 languages. This is a separate API path and should not be treated as a drop-in replacement for the current Vision request until its macOS availability, runtime requirements, privacy behavior, and language list are verified. [WWDC26: What’s new in image understanding](https://developer.apple.com/videos/play/wwdc2026/237/)
- Tesseract documents OCR under Apache 2.0, with language and script data distributed separately, including a Devanagari script model and more than 130 language packages across more than 35 scripts. It is a plausible local fallback, but its accuracy, packaging size, native build burden, and geometry quality on ShareSafe’s PDFs require measurement. [Tesseract documentation](https://tesseract-ocr.github.io/tessdoc/)
- PaddleOCR’s project documents support for more than 100 languages, including Devanagari, Telugu, and Tamil. Its broader coverage is interesting for an optional engine experiment, but the runtime and model footprint are a larger integration question for this small native app. Do not choose it based on language count alone. [PaddleOCR project](https://github.com/PaddlePaddle/PaddleOCR)
- A 2026 research preprint specifically studies OCR and post-correction on Devanagari scans, including degradation conditions. This reinforces the need for a representative benchmark; it is not evidence that any one engine meets ShareSafe’s safety bar. [Can OCR-VLMs Read Devanagari?](https://arxiv.org/abs/2606.29213)

### Product scope

**MVP:**

1. Add a small OCR-provider interface so PDF rendering, OCR text, confidence, and bounding boxes do not depend directly on one engine.
2. Keep Vision as the default path. At import, query the current Mac’s supported recognition languages and expose selectable languages/settings rather than showing a hard-coded promise.
3. Let users choose Auto, one language, or a small prioritized set for mixed-script documents. Do not run every language on every page by default; it increases latency and may reduce text quality.
4. Join OCR spans into script-aware reading lines for detection, while retaining source-level bounding boxes for exact mask placement. Keep PDF embedded-text extraction as a parallel source and deduplicate overlapping results.
5. Add an opt-in experimental local engine only if the benchmark proves a material coverage gain for scripts Vision lacks. Bundle only chosen model files, record their licenses, version hashes, and size, and disclose whether models are bundled or downloaded. Document bytes remain local; any model download is separate from document processing and requires a clear user-visible install choice.
6. Show per-page language/recognition status, confidence, and a “manual review required” indicator for unsupported, low-confidence, or nearly empty OCR pages. Never silently mark an unreadable page as covered.

**Out of scope for first release:** handwriting guarantees, translation, semantic inference of hidden identifiers, cloud OCR, and claiming a document is safe because OCR completed.

### Benchmark and release gates

Build a consented and synthetic corpus with digitally generated and scanned pages. Cover English plus a staged set of Indian scripts (start with Devanagari/Hindi, then Tamil and Bengali; add Telugu and other scripts after evidence), mixed English/Indic text, common Indian personal and financial fields, low-resolution scans, skew, rotation, compression, faint text, forms, and multi-column layouts. Keep personally identifying source documents out of the test corpus unless there is explicit, documented permission and secure handling.

Measure separately by script, engine, OS version, clean/degraded image, and field type:

- OCR character and word error rates.
- Sensitive-value candidate recall and precision.
- **Mask coverage:** fraction of the labeled sensitive glyph area covered by the proposed redaction geometry. Text recognition without accurate geometry is a failure for redaction.
- False candidates per page, latency per megapixel/page, peak memory, model download/bundle size, and cancellation behavior.
- Protected-output checks for residual selectable text, OCR-readable fragments, wrong-coordinate masks on rotated/cropped pages, and unchanged source bytes.

First release gate: zero missed critical test identifiers in the locked release corpus; at least 98% geometric coverage of labeled critical spans; no more than a 1 percentage point regression in the current English corpus; and publish measured per-script recall/precision and OS availability in the UI/help. These are internal release targets, not a promise that every real-world document will be detected. If an engine fails the gate for a script, label it experimental or unsupported and keep manual masking available.

### Technical plan and effort

1. **Corpus and instrumentation (about 1 week):** freeze current English baselines; define a synthetic fixture generator and labels including bounding polygons; expose timing and confidence in internal diagnostics without logging document text.
2. **Engine abstraction and runtime language selection (about 1–2 weeks):** isolate Vision, query languages per OS, and add mixed-script settings. Preserve existing PDF native-text supplement and orientation/crop transforms.
3. **Indic engine bake-off (about 2–3 weeks):** compare Vision and at least one packaged local candidate on the corpus. Decide by measured recall, mask coverage, speed, memory, distribution size, and license review. Avoid an engine commitment before this gate.
4. **Review UX and hardening (about 1–2 weeks):** language availability, low-confidence page notices, OCR diagnostics, cancellation, output re-scan, and cross-version verification.

Rough estimate: 4–8 engineer-weeks for a dependable first version, with engine integration and corpus construction the main uncertainties. This assumes one experienced macOS engineer and a product owner available to supply representative, consented samples.

## 2. Batch policy workflows

### User problem and product outcome

People who repeatedly prepare similar files need to apply consistent redaction choices without repeating setup on every document. The product outcome should be a local queue that applies a reusable policy as a *proposal*, then lets the user inspect each document and save each separate output. Batch must not turn uncertain detection into unattended publication.

### Research findings

- Adobe Acrobat documents pattern search and redaction, configurable redaction appearance, sanitization, and Action Wizard workflows that can be applied to multiple files. This sets a professional-tool baseline for repeatable operations, but Acrobat is a broad PDF suite rather than an exact like-for-like local-first competitor. [Acrobat redaction guide](https://helpx.adobe.com/acrobat/desktop/protect-documents/redact-pdfs/redact.html), [Acrobat Action Wizard reference](https://helpx.adobe.com/pdf/acrobat_reference.pdf)
- PDF Expert documents whole-document search and bulk removal of repeated text, alongside manual redaction. It is useful evidence that users expect repeated matching within one PDF; it does not by itself provide evidence for ShareSafe’s proposed multi-file policy queue. [PDF Expert search and redact](https://pdfexpert.com/features/search-pdf-mac), [PDF Expert redaction help](https://support.readdle.com/pdfexpert/en_US/edit-pdfs/remove-sensitive-content)
- Hushmark advertises reusable templates and batch redaction in its Mac app; its current site lists a $4.99 one-time price and local processing. These are vendor claims and pricing observed on the page, not audited sales or customer outcomes. The direct overlap means “offline batch redaction” alone is not a differentiator. [Hushmark](https://hushmark.shrikar.dev/)
- Redacted advertises batch workflows on Mac and on-device processing. This further validates category competition, not demand. ShareSafe’s opportunity is safer review orchestration and predictable document-specific outcomes, rather than the existence of a batch button. [Redacted](https://redacted.app/ios)

### Product scope

**MVP:**

1. Add multiple PDFs/images/text files to a queue from a multi-select open panel or drag-and-drop. Initially do not recurse folders; make directory traversal a later opt-in feature.
2. A **policy** stores which finding categories are proposed for redaction, exact terms/patterns, mask appearance, and sharing intent. Applying a policy creates normal per-document Redact/Keep decisions; it never exports automatically.
3. Show queue states (waiting, scanning, needs review, ready, exported, failed/cancelled), per-file suggestion/page counts, and a clear retry path. Selecting an item opens the existing single-document review experience.
4. Require a per-document review and explicit save destination. A future “export reviewed queue” action may only operate on items that have independently passed the current review gate and must show the full output list before saving.
5. Preserve existing source-file protection, fresh-output generation, pixel/text verification, receipts, no-network processing, and explicit warnings for flattened PDFs and blur.
6. Keep policies local and user-editable. Do not persist source contents, detections, or sensitive values in the policy. Give policies a version and allow rename, duplicate, update, and delete.

**Out of scope for first release:** recursive folder watch, background processing after app quit, unattended export, shared/cloud policies, team approval, cross-document identity linking, and multi-file PDF merge.

### UX and safety rules

- Opening a queue says files are processed on this Mac and shows the selected files before starting.
- Policy application is previewed as “proposed redactions” with category counts. Users can change decisions for every file independently.
- A policy change after review invalidates that document’s review state.
- Duplicate filenames, source/destination collisions, encrypted/unsupported files, and partial failures are resolved per item. A failure cannot silently skip a source or report a successful batch.
- Each output is saved as a separate copy. No “replace original” option.
- The batch summary lists every source, destination, outcome, and verification result. Receipts remain per output; do not write a sidecar containing detected values.
- Respect current resource limits by processing documents sequentially or with tightly bounded concurrency, releasing page images when a document leaves the review queue. The current app cap of eight session documents and 100 megapixels means a true large-folder queue needs a separate bounded queue model; do not simply raise the in-memory cap.

### Acceptance criteria

- Apply one policy to at least 20 mixed fictional fixtures; each produces independent suggestions and decisions with no cross-file leakage.
- Every file can be opened/reviewed independently. No item marked pending or with an unreviewed page can be exported.
- A changed policy invalidates the affected reviewed state and updates the preview before export.
- Cancel, retry, and one corrupt/password-protected file do not lose other queue items or produce a false success.
- Existing export checks pass for every output; sources remain byte-identical and cannot be overwritten through normal or symlinked paths.
- Bounded-memory run through a representative queue completes without loading all page rasters simultaneously. Establish throughput targets from the fixture benchmark instead of promising a fixed folder size up front.

### Technical plan and effort

1. **Policy model (about 1 week):** versioned, serializable rules with no document values; explicit migration and deletion behavior.
2. **Queue state machine (about 1–2 weeks):** bounded processor, cancellation/retry, scoped file access, independent outcomes, memory lifecycle. Keep existing `ReviewDocument` review and export logic as the per-item unit.
3. **Policy proposal and per-file review UI (about 1–2 weeks):** queue navigation, policy preview, apply/undo, status and error handling.
4. **Verified output flow (about 1 week):** destination selection, collisions, receipts, partial-batch recovery, and larger mixed fixture coverage.

Rough estimate: 4–6 engineer-weeks for a polished, safe initial queue, assuming policies remain local and the first version uses explicit file selection rather than recursive folders.

## Suggested sequencing and decision points

1. Approve corpus languages and source/consent rules, then instrument the current OCR before selecting an Indic OCR dependency.
2. Ship supported-language reporting and benchmark results. Only add a second OCR engine for scripts where measured improvements justify its binary/model cost.
3. Design and ship the local policy model and bounded queue after measurement hooks exist. Keep each document’s review decisions and export authorization independent.
4. Pilot with fictional fixtures and a small opt-in group using redacted examples. Track task time, correction rate, per-script miss rate, queue abandonment, processing time and memory. Never collect document contents or detections as analytics.

## Sources

- Apple Vision API: https://developer.apple.com/documentation/vision/vnrecognizetextrequest
- WWDC25 document OCR: https://developer.apple.com/videos/play/wwdc2025/272/
- WWDC26 image understanding: https://developer.apple.com/videos/play/wwdc2026/237/
- Tesseract: https://tesseract-ocr.github.io/tessdoc/
- PaddleOCR: https://github.com/PaddlePaddle/PaddleOCR
- Devanagari OCR evaluation preprint: https://arxiv.org/abs/2606.29213
- Adobe redaction and Action Wizard: https://helpx.adobe.com/acrobat/desktop/protect-documents/redact-pdfs/redact.html and https://helpx.adobe.com/pdf/acrobat_reference.pdf
- PDF Expert: https://pdfexpert.com/features/search-pdf-mac and https://support.readdle.com/pdfexpert/en_US/edit-pdfs/remove-sensitive-content
- Hushmark: https://hushmark.shrikar.dev/
- Redacted: https://redacted.app/ios
