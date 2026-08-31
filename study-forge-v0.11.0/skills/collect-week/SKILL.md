---
name: collect-week
description: >
  SCU 포털에서 해당 주차의 강의교안 PDF와 강의녹음 MP3를 내려받아 과목 폴더에 배치하는 스킬 (v0.1.0).
  사용자가 "N주차 자료 받아줘", "교안 다운로드", "MP3 받아줘", "주차 자료 수집",
  "collect-week" 등을 요청할 때 사용한다.
  전사(transcribe)·목차확정(confirm-toc)의 선행 단계이며, Chrome MCP로 포털을 조작한다.
version: 0.1.0
---

# 주차 자료 수집 스킬 (포털 → 과목 폴더)

강의교안 PDF와 강의녹음 MP3를 포털에서 받아 `강의교안/`·`강의녹음/`에 배치한다.

## 시작 전 필수

1. 워크스페이스 `CLAUDE.md`와 **과목 폴더 `CLAUDE.md`**를 읽는다 (강좌코드·수집 현황이 있다)
2. 같은 종류의 **기존 산출물을 열어 형식을 확인**한다
3. 확인할 수 없는 값은 **비워 두고 채울 방법을 안내**한다 — 그럴듯한 추정값 금지

## ⚠️ 실행 전 반드시 지킬 3가지

1. **참여도 집계** — 교안 다운로드는 참여도 점수에 잡힌다(과목별 9회 기준). **해당 주차분만** 받고 학기 전체를 몰아 받지 않는다. 참여도는 학기 내내 나눠 쌓는 항목이다
2. **저작권 고지 동의** — 교안 다운로드마다 모달이 뜬다. 대신 눌러도 되는지 **세션당 1회 사용자 승인**을 받는다
3. **Chrome 자동 다운로드 차단** — 아래 「Chrome 사전 조건」을 먼저 확인한다. 안 하면 첫 파일만 받아지고 나머지는 **조용히 사라진다**

## Chrome 사전 조건

한 사이트에서 **두 번째 파일부터 Chrome이 차단**한다. 실패가 아니라 **다운로드 시도 자체가 기록되지 않는다** — 파일이 없는데 에러도 없으므로 놓치기 쉽다.

```python
# 사이트 예외 확인
import json, os
p = os.path.expanduser('~/Library/Application Support/Google/Chrome/Default/Preferences')
ex = json.load(open(p)).get('profile', {}).get('content_settings', {}).get('exceptions', {})
print(ex.get('automatic_downloads', {}) or '예외 없음 → 사용자에게 설정 요청 필요')
```

예외가 없으면 사용자에게 요청한다 — **브라우저 설정이므로 대신 바꾸지 않는다**.

> `chrome://settings/content/automaticDownloads` → 허용 목록에 `https://home.iscu.ac.kr` 추가

**다운로드 폴더는 반드시 설정에서 읽는다.** `~/Downloads` 로 가정하지 말 것.

```python
json.load(open(p))['download']['default_directory']
```

## 1단계: 과목 폴더·강좌코드 확인

과목 폴더 `CLAUDE.md`의 「과목 정보」 표에서 **강좌코드**를 읽는다. 없으면 포털 강의동 목록에서 확인한다.

```python
# 강의동 목록에서 과목별 강좌코드 추출
[...document.querySelectorAll('a')]
  .map(a => [a.innerText.trim(), (a.getAttribute('href')||'').match(/targetHome\('(\d+)'/)?.[1]])
  .filter(x => x[1])
```

## 2단계: 교안자료실 진입

강의동 → 과목 강의실 → 교안자료실은 **폼 POST**로만 들어간다. URL 직접 입력은 실패한다.

```javascript
// 1) 강의동 목록으로 이동 후
go.targetHome('{강좌코드}', 'subj');
// 2) 3초 대기 후
fn_tabOpen('/lecture/main/kyoanDataL.scu', '', 'Y', '5282', '8736');
```

세션이 만료되면 SSO 로그인으로 리다이렉트된다. **공동인증서/스마트인증이 필요하므로 대신 로그인할 수 없다** — 사용자에게 요청한다.

## 3단계: 교안 PDF 수집

목록에서 대상 주차 행의 `fn_kyoan` 인자를 추출한다.

```javascript
[...document.querySelectorAll('table tr')].filter(r => r.cells.length >= 5)
  .map(r => {
    const a = r.cells[2].querySelector('a');
    const m = a && (a.getAttribute('href')||'')
      .match(/fn_kyoan\('([^']+)',\s*'([^']+)',\s*'([^']+)'\)/);
    return m ? {week: m[3], file: m[2], path: m[1],
                downloaded: r.cells[3].innerText.trim()} : null;
  }).filter(Boolean)
```

