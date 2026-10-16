# Launch readiness and purchase integrity

As of October 14, 2026: a Dodo-hosted checkout is linked from the pricing CTA at $2 USD one-time. This is a private, noindex preview. App delivery, licence terms and public distribution are not configured.

## Required before public selling

1. **Checkout**: all environments link to Dodo's live hosted checkout for product `pdt_0NnhU4WmYU9pKWXnIILA7`. The product is configured at $2 USD one-time, with no subscription. Config: `src/config.ts`.
2. **Offer enforcement**: the static product checkout does not switch to $5 after ten customers. If retaining that offer, use an authoritative server/payment ledger, not localStorage or a client counter. Decide whether “customer” means a unique paying identity and define refunded/duplicate-order treatment. Reserve discounted allocations atomically, expire failed/abandoned reservations, finalize with signed idempotent payment webhooks, and prevent simultaneous buyers from over-allocating the ten discounted purchases. If the provider supports capped discount redemption, verify its successful-purchase semantics and concurrency behavior. A static page cannot enforce this.
3. **Live presentation**: the page currently displays the $2 product price recorded in `src/config.ts`; this is not fetched from Dodo at runtime and must be kept synchronized with the product. Dodo's checkout confirms the final amount before payment. Show no remaining count unless verified.
4. **Distribution**: Developer ID signing, hardened-runtime/notarization verification, clean-Mac install check, supported architecture verification, stable versioned download and successful-purchase delivery. Local ad-hoc builds are not represented as production downloads.
5. **Licence and customer care**: owner-approved scope/device limit, upgrade policy, refund rules, tax treatment, seller details and support address. No lifetime-upgrade entitlement is promised by this site.
6. **Legal and privacy**: publish actual privacy policy and terms for the seller, marketing host, payment processor and support flow. The product privacy explanation is not a substitute. `site.supportUrl`, `privacyUrl`, `termsUrl` are reserved configuration values; wire footer links after real pages exist. Present footer instead links to transparent launch/support status.
7. **Production domain**: supply verified public origin in `site.productionUrl`, rebuild, check canonical/sitemap/robots and absolute OG image, then deliberately change hosting audience. Current private audience should remain unchanged until authorized.

## Analytics integration

`track()` emits `sharesafe:marketing` CustomEvents only. Payloads are fixed page identifiers (`location`, `item`), never document text or user form data. No storage, analytics vendor or outbound event request exists. Events: pricing/purchase clicks, demo changes, FAQ open, navigation (available hook). Add a consent-appropriate subscriber only after the actual policy and destinations are approved. Do not attach app documents to marketing events.

## Security and output limitations

The code audit supports local app processing and fresh rasterized PDF export. It does not establish certification, formal security audit or perfect detection. Solid redaction and blur remain distinct. Export receipt checks are not an assurance that the user's review was complete.

## External blockers

The Dodo checkout is available, but its product has no digital-file delivery or licence configured. Do not treat a successful payment as fulfilled until the signed app download, licence, refund/tax terms and customer-support details are ready. The production domain, official support URL and approved legal pages also remain unset.
