# Design and motion refresh

October 11, 2026. Reference: https://ox.lol/ (inspected in the live browser because the web retrieval service could not open it).

## Observed design patterns

The live reference uses a very large, tightly tracked semibold sans-serif headline (observed 93.6px / 600 at desktop), warm off-white background with a faint square grid, an angled dark eyebrow ribbon, pill navigation and filters, vivid green highlights, and layered rounded cards with offset bottom shadows. Its leaderboard emphasizes one dominant card followed by secondary rows. Strong dark text and a limited accent palette provide hierarchy.

ShareSafe adapts those broad patterns across its hero, navigation, features, gallery, animated workflow, pricing and final CTA. Its own crimson logo/action color remains. Pale lime/olive is used for local/privacy context, and an olive-black stage anchors the workflow. The reference's bidding, rankings, customer figures, logos, copy and proprietary artwork are not copied.

## Motion implementation

- `src/AmbientScene.tsx` / `src/threeScene.ts`: real Three.js WebGL scenes featuring an extruded crimson shield, a modeled layered document with masked lines, physically based materials, environment lighting and gentle pointer response. A second shield appears at the final CTA.
- Scene code is dynamically imported only near the viewport. At most two small canvases, pixel ratio capped at 1.5, frame rate capped at approximately 30fps. Rendering pauses out of view, in hidden tabs or via each explicit Pause motion control. GPU resources and observers are disposed on unmount. Reduced motion initially uses the static shield; unsupported/lost WebGL has a static fallback. Hero 3D decoration is omitted on narrow layouts.
- `src/Workflow.tsx`: four-stage illustrated document sequence with scan pass, selected-detail masks and export seal. Visible Play/Pause/Replay and direct step buttons; keyboard accessible. Automatically plays once upon entering view, stops after the last step, pauses out of view/hidden tabs, and uses manual Next step under reduced motion. The illustration is visibly labelled and never represented as an actual app screenshot.
- `src/useReveal.ts`, `premium.css`, `reference.css`: short entrance transitions, gallery transitions and restrained hover movement. All CSS motion respects prefers-reduced-motion; content remains visible without JavaScript.
- `src/WorkflowGif.tsx`: genuine-app GIF walkthrough, click-to-play and pause back to poster. GIF decoding is stopped out of view; no automatic GIF motion. A download link delivers the real asset.

## Generated GIF

`public/images/product/sharesafe-workflow.gif`: 960×700, 24 frames, about 1.48 MB, 10.2-second loop with four genuine app states and brief crossfades. Sources are the existing detection, individual-decision, protected-view and export-receipt screenshots. Every example is fictional. The poster is a small WebP. Reproduce with `node scripts/generate-workflow-gif.mjs`; normal builds use the committed outputs.

The GIF is an actual app walkthrough. The separate animated paper diagram is explanatory artwork. Neither sends or processes visitor documents.

## Performance boundaries

Core application JavaScript is about 81 KB gzip; the optional Three.js scene is about 144 KB gzip in a separate chunk. Vite reports the large uncompressed Three.js chunk as a size warning; it is lazy-loaded and not merged into the initial app chunk. No Lighthouse score or frames-per-second benchmark is claimed. The approximate 30fps value is the explicit rendering cap, not a measured device-performance promise.
