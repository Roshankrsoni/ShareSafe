import {execFileSync} from 'node:child_process';
import {mkdirSync, rmSync, writeFileSync, readFileSync} from 'node:fs';

/**
 * Narration direction for the ShareSafe demo.
 *
 * Robotic speech usually has two causes: one long sentence rendered as a single
 * intonation contour (every word gets identical weight), and choppy delivery
 * assembled from short fragments. This script fixes both.
 *
 * Each line is rendered as ONE connected utterance so the speech flows
 * naturally, while the prosody is still shaped inside it:
 *
 *   rate shaping   <prosody rate> pulls content words back, setup words move on
 *   declination    <prosody pitch> drifts down across the statement
 *   micro-pauses   <break> at clause boundaries, sized per pause
 *
 * One utterance per line also avoids the tell-tale seams you get from
 * concatenating separate clips.
 */

const VOICE = process.env.VOICE || 'Rocko (English (US))';
const BASE_RATE = Number(process.env.RATE || 156);
const SR = 44100;
const SCENE_END = 24.0;

const DIR = 'artifacts/audio/lines';
mkdirSync(DIR, {recursive:true});

/**
 * parts: spoken as one utterance. `rate` and `pitch` shape each part;
 *       `pause` (ms) is the silence that follows it. Copy is deliberately
 *       short and conversational — narration that has been tightened to sound
 *       spoken rather than read.
 */
const LINES = [
  {id:'title', at:0.25, limit:3.10, parts:[
    {text:'Review a document', rate:BASE_RATE,   pitch:2, pause:170},
    {text:'before you share it.', rate:BASE_RATE-6, pitch:-4, pause:0},
  ]},
  {id:'detect', at:3.35, limit:7.00, parts:[
    {text:'Local detection', rate:BASE_RATE,     pitch:2, pause:150},
    {text:'finds three suggestions right here.', rate:BASE_RATE-8, pitch:-4, pause:0},
  ]},
  {id:'decide', at:7.40, limit:12.00, parts:[
    {text:'Redact the email,', rate:BASE_RATE,   pitch:2, pause:190},
    {text:'or keep the number.', rate:BASE_RATE-8, pitch:-5, pause:0},
  ]},
  {id:'protect', at:12.50, limit:17.00, parts:[
    {text:'One click', rate:BASE_RATE,          pitch:3, pause:200},
    {text:'masks every suggestion.', rate:BASE_RATE-10, pitch:-5, pause:0},
  ]},
  {id:'export', at:17.35, limit:21.20, parts:[
    {text:'A separate copy is saved,', rate:BASE_RATE, pitch:1, pause:180},
    {text:'with a receipt you can check.', rate:BASE_RATE-8, pitch:-5, pause:0},
  ]},
  {id:'outro', at:21.35, limit:SCENE_END, parts:[
    {text:'Checkout opens soon.', rate:BASE_RATE-4, pitch:-1, pause:0},
  ]},
];

function wavSeconds(path){
  const b = readFileSync(path);
  let offset = 12;
  while(offset + 8 <= b.length){
    const tag = String.fromCharCode(b[offset], b[offset+1], b[offset+2], b[offset+3]);
    const len = b.readUInt32LE(offset + 4);
    if(tag === 'data') return len / 2 / SR;
    offset += 8 + len + (len % 2);
  }
  return 0;
}

const wrap = (part) => {
  const p = `${part.pitch >= 0 ? '+' : ''}${part.pitch}%`;
  return `<prosody rate="${part.rate}%" pitch="${p}">${part.text}</prosody>`;
};

const manifest = [];
let problems = 0;

for(const line of LINES){
  const name = `${line.id}`;
  const ssmlPath = `/tmp/line-${name}.xml`;
  const aiffPath = `/tmp/line-${name}.aiff`;
  const wavPath = `${DIR}/${name}.wav`;

  // One utterance: prosody per clause, <break> between clauses.
  const body = line.parts
    .map((part, i) => i < line.parts.length - 1
      ? `${wrap(part)}<break time="${part.pause}ms"/>`
      : wrap(part))
    .join('');

  writeFileSync(ssmlPath,
    `<?xml version="1.0" encoding="UTF-8"?>\n<speak>${body}</speak>\n`);
  execFileSync('say', ['-v', VOICE, '-f', ssmlPath, '-o', aiffPath]);
  execFileSync('afconvert', ['-f', 'WAVE', '-d', `LEI16@${SR}`, aiffPath, wavPath]);
  rmSync(aiffPath, {force:true});

  const dur = Math.max(0.2, wavSeconds(wavPath) - 0.05);
  const end = line.at + dur;
  const ok = end <= line.limit;
  if(!ok) problems++;

  manifest.push({id:line.id, file:`${name}.wav`, at:line.at, dur:+dur.toFixed(3)});
  console.log(`${ok ? 'ok ' : 'OVERFLOW'} ${line.id.padEnd(8)} ${line.at.toFixed(2)}–${end.toFixed(2)}s ` +
              `(limit ${line.limit.toFixed(2)})  ${line.parts.length} clause${line.parts.length > 1 ? 's' : ''}, ${dur.toFixed(2)}s`);
}

writeFileSync('artifacts/audio/narration.json', JSON.stringify(manifest, null, 2));
console.log(`\nManifest written to artifacts/audio/narration.json (voice: ${VOICE}, base ${BASE_RATE} wpm)`);
if(problems){ console.error(`${problems} line(s) exceed their scene window — tighten the copy or move the anchor.`); process.exit(1); }