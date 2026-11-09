"""Usage: python pdfinfo.py <pdf> [phrases.txt]
Prints page count, page sizes (mm), whether all pages are landscape, and phrases (one per line) missing from the PDF text.
Exit 1 when a phrase is missing. Needs pypdf."""
import re
import sys
import unicodedata

import pypdf


def norm(t):
    # pypdf returns some CJK compatibility forms; normalize before matching
    return unicodedata.normalize('NFKC', re.sub(r'\s+', '', t)).replace('‧', '・')


def main():
    if len(sys.argv) not in (2, 3):
        sys.exit(__doc__)
    r = pypdf.PdfReader(sys.argv[1])
    sizes = {(round(float(p.mediabox.width) * 25.4 / 72), round(float(p.mediabox.height) * 25.4 / 72)) for p in r.pages}
    text = norm(''.join(p.extract_text() for p in r.pages))
    missing = []
    if len(sys.argv) == 3:
        phrases = open(sys.argv[2], encoding='utf-8').read().split('\n')
        missing = [ph for ph in phrases if ph.strip() and norm(ph) not in text]
    print('pages', len(r.pages), 'sizes_mm', sorted(sizes), 'landscape', all(w > h for w, h in sizes), 'missing', missing)
    sys.exit(1 if missing else 0)


if __name__ == '__main__':
    main()
