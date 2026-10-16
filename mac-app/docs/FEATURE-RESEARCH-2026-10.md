# ShareSafe: next-feature research and delivery plan

Research date: 16 October 2026. These are proposals, not shipped capabilities. The scanning animation is implemented separately. This update builds on [the earlier OCR and batch plan](FEATURE-RESEARCH-AND-PLAN.md), with priorities based on the current app and the reported detection problems.

## Recommendation

Build **Recognition Quality Review** first, then **Visual Privacy Suggestions** for QR/barcodes and faces. Follow those with a **Repeatable Review Queue**. Improve the existing export receipt into an **Export Inspection Report** as a smaller parallel product improvement once inspection tests exist.

These priorities are engineering/product judgments, not validated market demand. Competitor documentation establishes features offered, not adoption, accuracy, sales, or customer willingness to pay. Interview 5–8 people who routinely share resumes, identity scans, invoices, or client briefs before committing to the larger queue project. Use fictional documents in demonstrations and ask where they still manually check or repeat work.

## Added feature: face-region review and round masks

This feature is now implemented in the Mac app. Apple Vision's `VNDetectFaceRectanglesRequest` returns face rectangles; `VNFaceObservation.boundingBox` uses normalized image coordinates with a lower-left origin. ShareSafe processes the already rendered page image locally and shows a padded oval suggestion titled **Face region**. It neither identifies nor names a person. The suggestion starts pending and needs the same explicit Keep/Redact decision as other findings. Face suggestions apply to new PDF and image imports when the **Suggest face regions** setting is enabled. Text files do not have face geometry.

Users can choose **Rectangle** or **Round** while drawing a manual mask. Round uses an ellipse based on the drag bounds, which suits face regions and other curved details. The selected geometry is retained in the session, appears in both views, and is written into the exported page image using the same shape-aware mask renderer. Solid masks remain the recommended treatment for sensitive material; a round blur remains visual concealment only.

### Research and product boundaries

- Apple documents `VNDetectFaceRectanglesRequest` as returning face bounding boxes and `VNFaceObservation` as its result. Its normalized bounding boxes use a lower-left coordinate origin. This makes it possible to use the page's existing OCR, preview, and export coordinate system without uploading images or storing face identity data. [Apple: face rectangle request](https://developer.apple.com/documentation/vision/vndetectfacerectanglesrequest), [Apple: face observation](https://developer.apple.com/documentation/vision/vnfaceobservation), [Apple: bounding box](https://developer.apple.com/documentation/vision/vndetectedobjectobservation/boundingbox)
- A face box is a candidate region, not a person identity or a privacy judgment. Profile photos, illustrations, tiny faces, occlusion, rotation, and low-quality scans can cause misses or false matches. Use neutral “Face region” labels and require human review; do not announce the document is face-free after a scan.
- A bounding ellipse only covers the detected face region. It does not cover the rest of a portrait or prove that a person cannot be recognized from clothing, captions, context, or other images. Use the manual rectangle/round draw tool to cover a larger portrait when needed.
- Elliptical masks must preserve the original pixels outside the ellipse, including on a page export. The export renderer therefore creates a source-preserving tile, applies the chosen solid or blur effect within the ellipse, and passes that tile through the same output pixel comparison as rectangle masks.

### Future quality work

Add fictional and consented fixtures for portrait photos, scanned IDs, group photos, small/cropped faces, illustrated faces, rotations, annotations, and faces near page edges. Measure face-region coverage, misses, false suggestions per page, latency, and memory on the minimum supported OS and hardware. Validate ellipse coverage visually and verify that preview and export agree at rotated/cropped page coordinates. Keep the feature optional if measured noise makes page review worse.

## Current baseline and gaps

The app renders PDFs, combines embedded text and Vision OCR, suggests sensitive text, supports exact matches and manual rectangles, and creates image-only PDF/PNG or replaced-text exports. Existing controls cover individual decisions, custom solid/blur masks, original/protected views, undo/redo, page zoom, recovery copies, password prompts, and export receipts.

Current constraints materially affect the roadmap:

- Vision recognition languages depend on the installed OS/API. An identifier regex cannot recover text that OCR never recognized.
- No recognized text and no sensitive findings are different outcomes. Neither establishes that a page is private.
- Text detection does not propose masks for faces or encoded QR content. Users must draw those masks themselves.
- Sessions hold at most eight documents and 100 million raster pixels; each import also has file/page/rendering limits. A queue must manage memory rather than simply increase these caps.
- Solid masking and image-only exports have verification tests; blur is only visual concealment. A stronger report must preserve that distinction.

