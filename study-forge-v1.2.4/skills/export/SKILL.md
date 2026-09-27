---
name: export
description: >
  강의노트를 PDF, DOCX, PPTX 등 다른 형식으로 변환하는 스킬.
  사용자가 "노트를 PDF로", "export", "워드로 변환", "인쇄용으로 만들어줘",
  "pptx로 내보내기" 등을 요청할 때 사용한다.
  PDF는 pandoc → HTML → Playwright/Chromium 파이프라인으로 직접 만든다 —
  한글 폰트·그림·표·코드블록·MathML 수식·표지·쪽번호가 모두 들어간다 (v0.2.0).
version: 0.2.0
---

# 강의노트 형식 변환 스킬

마크다운 강의노트를 PDF, DOCX, PPTX 등으로 변환한다.

| 형식 | 용도 | 방법 |
|------|------|------|
| **PDF** | 읽기·인쇄·제출 | **이 스킬의 파이프라인** (아래) — pandoc → HTML → Playwright/Chromium |
| DOCX | 편집, 제출 | Cowork의 `docx` 스킬 활용 |
| PPTX | 발표, 요약 | Cowork의 `pptx` 스킬 활용 |

---

## PDF — 이 스킬이 직접 만든다

> **왜 직접 만드는가** — 강의노트는 표·코드블록·다이어그램 PNG·LaTeX 수식·한글이 한 문서에 섞여 있다.
> 범용 변환기에 맡기면 수식이 코드로 찍히거나 그림이 빠진다. 아래 파이프라인은 5과목 1~3주차 노트 15개(584쪽)로 검증했다.

### 1단계: 도구 확인 (없으면 설치)

```bash
command -v pandoc || brew install pandoc
python3 -c "import playwright" 2>/dev/null || pip3 install playwright
# 크롬은 새로 받지 않는다 — Playwright 캐시에 이미 있으면 그 바이너리를 지정해 쓴다
ls ~/Library/Caches/ms-playwright/ | grep -i chromium
```

- `pdftotext`(poppler)는 검증에 쓴다 — `brew install poppler`
- 크롬 바이너리를 못 찾으면 `python3 -m playwright install chromium`

### 2단계: 변환 스크립트

아래를 `build_pdf.py`로 저장해 쓴다. **과목 폴더·주차만 인자로 준다.**

```python
# -*- coding: utf-8 -*-
"""강의노트 마크다운 → PDF (pandoc → HTML → Playwright/Chromium)

사용:
    python3 build_pdf.py <과목 키워드> <주차> [--install]   예: build_pdf.py 딥러닝 3 --install
    python3 build_pdf.py all <주차>  [--install]
--install 이 있으면 과목 `강의노트/`에 `NN주차-강의노트.pdf`로 저장한다(없으면 out/ 에만).
"""
import glob
import html
import os
import re
import shutil
import subprocess
import sys
import unicodedata as ud
from urllib.parse import quote

N = lambda s: ud.normalize('NFC', s)
FENCE = '`' * 3      # 코드 펜스 — 이 문서의 코드블록을 끊지 않도록 리터럴로 쓰지 않는다
ROOT = os.path.expanduser('~/Library/Mobile Documents/com~apple~CloudDocs/보관함(iCloud)/SCU')
OUT = os.path.expanduser('~/Workspace/scu-pdf')          # 작업 폴더 — iCloud 밖
SCHOOL = '서울사이버대학교'


def chrome_path():
    """Playwright 캐시의 크롬 — 없으면 chrome-headless-shell, 그것도 없으면 None"""
    base = os.path.expanduser('~/Library/Caches/ms-playwright')
    for pat in ('chromium-*/chrome-mac-arm64/Google Chrome for Testing.app/Contents/MacOS/Google Chrome for Testing',
                'chromium-*/chrome-mac/Chromium.app/Contents/MacOS/Chromium',
                'chromium_headless_shell-*/chrome-headless-shell-mac-arm64/chrome-headless-shell'):
        hit = sorted(glob.glob(os.path.join(base, pat)))
        if hit:
            return hit[-1]
    return None


def rs(parent, name):
    """NFD/NFC 안전 — 실제 디렉터리 항목 이름으로 돌려준다"""
    return next(os.path.join(parent, e) for e in os.listdir(parent) if N(e) == N(name))


def find_course(keyword):
    for e in sorted(os.listdir(ROOT)):
        if N(e).startswith('[') and N(keyword) in N(e):
            return os.path.join(ROOT, e)
    raise FileNotFoundError(keyword)


