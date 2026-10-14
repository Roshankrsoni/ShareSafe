import sharp from 'sharp';
import {mkdir} from 'node:fs/promises';

/**
 * The real ShareSafe captures have the Mac pointer (and its soft spotlight halo)
 * burned into every frame. Two repairs are used so nothing is recoloured:
 *
 *  1. donor  - copy the identical UI region from another frame of the same theme
 *              that has no pointer there. The layout is pixel-identical, so the
 *              patch is an exact reconstruction (buttons, text, gradients kept).
 *  2. flat   - sample the median colour of the ring around the pointer and fill,
 *              used only where the background is a single uniform colour.
 *
 * Pointer centres were read off an absolute pixel grid (scripts/grid-locate-cursors.mjs).
 * Output: artifacts/video-frames/clean/<theme>-<n>.png
 */
await mkdir('artifacts/video-frames/clean', {recursive:true});

const REPAIRS = {
  // frame        strategy  donor      box [x, y, w, h]
  'light-0': {mode:'donor', donor:'light-1', box:[1128, 168, 88, 88]},
  'dark-0':  {mode:'donor', donor:'dark-1',  box:[1132, 158, 88, 88]},
  'light-1': {mode:'donor', donor:'light-0', box:[1390, 538, 190, 116]},
  'light-2': {mode:'donor', donor:'light-1', box:[1374, 826, 92, 92]},
  'dark-1':  {mode:'donor', donor:'dark-2',  box:[1328, 418, 80, 80]},
  'dark-2':  {mode:'donor', donor:'dark-1',  box:[1332, 928, 80, 80]},
  // Uniform backgrounds: white receipt and dark receipt.
  'light-3': {mode:'flat',  box:[740, 110, 205, 165], colour:[255, 255, 255]},
  'dark-3':  {mode:'flat',  box:[873, 173, 124, 92]},
};

const FEATHER = 8;

function median(values){
  const sorted = [...values].sort((a, b) => a - b);
  return sorted[Math.floor(sorted.length / 2)];
}

for(const [name, plan] of Object.entries(REPAIRS)){
  const file = `artifacts/video-frames/${name}.png`;
  const [x, y, w, h] = plan.box;
  let layer;

  if(plan.mode === 'donor'){
    layer = await sharp(`artifacts/video-frames/${plan.donor}.png`)
      .extract({left:x, top:y, width:w, height:h}).png().toBuffer();
  } else {
    const {data, info} = await sharp(file).removeAlpha().raw().toBuffer({resolveWithObject:true});
    const {width, height, channels} = info;
    let fill = plan.colour;
    if(!fill){ // sample the ring
      const RING = 14, rs = [], gs = [], bs = [];
      for(let yy = y - RING; yy < y + h + RING; yy++)
        for(let xx = x - RING; xx < x + w + RING; xx++){
          if(xx < 0 || yy < 0 || xx >= width || yy >= height) continue;
          const inX = xx >= x && xx < x + w, inY = yy >= y && yy < y + h;
          if(inX && inY) continue;
          if(inX || inY){ const p = (yy * width + xx) * channels; rs.push(data[p]); gs.push(data[p+1]); bs.push(data[p+2]); }
        }
      fill = [median(rs), median(gs), median(bs)];
    }
    const patch = Buffer.alloc(w * h * 4);
    for(let yy = 0; yy < h; yy++)
      for(let xx = 0; xx < w; xx++){
        const edge = Math.min(xx, yy, w - 1 - xx, h - 1 - yy);
        const p = (yy * w + xx) * 4;
        patch[p] = fill[0]; patch[p+1] = fill[1]; patch[p+2] = fill[2];
        patch[p+3] = Math.round(255 * Math.min(1, edge / FEATHER));
      }
    layer = await sharp(patch, {raw:{width:w, height:h, channels:4}}).png().toBuffer();
    console.log(`${name}: flat fill rgb(${fill.join(',')})`);
  }

  await sharp(file).composite([{input:layer, left:x, top:y}]).png().toFile(`artifacts/video-frames/clean/${name}.png`);
  console.log(`${name}: repaired ${w}x${h} at ${x},${y} via ${plan.mode}${plan.donor ? ' from ' + plan.donor : ''}`);
}
console.log('Clean frames written to artifacts/video-frames/clean/');