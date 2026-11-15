#!/usr/bin/env node
'use strict';
/*
 * make-icons.js - build the CCA app icons from build/icon-master.svg.
 *
 * Original artwork, no SF Symbols or third-party glyphs.
 *
 * Usage:
 *   node desktop/scripts/make-icons.js [--out <dir>] [--preview <dir>]
 *
 * Reads  ../build/icon-master.svg
 * Writes ../build/icon.png  (1024x1024 RGBA, whole viewBox, keeps the macOS padding)
 *        ../build/icon.ico  (PNG entries at 16, 24, 32, 48, 64, 128, 256; view cropped
 *                            to "92 92 840 840" so the tile fills the icon on Windows)
 * --out <dir>      write there instead of ../build
 * --preview <dir>  also write every rendered size as a PNG for review
 *
 * SVG subset (anything else throws): root <svg viewBox>, comments,
 * <rect x y width height rx fill fill-opacity>, <circle cx cy r fill fill-opacity>,
 * and <g data-min-px="N"> (children are drawn only when the output width >= N).
 * Colours are #RRGGBB only. Output is deterministic on Node 20+ (fixed zlib level, fixed filter).
 */
const fs = require('fs');
const path = require('path');
const zlib = require('zlib');

const BUILD = path.join(__dirname, '..', 'build');
const ICO_SIZES = [16, 24, 32, 48, 64, 128, 256];
const ICO_VIEW = [92, 92, 840, 840];

function parseAttrs(s, tag) {
  const attrs = {};
  const re = /([A-Za-z_:][\w:.-]*)\s*=\s*"([^"]*)"/g;
  let m, last = 0;
  while ((m = re.exec(s))) {
    if (s.slice(last, m.index).trim() !== '') throw new Error(`<${tag}>: cannot parse attributes: ${s}`);
    attrs[m[1]] = m[2];
    last = re.lastIndex;
  }
  if (s.slice(last).trim() !== '') throw new Error(`<${tag}>: cannot parse attributes: ${s}`);
  return attrs;
}

function num(a, name, tag, def) {
  if (a[name] === undefined) {
    if (def !== undefined) return def;
    throw new Error(`<${tag}>: missing attribute ${name}`);
  }
  if (!/^-?\d+(\.\d+)?$/.test(a[name])) throw new Error(`<${tag}>: bad number in ${name}="${a[name]}"`);
  return Number(a[name]);
}

