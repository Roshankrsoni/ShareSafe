# Scan animation and app regression verification

Date: 16 October 2026. Host: Apple silicon, macOS 15.7.4 (24G517). These results cover this machine and the listed fixtures, not every PDF or supported macOS version.

## Implemented

- Import-only scan workspace with actual rendered page imagery, warm sweeping beam, corner guides, filename, actual page index/count, progress message, and Cancel.
- Image preview is published after orientation/rendering and before OCR. Text imports expose a bounded 4,000-character preview while detection uses the full document.
- A 30 Hz animation timeline exists only while the scan view is visible. Reduce Motion and cancellation use a static frame. Completion has no artificial minimum duration.
- Operation identity checks reject stale preview/progress updates. Completion, errors, cancellation, and password/preparation prompts clear temporary preview state.
- Export retains its existing processing UI and is not presented as an import scan.
- Fixed scan Cancel contrast discovered during visual testing, and removed an obsolete privacy-sheet sentence claiming encrypted PDFs were rejected despite the password recovery flow.

## Automated results

Command from the repository: `swift test --package-path mac-app`.

**47 tests passed; zero failures.** The existing 38 core tests were retained, with three preview regressions and six workspace integration tests added. No warnings or errors appeared in the final test build log.

| Coverage | Evidence |
| --- | --- |
| PDF page preview order and raster geometry | Three-page fixture; preview sizes match imported rasters |
| Text preview truncation | 4,000-character UI limit; detection still finds a later email |
| Image preview and worker cancellation | Image dimensions verified; cancelling before OCR throws cancellation |
| Import failure | Scan state clears; selected existing document survives |
| Immediate cancellation and retry | No cancelled document appended; next import succeeds; scan state clears |
| Password recovery | Prompt appears after scan cleanup; correct password imports successfully |
| Annotated PDF recovery | Previous document survives; preparation retry imports a review copy |
| Export confirmation, undo/redo | Review state and export eligibility restore correctly |
| Zoom and session removal | Width toggle restores previous zoom; removal requires confirmation |
| Existing regression suite | Indian/international detections, false positives, rotated/cropped PDF geometry, form/comment flattening, masks/blur/colors, text aliases, metadata/text removal, export gates, pixel checks, source/symlink protection, malformed and unsupported files |

## Packaged app checks

`bash scripts/build-app.sh` produced the local `dist/ShareSafe.app`. The script's ad-hoc signing and strict signature verification passed; `codesign --verify --deep --strict` also passed after the final build. This is not Developer ID notarization.

Using the native UI and fictional documents:

- A 25-page Northstar sample displayed the actual document with a moving scan beam and page progress, then returned to review with 75 suggestions.
- Individual redaction, undo, redo, Original preview, and zoom were exercised. Original view remained visibly selected after export.
- Export requested review confirmation, opened export settings and the native save panel, and saved a separate 25-page PDF. The receipt reported mask-pixel checks, page-count verification, and image-only output. The saved test output was 258 KB.
- The final build displayed a dense 40-page fictional fixture during processing, with readable Cancel control. Cancelling returned to the empty workspace and displayed “Import cancelled.” No partially imported document was added.
- An oversized import displayed the rendering-limit error and returned control instead of retaining the scan view.

An isolated QA bundle's UI automation connection timed out after a rebuild. That particular attempt is inconclusive. The dense scan and cancellation were then repeated successfully in the rebuilt normal app bundle. A process sample during the timeout showed the main thread in its event loop; this alone does not establish the cause of the automation timeout.

## Remaining validation

- Reduced Motion is implemented and code-reviewed; toggling the actual system preference and full VoiceOver traversal remain manual checks.
- No sustained energy/frame-time benchmark or minimum-hardware performance claim is made. Timeline frequency is capped, but actual frame delivery depends on the system.
- Wider macOS/Intel compatibility, difficult real-world language/scan coverage, and independent redaction/security auditing remain release work.
- No claims of exhaustive document support or complete sensitive-information detection follow from this test run.
