import sharp from 'sharp';
import {mkdir} from 'node:fs/promises';

const W = 1280, H = 860;
await mkdir('artifacts/video-frames', {recursive:true});

const scenes = [
  {pill:'01 · DETECT', caption:'Find likely sensitive details — nothing leaves your Mac.'},
  {pill:'02 · DECIDE', caption:'Redact or Keep — you make every call, with undo.'},
  {pill:'03 · PROTECT', caption:'Inspect the Protected preview before exporting.'},
  {pill:'04 · EXPORT', caption:'Export a separate copy — mask checks + receipt.'},
];

function esc(s){return s.replace(/&/g,'&amp;').replace(/</g,'&lt;');}

async function overlay(svg, name){
  await sharp(Buffer.from(svg)).png().toFile(`artifacts/video-frames/overlay-${name}.png`);
  console.log('overlay', name);
}

// Title card: scrim + centered story
await overlay(`<svg xmlns="http://www.w3.org/2000/svg" width="${W}" height="${H}">
<rect width="${W}" height="${H}" fill="rgba(6,12,10,0.58)"/>
<g font-family="Arial, Helvetica, sans-serif" text-anchor="middle">
<rect x="524" y="252" width="232" height="40" rx="20" fill="none" stroke="#ffffff" stroke-opacity="0.7" stroke-width="2"/>
<text x="640" y="279" font-size="17" font-weight="bold" letter-spacing="3" fill="#fff">SHARESAFE FOR MAC</text>
<text x="640" y="380" font-size="72" font-weight="bold" fill="#fff">Review before you share.</text>
<text x="640" y="428" font-size="24" fill="#ffffff" fill-opacity="0.88">Detect → Decide → Protect → Export · All on your Mac</text>
<text x="640" y="472" font-size="18" fill="#ffffff" fill-opacity="0.65">Actual app captures · Fictional Northstar sample</text>
</g></svg>`, 'title');

// Scene overlays: top-left pill + bottom caption pill (transparent elsewhere)
for(let i=0;i<scenes.length;i++){
  const s = scenes[i];
  await overlay(`<svg xmlns="http://www.w3.org/2000/svg" width="${W}" height="${H}">
<g font-family="Arial, Helvetica, sans-serif">
<rect x="48" y="42" width="184" height="42" rx="21" fill="rgba(8,14,12,0.82)"/>
<circle cx="74" cy="63" r="6.5" fill="#4ADE80"/>
<text x="89" y="69" font-size="17" font-weight="bold" letter-spacing="1.4" fill="#fff">${esc(s.pill)}</text>
<text x="1232" y="69" font-size="15" fill="#fff" fill-opacity="0.82" letter-spacing="0.6" text-anchor="end">ShareSafe · ${i+1}/4</text>
<rect x="0" y="0" width="${W}" height="6" fill="rgba(255,255,255,0.18)"/>
<g>
<rect x="316" y="774" width="648" height="42" rx="21" fill="rgba(8,14,12,0.82)"/>
<text x="640" y="801" font-size="17" font-weight="bold" fill="#fff" text-anchor="middle">${esc(s.caption)}</text>
</g>
</g></svg>`, `${i}`);
}

// End card
await overlay(`<svg xmlns="http://www.w3.org/2000/svg" width="${W}" height="${H}">
<rect width="${W}" height="${H}" fill="rgba(6,12,10,0.62)"/>
<g font-family="Arial, Helvetica, sans-serif" text-anchor="middle">
<text x="640" y="360" font-size="64" font-weight="bold" fill="#fff">On your Mac, start to finish.</text>
<text x="640" y="412" font-size="25" fill="#FFD76A" font-weight="bold">$2 launch for first 10 · Then $5 once</text>
<text x="640" y="452" font-size="19" fill="#ffffff" fill-opacity="0.75">Planned pricing · Checkout not open yet · No account</text>
<rect x="470" y="500" width="340" height="52" rx="26" fill="none" stroke="#fff" stroke-opacity="0.6" stroke-width="2"/>
<text x="640" y="534" font-size="20" font-weight="bold" fill="#fff">Local · Private · Yours</text>
</g></svg>`, 'end');

console.log('Done: title, 0-3, end overlays at 1280x860');