def fix_literal_bold(body):
    """pandoc이 굵게로 읽지 못해 글자로 남은 `**…**`만 <strong>으로

    ⚠️ 마크다운 단계에서 미리 바꾸지 말 것 — 여는/닫는 구분자를 구분하지 못해 강조가 한 칸씩 밀린다.
    pandoc이 짝짓기를 끝낸 뒤 HTML에서 고치면 표 칸·코드 경계를 넘을 수 없다.
    """
    pat = re.compile(r'\*\*(?!\s)((?:[^*<>\n]|<code>[^<]*</code>|</?(?:code|em)>){1,300}?)\*\*')
    parts = re.split(r'(<pre\b.*?</pre>)', body, flags=re.S)
    return ''.join(p if p.startswith('<pre') else pat.sub(r'<strong>\1</strong>', p) for p in parts)


def latex_to_math(m):
    """latex 블록 — 줄마다 독립 수식으로 (두 식이 한 줄로 붙는 것을 막는다)"""
    lines = [l.strip() for l in m.group(1).split('\n') if l.strip()]
    return '\n\n'.join('$$\n' + l + '\n$$' for l in lines)


def md_to_html_body(md, img_dir):
    md = re.sub(FENCE + r'latex\n(.*?)\n' + FENCE, latex_to_math, md, flags=re.S)
    p = subprocess.run(['pandoc', '-f', 'gfm+tex_math_dollars', '-t', 'html5', '--mathml', '--wrap=none'],
                       input=md, capture_output=True, text=True, check=True)
    body = fix_literal_bold(p.stdout)
    body = re.sub(r'<hr\s*/?>\s*(?=<h1)', '', body)      # 대단원이 새 쪽을 열므로 앞 구분선은 빈 쪽만 만든다

    def abs_img(m):
        return 'src="file://{}"'.format(quote(os.path.join(img_dir, os.path.basename(m.group(1)))))

    return re.sub(r'src="img/([^"]+)"', abs_img, body)


CSS = """
* { box-sizing: border-box; }
body { font-family: 'Apple SD Gothic Neo', -apple-system, sans-serif; font-size: 10.2pt;
       line-height: 1.62; color: #1a2430; margin: 0; letter-spacing: -0.15px; }
.cover { height: 244mm; display: flex; flex-direction: column; justify-content: center;
         page-break-after: always; border-left: 6px solid #1f4e82; padding-left: 14mm; }
.cover .course { font-size: 26pt; font-weight: 800; color: #1f2d3d; margin-bottom: 6mm; }
.cover .week { font-size: 15pt; font-weight: 700; color: #1f4e82; }
.cover .meta { margin-top: 14mm; font-size: 9.5pt; color: #64748b; line-height: 1.9; }
.cover .toc { margin-top: 10mm; font-size: 9.5pt; color: #334155; column-count: 2; column-gap: 8mm; }
.cover .toc div { break-inside: avoid; margin-bottom: 1.5mm; }
h1 { font-size: 16pt; font-weight: 800; color: #fff; background: #1f4e82; padding: 3.2mm 4mm;
     border-radius: 2mm; margin: 0 0 5mm; page-break-before: always; page-break-after: avoid; }
h2 { font-size: 13pt; font-weight: 800; color: #1f2d3d; margin: 7mm 0 3mm;
     border-bottom: 2px solid #9fb3c8; padding-bottom: 1.5mm; page-break-after: avoid; }
h3 { font-size: 11.2pt; font-weight: 800; color: #1f4e82; margin: 5mm 0 2mm; page-break-after: avoid; }
h4 { font-size: 10.6pt; font-weight: 800; color: #334155; margin: 4mm 0 1.5mm;
     page-break-after: avoid; background: #eef2f7; padding: 1.2mm 2.5mm; border-radius: 1.5mm; }
p { margin: 1.5mm 0; }
ul, ol { margin: 1.5mm 0; padding-left: 5.5mm; }
li { margin: 0.8mm 0; }
li > ul, li > ol { margin: 0.6mm 0; }
strong { font-weight: 800; color: #10243a; }
code { font-family: 'SF Mono', Menlo, Consolas, monospace; font-size: 0.88em;
       background: #f1f5f9; border: 1px solid #e2e8f0; border-radius: 1mm; padding: 0 1mm;
       letter-spacing: 0; word-break: keep-all; overflow-wrap: break-word; }
pre { background: #f8fafc; border: 1px solid #d7dee8; border-left: 3px solid #7aa2d0;
      border-radius: 1.5mm; padding: 2.5mm 3mm; margin: 2.5mm 0; page-break-inside: avoid; }
pre code { background: none; border: none; padding: 0; font-size: 8.6pt; line-height: 1.45;
           white-space: pre-wrap; word-break: normal; }
table { border-collapse: collapse; width: 100%; margin: 2.5mm 0; font-size: 9.2pt;
        page-break-inside: avoid; }
th { background: #eef2f7; color: #1f2d3d; font-weight: 800; text-align: left;
     border: 1px solid #c9d3de; padding: 1.6mm 2mm; }
td { border: 1px solid #dbe3ec; padding: 1.6mm 2mm; vertical-align: top; }
tr:nth-child(even) td { background: #fbfcfe; }
img { max-width: 100%; height: auto; display: block; margin: 3mm auto;
      border: 1px solid #e2e8f0; border-radius: 1.5mm; page-break-inside: avoid; }
hr { border: none; border-top: 1px solid #dbe3ec; margin: 6mm 0; }
blockquote { border-left: 3px solid #e2b04a; background: #fffaf0; margin: 2.5mm 0;
             padding: 2mm 3mm; color: #5c3b00; }
math { font-size: 1.05em; }
"""