- `downloaded` 가 `예`면 이미 받은 주차다 — 참여도는 이미 집계됐다
- 교안은 **강의 콘텐츠가 `콘텐츠개발중`이어도 미리 열려 있는 경우가 많다**

다운로드는 함수 호출 후 모달의 `확인`을 누른다.

```javascript
fn_kyoan(path, file, week);
setTimeout(() => {
  const b = [...document.querySelectorAll('button')]
    .find(x => x.offsetParent && x.innerText.trim() === '확인');
  if (b) b.click();
}, 600);
```

> **주의** `await`로 클릭까지 기다리면 다운로드 직후 페이지가 새로고침되며 CDP 평가가 끊긴다.
> 위처럼 `setTimeout`으로 던져놓고 즉시 반환한 뒤, 다음 호출 전에 3초 대기한다.

목록에 링크가 있어도 **서버에 파일이 없을 수 있다(404)**. 실패하면 교수 문의 대상으로 보고한다.

## 4단계: MP3 수집 — ZIP 일괄이 정답

**MP3는 해당 주차 수업구성이 공개된 뒤에만 제공된다.** 아이콘이 보여도 파일이 없을 수 있으니 **아이콘 유무로 판단하지 말고** 팝업을 열어 실제 목록을 확인한다.

```javascript
// 대상 주차 행의 MP3 아이콘 (6번째 셀)
rows[weekIndex].cells[5].querySelector('a,button').click();
```

새 탭이 열린다. 그 탭에서 **`MP3 ZIP 전체 다운로드`** 버튼 하나만 누른다.

- 개별 받기는 주차당 7~13회 → Chrome 차단에 걸리고 불필요
- ZIP 파일명 규칙 — `{연도}_{학기}_{콘텐츠코드}_{주차}_mp3.zip`
- 받은 뒤 탭을 닫는다

## 5단계: 파일 배치 (NFD 경로)

```python
import os, re, shutil, unicodedata, zipfile

def rs(parent, name):
    """NFD 안전 하위 경로 해석"""
    t = unicodedata.normalize('NFC', name)
    for e in os.listdir(parent):
        if unicodedata.normalize('NFC', e) == t:
            return os.path.join(parent, e)

# 교안 → 강의교안/
for e in os.listdir(DL):
    if re.match(r'^\[교안\].+_\d+\.pdf$', unicodedata.normalize('NFC', e)):
        shutil.move(os.path.join(DL, e),
                    os.path.join(rs(course, '강의교안'),
                                 unicodedata.normalize('NFD', e)))

# MP3 ZIP → 강의녹음/ 에 풀고 원본 삭제
with zipfile.ZipFile(zip_path) as zf:
    for m in zf.namelist():
        if m.endswith('/'): continue
        base = os.path.basename(m)
        with zf.open(m) as f, open(os.path.join(rs(course, '강의녹음'),
                                   unicodedata.normalize('NFD', base)), 'wb') as o:
            shutil.copyfileobj(f, o)
os.remove(zip_path)
```

- 저장 후 **NFD 경로에 실제로 있는지 검증**하고 NFC 고스트가 생겼으면 정리한다
- 중복 파일(`… (1).pdf`)이 생기면 md5 비교 후 삭제한다

## 6단계: 보고

| 항목 | 보고 내용 |
|---|---|
| 교안 | 받은 주차 번호, 실패분과 사유(404 등) |
| MP3 | 개수·총 재생시간·용량 |
| 참여도 | 이번 수집으로 올라간 다운로드 횟수 |
| 다음 | `confirm-toc` 로 목차 확정 → `transcribe` |

재생시간은 `ffprobe`로 뽑는다 — **`confirm-toc`의 목차 매칭 근거가 되므로 반드시 기록**한다.

```bash
ffprobe -v error -show_entries format=duration -of default=nw=1:nk=1 <파일>
```

## 흔한 오류와 해결

| 증상 | 원인 | 해결 |
|---|---|---|
| 첫 파일만 받아지고 나머지 무응답 | Chrome 자동 다운로드 차단 | 사이트 예외 추가 요청 |
| `fn_kyoan is not defined` | 교안자료실에 폼 POST로 진입하지 않음 | 2단계부터 다시 |
| SSO 로그인 화면으로 이동 | 포털 세션 만료 | 사용자에게 재로그인 요청 |
| 다운로드 폴더에 파일 없음 | 기본 경로가 `~/Downloads`가 아님 | Chrome Preferences에서 확인 |
| MP3 아이콘은 있는데 목록이 빔 | 해당 주차 미공개 | 주차 오픈 후 재시도 |