function colour(a, tag) {
  const f = a.fill;
  if (!f || !/^#[0-9A-Fa-f]{6}$/.test(f)) throw new Error(`<${tag}>: fill must be #RRGGBB, got "${f}"`);
  const op = num(a, 'fill-opacity', tag, 1);
  if (op < 0 || op > 1) throw new Error(`<${tag}>: fill-opacity out of range`);
  return { r: parseInt(f.slice(1, 3), 16), g: parseInt(f.slice(3, 5), 16), b: parseInt(f.slice(5, 7), 16), op };
}

function allow(a, tag, names) {
  for (const k of Object.keys(a)) if (!names.includes(k)) throw new Error(`<${tag}>: unsupported attribute ${k}`);
}

function parseSvg(text) {
  text = text.replace(/<!--[\s\S]*?-->/g, '');
  const tagRe = /<\s*(\/?)\s*([A-Za-z][\w:-]*)([^>]*?)(\/?)>/g;
  const shapes = [];
  let view = null, depthSvg = 0, minPx = null, m, pos = 0;
  while ((m = tagRe.exec(text))) {
    if (text.slice(pos, m.index).trim() !== '') throw new Error('unexpected text in SVG');
    pos = tagRe.lastIndex;
    const [, close, name, rest, selfClose] = m;
    if (close) {
      if (name === 'svg') depthSvg--;
      else if (name === 'g') minPx = null;
      else throw new Error(`unsupported closing tag </${name}>`);
      continue;
    }
    const a = parseAttrs(rest, name);
    if (name === 'svg') {
      if (view || selfClose) throw new Error('only one root <svg> is supported');
      const v = (a.viewBox || '').trim().split(/[\s,]+/).map(Number);
      if (v.length !== 4 || v.some((n) => !isFinite(n)) || v[2] <= 0 || v[3] <= 0) throw new Error('<svg>: bad or missing viewBox');
      view = v;
      depthSvg++;
    } else if (!view) {
      throw new Error('root <svg> must come first');
    } else if (name === 'g') {
      allow(a, 'g', ['data-min-px']);
      if (selfClose || minPx !== null) throw new Error('<g>: nested or empty groups are not supported');
      minPx = num(a, 'data-min-px', 'g');
    } else if (name === 'rect') {
      allow(a, 'rect', ['x', 'y', 'width', 'height', 'rx', 'fill', 'fill-opacity']);
      shapes.push({ type: 'rect', minPx: minPx || 0, x: num(a, 'x', name, 0), y: num(a, 'y', name, 0),
        w: num(a, 'width', name), h: num(a, 'height', name), rx: num(a, 'rx', name, 0), ...colour(a, name) });
    } else if (name === 'circle') {
      allow(a, 'circle', ['cx', 'cy', 'r', 'fill', 'fill-opacity']);
      shapes.push({ type: 'circle', minPx: minPx || 0, cx: num(a, 'cx', name), cy: num(a, 'cy', name),
        rad: num(a, 'r', name), ...colour(a, name) });
    } else {
      throw new Error(`unsupported element <${name}>`);
    }
  }
  if (text.slice(pos).trim() !== '') throw new Error('unexpected trailing text in SVG');
  if (!view || depthSvg !== 0) throw new Error('missing or unclosed <svg>');
  if (minPx !== null) throw new Error('unclosed <g>');
  return { viewBox: view, shapes };
}

// Signed distance (user units) from point to the shape edge; negative inside.
function dist(s, px, py) {
  if (s.type === 'circle') return Math.hypot(px - s.cx, py - s.cy) - s.rad;
  const r = Math.min(s.rx, s.w / 2, s.h / 2);
  const qx = Math.abs(px - (s.x + s.w / 2)) - (s.w / 2 - r);
  const qy = Math.abs(py - (s.y + s.h / 2)) - (s.h / 2 - r);
  return Math.hypot(Math.max(qx, 0), Math.max(qy, 0)) + Math.min(Math.max(qx, qy), 0) - r;
}

// Render to straight-alpha RGBA, size x size, for the given view [x y w h].
function render(svg, view, size) {
  const shapes = svg.shapes.filter((s) => size >= s.minPx);
  const ss = size <= 64 ? 4 : 1;
  const scale = size / view[2]; // output pixels per user unit
  const out = Buffer.alloc(size * size * 4);
  for (let y = 0; y < size; y++) {
    for (let x = 0; x < size; x++) {
      let pr = 0, pg = 0, pb = 0, pa = 0; // accumulated premultiplied, 0..1 colour scale of 255
      for (let sy = 0; sy < ss; sy++) {
        for (let sx = 0; sx < ss; sx++) {
          const ux = view[0] + (x + (sx + 0.5) / ss) / scale;
          const uy = view[1] + (y + (sy + 0.5) / ss) / scale;
          let r = 0, g = 0, b = 0, a = 0; // straight alpha composite
          for (const s of shapes) {
            const cov = Math.min(1, Math.max(0, 0.5 - dist(s, ux, uy) * scale));
            const sa = cov * s.op;
            if (sa <= 0) continue;
            const oa = sa + a * (1 - sa);
            r = (s.r * sa + r * a * (1 - sa)) / oa;
            g = (s.g * sa + g * a * (1 - sa)) / oa;
            b = (s.b * sa + b * a * (1 - sa)) / oa;
            a = oa;
          }
          pr += r * a; pg += g * a; pb += b * a; pa += a;
        }
      }
      const n = ss * ss, i = (y * size + x) * 4;
      const A = pa / n;
      if (A > 0) {
        out[i] = Math.round(pr / pa);
        out[i + 1] = Math.round(pg / pa);
        out[i + 2] = Math.round(pb / pa);
        out[i + 3] = Math.round(A * 255);
      }
    }
  }
  return out;
}

const CRC = (() => {
  const t = new Uint32Array(256);
  for (let n = 0; n < 256; n++) {
    let c = n;
    for (let k = 0; k < 8; k++) c = c & 1 ? 0xedb88320 ^ (c >>> 1) : c >>> 1;
    t[n] = c >>> 0;
  }
  return t;
})();

function crc32(buf) {
  let c = 0xffffffff;
  for (let i = 0; i < buf.length; i++) c = CRC[(c ^ buf[i]) & 0xff] ^ (c >>> 8);
  return (c ^ 0xffffffff) >>> 0;
}

function chunk(type, data) {
  const len = Buffer.alloc(4); len.writeUInt32BE(data.length);
  const body = Buffer.concat([Buffer.from(type, 'ascii'), data]);
  const crc = Buffer.alloc(4); crc.writeUInt32BE(crc32(body));
  return Buffer.concat([len, body, crc]);
}

function encodePng(rgba, size) {
  const ihdr = Buffer.alloc(13);
  ihdr.writeUInt32BE(size, 0); ihdr.writeUInt32BE(size, 4);
  ihdr[8] = 8; ihdr[9] = 6; // 8-bit RGBA
  const stride = size * 4;
  const raw = Buffer.alloc((stride + 1) * size); // filter byte 0 (None) on every row
  for (let y = 0; y < size; y++) rgba.copy(raw, y * (stride + 1) + 1, y * stride, (y + 1) * stride);
  return Buffer.concat([
    Buffer.from([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]),
    chunk('IHDR', ihdr),
    chunk('sRGB', Buffer.from([0])),
    chunk('IDAT', zlib.deflateSync(raw, { level: 9 })),
    chunk('IEND', Buffer.alloc(0)),
  ]);
}

function encodeIco(pngs) { // pngs: [{size, data}] ascending
  const head = Buffer.alloc(6);
  head.writeUInt16LE(0, 0); head.writeUInt16LE(1, 2); head.writeUInt16LE(pngs.length, 4);
  const dir = Buffer.alloc(16 * pngs.length);
  let offset = 6 + dir.length;
  pngs.forEach((p, i) => {
    const o = i * 16;
    dir[o] = p.size >= 256 ? 0 : p.size;
    dir[o + 1] = p.size >= 256 ? 0 : p.size;
    dir[o + 2] = 0; dir[o + 3] = 0;
    dir.writeUInt16LE(1, o + 4); dir.writeUInt16LE(32, o + 6);
    dir.writeUInt32LE(p.data.length, o + 8); dir.writeUInt32LE(offset, o + 12);
    offset += p.data.length;
  });
  return Buffer.concat([head, dir, ...pngs.map((p) => p.data)]);
}

function main() {
  const args = process.argv.slice(2);
  let outDir = BUILD, previewDir = null;
  for (let i = 0; i < args.length; i++) {
    if (args[i] === '--out' && args[i + 1]) outDir = path.resolve(args[++i]);
    else if (args[i] === '--preview' && args[i + 1]) previewDir = path.resolve(args[++i]);
    else throw new Error(`unknown or incomplete option: ${args[i]}`);
  }
  const svg = parseSvg(fs.readFileSync(path.join(BUILD, 'icon-master.svg'), 'utf8'));
  fs.mkdirSync(outDir, { recursive: true });
  if (previewDir) fs.mkdirSync(previewDir, { recursive: true });

  const png = encodePng(render(svg, svg.viewBox, 1024), 1024);
  fs.writeFileSync(path.join(outDir, 'icon.png'), png);
  if (previewDir) fs.writeFileSync(path.join(previewDir, 'png-1024.png'), png);

  const entries = ICO_SIZES.map((size) => {
    const data = encodePng(render(svg, ICO_VIEW, size), size);
    if (previewDir) fs.writeFileSync(path.join(previewDir, `ico-${size}.png`), data);
    return { size, data };
  });
  fs.writeFileSync(path.join(outDir, 'icon.ico'), encodeIco(entries));
  console.log(`wrote icon.png and icon.ico to ${outDir}`);
}

try { main(); } catch (e) { console.error(`make-icons: ${e.message}`); process.exit(1); }
