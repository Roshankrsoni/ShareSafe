# DiskBuddy → ShareSafe: launch-page design analysis

Reference: https://diskbuddy.com/  
Inspected: October 14, 2026. Desktop browser, page interactions, typography and document structure.

## What gives the reference its character

The visual hierarchy is exceptionally simple: a small navigation row, an oversized two-line statement, a short explanation, then the product. In the inspected desktop view, the heading uses National Park at 88px, 700 weight and approximately −3.08px tracking. Its rounded letterforms make a technical utility feel approachable. The dark surface is #0f0f10; controls are near-white and color is concentrated in the headline and demonstration. A warm amber-to-purple-to-blue gradient provides the memorable brand moment without becoming a full-page background.

The content sits within a restrained central column. Wide margins, low-contrast dividers and limited card borders give individual sections room. The app presentation is followed by a three-column feature grid whose items are plain icons, headings and short explanations rather than heavy cards. Later sections narrow for pricing and categorized FAQ rows. The persistent header is lightweight enough to keep attention on the content.

The page's compact animated example makes the utility understandable before the larger workspace appears. This is more useful than motion that simply decorates the hero. Primary actions have a simple filled treatment, secondary actions use a fine outline, and support content recedes in gray.

## ShareSafe implementation decisions

| Reference pattern | ShareSafe adaptation |
| --- | --- |
| Oversized two-line heading | “Share the file. Keep the details yours.” with a gradient on the privacy benefit |
| Small animated utility example | Fictional email, phone and card values transition from suggestions to solid masks and a saved-copy state |
| Full workspace presentation | Four selectable genuine screenshots: Detect, Decide, Protect and Export |
| Lightweight feature grid | Nine actual review, OCR, masking and export capabilities |
| Concise privacy statement | Local processing, originals preserved and explicit review responsibilities |
| Focused purchase block | Planned $2 launch pricing, then $5, with a truthful pre-launch status action |
| Categorized questions | Getting started, privacy and safety, compatibility and launch |
| Appearance control | System, light and dark; real product imagery follows the selected appearance |

## Content and interaction

The prior long pinned tour and repeated marketing panels have been replaced by a shorter reading sequence. The existing narrated product video is preserved as a dedicated workflow chapter. Its playback remains muted by default, with explicit sound and pause controls, and pauses outside the viewport. The new illustrative animation also includes pause/replay controls and starts paused when reduced motion is requested.

The original ShareSafe product name and red shield are retained. Download availability, testimonials, scarcity counters and cross-platform support from the reference are not transferable product facts. The pricing CTA links to Dodo's hosted checkout; app delivery and licence fulfillment remain unconfigured.

## Assets and performance

The existing real app captures are sufficiently clear and already show the relevant states, so no synthetic replacement screenshots were generated. The light/dark narrated videos and recent capture refinements in the workspace were preserved. National Park is served locally with its OFL licence; no runtime font service is required. The active layout uses a single small stylesheet instead of the previous design overrides.

## Review checklist

- Desktop, tablet and narrow-phone layout and horizontal overflow.
- All four screenshot selections and their captions.
- Theme switching and corresponding genuine screenshots.
- Animation pause/replay; video playback and sound controls.
- FAQ expansion, in-page navigation and truthful launch links.
- Build, type checking and existing purchase/navigation regression tests.
