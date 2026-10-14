import {readFileSync, writeFileSync, mkdirSync} from 'node:fs';

/**
 * Sound design for the ShareSafe demo film. Everything is synthesised or spoken
 * in-repo — no third-party samples, music or stock audio — so the soundtrack
 * carries no licensing risk.
 *
 * Three layers:
 *   bed        harmonic pad, scene whooshes, UI clicks that land on the
 *              pointer's clicks, confirmation chimes
 *   narration  per-scene voice cues (scripts/generate-narration.sh)
 *   mix        the bed is sidechain-ducked under each cue so speech stays clear
 */
const SR = 44100, DUR = 24, N = SR * DUR;
const left = new Float32Array(N), right = new Float32Array(N);
const bedL = new Float32Array(N), bedR = new Float32Array(N);
const voiceL = new Float32Array(N), voiceR = new Float32Array(N);

const add = (buf, i, l, r) => { if(i >= 0 && i < N){ buf[i] += l; if(r !== undefined) buf[i] += r; } };

let seed = 0x2f6e2b1;
const rnd = () => ((seed = (seed * 1664525 + 1013904223) >>> 0) / 0xffffffff) * 2 - 1;

// ── Bed: A2 · E3 · C4 · E4, gently detuned per channel ───────────────────────
const PAD = [[110, 0.108], [164.81, 0.076], [261.63, 0.045], [329.63, 0.032]];
for(let i = 0; i < N; i++){
  const t = i / SR;
  const fadeIn = Math.min(1, t / 1.3);
  const fadeOut = t > 21.0 ? Math.max(0, 1 - (t - 21.0) / 2.8) : 1;
  const env = fadeIn * fadeOut * (1 + 0.22 * Math.sin(2 * Math.PI * 0.11 * t));
  if(env <= 0) continue;
  let l = 0, r = 0;
  for(const [f, a] of PAD){
    l += Math.sin(2 * Math.PI * f * t) * a;
    r += Math.sin(2 * Math.PI * (f + 0.35) * t) * a;
  }
  add(bedL, i, l * env); add(bedR, i, r * env);
}

// ── Scene transition whooshes ────────────────────────────────────────────────
function whoosh(at, dur, gain){
  const start = Math.floor(at * SR), len = Math.floor(dur * SR);
  let lp = 0;
  for(let i = 0; i < len; i++){
    const p = i / len;
    lp += (rnd() - lp) * (0.02 + 0.34 * Math.sin(Math.PI * p));
    const env = Math.sin(Math.PI * p) ** 1.6;
    add(bedL, start + i, lp * env * gain);
    add(bedR, start + i, lp * env * gain * 0.85);
  }
}
[1.85, 6.85, 11.85, 16.85].forEach(at => whoosh(at, 0.75, 0.21));

// ── UI click: filtered tick + short transient ────────────────────────────────
function click(at, gain = 1){
  const start = Math.floor(at * SR), len = Math.floor(0.09 * SR);
  let lp = 0, hp = 0, prev = 0;
  for(let i = 0; i < len; i++){
    const p = i / len;
    const env = Math.exp(-p * 26);
    lp += (rnd() - lp) * 0.55;
    hp = 0.92 * (hp + lp - prev); prev = lp;
    const body = Math.sin(2 * Math.PI * 1150 * (i / SR)) * Math.exp(-p * 34);
    const s = (hp * 0.55 + body * 0.65 + rnd() * 0.10) * env * 0.5 * gain;
    add(bedL, start + i, s); add(bedR, start + i, s * 0.92);
  }
}
// Pointer clicks: email Redact, phone Keep, Redact all on page, Done.
[7.95, 9.05, 13.25, 19.85].forEach(at => click(at));
[7.30, 12.55, 17.55].forEach(at => click(at, 0.34));

// ── Confirmation chime on the export receipt ─────────────────────────────────
function chime(at, notes, gain = 1){
  notes.forEach(([freq, offset, amp]) => {
    const start = Math.floor((at + offset) * SR), len = Math.floor(1.9 * SR);
    for(let i = 0; i < len; i++){
      const t = i / SR;
      const env = Math.exp(-t * 3.1) * (1 - Math.exp(-t * 320));
      const v = (Math.sin(2 * Math.PI * freq * t) + 0.28 * Math.sin(4 * Math.PI * freq * t)) * env * amp * gain;
      add(bedL, start + i, v); add(bedR, start + i, v * 0.88);
    }
  });
}
chime(19.45, [[523.25, 0, 0.16], [659.25, 0.10, 0.13], [783.99, 0.20, 0.10]]);
chime(23.55, [[392.00, 0, 0.11], [523.25, 0.13, 0.09]], 0.85);

