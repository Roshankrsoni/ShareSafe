import { readFileSync,writeFileSync } from 'node:fs';
import { renderToString } from 'react-dom/server';
import App from '../src/App';
import {site} from '../src/config';
let html=readFileSync('dist/index.html','utf8').replace('<div id="root"></div>',`<div id="root">${renderToString(<App/>)}</div>`);
const schema={'@context':'https://schema.org','@type':'SoftwareApplication',name:'ShareSafe',operatingSystem:'macOS 14+',applicationCategory:'UtilitiesApplication',description:'Local document review and redaction for Mac.'};
html=html.replace('</head>',`<script type="application/ld+json">${JSON.stringify(schema)}</script></head>`);
html=html.replace('content="/images/social-share.jpg"',`content="${site.productionUrl || site.previewUrl}/images/social-share.jpg"`);
if(site.productionUrl){
 const origin=new URL(site.productionUrl).origin;
 html=html.replace('noindex,nofollow','index,follow').replace('content="/images/social-share.jpg"',`content="${origin}/images/social-share.jpg"`).replace('</head>',`<link rel="canonical" href="${origin}/"/><meta property="og:url" content="${origin}/"/></head>`);
 writeFileSync('dist/robots.txt',`User-agent: *\nAllow: /\nSitemap: ${origin}/sitemap.xml\n`);
 writeFileSync('dist/sitemap.xml',`<?xml version="1.0" encoding="UTF-8"?><urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9"><url><loc>${origin}/</loc></url><url><loc>${origin}/product-guide.html</loc></url></urlset>`);
}
writeFileSync('dist/index.html',html);
console.log('Prerendered complete landing page; indexing is '+(site.productionUrl?'enabled.':'off until production domain is configured.'));
