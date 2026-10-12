import sharp from 'sharp';
import gifenc from 'gifenc';
const { GIFEncoder, quantize, applyPalette } = gifenc;
import { writeFileSync } from 'node:fs';
const dark=process.argv.includes('--dark');
const suffix=dark?'-dark':'';
const width=960,height=700;
const states=[
 ['02-pdf-detection-workspace','01 / DETECT','Find likely sensitive details.'],
 ['03-individual-redact-and-keep','02 / DECIDE','Choose what to redact. Keep what belongs.'],
 ['04-redact-all-protected','03 / PROTECT','Inspect the protected copy before exporting.'],
 ['13-export-success','04 / EXPORT','Review the saved copy and export checks.'],
];
const frames=[];
for(const [name,label,title] of states){
 const backing=Buffer.from(`<svg xmlns="http://www.w3.org/2000/svg" width="${width}" height="${height}"><rect width="960" height="700" fill="${dark?'#18181f':'#f5f6f9'}"/><rect x="28" y="26" width="123" height="27" rx="13" fill="#de041f"/><text x="43" y="44" font-family="Arial" font-size="11" font-weight="bold" fill="#fff">${label}</text><text x="930" y="45" text-anchor="end" font-family="Arial" font-weight="bold" font-size="19" fill="${dark?'#f5f5f7':'#20232d'}">ShareSafe.</text><text x="28" y="83" font-family="Arial" font-size="19" font-weight="bold" fill="${dark?'#f5f5f7':'#20232d'}">${title}</text><text x="28" y="671" font-family="Arial" font-size="12" fill="${dark?'#b5b5be':'#626773'}">ACTUAL APP SCREENS · FICTIONAL NORTHSTAR DOCUMENT</text><rect x="28" y="635" width="904" height="3" rx="1" fill="${dark?'#373740':'#e1e3e8'}"/><rect x="28" y="635" width="${226*(frames.length+1)}" height="3" rx="1" fill="#ba1535"/></svg>`);
 const picture=await sharp(`public/images/product/${name}${suffix}-1600.webp`).resize({width:904,height:522,fit:'inside'}).png().toBuffer();const size=await sharp(picture).metadata();
 frames.push(await sharp(backing).composite([{input:picture,left:Math.round((width-size.width)/2),top:105+Math.round((522-size.height)/2)}]).ensureAlpha().raw().toBuffer());
}
const gif=GIFEncoder();
function add(data,delay){const palette=quantize(data,256);const index=applyPalette(data,palette);gif.writeFrame(index,width,height,{palette,delay,repeat:0});}
for(let i=0;i<frames.length;i++){
 add(frames[i],2200);
 const next=frames[(i+1)%frames.length];
 for(let t=1;t<=5;t++){const blend=Buffer.alloc(frames[i].length),a=t/6;for(let p=0;p<blend.length;p++)blend[p]=Math.round(frames[i][p]*(1-a)+next[p]*a);add(blend,70);}
}
gif.finish();writeFileSync(`public/images/product/sharesafe-workflow${suffix}.gif`,gif.bytes());
await sharp(frames[0],{raw:{width,height,channels:4}}).webp({quality:90}).toFile(`public/images/product/sharesafe-workflow${suffix}-poster.webp`);
console.log(`Generated ${width}×${height} workflow GIF: ${gif.bytes().length} bytes, 24 frames, four real product states.`);