## Evidence from primary sources

| Evidence | Implication for ShareSafe | Limit of the evidence |
| --- | --- | --- |
| [Apple Vision text recognition](https://developer.apple.com/documentation/vision/recognizing-text-in-images) describes runtime language support and language prioritization. | Show actual availability and page-level recognition evidence; benchmark language choices. | API support does not prove recall or mask geometry on real scans. |
| [Tesseract language/model data](https://tesseract-ocr.github.io/tessdoc/Data-Files-in-different-versions.html) lists Hindi, Bengali, Tamil and other script models; [its manual](https://tesseract-ocr.github.io/tessdoc/Home.html) documents the engine and licensing. | Evaluate a local fallback for missing scripts using the same corpus. | A listed model is not a quality guarantee. Native packaging, model licensing and distribution size require validation. |
| Apple provides [barcode detection](https://developer.apple.com/documentation/vision/vndetectbarcodesrequest) and [face rectangle detection](https://developer.apple.com/documentation/vision/vndetectfacerectanglesrequest). | There is a native route to visual suggestions without a cloud service or identifying a person. | Detection is not identity recognition or proof that a code is sensitive. |
| [Adobe’s redaction workflow](https://experienceleague.adobe.com/en/docs/document-cloud-learn/acrobat-learning/advanced-tasks/protect/redact) separates finding/removing visible content from sanitizing hidden information. | Explain export transformations and verifiable checks separately from detection coverage. | Matching Acrobat’s broad editing suite would be a different product. |
| [PDF Expert search and redact](https://pdfexpert.com/features/search-pdf-mac) supports removing repeated matching text across a document. | Repeated matching is a baseline expectation; ShareSafe already has exact-text matching. Invest beyond duplicating that feature. | This does not establish demand for a multi-document policy queue. |
| [Apple Preview](https://support.apple.com/en-gb/guide/preview/prvw11580/11.0/mac/26) offers manual redaction and distinguishes editable annotations from flattening. | ShareSafe should differentiate through assisted review and clear export evidence. | A comparison of documentation is not a head-to-head accuracy test. |

Apple’s [motion guidance](https://developer.apple.com/design/human-interface-guidelines/motion) also informs the shipped scan treatment: functional motion, a reduced-motion alternative, and no animation that delays completion.

## 1. Recognition Quality Review — highest priority

**Problem:** Users cannot tell whether zero suggestions means no matches or an unreadable scan. This is especially important for regional scripts, faint scans, and mixed-language pages.

**Experience:** Each page gets a recognition summary: Embedded text, OCR available, Limited recognition, or No readable text. A “Check recognized text” action places OCR spans beside the original region. Users can choose supported recognition languages and retry that page. Show confidence as recognition evidence, never a probability that the document is safe.

**Architecture:** Introduce an `OCRProvider` interface returning spans, normalized geometry, engine/language metadata, and recognition confidence. Store page diagnostics separately from `Finding` and `ReviewDecision`. Preserve native PDF text as a complementary source. A retry replaces that page’s suggested findings transactionally, invalidates its review state, and offers undo; manually drawn masks must survive. Stable region identifiers or an explicit confirmation are needed before carrying old decisions onto new text.

**MVP:** Vision language selection; low-text/low-confidence notices; recognized-text inspection; single-page retry. The fallback engine is a separate experiment, not an automatic dependency. Prototype Vision versus Tesseract on synthetic English, Hindi, Tamil, and Bengali pages before choosing models.

**Acceptance:** Measure sensitive-field recall, precision, false candidates/page, and sensitive-glyph coverage by script and scan condition. Include rotation, crop, low contrast, mixed columns, and text hidden behind visible annotations. Every empty/unsupported fixture must surface a review notice. Retrying must preserve manual masks and invalidate review; cancellation restores the old page. Establish latency and peak-memory baselines on the minimum supported hardware. Do not publish language claims from one clean sample.

**Estimated effort:** 2–3 engineer-weeks for native diagnostics and retry; an additional 3–5 for a measured fallback-engine pilot. Estimates assume one experienced macOS engineer and an available labeled corpus.

## 2. Visual Privacy Suggestions — second priority

**Problem:** A document may expose identity through a face, QR code, or barcode even after its visible email or ID text is hidden.

**Experience:** Optional “Visual details” suggestions appear in the existing review list with a cropped region and Keep/Redact actions. Label a face as “Face region” rather than identifying the person. Label codes by type where available. Do not display decoded payloads by default, open links, or claim every face/code is private. Default masks for these suggestions should be solid.

**Architecture:** Run Vision face/barcode requests on the already-rendered upright page image, with cancellation between requests. Map their normalized bounding boxes through the same export coordinate path used by text and manual masks. Extend finding kinds and accessibility labels without requiring a text range; current text-only operations must handle visual findings explicitly. Avoid decoding payloads if geometry alone is sufficient. Store regions only in session memory.

**MVP:** Rectangular face and QR/barcode proposals. No face identity, signature recognition, handwriting guarantees, or automatic export. Deduplicate overlapping code detections and pad full code boundaries, including quiet zones, conservatively.

**Acceptance:** Synthetic codes with known payloads and consented/synthetic portraits; multiple faces; rotated and cropped PDFs; codes near page edges; tiny/low-resolution codes; logos that resemble faces. Redacted codes must fail a decode attempt in the test corpus, but this check must not be marketed as universal proof. Verify pixel coverage, original-file hashes, undo/redo, Keep behavior, and absence of hidden source data in exports. Track false suggestions/page to avoid making review noisier.

**Estimated effort:** 2–4 engineer-weeks, with geometry and false-positive testing as the main uncertainties.

## 3. Repeatable Review Queue — after coverage improvements

**Problem:** Repeated document types require the same choices on every file.

**Experience:** Multi-select import creates a queue with Waiting, Scanning, Needs review, Ready, Exported, Cancelled, and Failed states. A named policy proposes categories and mask appearance. Each document remains independently reviewable. “Export reviewed items” previews destinations and unresolved items rather than silently skipping failures.

**Architecture:** A bounded queue orchestrates the existing processor. Keep only the active document’s rasters plus a small prefetch budget. Security-scoped access must remain valid for each job. Store policy configuration separately from document data; do not persist recognized values by default. Define collision handling, cancellation/retry, and per-file receipts before adding folder traversal. Exact terms can themselves be sensitive, so persistent custom terms require explicit opt-in and a delete path.

**Acceptance:** At least 20 mixed fixtures with duplicate names, one corrupt PDF, a password prompt, and a cancellation. No cross-file decisions or findings; no source overwrite; no reviewed state carried across a policy edit. Report every outcome. Measure sustained memory rather than relying on file count. Keep existing single-document review semantics, including the explicit export confirmation for undecided suggestions.

**Estimated effort:** 4–6 engineer-weeks. Defer folder watchers, recursive import, cloud policies, and unattended output.

## 4. Export Inspection Report — build on the existing receipt

**Problem:** Users need understandable evidence of what happened to their exported file without interpreting a hash as a safety certificate.

**Experience:** Show export format, selected mask count, page count, structural/text-layer checks, source-preservation result, and limitations. Offer an optional local report that excludes source text, detected values and absolute paths. A “Review exported copy” action opens the result explicitly.

**Architecture:** Reopen saved bytes and inspect the actual output, not only in-memory render inputs. Keep separate fields for checks passed, checks not performed, and warnings. An optional local OCR rescan may flag residual candidate text for further review; a clean rescan must never mean “all private information removed.” Keep transient diagnostics out of logs.

**Acceptance:** Tampered/truncated output, text-layer injection, wrong page count, partial writes, blur outputs, and hardlink/symlink collisions all have explicit outcomes. A report corresponds to the hash of the saved file. Do not write a persistent sidecar unless requested.

**Estimated effort:** 1–2 engineer-weeks for a report over existing verified checks; 2–3 more for independent output inspection and a measured OCR rescan.

## Delivery sequence and decision gates

1. Freeze a representative corpus and baseline the existing detector before changing engines.
2. Ship recognition diagnostics and single-page retry. Validate whether users understand “limited recognition” without assuming “zero findings” is safe.
3. Add visual suggestions, checking whether their review value outweighs false positives.
4. Expand output inspection; validate reports with users before adding persistent artifacts.
5. Start the queue only when throughput and correction-rate evidence justify it. Policies should speed up review, not conceal uncertainty.

Before release: run the existing regression suite, add fixtures for each new transformation, test accessibility and reduced motion, test macOS 14 and newer releases on Intel and Apple silicon where supported, and complete signing/notarization and independent redaction review. Current testing on one Apple-silicon Mac does not establish that matrix.
