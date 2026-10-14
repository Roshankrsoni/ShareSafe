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
- Two 24-second, 30fps H.264 films (1280×860), composed from the real captures: a title card, four captioned scenes (Detect, Decide, Protect, Export) and an end card, joined by crossfades. Captures play at a fixed size with **no camera zoom**, so every pixel of the real UI stays legible. A pointer animates across each scene, a tooltip names the control under it, and a spoken narration cue explains each step. Playback stops offscreen or when the browser is hidden. Reduced-motion mode starts paused; native frames remain visible as posters. Only the active theme's video is requested. Autoplay is muted per browser policy; a speaker button in the player opts into sound.
- An accessible before/after range control and Review / Compare / Protected buttons using genuine matching screenshots.
- Feature chapters, product details, format and limit table, privacy facts, planned pricing, FAQ and footer follow the reference's reading sequence. Duplicate marketing sections have been consolidated.
- ShareSafe retains its real native features and pre-launch status. OpenScreen's download availability, platform support, awards, open-source claims and community metrics are not ShareSafe claims.
- One standalone stylesheet replaces the previous chain of design overrides on the active page. Earlier files and a local backup remain available.

## Assets and reproduction

`public/images/studio-wallpaper.svg` is an original vector background. It uses broad warm and cool color fields to support the product screenshots. No reference artwork or video was copied.

The real captures each contain the Mac pointer burned into the frame. `remove-baked-cursors.mjs` repairs them before compositing: five frames copy the identical UI region from a sibling frame that has no pointer there (so buttons, text and gradients are reconstructed exactly), and the two receipt frames are filled with the median colour of their uniform white/dark surround. `grid-locate-cursors.mjs` is the helper used to pin each pointer's exact pixel position. No capture is recoloured to imitate the other appearance.

`render-product-video.swift` writes a silent master to `artifacts/video/frames-{light,dark}.mov`. `generate-video-overlays.mjs` produces the title, four scene cards and end card as transparent PNGs; the renderer composites those, draws the animated pointer, click ripples and CoreText tooltips, and adds the progress bar. `generate-narration.mjs` directs the narration. Robotic speech has two usual causes — a whole sentence rendered as one intonation contour, and a delivery chopped into short fragments. Both are addressed by rendering each line as **one connected utterance** with the prosody shaped inside it:

* **connected flow** — one utterance per line, so there are no seams between concatenated clips
* **rate shaping** — `<prosody rate>` lets setup words move while content words are pulled back
* **declination** — `<prosody pitch>` drifts down across the statement, as a speaker's does
* **micro-pauses** — `<break>` at clause boundaries, sized per pause

An earlier iteration split narration into two- and three-word phrases with hard gaps between separately rendered clips. It sounded worse: short fragments read as telegraphic rather than spoken. The copy is also deliberately short and conversational — narration that has been tightened to sound spoken rather than read.

The voice is **Rocko (English (US))** at 156 wpm. The natural voices installed here were measured for zero-crossing rate and high-frequency energy, the two correlates of a bright or synthetic timbre. Among the male voices, Rocko is clearly the softest (ZCR 0.0271, HF 0.0011) — Reed (0.0346/0.0023), Eddy (0.0357/0.0027) and especially Daniel (0.0755/0.0138) are all markedly brighter. Rocko also measures softer than the previous female lead, Sandy (0.0455/0.0013). The rate is lower than the female default because a male voice is more compact at the same nominal words-per-minute. `generate-video-audio.mjs` places each line verbatim, then finishes the voice for **clarity**: a two-pole high-pass at 95 Hz removes rumble, a presence band around 3 kHz is mixed back in so consonants cut, and only light compression is applied so phrasing stays expressive. An earlier version low-passed at 5.2 kHz with a low shelf and a longer reverb; it sounded warm but buried the consonants and was noticeably harder to follow, so the room is now much shorter and quieter. The voice bus is normalised to a fixed **RMS** rather than a peak. Peak-normalising left the lower male voice buried under the bed; a fixed RMS keeps narration at a consistent, clear level whichever voice is selected, while a single shared gain still preserves the dynamics between lines. The bed — a harmonic pad, four scene whooshes, four UI clicks that land on the pointer's clicks and two confirmation chimes — is sidechain-ducked under the speech. On the finished mix narration measures ~0.091 RMS against ~0.042 in the gaps, about 2.2:1, which is clear without the bed disappearing. `mux-video-audio.swift` muxes the result into the MP4s with a passthrough export so the video bitstream is not re-encoded, and Sharp builds the WebP posters. Regenerate with:

```
node scripts/remove-baked-cursors.mjs
node scripts/generate-video-overlays.mjs
node scripts/generate-narration.mjs
node scripts/generate-video-audio.mjs
swift scripts/render-product-video.swift
swift scripts/mux-video-audio.swift
```

`public/images/studio-wallpaper.svg` is the shared backdrop for the site's product stages and for the films. It is a dark, low-contrast field with emerald and crimson glows, faint concentric arcs and a vignette, so the white app window stays the brightest thing on screen.

All audio — music bed, interface sounds and narration — is generated in-repo by the scripts above; no third-party samples, music, stock footage or voice recordings are used, so the films carry no licensing obligations. They remain demonstrations of actual states, not real-time recordings or evidence of processing speed.
