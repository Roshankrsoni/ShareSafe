import sharp from 'sharp';
import {mkdir} from 'node:fs/promises';

/** Debug helper: crops the pointer neighbourhood with an absolute pixel grid. */
await mkdir('artifacts/video-frames/grid', {recursive:true});

const SPAN = 240;   // crop size in source pixels
const STEP = 20;    // grid step in source pixels
const SCALE = 3;    // output zoom

const SEARCH = {
  'light-0': [1174, 210], 'dark-0': [1192, 205],
  'light-1': [1482, 595], 'dark-1': [1332, 455],
  'light-2': [1378, 885], 'dark-2': [1408, 972],
  'light-3': [820, 200],  'dark-3': [940, 215],
};

for(const [name, [cx, cy]] of Object.entries(SEARCH)){
  const {width, height} = await sharp(`artifacts/video-frames/${name}.png`).metadata();
  const left = Math.max(0, Math.min(width - SPAN, cx - SPAN / 2));
  const top = Math.max(0, Math.min(height - SPAN, cy - SPAN / 2));

  const lines = [];
  const labels = [];
  const firstX = Math.ceil(left / STEP) * STEP;
  for(let x = firstX; x < left + SPAN; x += STEP){
    const px = (x - left) * SCALE;
    const major = x % 100 === 0;
    lines.push(`<line x1="${px}" y1="0" x2="${px}" y2="${SPAN * SCALE}" stroke="${major ? '#ff00ff' : '#00b7ff'}" stroke-width="${major ? 2 : 1}" stroke-opacity="${major ? 0.9 : 0.5}"/>`);
    if(major) labels.push(`<text x="${px + 3}" y="16" font-family="monospace" font-size="15" font-weight="bold" fill="#ff00ff">${x}</text>`);
  }
  const firstY = Math.ceil(top / STEP) * STEP;
  for(let y = firstY; y < top + SPAN; y += STEP){
    const py = (y - top) * SCALE;
    const major = y % 100 === 0;
    lines.push(`<line x1="0" y1="${py}" x2="${SPAN * SCALE}" y2="${py}" stroke="${major ? '#ff00ff' : '#00b7ff'}" stroke-width="${major ? 2 : 1}" stroke-opacity="${major ? 0.9 : 0.5}"/>`);
    if(major) labels.push(`<text x="4" y="${py + 16}" font-family="monospace" font-size="15" font-weight="bold" fill="#ff00ff">${y}</text>`);
  }
  const grid = Buffer.from(`<svg xmlns="http://www.w3.org/2000/svg" width="${SPAN * SCALE}" height="${SPAN * SCALE}">${lines.join('')}${labels.join('')}</svg>`);
  await sharp(`artifacts/video-frames/${name}.png`)
    .extract({left, top, width:SPAN, height:SPAN})
    .resize({width:SPAN * SCALE, kernel:'nearest'})
    .composite([{input:grid}])
    .png().toFile(`artifacts/video-frames/grid/${name}.png`);
  console.log(`${name}: crop origin ${left},${top}`);
}