FOOTER = ("""<div style="width:100%;font-size:7.5pt;color:#94a3b8;padding:0 15mm;
 font-family:'Apple SD Gothic Neo',sans-serif;display:flex;justify-content:space-between">
 <span>{title}</span><span><span class="pageNumber"></span> / <span class="totalPages"></span></span></div>""")


def build(course_dir, week, install=False):
    nd = rs(course_dir, '강의노트')
    md_path = next((os.path.join(nd, e) for e in os.listdir(nd)
                    if N(e) == f'{week:02d}주차-강의노트.md'), None)
    if not md_path:
        print(f'{N(os.path.basename(course_dir))} {week}주차 — 노트 없음')
        return None
    img_dir = rs(nd, 'img')
    md = open(md_path, encoding='utf-8').read()
    body = md_to_html_body(md, img_dir)

    fence, tops = False, []
    for ln in md.split('\n'):
        if ln.lstrip().startswith(FENCE):
            fence = not fence
            continue
        if not fence and ln.startswith('# '):
            tops.append(ln[2:].strip())

    folder = N(os.path.basename(course_dir))                 # 예: [4-2] 딥러닝
    m = re.match(r'\[(\d+)-(\d+)\]\s*(.+)', folder)
    sem = f'{m.group(1)}학년 {m.group(2)}학기' if m else ''
    course_name = m.group(3) if m else folder
    toc = '\n'.join('<div>{}. {}</div>'.format(i, html.escape(t)) for i, t in enumerate(tops, 1))
    cover = f"""<div class="cover">
  <div class="course">{html.escape(course_name)}</div>
  <div class="week">{week}주차 강의노트</div>
  <div class="meta">{SCHOOL} · {sem}<br>{len(md):,}자 · 대단원 {len(tops)}개</div>
  <div class="toc">{toc}</div>
</div>"""
    title = f'{course_name} · {week}주차 강의노트'
    doc = ('<!DOCTYPE html><html lang="ko"><head><meta charset="utf-8">'
           f'<title>{html.escape(title)}</title><style>{CSS}</style></head>'
           f'<body>{cover}{body}</body></html>')

    os.makedirs(OUT, exist_ok=True)
    stem = f'{course_name}-{week:02d}'
    html_path = os.path.join(OUT, stem + '.html')
    pdf_path = os.path.join(OUT, stem + '.pdf')
    open(html_path, 'w', encoding='utf-8').write(doc)

    from playwright.sync_api import sync_playwright
    with sync_playwright() as p:
        b = p.chromium.launch(executable_path=chrome_path())
        pg = b.new_page()
        pg.goto('file://' + quote(html_path), wait_until='networkidle')   # 그림 로드 대기
        pg.pdf(path=pdf_path, format='A4', print_background=True,
               display_header_footer=True, header_template='<div></div>',
               footer_template=FOOTER.format(title=html.escape(title)),
               margin={'top': '14mm', 'bottom': '16mm', 'left': '15mm', 'right': '15mm'})
        b.close()

    pages = len(re.findall(rb'/Type\s*/Page[^s]', open(pdf_path, 'rb').read()))
    dest = None
    if install:
        # ⚠️ 새 파일명은 반드시 NFD로 — 옆의 .md 와 표기가 갈리면 이후 스크립트가 파일을 놓친다
        dest = next((os.path.join(nd, e) for e in os.listdir(nd)
                     if N(e) == f'{week:02d}주차-강의노트.pdf'),
                    os.path.join(nd, ud.normalize('NFD', f'{week:02d}주차-강의노트.pdf')))
        shutil.copy2(pdf_path, dest)
    print(f'{course_name} {week}주차 · {pages}쪽 · {os.path.getsize(pdf_path)/1024/1024:.1f}MB'
          + ('  → 설치' if dest else ''))
    return pdf_path