// ── Narration ────────────────────────────────────────────────────────────────
function readWavMono(path){
  const b = readFileSync(path);
  let offset = 12, rate = SR, data = null;
  const tag = o => String.fromCharCode(b[o], b[o+1], b[o+2], b[o+3]);
  while(offset + 8 <= b.length){
    const id = tag(offset), size = b.readUInt32LE(offset + 4);
    if(id === 'fmt '){ rate = b.readUInt32LE(offset + 12); }
    else if(id === 'data'){ data = b.subarray(offset + 8, offset + 8 + size); }
    offset += 8 + size + (size % 2);
  }
  if(!data) throw new Error(`No data chunk in ${path}`);
  const out = new Float32Array(Math.floor(data.length / 2));
  for(let i = 0; i < out.length; i++) out[i] = data.readInt16LE(i * 2) / 32768;
  return {samples: out, rate};
}

/** Linear resample so cues recorded at any rate land on the 44.1 kHz grid. */
function resample(samples, from, to){
  if(from === to) return samples;
  const out = new Float32Array(Math.round(samples.length * to / from));
  for(let i = 0; i < out.length; i++){
    const p = i * from / to, i0 = Math.floor(p), frac = p - i0;
    const a = samples[Math.min(samples.length - 1, i0)];
    const b = samples[Math.min(samples.length - 1, i0 + 1)];
    out[i] = a + (b - a) * frac;
  }
  return out;
}

// ── Narration placement ──────────────────────────────────────────────────────
// Phrase timings come from scripts/generate-narration.mjs, which renders each
// phrase separately with its own prosody. They are placed verbatim so the
// directed rhythm survives into the mix.
let manifest = [];
try{ manifest = JSON.parse(readFileSync('artifacts/audio/narration.json', 'utf8')); }
catch{ console.error('No narration.json — run: node scripts/generate-narration.mjs'); }

const phrases = [];
for(const line of manifest){
  try{
    const w = readWavMono(`artifacts/audio/lines/${line.file}`);
    phrases.push({at:line.at, samples:clarityVoice(resample(w.samples, w.rate, SR))});
  }catch{ console.log(`  (missing ${line.file})`); }
}

// Normalise the voice bus to a fixed RMS, not a peak. A male voice sits lower
// than a female one at the same nominal rate, so peak-normalising left it buried
// under the bed; a fixed RMS keeps narration at a consistent, clear level for
// whichever voice is selected, while a single shared gain preserves the natural
// dynamics between lines.
let voiceSum = 0, voiceCount = 0;
for(const p of phrases){ for(const s of p.samples){ voiceSum += s * s; voiceCount++; } }
const voiceRms = voiceCount ? Math.sqrt(voiceSum / voiceCount) : 0;
const VOICE_TARGET_RMS = 0.205;
const voiceGain = voiceRms > 0 ? VOICE_TARGET_RMS / voiceRms : 1;

const gate = new Float32Array(N);
const fadeIn = Math.round(0.008 * SR), fadeOut = Math.round(0.014 * SR);
for(const p of phrases){
  const start = Math.round(p.at * SR);
  for(let i = 0; i < p.samples.length; i++){
    const s = start + i;
    if(s >= N) break;
    let g = voiceGain;
    if(i < fadeIn) g *= i / fadeIn;                       // avoid a click on entry
    const tail = p.samples.length - i;
    if(tail < fadeOut) g *= tail / fadeOut;              // and on the tail
    const v = p.samples[i] * g;
    voiceL[s] += v; voiceR[s] += v * 0.97;
    gate[s] = 1;
  }
}
console.log(`  ${phrases.length} narration lines placed, voice rms ${voiceRms.toFixed(3)} -> ${VOICE_TARGET_RMS}`);

/**
 * Voice finishing, clarity first. An earlier version low-passed at 5.2 kHz and
 * added a low shelf, which sounded warm but buried the consonants and made the
 * delivery harder to follow. This chain instead:
 *   - removes sub-bass rumble with a two-pole high-pass
 *   - adds presence around 3 kHz so consonants cut
 *   - applies only light compression, so phrasing stays expressive
 */
