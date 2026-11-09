// Usage: node shoot.mjs <deck.html> <width> <height> [query=?all] [slides=all|0,1,2] [outdir=.] [extraJS]
// Per slide: elements outside .stage (bad), empty band below the content (deadBand, px), smallest text size (minFont, px on a 1280 stage). Saves s<n>_<width>.png.
import { writeFileSync } from 'node:fs';
import { pathToFileURL } from 'node:url';
import { openChrome, sleep } from './cdp.mjs';

const [deck, W, H, query = '?all', list = 'all', outdir = '.', extra = ''] = process.argv.slice(2);
if (!deck || !W || !H) { console.error('usage: node shoot.mjs <deck.html> <width> <height> [query] [slides] [outdir] [extraJS]'); process.exit(2); }
const url = pathToFileURL(deck).href;
const { cmd, evaluate, close } = await openChrome([`--window-size=${W},${H}`]);
await cmd('Emulation.setDeviceMetricsOverride', { width: +W, height: +H, deviceScaleFactor: 1, mobile: false });

const measure = `(() => {
  const s = document.querySelector('.slide.active'); const st = s.querySelector('.stage').getBoundingClientRect();
  const scale = st.width / 1280, bad = []; let minFont = 999;
  for (const el of s.querySelectorAll('.inner *')) {
    if (el.closest('defs, symbol')) continue;
    const r = el.getBoundingClientRect(); if (!r.width && !r.height) continue;
    if (r.left < st.left - 1 || r.top < st.top - 1 || r.right > st.right + 1 || r.bottom > st.bottom + 1)
      bad.push((el.className.baseVal ?? el.className) + ' ' + el.tagName + ' ' + [r.left, r.top, r.right, r.bottom].map(Math.round));
    const own = [...el.childNodes].some(n => n.nodeType === 3 && n.textContent.trim());
    if (own && !el.closest('svg') && !el.closest('.hint, .hud, .tag, .qt, .timer')) minFont = Math.min(minFont, parseFloat(getComputedStyle(el).fontSize) / scale);
  }
  const kids = [...s.querySelector('.inner').children].filter(c => getComputedStyle(c).position !== 'absolute');
  const bottom = Math.max(...kids.map(c => c.getBoundingClientRect().bottom));
  return { n: s.dataset.n, deadBand: Math.round((st.bottom - bottom) / scale), minFont: Math.round(minFont * 10) / 10, bad: bad.slice(0, 8) };
})()`;
const total = await (async () => { await cmd('Page.navigate', { url: url + query }); await sleep(1500); return evaluate('document.querySelectorAll(".slide").length'); })();
const nums = list === 'all' ? [...Array(total).keys()] : list.split(',').map(Number);
let fail = 0;
for (const n of nums) {
  await cmd('Page.navigate', { url: `${url}${query}#${n}` });
  await cmd('Page.reload');
  await sleep(2600);
  if (extra) console.log('extra =>', JSON.stringify(await evaluate(extra)));
  await sleep(800);
  const r = await evaluate(measure);
  if (r.bad.length) fail = 1;
  console.log(JSON.stringify(r));
  const shot = await cmd('Page.captureScreenshot', { format: 'png' });
  writeFileSync(`${outdir}/s${n}_${W}${extra ? '_x' : ''}.png`, Buffer.from(shot.result.data, 'base64'));
}
close();
process.exit(fail);
