# OpenScreen reference study and ShareSafe implementation

Reference: https://getopenscreen.com/ — inspected October 12, 2026 in desktop dark and light appearances, including the live scroll-driven editor and lower video chapters.

## Composition and hierarchy

OpenScreen uses a 60px full-width sticky navigation bar, with the brand and product links on the left and utility controls plus the main action on the right. The centered hero starts with two small pills, then a restrained one-line desktop headline, a two-line description and a single primary action. The measured headline is 66px, weight 700, 1.1 line-height and -0.03em tracking. The desktop background is #080a0d in dark mode and #fafbfc in light mode. Secondary text is muted neutral gray, with a restrained mint/forest green action color.

A 1312px-wide colorful stage follows the hero. During scrolling it becomes a sticky two-column feature demonstration: a narrow explanation and control panel on the left, with an evolving product composition on the right. The long sequence makes the product itself the main content. Lower sections switch to a 1080px content width, centered 44px headings, concise text, full-width videos or tabbed media, and three explanatory columns below. Later sections use paired feature explanations, an honest text-led product section, quick-start cards and a multi-column footer.

## Motion and interaction

The reference keeps the header still and uses scroll to change the editor's focus and composition. Media frames remain stable as states change. Pause controls are visible. Tabbed chapters expose specific functions without forcing visitors through every video. The surface treatment is restrained: fine borders, 16–22px frame corners and soft shadows, with colorful backgrounds limited to demonstrations.

## Application to ShareSafe

- A compact centered hero with two truthful product badges, one green CTA and platform details.
- A wide product stage that narrows into a sticky tour for Detect, Decide, Protect and Export. Scroll selects each state; explicit controls support manual selection and playback. Narrow screens and reduced-motion mode use a compact, non-pinned presentation.
- Genuine ShareSafe light/dark screenshots, never recolored to simulate the other appearance.
- Two 20-second, 30fps H.264 demo films, composed from the real captures, with restrained camera movement and crossfades. Video playback stops offscreen or when the browser is hidden. Reduced-motion mode starts paused; native frames remain visible as posters. Only the active theme's video is requested.
- An accessible before/after range control and Review / Compare / Protected buttons using genuine matching screenshots.
- Feature chapters, product details, format and limit table, privacy facts, planned pricing, FAQ and footer follow the reference's reading sequence. Duplicate marketing sections have been consolidated.
- ShareSafe retains its real native features and pre-launch status. OpenScreen's download availability, platform support, awards, open-source claims and community metrics are not ShareSafe claims.
- One standalone stylesheet replaces the previous chain of design overrides on the active page. Earlier files and a local backup remain available.

## Assets and reproduction

`public/images/studio-wallpaper.svg` is an original vector background. It uses broad warm and cool color fields to support the product screenshots. No reference artwork or video was copied.

`render-product-video.swift` writes the light/dark MP4s from prepared PNG captures. `extract-video-posters.swift` extracts their first frames; Sharp optimizes those frames into WebP posters. Videos are silent visual demonstrations of actual states; they are not presented as real-time recordings or evidence of processing speed.
