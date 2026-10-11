export type OfferStatus = 'unverified' | 'launch' | 'regular';
export type Pricing = { currency: 'USD'; launchPrice: number; regularPrice: number; launchCap: number; offerStatus: OfferStatus; checkoutUrl: string | null };
export const pricing: Pricing = { currency: 'USD', launchPrice: 2, regularPrice: 5, launchCap: 10, offerStatus: 'unverified', checkoutUrl: null };
export function purchaseState(config: Pricing) {
  const validDestination = config.checkoutUrl && /^https:\/\/[^\s]+$/.test(config.checkoutUrl);
  const available = !!validDestination && config.offerStatus !== 'unverified';
  const price = config.offerStatus === 'launch' ? config.launchPrice : config.regularPrice;
  return { available, price, href: available ? config.checkoutUrl! : '#pricing', label: available ? `Buy ShareSafe — $${price}` : 'View launch pricing' };
}
export const site = { name: 'ShareSafe', productionUrl: '', previewUrl: 'https://sharesafe-mac.activeclove16.chatgpt.site', supportUrl: '', privacyUrl: '', termsUrl: '' };
