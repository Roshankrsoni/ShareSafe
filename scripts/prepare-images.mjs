import sharp from 'sharp';
import {mkdir,writeFile} from 'node:fs/promises';
const source='../public/images/product';
const dest='public/images/product';
await mkdir(dest,{recursive:true});
const names=['02-pdf-detection-workspace','03-individual-redact-and-keep','04-redact-all-protected','13-export-success'];
for(const name of names){for(const width of [960,1600])await sharp(`${source}/${name}.png`).resize({width,withoutEnlargement:true}).webp({quality:86}).toFile(`${dest}/${name}-${width}.webp`);}
const meta=await sharp(`${source}/02-pdf-detection-workspace.png`).metadata();
console.log({sourceSize:meta.width+'x'+meta.height,receipt:await sharp(`${source}/13-export-success.png`).metadata()});
await sharp(`${source}/02-pdf-detection-workspace.png`).extract({left:Math.round(meta.width*.774),top:Math.round(meta.height*.139),width:Math.round(meta.width*.212),height:Math.round(meta.height*.65)}).resize({width:680}).webp({quality:90}).toFile(`${dest}/review-detail.webp`);
const background=Buffer.from(`<svg width="1200" height="630"><rect width="1200" height="630" fill="#e9ece1"/><text x="62" y="80" font-family="Arial" font-size="32" font-weight="bold" fill="#24392f">ShareSafe</text><text x="62" y="137" font-family="Arial" font-size="38" font-weight="bold" fill="#24392f">Good to share. Yours to keep private.</text><text x="62" y="181" font-family="Arial" font-size="20" fill="#52664c">Review and redact documents on your Mac.</text></svg>`);
const shot=await sharp(`${source}/02-pdf-detection-workspace.png`).resize({width:820}).toBuffer();
await sharp(background).composite([{input:shot,left:190,top:216}]).jpeg({quality:90}).toFile('public/images/social-share.jpg');
await writeFile('public/images/product/README.txt','Genuine ShareSafe screenshots, captured October 10, 2026 using the fictional Northstar sample. Optimized derivatives only; no UI fabricated. Originals: ShareSafe/public/images/product/.');
