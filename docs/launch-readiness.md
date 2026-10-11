# Launch readiness and purchase integrity

As of October 11, 2026: website implemented; payment and public distribution NOT implemented. This is a private, noindex launch preview. No sales or launch slots are claimed.

## Required before public selling

1. **Checkout**: supply a verified HTTPS destination or server-created checkout endpoint. Prices are USD $2 for first 10 successful paying customers, then $5. No subscriptions. Config: `src/config.ts`.
2. **Offer enforcement**: use an authoritative server/payment ledger, not localStorage or a client counter. Decide whether “customer” means a unique paying identity and define refunded/duplicate-order treatment. Reserve discounted allocations atomically, expire failed/abandoned reservations, finalize with signed idempotent payment webhooks, and prevent simultaneous buyers from over-allocating the ten discounted purchases. If the provider supports capped discount redemption, verify its successful-purchase semantics and concurrency behavior. A static page cannot enforce this.
3. **Live presentation**: retrieve authoritative offer availability and displayed price from that backend, or keep the preview status. Revalidate price at checkout. Show no remaining count unless verified. A stale page must never charge more than the checkout explicitly confirms. Current `launch`/`regular` modes are tested configuration states, not automatic synchronization.
4. **Distribution**: Developer ID signing, hardened-runtime/notarization verification, clean-Mac install check, supported architecture verification, stable versioned download and successful-purchase delivery. Local ad-hoc builds are not represented as production downloads.
5. **Licence and customer care**: owner-approved scope/device limit, upgrade policy, refund rules, tax treatment, seller details and support address. No lifetime-upgrade entitlement is promised by this site.
6. **Legal and privacy**: publish actual privacy policy and terms for the seller, marketing host, payment processor and support flow. The product privacy explanation is not a substitute. `site.supportUrl`, `privacyUrl`, `termsUrl` are reserved configuration values; wire footer links after real pages exist. Present footer instead links to transparent launch/support status.
7. **Production domain**: supply verified public origin in `site.productionUrl`, rebuild, check canonical/sitemap/robots and absolute OG image, then deliberately change hosting audience. Current private audience should remain unchanged until authorized.

## Analytics integration

`track()` emits `sharesafe:marketing` CustomEvents only. Payloads are fixed page identifiers (`location`, `item`), never document text or user form data. No storage, analytics vendor or outbound event request exists. Events: pricing/purchase clicks, demo changes, FAQ open, navigation (available hook). Add a consent-appropriate subscriber only after the actual policy and destinations are approved. Do not attach app documents to marketing events.

## Security and output limitations

The code audit supports local app processing and fresh rasterized PDF export. It does not establish certification, formal security audit or perfect detection. Solid redaction and blur remain distinct. Export receipt checks are not an assurance that the user's review was complete.

## External blockers

No checkout URL, payment credentials, production domain, official support URL, approved legal pages or signed public download were provided. These cannot be safely invented. No payment is possible in this delivery.
