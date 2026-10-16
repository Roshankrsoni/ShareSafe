# ShareSafe

ShareSafe helps people review sensitive information in a document before sharing it. This repository contains the product’s marketing website and its separate native macOS app.

The Mac app processes documents on-device. It can find likely personal details, let you decide what to keep or redact, and export a separate protected copy. Detection is an aid to human review, not a guarantee that every sensitive detail has been found.

## What’s here

| Folder | Contents |
| --- | --- |
| [`/`](.) | React and TypeScript marketing site |
| [`mac-app/`](mac-app/) | Native SwiftUI macOS app, tests, resources, and build scripts |
| [`docs/`](docs/) | Website research, feature inventory, launch readiness, and verification notes |
| [`public/images/product/`](public/images/product/) | Product screenshots used by the site |

## Marketing website

The site is built with React, TypeScript, Vite, and Tailwind CSS. It includes responsive product pages, app screenshots, an interactive workflow demo, pricing, and FAQs.

### Run locally

Requirements: Node.js and npm.

```sh
npm ci
npm run dev
```

### Build and check

```sh
npm run build
npm run preview
npm run lint
npm run typecheck
npm test
```

`npm run build` type-checks the site, creates the production bundle in `dist/`, and prerenders page content for search engines and browsers without JavaScript. `npm run preview` serves that production build locally.

Useful website files:

- `src/App.tsx` — page structure and interactive sections
- `src/styles.css` — shared styles and design tokens
- `src/config.ts` and `src/content.ts` — pricing, links, and page content
- `public/images/product/` — product imagery
- `docs/launch-readiness.md` and `docs/verification.md` — release notes and checks

## Native Mac app

The macOS app is an independent Swift package in [`mac-app/`](mac-app/). It requires macOS 14 or later and uses Apple frameworks including SwiftUI, AppKit, Vision, NaturalLanguage, and CoreGraphics. It has no third-party package dependencies.

From the repository root, run:

```sh
cd mac-app
swift test
bash scripts/build-app.sh
```

The build script creates an ad-hoc signed app bundle at `mac-app/dist/ShareSafe.app`. Build output is ignored by Git; the repository contains the app source and instructions, not a ready-to-install or notarized release. Open `mac-app/Package.swift` in Xcode to work on the app.

The app supports PDF, image, and plain-text review; per-suggestion Keep or Redact decisions; exact-text matches and drawn masks; custom solid or blur appearances; original and protected previews; and separate exports. Read [`mac-app/README.md`](mac-app/README.md) for workflow details and known limitations.

## Privacy and redaction notes

Document processing in the native app is local. Its source does not request network access. Review the exported copy before sharing: automatic detection can miss names, handwriting, addresses, and context-specific identifiers. For the strongest concealment, use solid masks; blur can leave content recognizable.

PDF exports are rebuilt as image-only documents to remove underlying searchable text and attachments. This may discard vector detail, forms, signatures, or other PDF features. The original document is kept separate and is not intentionally overwritten. See the app’s verification notes for the safeguards and remaining release checks.

## Website checkout and release status

The website’s purchase links use Dodo Payments’ hosted checkout. App download and license delivery are not yet configured as an end-to-end purchase flow; see [`docs/launch-readiness.md`](docs/launch-readiness.md) before treating the site as a complete sales channel.

The website deployment configuration is in `.openai/hosting.json`. For other static hosts, deploy the generated `dist/` folder and set the production URL only after the public domain is confirmed. Do not commit deployment credentials or local environment files.

## License

No license has been added yet. Contact the repository owner before reusing or distributing this code.
