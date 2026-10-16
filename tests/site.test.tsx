import test from 'node:test';
import assert from 'node:assert/strict';
import {renderToStaticMarkup} from 'react-dom/server';
import {existsSync,readFileSync} from 'node:fs';
import {pricing,purchaseState} from '../src/config';
import App from '../src/App';
import {gallery} from '../src/content';

test('unverified offer cannot send a visitor to checkout',()=>{
  for(const checkoutUrl of [null,'https://example.com/checkout']){
  const state=purchaseState({...pricing,offerStatus:'unverified',checkoutUrl});assert.equal(state.available,false);assert.equal(state.href,'#pricing');assert.equal(state.label,'View launch pricing');
 }
});
test('verified launch and regular states use their correct price',()=>{
 const launch=purchaseState({...pricing,offerStatus:'launch',checkoutUrl:'https://example.com/checkout'});
 const regular=purchaseState({...pricing,offerStatus:'regular',checkoutUrl:'https://example.com/checkout'});
 assert.equal(launch.label,'Buy ShareSafe — $2');assert.equal(regular.label,'Buy ShareSafe — $5');assert.equal(launch.available,true);
});
test('invalid checkout destinations fail closed',()=>{
  for(const checkoutUrl of ['javascript:alert(1)','http://example.com','/checkout','']) assert.equal(purchaseState({...pricing,checkoutUrl,offerStatus:'launch'}).available,false);
});
test('all environments use the live ShareSafe checkout URL',()=>{
 assert.equal(pricing.checkoutUrl,'https://dodo.pe/sharesafe-buy');
 assert.equal(purchaseState(pricing).href,'https://dodo.pe/sharesafe-buy');
});
const html=renderToStaticMarkup(<App/>);
test('all internal navigation targets exist and no placeholder links remain',()=>{
 for(const match of html.matchAll(/href="#([^"]*)"/g)){assert.ok(match[1]);assert.ok(html.includes(`id="${match[1]}"`),match[1]);}
 for(const match of html.matchAll(/href="(\/[^"#]*)"/g))assert.ok(existsSync(`public${match[1]}`),match[1]);
 assert.equal((html.match(/<h1>/g)||[]).length,1);
});
test('real screenshot files exist for every gallery state',()=>{
 for(const slide of gallery)for(const theme of ['', '-dark'])for(const width of [960,1600])assert.ok(existsSync(`public/images/product/${slide.image}${theme}-${width}.webp`));
});
test('purchase CTA opens the verified Dodo checkout and discloses delivery status',()=>{
  assert.equal((html.match(/href="https:\/\/dodo\.pe\/sharesafe-buy"/g)||[]).length,4);assert.match(html,/Buy ShareSafe — \$2/);
  assert.match(html,/download and licence terms are not yet configured for delivery/);assert.match(html,/Blur may leave details inferable/);
 assert.match(readFileSync('index.html','utf8'),/noindex,nofollow/);
});