function clarityVoice(samples){
  // Two-pole high-pass at 95 Hz: y = a*(y1 + x - x1)
  const hp = 1 / (1 + 2 * Math.PI * 95 / SR);
  let y1 = 0, x1 = 0;
  const clean = new Float32Array(samples.length);
  for(let i = 0; i < samples.length; i++){
    const x = samples[i];
    const y = hp * (y1 + x - x1);
    x1 = x; y1 = y;
    clean[i] = y;
  }

  // Presence band 1.4-5 kHz, mixed back in for intelligibility.
  const lpCoef = 1 - Math.exp(-2 * Math.PI * 5000 / SR);
  const hpCoef = 1 / (1 + 2 * Math.PI * 1400 / SR);
  let b1 = 0, b2 = 0, bx = 0, by = 0;
  for(let i = 0; i < clean.length; i++){
    const x = clean[i];
    by = hpCoef * (by + x - bx); bx = x;
    b1 += lpCoef * (by - b1);
    b2 += lpCoef * (b1 - b2);
    clean[i] = x + b2 * 0.26;
  }

  // Light soft-knee compression so level is even without flattening phrasing.
  let env = 0;
  const attack = Math.exp(-1 / (0.010 * SR)), release = Math.exp(-1 / (0.20 * SR));
  for(let i = 0; i < clean.length; i++){
    const a = Math.abs(clean[i]);
    env = a > env ? attack * env + (1 - attack) * a : release * env + (1 - release) * a;
    const over = Math.max(0, env - 0.28) / 0.72;
    clean[i] *= 1 - 0.20 * over * over;
  }
  return clean;
}

/** A very short room — enough to avoid bone-dry synthesis, not enough to smear. */
function addRoom(buf, wet, decay){
  const combDelays = [1557, 1617, 1491, 1422];
  const out = new Float32Array(buf.length);
  for(const d of combDelays){
    const line = new Float32Array(buf.length);
    const fb = Math.pow(0.001, d / (decay * SR));
    const idx = Math.round(d);
    for(let i = 0; i < buf.length; i++)
      line[i] = buf[i] + (i >= idx ? line[i - idx] * fb : 0);
    for(let i = 0; i < buf.length; i++) out[i] += line[i] * 0.25;
  }
  const pre = Math.round(0.015 * SR);
  for(let i = pre; i < out.length; i++) buf[i] += out[i - pre] * wet;
}
addRoom(voiceL, 0.035, 0.22);
addRoom(voiceR, 0.035, 0.24);

// ── Mix: duck the bed under speech, then normalise ───────────────────────────
// The bed sits well under the voice so every cue stays intelligible; the
// sidechain dip is fast to catch the first syllable and slow to release.
const BED_GAIN = 0.95, DUCK = 0.86;
let gateSmoothed = 0;
for(let i = 0; i < N; i++){
  const target = gate[i];
  const rate = target > gateSmoothed ? 0.0016 : 0.00012;
  gateSmoothed += (target - gateSmoothed) * rate;
  const duck = (1 - DUCK * gateSmoothed) * BED_GAIN;
  left[i] = bedL[i] * duck + voiceL[i];
  right[i] = bedR[i] * duck + voiceR[i];
}

let peak = 0;
for(let i = 0; i < N; i++) peak = Math.max(peak, Math.abs(left[i]), Math.abs(right[i]));
const gain = peak > 0 ? 0.89 / peak : 1;
for(let i = 0; i < N; i++){
  left[i] = Math.tanh(left[i] * gain * 1.15) * 0.92;
  right[i] = Math.tanh(right[i] * gain * 1.15) * 0.92;
}

// ── 16-bit PCM WAV ───────────────────────────────────────────────────────────
const dataBytes = N * 4;
const buf = Buffer.alloc(44 + dataBytes);
buf.write('RIFF', 0); buf.writeUInt32LE(36 + dataBytes, 4); buf.write('WAVE', 8);
buf.write('fmt ', 12); buf.writeUInt32LE(16, 16); buf.writeUInt16LE(1, 20);
buf.writeUInt16LE(2, 22); buf.writeUInt32LE(SR, 24); buf.writeUInt32LE(SR * 4, 28);
buf.writeUInt16LE(4, 32); buf.writeUInt16LE(16, 34);
buf.write('data', 36); buf.writeUInt32LE(dataBytes, 40);
let o = 44;
for(let i = 0; i < N; i++){
  buf.writeInt16LE(Math.max(-32768, Math.min(32767, Math.round(left[i] * 32767))), o); o += 2;
  buf.writeInt16LE(Math.max(-32768, Math.min(32767, Math.round(right[i] * 32767))), o); o += 2;
}

mkdirSync('artifacts/audio', {recursive:true});
writeFileSync('artifacts/audio/sharesafe-demo.wav', buf);
console.log(`Wrote artifacts/audio/sharesafe-demo.wav — ${DUR}s stereo ${SR}Hz, ${(buf.length / 1048576).toFixed(2)} MB (bed + ${phrases.length} narration lines, ducked).`);