import sharp from 'sharp';
import {rename,mkdir} from 'node:fs/promises';
const dir='public/images/product';
const names=[['review','02-pdf-detection-workspace'],['individual','03-individual-redact-and-keep'],['protected','04-redact-all-protected'],['export','13-export-success']];
await mkdir('artifacts/captures',{recursive:true});
for(const [state,name] of names){for(const width of [960,1600])await sharp(`${dir}/dark-${state}.png`).resize({width,withoutEnlargement:true}).webp({quality:88}).toFile(`${dir}/${name}-dark-${width}.webp`);}
const meta=await sharp(`${dir}/dark-review.png`).metadata();
await sharp(`${dir}/dark-review.png`).extract({left:Math.round(meta.width*.774),top:Math.round(meta.height*.139),width:Math.round(meta.width*.212),height:Math.round(meta.height*.65)}).resize({width:680}).webp({quality:90}).toFile(`${dir}/review-detail-dark.webp`);
for(const [state] of names)await rename(`${dir}/dark-${state}.png`,`artifacts/captures/dark-${state}.png`);
