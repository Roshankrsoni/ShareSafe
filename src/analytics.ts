type MarketingEvent = 'pricing_click' | 'purchase_click' | 'demo_view' | 'faq_open' | 'navigation';
type EventDetails = { location?: string; item?: string };
// No tracker, network request, document content, or personal data by default.
// An approved integration can subscribe to this event later.
export function track(name: MarketingEvent, details: EventDetails = {}) {
  if (typeof window !== 'undefined') window.dispatchEvent(new CustomEvent('sharesafe:marketing', { detail: { name, ...details } }));
}