if __name__ == '__main__':
    install = '--install' in sys.argv
    a = [x for x in sys.argv[1:] if not x.startswith('--')]
    week = int(a[1])
    if a[0] == 'all':
        for e in sorted(os.listdir(ROOT)):
            if N(e).startswith('['):
                build(os.path.join(ROOT, e), week, install)
    else:
        build(find_course(a[0]), week, install)
```

### 3단계: 검증 (생략 금지)

변환은 조용히 틀린다 — **기계 점검 + 표본 육안**을 둘 다 한다.

```bash
# 기계 점검 — 글자로 남은 마크다운 기호 · 중첩 강조 · 빈 쪽
python3 - <<'PY'
import glob, os, re, subprocess
for pdf in sorted(glob.glob(os.path.expanduser('~/Workspace/scu-pdf/*.pdf'))):
    h = open(pdf[:-4] + '.html', encoding='utf-8').read()
    nest = len(re.findall(r'<strong>(?:(?!</strong>).)*?<strong>', h, re.S))
    txt = subprocess.run(['pdftotext', '-layout', pdf, '-'], capture_output=True, text=True).stdout
    pages = txt.split('\f')[:-1]
    blanks = [i + 1 for i, p in enumerate(pages) if len(p.strip()) < 5]
    print(f'{os.path.basename(pdf):28} {len(pages):3}쪽  리터럴** {txt.count("**"):2}  중첩strong {nest}  빈쪽 {blanks or "없음"}')
PY
```

- 리터럴 `**`가 잡히면 내용에 원래 있는 별표인지 본다(`A***` 같은 마스킹 예시는 정상)
- **육안 표본** — 표지 · 그림이 있는 지면 · 큰 표 · 긴 코드블록 · 수식 지면 · 학습평가 · 마지막 쪽. Read 도구에 `pages: "3-6"`처럼 4~6쪽씩 끊어 준다
- 분량이 많으면 노트마다 에이전트를 붙여 병렬로 대조시키고, 지적은 해당 지면을 다시 보는 검증자로 확인한다

### ⚠️ 이 파이프라인에서 실제로 겪은 함정 (2026-09-20 · 노트 15개)

| 함정 | 무슨 일이 났나 | 처방 |
|---|---|---|
| **굵게를 마크다운에서 미리 손대기** | 「`**굵게**` 뒤에 한글이 오면 CommonMark가 못 읽는다」는 것까지는 맞다. 그런데 정규식으로 고치려 하면 **여는/닫는 구분자를 구분하지 못해** 한 줄에 강조가 여럿일 때 짝이 밀린다 — 표에서 「강 인공지능」 대신 「(Strong AI)」가 굵어졌다. 검증 결함 36건이 전부 이 하나에서 나왔다 | **pandoc이 짝을 지은 뒤** HTML에 글자로 남은 `**`만 `<strong>`으로 (`fix_literal_bold`) |
| `#` 앞 구분선 | h1이 `page-break-before`로 새 쪽을 여는데 앞 구분선이 이전 쪽에 남아 **빈 쪽**이 생겼다(3곳) | HTML에서 `<hr>` + `<h1>` 조합 제거 |
| ```latex 블록 | 블록을 통째로 `$$…$$`에 넣으면 **두 식이 한 줄로 붙는다** | 줄마다 독립 `$$` 블록으로 |
| 인라인 코드 `word-break: break-all` | 코드가 **단어 중간에서 잘렸다** | `keep-all` + `overflow-wrap: break-word` |
| 저장 파일명 | 파이썬이 만든 이름은 **NFC**라 옆의 NFD `.md`와 표기가 갈렸다 | 저장 시 `ud.normalize('NFD', …)` |
| 쪽 번호 | 크롬 CLI `--print-to-pdf`는 머리말에 날짜, 꼬리말에 **파일 경로**를 박는다(수정 불가) | Playwright `page.pdf(footer_template=…)` |

> **수식이 많은 노트는 쪽수가 는다** — 딥러닝 3주차가 63 → 83쪽이 됐는데, 이전에는 수식이 깨져 한 줄로 눌려 있던 것이다. 늘어난 것이 정상이다.

---

## DOCX 변환

- Cowork의 `docx` 스킬을 활용
- 마크다운 헤더 → Word 제목 스타일 매핑
- 목차 자동 생성 가능

## PPTX 변환

- Cowork의 `pptx` 스킬을 활용
- 대단원(`#`) → 슬라이드 구분
- 핵심 내용만 추출하여 슬라이드에 배치 — 전체 내용이 아닌 요약 형태

## 저장 위치

- 과목 폴더 `강의노트/`에 `{NN}주차-강의노트.{확장자}`
- 마크다운 원본은 그대로 둔다 — PDF는 읽기용 사본이지 정본이 아니다
