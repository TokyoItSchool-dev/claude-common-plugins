// Usage: node pdftest.mjs <file.html[?query]> <out.pdf> <css|default>
// css: preferCSSPageSize true (what 「PDFに保存」 does). default: CSS page size ignored, A4 portrait, ~10mm margins, header/footer on.
import { writeFileSync } from 'node:fs';
import { pathToFileURL } from 'node:url';
import { openChrome, sleep } from './cdp.mjs';

const [file, out, mode] = process.argv.slice(2);
if (!file || !out || !['css', 'default'].includes(mode)) { console.error('usage: node pdftest.mjs <file.html[?query]> <out.pdf> <css|default>'); process.exit(2); }
const [path, query = ''] = file.split('?');
const { cmd, close } = await openChrome();
await cmd('Page.navigate', { url: pathToFileURL(path).href + (query ? '?' + query : '') });
await sleep(2500);
const opts = mode === 'css'
  ? { preferCSSPageSize: true, printBackground: true }
  : { preferCSSPageSize: false, landscape: false, printBackground: false, displayHeaderFooter: true,
      paperWidth: 8.27, paperHeight: 11.69, marginTop: 0.4, marginBottom: 0.4, marginLeft: 0.4, marginRight: 0.4 };
const p = await cmd('Page.printToPDF', opts);
close();
if (!p.result) { console.error('error', JSON.stringify(p.error)); process.exit(1); }
writeFileSync(out, Buffer.from(p.result.data, 'base64'));
console.log('pdf', out);
