# Verification report

October 11, 2026. The existing Swift app was preserved; native tests were not rerun because this task changes only the independent website.

## Completed

- Production build: passed, including TypeScript check, Vite bundling and static React prerender.
- ESLint: passed with no errors/warnings.
- Unit/contract tests: 6 passed. Covers unverified offer with/without a URL, $2 and $5 verified modes, unsafe/missing URL fallback, internal anchors/supporting page existence, screenshot assets, Dodo checkout CTA and delivery disclosure.
- Dependency audit: zero known vulnerabilities after updating the image optimizer. Audit is a point-in-time dependency check, not a security certification.
- Dev server and production preview: HTTP 200. Production page hydrated successfully in the Codex browser; no captured page console warnings/errors.
- Actual responsive browser render: 1440, 1280, 1024, 768, 390, 320 pixels. Document width equals viewport width at all six; no horizontal overflow. Saved full-page screenshots in ignored `artifacts/viewport-*.png`, plus `artifacts/responsive.json`.
- Visual inspection: desktop hero/full page, tablet, narrow mobile. Corrected oversized feature-card height and crowded 320px header.
- Mobile navigation: opens/closes, selecting Features closes it and navigates; Escape closes it and restores button focus.
- Gallery: Detect initial state plus Decide, Protect, Export controls update real screenshots/captions. Enter activates the Protect control.
- FAQ: all nine disclosures opened and closed by click; first disclosure separately tested with Enter to open/close.
- CTA: header Buy, pricing Buy ShareSafe, and both Download CTAs use the live Dodo hosted checkout in every environment. The pricing section discloses that app/license delivery is not configured.
- Supporting destinations: Product guide and Launch & support status opened in the browser and rendered their expected headings. No fake external/legal/support links.
- Accessibility: semantic header/main/footer, one H1, labelled navigation, real buttons with pressed/expanded state, native details disclosures, image alternatives, visible focus styles, skip link, and reduced-motion CSS. Read-only computed foreground/background contrast check caught small-caption failures; corrected colors and reran with zero flagged text nodes. This check excludes screenshot text, complex compositing, and does not certify WCAG conformance.
- Images: responsive WebP derivatives (roughly 32–64 KB each), explicit dimensions, eager high-priority hero, lazy below-fold images, system fonts, no third-party runtime requests.
- SEO: prerendered HTML, title/description, Open Graph with genuine-app social image, favicon and honest SoftwareApplication JSON-LD. Private preview deliberately noindex; canonical/sitemap/indexing activate only on configured public origin.

## Measurements and limits

Production assets: approximately 252.45 KB JavaScript / 78.08 KB gzip, 24.12 KB CSS / 6.29 KB gzip. These are actual Vite build figures, not Lighthouse scores. React hydration is the primary JS cost.

Lighthouse, axe, screen-reader testing, real touch hardware and cross-browser coverage were not run. Available browser tooling supports rendering, interactions and read-only DOM checks; no Lighthouse auditing API is exposed. No performance or WCAG certification score is claimed.

Payment completion, launch-cap concurrency, payment webhooks, download delivery, licence activation, legal destinations and production-domain behavior are not end-to-end verified. The current Dodo product has no digital-file delivery or licence configured. See `launch-readiness.md`.

## Design and animation refresh — October 11

Rebuilt and verified after the ox.lol-inspired design refresh. Build/type checks, lint and all six contract tests pass; npm audit reports zero known vulnerabilities. Vite flags the optional 565 KB uncompressed Three.js chunk; it is a separate dynamic import (about 144 KB gzip), not part of the 81 KB gzip initial application JavaScript.

Browser checks: live WebGL canvas initialized with no console errors; 3D Pause changes to Play; workflow auto-advanced from 01 to 02; direct Review/Redact/Export, keyboard Enter, Replay back to 01, and Pause worked. GIF Play loads the actual GIF; Pause switches to WebP poster. Mobile navigation to the workflow works at 320px; workflow text and controls fit. Rendered widths 1440,1280,1024,768,390,320 match document widths without overflow. New palette text-contrast check found green eyebrow labels below 4.5:1; darkened them and reran with zero flagged non-decorative text nodes. No full accessibility certification is implied.

The GIF was decoded with Sharp to confirm GIF format, 960px width, 700px frame height, 24 frames and 10.2-second loop duration. File size 1,476,531 bytes. Screenshots saved as ignored `artifacts/motion-*.png` and `artifacts/sharesafe-premium-hero.png`. OS-level reduced-motion emulation was not available; reduced-motion CSS and media-query behavior were inspected in source, not claimed as an automated OS test.
