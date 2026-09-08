---
name: confirm-toc
description: >
  강의실 플레이어의 학습목차 패널을 읽어 하위 목차명을 확정하고, 영상 길이와 MP3 길이를 대조해
  ##(N) 순번 매칭을 근거 있게 확정하는 스킬 (v0.7.1).
  주경로는 **재생 없는 산술 확정**(항목 강의시간 ↔ MP3 길이 분할)이고, 플레이어는 하위 제목 채록과
  **공식 자막(textTracks) 수확**에 쓴다 — 자막은 전사보다 정확한 본문 정본이다.
  학습평가·학습정리처럼 MP3도 자막도 없는 구역의 내용도 이 단계에서 채록한다.
  사용자가 "목차 확인해줘", "목차 채워줘", "학습목차 확정", "자막 받아줘", "캡션 수집",
  "confirm-toc" 등을 요청하거나, 강의를 수강하며 목차를 알려주겠다고 할 때 사용한다.
  prepare-script의 선행 단계이자, 전사 필요 여부를 결정하므로 transcribe의 선행 단계이기도 하다.
version: 0.7.1
---

# 학습목차 확정 스킬 (추정 금지)

`##(N)` 하위 목차명을 **추측 없이** 확정한다.

## 시작 전 필수

1. 워크스페이스 `CLAUDE.md`와 **과목 폴더 `CLAUDE.md`**를 읽는다
2. 같은 종류의 **기존 산출물을 열어 형식을 확인**한다
3. 확인할 수 없는 값은 **비워 두고 채울 방법을 안내**한다 — 그럴듯한 추정값 금지

## ⛔ 절대 하지 말 것

**1. 전사 내용으로 목차명을 지어내지 말 것**

전사 도입부가 "머신러닝의 개념을 살펴보겠습니다"라고 해서 목차명이 `머신러닝`인 것은 아니다. **그럴듯하지만 틀린 라벨**이 만들어진다(2026-08-31 실제 사고 — 전량 오답).

**2. 다른 과목의 목차 패턴을 이식하지 말 것**

첫 MP3가 어느 항목에 붙는지는 **과목마다 다르다.**

| 과목 | 구조 | MP3 없는 선행 항목 | 순번 공식 |
|---|---|---|---|
| 딥러닝 | 상위 4개 · 인트로 · 학습개요 | 인트로 | — |
| 빅데이터분석실무 | 상위 3개 · 인트로 · 학습개요 · 생각해보기 | 인트로 · 학습개요 (2개) | `순번 = pi − 1` |
| 문제해결프로그래밍입문 | **상위 1개**(수업 개요)에 8항목 평면 · **인트로 없음** | (실습·URL 항목이 중간에 섞임) | 공식 불가 |
| AWS클라우드실습프로젝트 | 상위 5개 (4·1·1·2·1) | 인트로 (1개) | `순번 = pi` |
| GitHub포트폴리오 | 상위 6개 (4·2·3·2·3) | 인트로 (1개) | `순번 = pi` |

**다섯 과목이 전부 다르다.** 어느 패턴도 다음 과목에 그대로 통하지 않으므로 **항상 길이로 확인한다.**

⚠️ **오프셋은 MP3 없는 선행 항목 수로 결정된다.** 빅데이터는 인트로·학습개요 2개가 빠져 `pi − 1`, AWS·GitHub는 인트로만 빠져 `pi`다. 같은 교수(이성만)의 AWS·GitHub만 일치했다.

⚠️ **파일명 사전순이 목차순이 아닐 수 있다.** 문제해결프로그래밍입문은 `_t_01_01`·`_t_01-02`·`_t_01-03`을 쓰는데 `_`(0x5F)가 `-`(0x2D)보다 뒤로 정렬되어 **사전순이면 첫 번째가 마지막에 온다.** 파일명 순서를 믿지 말고 길이로만 배정한다.

⚠️ **영상 없는 항목이 중간에 끼면 `pageindex − k` 오프셋 공식이 깨진다.** 문제해결은 실습·외부링크 항목이 영상 항목 사이에 섞여 있다.

## ⚠️ 재생과 진도 — 4분 경계의 비대칭

목차 확인을 위해 항목을 여는 것이 **완료 처리로 이어질 수 있다.** 규칙이 항목 길이에 따라 갈린다.

| 완료조건 | 의미 | 목차 확인 목적으로 열면 |
|---|---|---|
| `열람하면 완료가 됩니다` | 대개 4분 이하 · 웹페이지·실습 항목 | 열는 순간 **완료된다** |
| `강의시간의 50% 이상 수강해야 합니다` | 본강의 항목 | 열고 즉시 정지하면 **완료되지 않는다**(수 초는 무해) |

**0단계에서 완료조건이 문자열로 노출되면 그것을 쓴다** — 4분 경계는 경험칙이고, 노출된 완료조건이 정확한 값이다.

- 그래서 **긴 본강의 항목은 열어서 길이만 읽고 정지해도 안전**하다
- 반대로 `인트로`·`학습개요`처럼 짧은 항목은 **열면 완료된다** — 사용자에게 미리 알리고 동의를 받는다
- 수강은 사용자 본인의 행위다. **사용자가 지시하지 않았다면 열지 않는다.** 지시했다면 무엇이 완료되는지 알린 뒤 진행하고, 사후에도 무엇이 완료로 바뀌었는지 보고한다
- ⛔ **영상이 끝나면 자동으로 다음으로 넘어간다.** 확인만 하려면 읽은 직후 정지시킨다

```javascript
// 모든 iframe을 재귀 순회해 정지
(function dig(d){ try {
  d.querySelectorAll('video,audio').forEach(v => { v.pause(); v.autoplay = false; });
  d.querySelectorAll('iframe').forEach(f => { if (f.contentDocument) dig(f.contentDocument); });
} catch(e) {} })(document);
```

## 목차 구조 — 2단이다

| 단계 | 위치 | 예 |
|---|---|---|
| **상위 목차** `#` | 강의실 **주차 목록에 바로 보임** | `들어가기` · `수업 계획` · `딥러닝 소개` · `실습환경 소개` · `평가하기` · `정리하기` |
| **하위 목차** `##(N)` | 상위 항목 **안으로 들어가야 나옴** | `들어가기` → `인트로`, `학습개요` |

- **MP3 1개 = 동영상 1개 = `##(N)` 1개**
- 상위 항목 수와 MP3 수는 **일치하지 않는다** (딥러닝 1주차: 상위 4개 vs MP3 7개)
- 하위 목차는 **앞 영상을 끝까지 봐야 다음 상위 항목이 열리는 순차 잠금** 구조다.
  배속도 통하지 않는다(출석이 실시간 기준) → **목차 수집 속도 = 상위 항목 도달 시간**(하위 전량 재생은 불필요 — 상위 진입 시 하위 이름이 전부 나온다).
  한 세션에 다 모으려 하지 말고 사용자 진도에 맞춰 나눠 받는다

## 0단계: ⭐ 주차 목록에서 강의시간을 먼저 읽는다 — 재생이 불필요할 수 있다

**이것부터 한다.** 과목에 따라 주차 목록의 각 항목이 **「학습시간/강의시간」과 「완료조건」을 그대로 노출**한다. 노출되면 **플레이어를 한 번도 열지 않고** 목차를 확정할 수 있다.

```javascript
(() => {
  const hdr = [...document.querySelectorAll('.accordion-header')].find(e => e.querySelector('.week-circle')?.textContent.trim() === '1주차');
  (hdr.querySelector('button,a,[role=button]') || hdr).click();               // 펼치기
  const secs = [...hdr.closest('.accordion-item').querySelectorAll('section.item')];
  // ⚠️ section.item은 미검증 경로다 — 0건이면 0-B단계의 innerText 줄 파싱을 쓸 것
  return JSON.stringify(secs.map((s, i) => {
    const t = s.innerText.replace(/\s+/g, ' ').trim();
    const m = t.match(/(\d+)분(\d+)초\s*\/\s*(\d+)분(\d+)초/);               // 학습시간/강의시간
    return { i: i + 1,
      제목: t.split(/\s*(완료|To do)\s*/)[0].slice(0, 40),
      상태: /(^|\s)완료(\s|$)/.test(t.slice(0, 80)) ? '완료' : 'To do',
      학습초: m ? +m[1] * 60 + +m[2] : null,
      강의초: m ? +m[3] * 60 + +m[4] : null,
      완료조건: (t.match(/\[완료조건\]\s*•?\s*([^\[]{0,60})/) || [])[1]?.trim() };
  }), null, 1);
})()
```

**`강의초`가 나오면 그것이 영상 길이다.** MP3 길이와 대조해 그 자리에서 확정한다.

| 얻는 것 | 값어치 |
|---|---|
| 항목별 **강의시간** | 재생 없이 MP3 매칭 확정 |
| 항목별 **완료조건** | `열람하면 완료` vs `강의시간의 50% 이상` — 경계를 추측하지 않고 **명시값으로** 안다 |
| 항목별 **학습시간** | 이미 얼마나 봤는지 (진도 현황) |
| **영상 없는 항목** | `강의초`가 `null`이면 웹페이지·실습·외부링크 항목 — MP3도 없다 |

> 실측: 문제해결프로그래밍입문 1주차는 이 방법만으로 MP3 3개를 전부 확정했다(2026-09-01).
> 같은 정보를 빅데이터분석실무에서는 플레이어를 45분간 지켜보며 얻었다.

### ⚠️ 노출 방식 — 과거 3분류는 폐기됐다

**2026-09-08 실측: 2주차 기준 5과목 전부 인라인 노출이다.** 1주차의 3분류(인라인 / 툴팁 / 미노출)를 믿고 곧장 플레이어 경로로 가지 말 것.

| 과목 | 1주차 관측 | **2주차 실측** |
|---|---|---|
| 문제해결프로그래밍입문 | 인라인 | ✅ 인라인 |
| AWS클라우드실습프로젝트 | 툴팁 | ✅ **인라인** |
| GitHub포트폴리오 | 툴팁 | ✅ **인라인** |
| 딥러닝 | 미노출 | ✅ **인라인** — `• 0분0초/34분6초` |
| 빅데이터분석실무 | 미노출 | ✅ **인라인** |

⚠️ **수확 결과가 0건이면 「미노출 과목」으로 단정하지 말고 셀렉터를 먼저 의심한다.** 아코디언이 접혀 있거나 셀렉터가 안 맞으면 빈 배열이 조용히 반환되어 미노출과 구분되지 않는다.

### ⚠️ 상위 항목의 강의시간 = 하위 영상 길이를 **각각 내림한 뒤** 합산한 값

상위 항목이 여러 영상을 품으면 그 「강의시간」은 합계다. **단일 MP3와 대조하면 안 된다.**

⚠️ **합계 후 내림도, 각 항 반올림도 아니다 — 항별 내림 → 합산이다.** 딥러닝 2주차 실측: 손실 함수 표기 1031 = 245+384+402(원값 245.43·384.40·402.69). 각항 반올림이면 1032, 합계후내림도 1032로 어긋난다. 5과목 민감도 검사에서 **floor일 때만 전 과목 해가 존재**했고 round·ceil은 전 과목 해가 없었다. 자세한 절차는 아래 0-B단계.

```
AWS 「들어가기」 1890초 = 인트로 17 + 강의소개 1519 + 학습개요 64 + 학습에 앞서 290
```

어떤 MP3와도 안 맞는 큰 값이 나오면 "MP3 없음"으로 단정하지 말고 **합계 분해를 의심**한다.

⚠️ **목차 확정 ≠ 수강 완료.** 0단계로 목차를 확정해도 **출석은 실제 열람이 필요하다.** 사용자가 수강을 원하면 목차가 이미 확정됐더라도 항목을 순서대로 열어야 한다.

## 0-B단계: ⭐ 재생 없이 그룹 경계를 확정하는 산술 절차

0단계에서 얻은 **항목별 강의시간 배열**과 `ffprobe`로 잰 **MP3 길이 배열**만 있으면, 플레이어를 한 번도 열지 않고 **어느 MP3가 어느 상위 항목에 속하는지**를 산술로 확정할 수 있다.

> 실측: 2026-09-08 딥러닝·빅데이터분석실무·문제해결프로그래밍입문·AWS·GitHub **2주차 5과목 전수**에서 이 절차만으로 그룹 경계가 **전부 유일하게 결정**됐다.

### ⭐ 확정되는 것과 확정되지 않는 것 — 경계를 흐리지 말 것

| | 산술로 | 근거 |
|---|---|---|
| 어느 MP3가 어느 **상위 항목**에 속하는가 (그룹 경계) | ✅ **확정** | 유일해 |
| 한 그룹 안에서 MP3의 **순서** | ✅ 확정 | 순서보존 배정이므로 파일 순번 그대로 |
| 그룹별 **비MP3 구간의 총량**(잔여) | 🔸 **명목값 추정** | 관측값 아님 — 아래 경고 |
| 하위 목차 **개별 제목** | ⛔ **불가** | 플레이어를 열어야 나온다 → 1~2단계 |
| 어느 하위 항목이 인트로/학습개요인가 | ⛔ 불가 | 잔여의 내역은 분해되지 않는다 |

⛔ **산술은 이름을 만들어 주지 않는다.** 그룹이 확정됐다고 해서 목차명을 채워 넣지 말 것 — 그것은 이 스킬이 금지하는 「추정으로 지어내기」와 같다.

### ⚠️ 0단계 노출 분류 갱신 — 2주차 기준 5과목 전부 인라인이다

앞의 3분류(인라인 / 툴팁 / 미노출)는 **1주차 관측이고 이미 낡았다.**

| | 1주차 관측 | **2주차 실측(2026-09-08)** |
|---|---|---|
| 딥러닝 | 미노출 | ✅ **인라인** — `• 0분0초/34분6초` |
| 빅데이터분석실무 | 미노출 | ✅ **인라인** |
| 문제해결프로그래밍입문 | 인라인 | ✅ 인라인 |
| AWS클라우드실습프로젝트 | 툴팁 | ✅ 인라인 |
| GitHub포트폴리오 | 툴팁 | ✅ 인라인 |

→ **먼저 인라인을 확인한다.** "이 과목은 미노출"이라는 과거 분류를 믿고 곧장 플레이어 경로로 가지 말 것.

### 동작이 확인된 DOM 접근 — `innerText` 줄 파싱

0단계의 `section.item` 셀렉터는 **이번 페이지 구조에서 존재 여부가 미확인**이다. 아래 `innerText` 파싱은 5과목에서 실제로 동작했다.

```javascript
(() => {
  const N = '2주차';
  const item = [...document.querySelectorAll('.accordion-item')]
    .find(e => e.querySelector('.week-circle')?.textContent.trim() === N);
  if (!item) return 'no such week';
  const head = item.querySelector('.accordion-header');                 // 주차명·출석인정기간·예상학습시간
  const body = [...item.children].find(c => c !== head);                // = DIV.accordion-content
  const L = body.innerText.split('\n').map(s => s.trim()).filter(Boolean);

  const out = []; let cur = null;
  for (const s of L) {
    if (/^(To do|완료)$/.test(s)) { cur.상태 = s; continue; }
    if (/^\[학습시간\/강의시간\]/.test(s)) { cur._t = 1; continue; }
    if (/^\[완료조건\]/.test(s)) { cur._c = 1; continue; }
    const m = s.match(/^•\s*(\d+)분(\d+)초\s*\/\s*(\d+)분(\d+)초/);
    if (m && cur?._t) { cur.학습초 = +m[1]*60 + +m[2]; cur.강의초 = +m[3]*60 + +m[4]; cur._t = 0; continue; }
    if (/^•/.test(s) && cur?._c) { cur.완료조건 = s.replace(/^•\s*/, ''); cur._c = 0; continue; }
    cur = { 제목: s, 강의초: null }; out.push(cur);                      // 그 외 = 새 항목 제목
  }
  out.forEach(o => { delete o._t; delete o._c; });
  return JSON.stringify(out, null, 1);
})()
```

- `강의초`가 `null`인 항목 = 영상 없음(URL·실습·게시판) → 아래 입력에 **0**으로 넣는다
- 아코디언이 접혀 있으면 `.accordion-content`가 비어 나온다 → 먼저 펼친다. **⚠️ 펼치기는 아래 G 경고를 읽고 할 것**

### C. 상위 항목 강의시간 = 하위 영상 길이를 **각각 내림한 뒤** 합산한 값

합계 후 내림도, 각 항 반올림도 아니다. **항별 내림 → 합산**이다.

| 실측 근거 (딥러닝 2주차) | 표기값 | 항별 floor 합 | 항별 round 합 | 합계후 floor |
|---|---:|---:|---:|---:|
| 손실 함수 표기 = 245.43 + 384.40 + 402.69 | **1031** | **1031** ✅ | 1032 ✗ | 1032 ✗ |
| 수치 예측 실습 = 332.26 + 1827.96 | **2159** | **2159** ✅ | 2160 ✗ | 2160 ✗ |

- 5과목 전수 민감도 검사: **floor일 때만 5과목 모두 해가 존재**했고, `round`·`ceil`은 5과목 전부 해가 없었다
- 그래도 방식을 코드에 박지 않는다 — 아래 절차는 **매번 세 방식을 다 돌려 데이터로 판별**한다

### D. 산술 절차 — 순서보존 연속 블록 배정

MP3 배열을 **순서를 지킨 연속 블록**으로 잘라 항목에 하나씩 배정한다. 제약은 셋이다.

| 제약 | 식 | 의미 |
|---|---|---|
| ① 블록합 상한 | `블록합 ≤ 항목 강의시간` | 항목 시간이 하위 영상 합보다 작을 수 없다 |
| ② 잔여 비음수 | `잔여 = 항목시간 − 블록합 ≥ 0` | 잔여 = 그 항목의 비MP3 구간(인트로·학습개요 등) |
| ③ 잔여 총합 항등 | `Σ잔여 = Σ항목시간 − Σ내림(MP3)` | 탐색을 좁히는 **핵심 가지치기** — 누적 잔여가 이 값을 넘으면 즉시 배제 |

- 블록은 **비어 있어도 된다**(영상 없는 항목) — 강의시간 0이면 자동으로 빈 블록이 된다
- 파일명은 **사전순이 아니라 순번 수치 오름차순**으로 정렬해 넣는다 (`_t_01_01` vs `_t_01-02` 함정)

```python
#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""그룹 경계 확정 — 상위 항목 강의시간 + MP3 실측 길이만으로, 재생 없이

입력
  ITEMS : 강의실홈 아코디언 항목의 「강의시간」 표기값(초, 정수) · 목차 순서 그대로
          영상 없는 항목(URL·실습·게시판·슬라이드)은 0
  MP3S  : ffprobe 실측 길이(초, 소수) · 파일명 순번의 **수치 오름차순**(사전순 금지)
출력
  ① floor/round/ceil 민감도 검사 ② 경계 유일성 ③ 배정표(잔여 포함)
"""
import math, re, subprocess, glob
from unicodedata import east_asian_width as _eaw

QUANT = {
    'floor': math.floor,
    'round': lambda x: math.floor(x + 0.5),   # 파이썬 기본 round는 은행가 반올림이라 쓰지 않는다
    'ceil':  math.ceil,
}


def _w(s):
    return sum(2 if _eaw(c) in 'WF' else 1 for c in str(s))


def _pad(s, n, right=False):
    p = ' ' * max(0, n - _w(s))
    return p + str(s) if right else str(s) + p


def search(items, mp3q, max_residual=None):
    """MP3를 순서보존 연속 블록으로 항목에 배정 · 모든 해를 반환

    제약 ① 블록합 <= 항목 강의시간          (잔여 = 항목시간 − 블록합 >= 0)
         ② 잔여 총합 == 항목시간합 − MP3합  (항등식이자 가지치기 상한)
    """
    n, m = len(items), len(mp3q)
    R = sum(items) - sum(mp3q)                      # 잔여 총합 = 비MP3 구간의 명목 합
    if R < 0:
        return [], R
    suf_i, suf_m = [0] * (n + 1), [0] * (m + 1)
    for i in range(n - 1, -1, -1):
        suf_i[i] = suf_i[i + 1] + items[i]
    for j in range(m - 1, -1, -1):
        suf_m[j] = suf_m[j + 1] + mp3q[j]

    sols = []

    def dfs(i, j, used, cuts):
        if i == n:
            if j == m:
                sols.append(tuple(cuts))
            return
        if suf_i[i] < suf_m[j]:                     # 남은 항목시간 < 남은 MP3합 → 불가
            return
        s, k = 0, j
        while True:
            res = items[i] - s
            if res < 0:
                break
            if used + res <= R and (max_residual is None or res <= max_residual):
                dfs(i + 1, k, used + res, cuts + [(j, k)])
            if k == m:
                break
            s += mp3q[k]
            k += 1

    dfs(0, 0, 0, [])
    return sols, R


def report(items, mp3s, labels=None, files=None, max_residual=None):
    labels = labels or ['항목%d' % (i + 1) for i in range(len(items))]
    files = files or ['_%02d' % (j + 1) for j in range(len(mp3s))]
    print('항목 %d개 · MP3 %d개 · 항목시간 합 %d초\n' % (len(items), len(mp3s), sum(items)))

    print('[1] 반올림 민감도 검사')
    res = {}
    for mode, f in QUANT.items():
        q = [f(x) for x in mp3s]
        sols, R = search(items, q, max_residual)
        res[mode] = (sols, q, R)
        tag = '해 없음' if not sols else ('유일해' if len(sols) == 1 else '해 %d개' % len(sols))
        print('  %-6s MP3합 %6d   잔여총합 %6d   → %s' % (mode, sum(q), R, tag))

    win = [m for m in QUANT if res[m][0]]
    print()
    if not win:
        print('⛔ 어느 방식으로도 해가 없다 — 입력을 의심하라')
        print('   · 영상 없는 항목(URL·실습·게시판)을 0으로 넣었는가')
        print('   · 주차 MP3를 빠짐없이 넣었는가')
        print('   · 항목이 목차 순서인가 / MP3가 순번 **수치** 오름차순인가 (사전순 금지)')
        return None

    print('[2] 판정')
    print('   · 반올림 방식 : %s' % ('%s 확정' % win[0] if len(win) == 1
                                     else '%s 공존 → **미판별**' % '/'.join(win)))
    common = set(res[win[0]][0])
    for m in win[1:]:
        common &= set(res[m][0])
    if len(common) == 1:
        print('   · 그룹 경계  : ✅ **유일 — 확정**' + ('' if len(win) == 1 else ' (방식이 갈려도 배정은 같다)'))
    elif not common:
        print('   · 그룹 경계  : ⛔ 방식별 배정이 서로 다르다 — 확정 불가')
        return None
    else:
        inv = set.intersection(*[set(c) for c in common])
        print('   · 그룹 경계  : ⚠️ 해 %d개 — 미확정' % len(common))
        print('     모든 해가 공유하는 경계만 확정된다: %s'
              % (sorted(inv) if inv else '없음'))
    sol = sorted(common)[0]
    q = res[win[0]][1]

    print('\n[3] 배정표' + ('' if len(common) == 1 else
          ' — ⚠️ 해 %d개 중 1개일 뿐이다. 이대로 확정 기록하지 말 것' % len(common)))
    print('  %s%s%s%s%s' % (_pad('상위 항목', 24), _pad('강의시간', 10, 1),
                            _pad('MP3', 24, 1), _pad('블록합', 10, 1), _pad('잔여', 8, 1)))
    for (a, b), lab, it in zip(sol, labels, items):
        blk = ' '.join(files[a:b]) or '—'
        bs = sum(q[a:b])
        print('  %s%s%s%s%s' % (_pad(lab, 24), _pad(it, 10, 1),
                                _pad(blk, 24, 1), _pad(bs, 10, 1), _pad(it - bs, 8, 1)))
    print('\n  잔여 총합 %d초 = 비MP3 구간(인트로·학습개요·슬라이드 등)의 **명목값 합**'
          % res[win[0]][2])
    print('  ⚠️ 관측값이 아니다 — 개별 인트로 길이로 승격해 적지 말 것')
    return win, sol


def probe(pattern):
    """MP3 길이 수확 — 파일명의 숫자열을 **수치**로 정렬(사전순 금지)"""
    rows = []
    for p in glob.glob(pattern):
        d = subprocess.run(['ffprobe', '-v', 'error', '-show_entries', 'format=duration',
                            '-of', 'default=nw=1:nk=1', p], capture_output=True, text=True).stdout
        name = p.rsplit('/', 1)[-1]
        rows.append(([int(x) for x in re.findall(r'\d+', name)], name, float(d)))
    rows.sort()
    return [r[1] for r in rows], [r[2] for r in rows]


if __name__ == '__main__':
    # 실측 — 딥러닝 2주차 (2026-09-08)
    #   강의시간 = 강의실홈 아코디언 **표기값** · MP3 = ffprobe **실측값**
    ITEMS  = [1031, 2159]
    LABELS = ['손실 함수 표기', '수치 예측 실습']
    MP3S   = [245.43, 384.40, 402.69, 332.26, 1827.96]
    FILES  = ['_01', '_02', '_03', '_04', '_05']
    report(ITEMS, MP3S, LABELS, FILES)
    # 실사용: FILES, MP3S = probe('강의녹음/*_2_*.mp3')
```

위 예제를 그대로 실행하면 나오는 출력이다. 딥러닝 2주차 실측을 재현한다.

```
[1] 반올림 민감도 검사
  floor  MP3합   3190   잔여총합      0   → 유일해
  round  MP3합   3192   잔여총합     -2   → 해 없음
  ceil   MP3합   3195   잔여총합     -5   → 해 없음

[2] 판정
   · 반올림 방식 : floor 확정
   · 그룹 경계  : ✅ **유일 — 확정**

[3] 배정표
  상위 항목                 강의시간                     MP3    블록합    잔여
  손실 함수 표기                1031             _01 _02 _03      1031       0
  수치 예측 실습                2159                 _04 _05      2159       0
```

### 실행 결과 판독

| 출력 | 뜻 | 다음 행동 |
|---|---|---|
| 한 방식만 유일해 | 방식·경계 모두 확정 | 그대로 기록. `←` 주석에 근거 남긴다 |
| 여러 방식이 **같은 배정** | 방식은 미판별이지만 **경계는 확정** | 경계만 기록. "반올림 방식 미판별"이라 적는다 |
| 여러 방식이 **다른 배정** | ⛔ 확정 불가 | 산술로 끝내지 말고 플레이어 경로(1~2단계)로 |
| 해가 여러 개 | 경계 미확정 | **공통 경계만** 확정 기록, 나머지는 빈칸 |
| 해 없음 | 입력 오류 | 영상 없는 항목 0 처리 · MP3 누락 · 정렬 순서를 점검 |

⛔ **해가 여러 개일 때 출력된 배정표는 그중 하나일 뿐이다.** 그대로 스크립트에 옮기면 「그럴듯하지만 틀린 라벨」과 같은 사고가 난다.

### ⚠️ 잔여를 관측값으로 승격하지 말 것

잔여는 **포털이 집계에 쓰는 명목값의 차**이지 어떤 파일의 실제 길이가 아니다.

- 현행 문서는 인트로를 「공용 랜덤 타이틀 클립 **18~22초**」로 적었지만, 2026-09-08 실측 로드는 **13.11초**였다 — 문서 범위 밖이다
- `doRandomIntroMedia.scu`는 **랜덤이라 로드마다 다르다.** 인트로 길이는 관측값으로 못 쓴다
- 따라서 `잔여 = 항목시간 − 하위 MP3 합`은 **추정치로만** 적는다 — `인트로 13초` ✗ / `비MP3 구간 명목 13초(추정)` ✅

### ⚠️ 수치를 적을 땐 **출처를 함께 적는다**

세 가지 수치가 뒤섞이며, 서로 다른 출처다. 구분하지 않으면 잘못된 반박이 성립한다.

| 표기 | 출처 | 성격 |
|---|---|---|
| **강의시간** | 강의실홈 목록 **표기값** | 항별 내림의 합 (정수) |
| **영상 N초** | 플레이어 `video.duration` | 실측 소수 |
| **MP3 N초** | `ffprobe` | 실측 소수 |
| **자막 endTime** | 마지막 cue의 `endTime` | 실측 소수 · `video.duration`에 근사 |

> 실제 사고: 1주차 스크립트의 「영상 N초」(= `video.duration`)와 0단계의 「강의시간」(= 목록 표기값)을 같은 것으로 보고 **"1주차는 반올림이었다"는 반박**이 성립했다. 서로 다른 출처를 비교한 것이 원인이다. 산출물에는 항상 출처를 병기한다.

### 그 다음 — 이름 채록은 **상위 항목 도달까지**면 된다

그룹 경계가 확정되면 남은 것은 하위 제목뿐이고, 여기엔 결정적인 지름길이 있다.

- ⭐ **상위 항목에 진입하는 순간 그 항목의 하위 목차 이름이 패널에 전부 나타난다.** 아직 재생하지 않은 하위 항목의 이름도 보인다
- 실측: `경사 하강법` 진입 시점에 `pi4 경사 하강법`과 `pi5 모델 학습`이 **동시에** 노출됐다
- → 이름 채록에 필요한 것은 **상위 항목 도달까지**다. 하위를 전부 재생할 필요가 없다
- 플레이어는 **페이지 내 iframe 오버레이**라 최상위 `document.querySelector('video')`로는 못 찾는다 — **iframe 재귀 순회 필수**(2단계 스니펫 사용)

#### ⛔ 좌표 클릭으로 아코디언을 펼치지 말 것 — 재생이 시작된다

2026-09-08 실제 사고다. 아코디언 헤더를 펼치려고 좌표 클릭했더니 **항목 플레이어가 열렸고**, 열리자마자 인트로가 재생되고 끝나면서 **다음 항목으로 자동 전환·자동 재생**됐다.

- 아코디언 펼치기와 항목 열기는 **좌표상 가깝다**
- 펼치기는 좌표가 아니라 **요소를 특정해서** 누른다 — `.accordion-header`의 버튼을 프로그래밍 `.click()`으로 (펼치기는 프로그래밍 클릭이 통한다)
- 그래도 열릴 위험이 있으면 **정지 안전장치를 먼저 걸어둔다**(위 「재생과 진도」의 재귀 정지 스니펫)
- 사후에 **무엇이 완료 처리됐는지 반드시 보고**한다

#### 장시간 수강 중 전환을 놓치지 않는 로거

5분 틱만으로는 짧은 항목이 틱 사이를 지나간다. 페이지에 로거를 심어두면 **10분 간격으로 수확해도 그 사이 전환이 전부 남는다.**

```javascript
window.__scuLog = [];
window.__scuRead = () => {                                   // iframe 재귀 순회
  const docs = []; (function c(d){ docs.push(d);
    [...d.querySelectorAll('iframe')].forEach(f => { try { if (f.contentDocument) c(f.contentDocument); } catch(e){} });
  })(document);
  const td = docs.find(d => d.querySelector('.toc-row'));
  const rows = td ? [...td.querySelectorAll('.toc-row')].map(e => ({
    pi: e.dataset.pageindex, sel: /selected/.test(e.className),
    t: e.innerText.replace(/\s+/g, ' ').trim() })) : [];
  let v = null;
  for (const d of docs) { const x = d.querySelector('video');
    if (x) { v = { f: (x.currentSrc || '').split('/').pop(), dur: x.duration,
                   cur: x.currentTime, paused: x.paused }; break; } }
  return { ts: new Date().toISOString().slice(11, 19), rows, v };
};
window.__scuTick = setInterval(() => {                       // 2초 간격, 변화만 적재
  const s = window.__scuRead();
  const cap = window.__scuCapture ? window.__scuCapture() : { len: 0 };   // 글자수까지 키에 넣는다
  const key = (s.rows.find(r => r.sel)?.t || '') + '|' + (s.v?.f || '') + '|' + cap.len;
  if (key !== window.__scuKey) { window.__scuKey = key; window.__scuLog.push(s); }
}, 2000);
// 수확: JSON.stringify(window.__scuLog)   /   종료: clearInterval(window.__scuTick)
```

- 로거는 **읽기만 한다.** 재생·일시정지·시크를 넣지 말 것
- 세션·페이지 이동으로 사라진다 → 수확은 미루지 말고 10분 안팎으로 끊어서 한다
- 3단계 크론과 병행하면 **크론은 수확만**, 전환 감지는 로거가 맡는다

## 1단계: 상위 목차 읽기 (재생 없음)

주차 아코디언을 펼치면 상위 항목이 보인다. 여기까지는 재생이 아니므로 안전하다.

```javascript
const hdr = [...document.querySelectorAll('.accordion-header')]
  .find(e => /{주차명}/.test(e.innerText));
hdr.querySelector('button,a,[role="button"]')?.click();   // 펼치기는 프로그래밍 클릭으로 됨
hdr.closest('.accordion-item').innerText
  .replace(/\s*To do\s*/g, ' ▸').replace(/\s+/g, ' ').trim()
// → "빅데이터의 이해 1주차 … 들어가기 ▸빅데이터 개요 및 활용 ▸빅데이터 기술 및 제도 ▸평가하기 ▸정리하기 ▸"
```

각 상위 항목의 완료 상태(`완료` / `To do`)도 같이 읽는다. 아코디언에는 **상위 항목만** 있고 하위 데이터는 없다 — `.tit.popup-btn`이 플레이어를 여는 버튼이다.

## 2단계: 플레이어 열기 — 반드시 실제 마우스 클릭

### ⚠️ 프로그래밍 방식 `.click()`은 통하지 않는다

`.tit.popup-btn`에는 인라인 `onclick`이 없고(jQuery 위임) 플레이어를 **사용자 제스처 기반으로** 띄운다. 스크립트 클릭은 **조용히 무시된다** — 에러도 없이 아무 일도 일어나지 않는다. 교안 다운로드가 Chrome에 막히던 것과 같은 계통이다.

**`computer` 도구의 실제 마우스 클릭을 쓴다.**

```
screenshot → 좌표 확인 → 즉시 left_click(coordinate)
```

### ⚠️ 좌표는 금방 무효해진다 — 스크린샷 직후에 클릭할 것

**모달을 닫으면 페이지가 다시 스크롤된다.** 직전 스크린샷 좌표로 클릭하면 엉뚱한 행을 눌러 순차 잠금 모달이 뜬다(실제로 3회 발생).

- 모달을 닫았으면 **반드시 다시 스크린샷**을 찍고 좌표를 재확인한다
- 모달이 없는 안정 상태에서 스크린샷 → 바로 클릭이 가장 확실하다
- `find`로 얻은 `ref` 클릭은 행에 포커스만 가고 **플레이어가 열리지 않을 수 있다** — 클릭 대상이 행이 아니라 `.tit.popup-btn`이기 때문. 좌표 클릭이 확실하다

### ⚠️ 플레이어는 팝업이 아니라 페이지 내 iframe 오버레이다

새 탭도 새 창도 열리지 않는다. 그래서 이런 탐지는 **전부 실패한다.**

```text
document.querySelector('video')          ✗ null — 최상위에 없다
window.open 감시                          ✗ 팝업이 아니다
tabs_context 로 새 탭 확인                 ✗ 탭이 안 늘어난다
```
(위는 실행 코드가 아니라 **실패한 접근 목록**이다)

**항상 iframe을 재귀 순회한다.** 인덱스(`iframes[4]`)를 박아두지 말 것 — 항목마다 바뀐다.

```javascript
(() => {
  const docs = [];
  (function collect(d) { docs.push(d);
    [...d.querySelectorAll('iframe')].forEach(f => {
      try { if (f.contentDocument) collect(f.contentDocument); } catch(e) {} });
  })(document);

  const td = docs.find(d => d.querySelector('.toc-row'));
  const rows = td ? [...td.querySelectorAll('.toc-row')].map(e => ({
    t:  e.innerText.replace(/\s+/g,' ').trim(),
    ty: e.dataset.typecd,        // MODULE = 상위, PAGE = 하위
    mi: e.dataset.moduleindex,   // 상위 목차 번호 (0부터)
    pi: e.dataset.pageindex,     // ⭐ 주차 전체 통산 페이지 번호
    sel: /selected/.test(e.className)
  })) : [];

  let v = null;
  for (const d of docs) { const x = d.querySelector('video');
    if (x) { v = { dur: Math.round(x.duration), cur: Math.round(x.currentTime),
                   paused: x.paused, src: x.currentSrc }; break; } }
  return JSON.stringify({ rows, v }, null, 1);
})()
```

### 상위/하위는 텍스트로 추측하지 말고 속성으로 판정한다

`.toc-row`에 구조가 박혀 있다.

| 속성 | 의미 |
|---|---|
| `data-typecd` | `MODULE` = 상위 목차 · `PAGE` = 하위 목차 |
| `data-moduleindex` | 상위 목차 번호 (0부터) |
| `data-pageindex` | **주차 전체 통산** 하위 페이지 번호 (0부터) |
| `data-tocid` | LCMS 내부 식별자 |

### ⭐ `data-pageindex`로 MP3 순번을 예측한다

`pageindex`는 모듈별로 리셋되지 않고 **주차 전체를 통산**한다.

```
모듈0 들어가기       인트로 pi=0 · 학습개요 pi=1 · 생각해보기 pi=2
모듈1 개요 및 활용   데이터와 정보 pi=3 · 데이터베이스 pi=4 · 빅데이터 개요 pi=5 · 데이터 산업과 조직 pi=6
```

MP3 없는 선행 항목이 k개면 **MP3 순번 N = pi − k + 1**이다. 위 예에서 `인트로`·`학습개요`가 MP3 없으므로 k=2 → **N = pi − 1** (생각해보기 pi=2 → `_01`, 데이터와 정보 pi=3 → `_02`, 둘 다 길이로 확인됨).

**이것은 예측이지 확정이 아니다.** 중간에 슬라이드 페이지가 또 끼면 오프셋이 깨진다. 반드시 3단계 길이 대조로 검증한다. 다만 이 예측이 있으면 **어느 MP3를 대조할지 바로 알 수 있어** 확인이 빨라진다.

### 목차 패널은 현재 모듈만 렌더한다

다른 상위 목차의 하위 항목은 패널에 **없다** — 그 항목을 따로 열어야 나온다. 여는 수단은 **플레이어 우하단 `‹` `›` 화살표**다(패널에는 다른 상위 항목 링크 자체가 없다).
**단 같은 모듈 안에서는 아직 재생하지 않은 하위 항목의 이름까지 전부 보인다** — 이름만 필요하면 모듈에 도달하는 것으로 충분하다. 플레이어 전역에 전체 매니페스트 객체도 없다(탐색해 확인).

### 부산물 — MP4 주소

`video.currentSrc`가 평문 MP4이고 **파일명이 MP3와 동일 체계**다. 목차 확인하면서 같이 모아 스크립트에 적어둔다.

```
https://mp4.iscu.ac.kr/iscu/Contents/{과목코드}/{강좌}/{미디어id}/{과목코드}_{주차}_{순번}.mp4
```

⚠️ **`{미디어id}`는 순번이 아니라 상위 목차(모듈) 단위로 바뀐다.** 한 모듈의 여러 항목이 같은 디렉터리를 공유한다.

```
2178063 → 모듈0 (들어가기)          : _01
2178064 → 모듈1 (빅데이터 개요 및 활용) : _02 · _03 · …
```

> **데이터 2개로 규칙을 세우지 말 것.** `_01`→`…063`, `_02`→`…064`만 보고 "미디어id = 기준값 + 순번"이라 단정했다가 `_03`이 `_02`와 같은 디렉터리로 나와 틀렸다(2026-08-31). 주소는 **모듈마다 실제 `currentSrc`를 읽어** 확인한다. 추정한 주소를 확정처럼 기록하면 안 된다.

`인트로`는 예외로 `doRandomIntroMedia.scu`를 가리킨다 — **공용 랜덤 타이틀 클립**이므로 과목 내용이 아니고 MP3도 없다. src로 바로 판별된다.

## 플레이어 실시간 채록 — iframe 리더와 전환 로거

2단계에서 플레이어를 열었으면, 이후는 **읽기 작업**이다. 여기서 쓰는 도구(`__scuRead`·`__scuHarvest`·`__scuTick`/`__scuLog`·`__scuStop`·`__scuCapture`)를 한 번 정의해두면 매 수확이 한 줄로 끝나고, 장시간 강의에서 전환을 놓치지 않는다.

⭐ **플레이어는 이름만 주는 창구가 아니다.** 항목을 로드하는 것만으로 그 항목의 **공식 자막 전량**이 `textTracks`에 실린다(재생 위치 900초에 1963초 분량 390 cue 실측). 같은 조작에서 본문 정본이 함께 나온다.

### ⚠️ 전제 — 이 도구들은 사용자가 수강하는 동안 **읽기 위한** 것이다

- **수강은 사용자 본인의 행위다.** 리더도 로거도 재생·시크·다음 항목 이동을 하지 않는다. 화면에 이미 떠 있는 것을 읽을 뿐이다
- 상태를 바꾸는 유일한 코드는 정지 헬퍼(`__scuStop`)이고, 그것은 진도를 **올리는** 방향이 아니라 **막는** 방향이다
- 상태를 건드리는 예외는 **둘**이며, 둘 다 **사용자가 명시적으로 지시했을 때만** 쓴다
  - **6단계 「퀴즈 자동 채점」** — 선택지·정답확인 클릭
  - **「자막 수확」의 `›` 화살표 순회** — ⚠️ **이미 완료된 항목에 한한다.** 완료 항목은 `paused` 상태로 로드되어 진도에 영향이 없다(실측). 미완료 항목에는 적용 금지
- 그 외 어떤 도구에도 클릭·재생 코드를 추가하지 말 것. 자막 수확기의 `textTracks.mode` 변경은 **읽기 조작**이며 재생·진도와 무관하다
- 로거를 걸기 전에 사용자에게 알린다 — 무엇을 읽는지, 탭을 새로고침하면 로그가 사라진다는 것

### ⭐ 상위 항목에 진입하면 그 모듈의 하위 목차명이 **전부** 나온다

이 섹션의 핵심 효율이다.

- 상위 항목에 **진입하는 순간** 목차 패널에 그 모듈의 하위 항목이 전부 렌더된다. **아직 재생하지 않은 항목의 이름도 보인다**
- 실측(2026-09-08 딥러닝 2주차): `경사 하강법` 진입 시점에 `pi=4 경사 하강법`과 `pi=5 모델 학습`이 **동시에** 노출됐다
- 즉 이름 채록에 필요한 것은 **상위 항목 도달까지**이고, 하위를 전부 재생할 필요가 없다
- 앞의 「목차 패널은 현재 모듈만 렌더한다」와 합치면 규칙은 하나다 — **모듈 경계마다 한 번씩만 읽으면 그 모듈의 하위 목차명은 전량 확보된다**

| 확정되는 것 | 방법 | 재생 필요? |
|---|---|---|
| 하위 목차 **개별 제목** | 상위 항목 진입 시 패널 1회 읽기 | 그 상위 항목까지만 |
| **어느 MP3가 어느 상위 항목에 속하는가** | 0단계 강의시간 ↔ MP3 길이 산술 | 불필요 |
| **개별 순번** `##(N)` | 4단계 길이 대조 (`video.duration` ↔ MP3) | 그 항목이 재생될 때 |

> 제목만 필요하면 모듈 첫 항목에 도달한 시점에 이미 다 얻은 것이다. 이름을 얻으려고 하위를 끝까지 돌리지 말 것.

### `window.__scuRead` — 재귀 iframe 리더

플레이어는 페이지 내 iframe 오버레이라 최상위 `document.querySelector('video')`로는 잡히지 않는다(2단계 참조). 매번 재귀 순회하는 함수로 박아둔다.

⚠️ **반드시 최상위 프레임에서 정의한다.** iframe 컨텍스트에서 실행되면 그 아래만 순회해 목차 패널을 놓친다.

```javascript
window.__scuRead = function () {
  const docs = [];
  (function collect(d) {
    docs.push(d);
    [...d.querySelectorAll('iframe')].forEach(f => {
      try { if (f.contentDocument) collect(f.contentDocument); } catch (e) {}
    });
  })(document);

  const td = docs.find(d => d.querySelector('.toc-row'));
  const rows = td ? [...td.querySelectorAll('.toc-row')].map(e => ({
    pi:  e.dataset.pageindex,      // 주차 전체 통산
    mi:  e.dataset.moduleindex,    // 상위 목차 번호
    ty:  e.dataset.typecd,         // MODULE = 상위 · PAGE = 하위
    sel: /selected/.test(e.className),
    t:   e.innerText.replace(/\s+/g, ' ').trim()
  })) : [];

  let v = null;
  for (const d of docs) {
    const x = d.querySelector('video');
    if (x && x.currentSrc) {
      v = {
        file:   decodeURIComponent((x.currentSrc.split('/').pop() || '').split('?')[0]),
        src:    x.currentSrc,
        dur:    isFinite(x.duration) ? +x.duration.toFixed(2) : null,   // ⚠️ 소수 유지
        cur:    +x.currentTime.toFixed(1),
        paused: x.paused
      };
      break;
    }
  }
  return { at: new Date().toTimeString().slice(0, 8), docs: docs.length, rows, v };
};
JSON.stringify(window.__scuRead(), null, 1)
```

⚠️ **`dur`을 `Math.round`로 뭉개지 말 것.** 상위 항목의 강의시간은 하위 `video.duration`을 **각각 내림해 합한 값**이라(아래 「출처 표기」) 소수 둘째자리가 검증의 근거다. 반올림해 저장하면 그 검증이 성립하지 않는다.

- `docs`가 1이면 아직 플레이어가 안 열린 것이다 — 열렸는데 못 찾은 것으로 오판하지 말 것
- `rows`가 비면 목차 패널이 접혔거나 다른 모듈로 넘어가는 중이다. 2초 뒤 다시 읽는다

### ⭐ `window.__scuHarvest` — 공식 자막 수확기 (본문의 **정본**)

#### 순서가 뒤집혔다 — 본문은 자막에서 오고, 전사는 폴백이다

**강의실 플레이어에는 사람이 만든 한국어 공식 자막이 실려 있고, 그것이 다글로·whisper 전사보다 정확하다**(2026-09-08 발견). 지금까지 이 플러그인은 자막의 존재를 몰랐고, 본문 확보를 전부 유료 전사에 의존했다.

| 순위 | 본문 소스 | 성격 | 비용 | 언제 쓰나 |
|---|---|---|---|---|
| **1 · 정본** | **강의실 공식 자막**(`video.textTracks`) | 사람이 규범 표기로 작성 | 무료 · 업로드 없음 | 영상형 항목 **전부** |
| 2 · 폴백 | 다글로 MP3 전사 | 기계 인식 | **유료 · 클라우드 업로드** | 자막 cue가 0인 영상 항목만 |
| 3 · 최후 | whisper-cli 로컬 | 기계 인식 · 품질 최하 | 무료 · 오프라인 | 다글로 불가 시 |
| — | DOM 채록 | 슬라이드 원문 | 무료 | **슬라이드형 항목** (자막도 MP3도 없다) |

⛔ **자막을 확인하지 않고 전사부터 돌리지 말 것.** 워크스페이스 `CLAUDE.md`의 유료 승인 게이트 앞에 **「자막 확보 여부 확인」이 선행 조건**으로 들어간다. 자막이 전량 확보된 주차는 `transcribe`가 **불필요**하다.

#### 실측 근거 — 딥러닝 2주차, 같은 음원 10개 대조

| 비교 항목 | 자막 | 다글로 | 판정 |
|---|---|---|---|
| 이산값 언급 | **4회 전부 정확** | 3회 + **이상값 오인식 1회** | 자막 승 |
| 경사 하강법 / 경사하강법 | **40 : 0** (규범) | 0 : 35 (혼입) | 자막 승 |
| 손실 함수 / 손실함수 | **41 : 0** (규범) | 2 : 39 (혼입) | 자막 승 |
| 최솟값 / 최소값 | **28 : 0** (규범) | 25 : 3 (혼입) | 자막 승 |
| 타깃값 / 타겟값 | **타깃값**(규범) | 타겟값 | 자막 승 |
| 총 분량 | 기준 | **+4,963자 (+9.7%)** | 다글로의 초과분은 **중복 발화·필러** |

- **분량이 많은 쪽이 정보가 많은 것이 아니다** — 다글로의 +9.7%는 같은 말 반복과 `어…`·`그…` 필러가 남은 것이다
- 자막은 **`설루션`**(국립국어원 표기)을 쓴다 — 기계 인식이 만들어낼 수 없는 표기이며, **사람이 규범에 맞춰 작성했다는 증거**다
- whisper 로컬 대조(빅데이터분석실무)는 더 나쁘다 — **의미 반전** `금방 할 수 없고` → `금방 할 수 있고`, **고유명사 뭉갬** `Quick-Win` → `퀵윈`, 문장 1건 유실(`내재화`)
- ⚠️ 의미 반전은 **읽어서는 오류인 줄 모른다.** 자막과 대조하지 않으면 사용자가 영영 모르는 종류의 오류다

#### A. 자막은 어떻게 실리고, 왜 로드만으로 전량이 잡히는가

| 사실 | 값 |
|---|---|
| 실리는 곳 | `video.textTracks` · `kind = metadata` · `mode = hidden` |
| cue 구조 | `startTime` · `endTime` · `text` |
| 로드 시점 | **항목을 로드하는 순간 전량** — 재생 완주 불필요 |
| 실측 | 재생 위치 **900초** 시점에 **1963초 분량 390 cue**가 이미 적재돼 있었다 |

- 자막 소스 엔드포인트는 `home.iscu.ac.kr/cdms/progress/devstatu/devstatuPageMakerCaptionDetailView.scu`
- ⛔ **직접 호출하지 말 것** — 호출부가 전역 함수가 아니라 **모듈 클로저 안**이라 재현에 실패했다
- ✅ **실용 경로는 하나다** — 플레이어에 항목을 로드시키고 `textTracks`를 읽는다
- ⭐ 부수 효과: **마지막 cue의 `endTime` ≈ `video.duration`** → 4단계 길이 대조의 **네 번째 출처**가 생긴다. MP3를 아직 못 받은 주차에서도 길이 검증이 가능하다

⛔ **자막으로 목차명을 지어내지 말 것.** 정확도가 올라간 소스라고 해서 「⛔ 절대 하지 말 것 1」이 무력해지는 것이 아니다. **자막 도입부는 목차명이 아니다** — 산술이 이름을 만들어 주지 않는 것과 같은 계열이다.

#### B. 수확기 — `__scuRead`의 재귀 순회를 그대로 재사용한다

⚠️ **반드시 최상위 프레임에서 정의한다.** iframe 안에서 실행하면 그 아래만 순회한다.
⚠️ **네임스페이스를 먼저 정한다.** localStorage는 오리진 공유라, 키를 나누지 않으면 **다른 과목 자막이 섞인다**(실측 — 빅데이터 자막 4건이 딥러닝 강의실에서 복원됐다).

```javascript
window.__scuNS = '{과목코드}_{주차}';          // ⚠️ 먼저 정한다 — 예: '15521541_2'
window.__scuCap = window.__scuCap || {};      // { 파일명: {dur, end, chars, cues[]} }

window.__scuHarvest = function (save) {
  const docs = [];
  (function collect(d) {
    docs.push(d);
    [...d.querySelectorAll('iframe')].forEach(f => {
      try { if (f.contentDocument) collect(f.contentDocument); } catch (e) {}
    });
  })(document);

  const store = window.__scuCap;
  let cur = null;

  for (const d of docs) {
    for (const x of d.querySelectorAll('video')) {
      if (!x.currentSrc) continue;
      if (/doRandomIntroMedia/.test(x.currentSrc)) continue;      // 공용 랜덤 인트로 — 과목 내용 아님
      const file = decodeURIComponent((x.currentSrc.split('/').pop() || '').split('?')[0]);

      const tracks = [...(x.textTracks || [])];
      tracks.forEach(t => { if (t.mode === 'disabled') t.mode = 'hidden'; });  // cue 접근 조건 · 재생과 무관
      const cues = [];
      tracks.forEach(t => [...(t.cues || [])].forEach(c => cues.push({
        s: +c.startTime.toFixed(2),
        e: +c.endTime.toFixed(2),
        t: (c.text || '').replace(/<[^>]*>/g, '').replace(/\s+/g, ' ').trim()
      })));

      cur = { file, n: cues.length };
      if (!cues.length) continue;                                  // 아직 안 붙었다 — 5~10초 뒤 재시도
      cues.sort((a, b) => a.s - b.s);

      const prev = store[file];
      if (!prev || cues.length > prev.cues.length) {               // ⚠️ 적은 쪽으로 덮어쓰지 않는다
        store[file] = {
          dur:   isFinite(x.duration) ? +x.duration.toFixed(2) : null,
          end:   cues[cues.length - 1].e,
          chars: cues.reduce((n, c) => n + c.t.length, 0),
          cues
        };
      }
    }
  }
  if (save !== false) window.__scuBackup();
  return {
    cur,                                                           // 지금 열려 있는 항목
    files: Object.keys(store).map(f => ({
      file: f, n: store[f].cues.length, chars: store[f].chars,
      dur: store[f].dur, end: store[f].end
    }))
  };
};
JSON.stringify(window.__scuHarvest(), null, 1)
```

- `cur.n === 0`이면 **트랙이 아직 안 붙은 것**이다 — 「자막 없음」으로 단정하지 말고 5~10초 뒤 다시 부른다
- ⚠️ **`mode`를 `hidden`으로 올리는 것은 읽기 조작이다** — 재생·시크·진도에 영향이 없다. 여기에 `play()`를 절대 추가하지 말 것
- **더 많은 cue가 들어올 때만 갱신**한다. 전환 직후의 부분 로드가 완전본을 덮어쓰는 사고를 막는다

#### C. 영속 — localStorage 자동 백업과 blob 반출

**수확물이 페이지 메모리에만 있으면 새로고침 한 번에 사라진다.** 반출까지가 수확이다.

```javascript
window.__scuBackup = function () {
  try {
    localStorage.setItem('scuCap:' + window.__scuNS, JSON.stringify(window.__scuCap || {}));
    return 'saved ' + Object.keys(window.__scuCap || {}).length + ' files';
  } catch (e) { return 'SAVE FAILED: ' + e.message; }             // 용량 초과 시 즉시 디스크 반출
};

window.__scuRestore = function () {
  try {
    const raw = localStorage.getItem('scuCap:' + window.__scuNS);
    window.__scuCap = raw ? JSON.parse(raw) : {};
  } catch (e) { window.__scuCap = window.__scuCap || {}; }
  return Object.keys(window.__scuCap).length + ' files restored';
};

window.__scuExport = function () {                                 // 디스크 반출 — 에이전트 맥락을 거치지 않는다
  const name = 'scu-caption-' + window.__scuNS + '.json';
  const blob = new Blob([JSON.stringify(window.__scuCap || {}, null, 1)], { type: 'application/json' });
  const url  = URL.createObjectURL(blob);
  const a    = document.createElement('a');
  a.href = url; a.download = name;
  document.body.appendChild(a); a.click();
  setTimeout(() => { URL.revokeObjectURL(url); a.remove(); }, 1000);
  return name + ' · ' + blob.size + ' bytes';
};

window.__scuPurge = function () {                                  // 반출 확인 후에만 부른다
  localStorage.removeItem('scuCap:' + window.__scuNS);
  return 'purged ' + window.__scuNS;
};
```

⭐ **blob 다운로드는 동작한다 — 227KB 반출 성공(실측).** 이것은 2단계 「⚠️ 프로그래밍 방식 `.click()`은 통하지 않는다」의 **명시적 예외**다.

| 대상 | 프로그래밍 클릭 | 이유 |
|---|---|---|
| `.tit.popup-btn` · 교안 다운로드 버튼 · 퀴즈 `maui-component` | ⛔ 조용히 무시됨 | 포털이 **사용자 제스처**를 요구 |
| **페이지가 스스로 만든 blob 앵커** (`URL.createObjectURL` → `a.click()`) | ✅ **동작한다** | 포털 코드를 거치지 않는다 |

- **에이전트 맥락을 거치지 않으므로 대용량에 유리하다** — cue 원본을 통째로 내려도 대화가 폭증하지 않는다
- localStorage 백업은 **같은 오리진이면 강의실을 이동해도 생존**한다(실측 — 빅데이터 자막 4건이 딥러닝 강의실로 이동 후 복원)
- ⚠️ **그 생존성이 그대로 오염 위험이다** — 반드시 `scuCap:{과목코드}_{주차}` 네임스페이스를 쓰고, 디스크 반출을 확인한 뒤 `__scuPurge()`로 비운다

#### D. 순회 절차 — 완료된 항목은 자동재생되지 않는다

⭐ **이미 완료 처리된 항목은 열어도 `paused` 상태로 로드된다.** 그래서 **진도에 영향 없이** 자막만 수확할 수 있다.

1. `__scuStop(true)` → `__scuRead` → `__scuHarvest` → `__scuBackup` 순으로 정의하고, 이전 세션 수확물이 있으면 `__scuRestore()`
2. **수강이 끝난 주차인지 확인**한다 — 0단계 `상태`가 전부 `완료`여야 순회 대상이다
3. 첫 항목의 플레이어를 연다 (2단계 좌표 클릭 규칙 그대로 — 스크린샷 → **즉시** 클릭)
4. `__scuHarvest()` 호출 → `cur.n`이 0이면 **5~10초 대기 후 재호출**
5. 플레이어 **우하단 `›`(다음) 화살표**로 다음 항목 이동 → 5~10초 대기 → `__scuHarvest()`
6. 마지막 항목까지 4~5 반복. **실측: 딥러닝 2주차 10개 항목을 약 1분에 전량 수확**
7. `__scuExport()`로 디스크 반출 → 파일 크기 확인 → `__scuPurge()`
8. `__scuStop` 가드 해제 확인 후 사용자에게 보고

| 상태 | 화살표 순회 |
|---|---|
| 항목이 **완료**로 표시됨 | ✅ **허용** — 자동재생되지 않아 진도 영향 없음. 사용자 지시 아래 진행 |
| 항목이 **To do** | ⛔ **금지** — 여는 순간 완료되거나 진도가 오른다. 수강은 사용자 본인의 행위다 |

- ⚠️ 6단계의 「**다음 항목으로 넘기는 것도 수강 행위다**」 금칙은 유효하다. **이 절은 「완료 항목 한정」이라는 명시적 예외**이며, 미완료 항목으로 확장하지 않는다
- 순회 전에 사용자에게 알린다 — 어느 항목을 몇 개 열지, 전부 완료 항목인지, 진도가 오르지 않는다는 것
- 실수로 미완료 항목이 열렸으면 **즉시 정지하고 8단계 보고에 포함**한다

##### 전환 로거 연동 — 키에 cue 수를 넣는다

트랙은 항목 로드보다 **늦게 붙는다.** 전환 키에 cue 수가 없으면 「자막 0」 상태로 한 건만 기록되고 **자막이 붙는 순간을 놓친다.** `dur` 확보 여부(`D`/`-`)를 키에 넣은 것과 정확히 같은 이유다.

```javascript
const cue = window.__scuHarvest ? ((window.__scuHarvest(false).cur || {}).n || 0) : 0;
const key = (r.t || '') + '|' + (s.v ? s.v.file : '') + '|' + (s.v && s.v.dur ? 'D' : '-')
          + '|' + (s.cap ? s.cap.len : 0) + '|' + cue;
```

- 로거 안에서는 `__scuHarvest(false)`로 부른다 — **2초마다 localStorage에 쓰지 않기 위해서**다. 백업은 수확 스니펫에서 10분마다 한 번

#### E. 문단 나눔 — 시간 기반은 **불가능하다**

| 관측 | 값 | 결론 |
|---|---|---|
| cue 간 간격 | **전부 0.30초** (1047개 전수 · 최대 0.31초) | 간격으로 문단을 못 나눈다 |
| 빈 cue(침묵) | 파일당 **0~1개** | 경계 신호로 못 쓴다 |

⛔ **「간격이 벌어지면 문단」 규칙을 쓰지 말 것** — 실측상 간격 분포에 경계가 없다. 시도하면 전 파일이 한 문단이 되거나 cue 단위로 산산조각 난다.

✅ **문장 경계로 모아 목표 자수(약 480자)에서 끊는다.**

```python
import re

TARGET, HARD = 480, 720          # 목표 자수 · 강제 절단 상한

# 자막에는 마침표가 없을 수 있다 → 종결어미가 실질 기준이다
ENDER = re.compile(
    r'(?:[.!?…]|습니다|입니다|합니다|됩니다|봅니다|겠습니다|십시오'
    r'|하세요|세요|이에요|예요|이죠|거죠|네요|군요|까요)\s*$')

def cues_to_paragraphs(cues, target=TARGET, hard=HARD):
    """cue 배열 → 문단 리스트. ⛔ startTime/endTime을 경계 판단에 쓰지 않는다"""
    sents, buf = [], ''
    for c in cues:
        t = (c['t'] or '').strip()
        if not t:
            continue                                  # 빈 cue는 파일당 0~1개 — 경계로 쓰지 않는다
        buf = (buf + ' ' + t).strip()
        if ENDER.search(buf):
            sents.append(buf); buf = ''
    if buf:
        sents.append(buf)                             # 마지막 미종결 조각도 버리지 않는다

    paras, cur = [], ''
    for s in sents:
        if cur and len(cur) + 1 + len(s) > target and len(cur) >= target * 0.6:
            paras.append(cur); cur = s
        else:
            cur = (cur + ' ' + s).strip()
        while len(cur) > hard:                        # 종결어미가 오래 안 나오는 구간 방어
            cut = cur.rfind(' ', 0, hard)
            cut = cut if cut > 0 else hard
            paras.append(cur[:cut].strip()); cur = cur[cut:].strip()
    if cur:
        paras.append(cur)
    return paras

def verify(cues, paras):
    """⭐ 무손실 검증 — 공백 제외 문자열이 완전히 같아야 한다"""
    a = re.sub(r'\s+', '', ' '.join((c['t'] or '') for c in cues))
    b = re.sub(r'\s+', '', '\n\n'.join(paras))
    return {'ok': a == b, 'cue_chars': len(a), 'para_chars': len(b)}
```

- **`verify`가 `ok: False`면 재조립이 글자를 잃은 것이다** — 문단화는 **한 글자도 더하거나 빼지 않는다**
- ⚠️ **역할 분담** — 이 스킬은 **cue 원본(`startTime`/`endTime`/`text`)을 그대로 반출**하고, `##(N)` 아래 삽입용 문단화는 `prepare-script`/`transcribe`가 맡는다. 원본을 보존해야 규칙이 바뀌어도 재조립할 수 있다

#### F. 후처리 규칙 변화 — 자막에는 전문용어 후처리가 **불필요하다**

| 경로 | LLM 후처리 | 이유 |
|---|---|---|
| **자막** | ⛔ **하지 않는다** | 화자 라벨·환각·용어 오인식이 **없다.** 규범 표기가 이미 일관(40:0 · 41:0 · 28:0) |
| 다글로 전사 | ✅ 필수 | `참석자 N:` 라벨 제거 + 오인식 교정 |
| whisper 로컬 | ✅ 필수 + 의미 검증 | 의미 반전 실측 사례 있음 |

⛔ **`whisper-terms.txt`를 정답으로 삼아 기계적으로 정규화하지 말 것 — 오히려 틀린다.**

- **실측 반증**: `[4-2] 딥러닝/whisper-terms.txt`에 **`에폭`**이 있는데, **강의도 자막도 `에포크`(각 16회)를 쓴다**
- 용어집대로 일괄 치환하면 **맞는 표기를 틀린 표기로 되돌린다**
- ✅ **용어집은 정답이 아니라 「의심 후보 목록」이다** — 강의·자막의 **실제 표기가 항상 우선**한다
- 반대로 `경사 하강법`·`손실 함수`는 용어집이 띄어쓰기까지 자막과 **일치**한다 — 용어집 전체가 틀린 것이 아니라 **그 한 줄이 틀렸다.** 항목 단위로 검증한다

#### G. 항목 유형별 확보 경로 — **이름이 아니라 실물로 판별한다**

| 유형 | 판별 근거 | 본문 | 화면 | 폴백 |
|---|---|---|---|---|
| **영상형 · 자막 있음** | `<video>` 있음 · cue > 0 | ⭐ **자막(정본)** | 프레임 | MP3 다글로 |
| **영상형 · 자막 없음** | `<video>` 있음 · cue = 0 (재시도 후에도) | 다글로 MP3 전사 | 프레임 | whisper 로컬 |
| **슬라이드형** (학습평가·학습정리 등) | `<video>` 자체가 없음 | **DOM 채록만** (`__scuCapture`) | — | ⛔ **없다** |
| **인트로** | `currentSrc`가 `doRandomIntroMedia.scu` | 없음 (공용 랜덤 클립) | — | — |

⚠️ **`학습개요`가 어느 쪽인지는 과목마다 다르다 — 패턴을 이식하지 말 것**

| 과목 | 학습개요의 실체 | MP3 | 확보 경로 |
|---|---|---|---|
| 딥러닝 | **32초 영상** | ✅ 있음 | 자막 → 없으면 MP3 |
| 빅데이터분석실무 | **슬라이드** | ⛔ 없음 | DOM 채록만 |

- 같은 이름이 과목마다 다른 실체를 가리킨다 — 5단계 표의 「학습개요 = 슬라이드」 단정은 **딥러닝에서 반증됐다**
- ⛔ **슬라이드형은 자막에도 없다.** 「자막이 더 정확하다」가 「자막을 뒤지면 나온다」는 뜻이 아니다 — 슬라이드형은 **수강 중 DOM 채록만이 유일한 경로**이고, 이 사실은 자막 도입 후에 **더 강해진다**
- ⚠️ 자동 채록기 임계값 — 슬라이드형은 본문이 짧다. **학습개요 실측 230자**로 기존 400자 임계값을 통과하지 못했다 → **영상이 없으면 120자**로 낮추고, 감시 정규식에 `학습개요`·`들어가기`·`생각해보기`를 추가한다

#### H. 8단계 보고에 반드시 넣을 것

| 항목 | 내용 |
|---|---|
| **자막 확보 현황** | 항목별 `{cue 수, 총 자수, 마지막 cue endTime}` — 자수가 있어야 전사와 대조가 성립한다 |
| **자막 없는 항목과 그 이유** | 슬라이드형(DOM 채록 완료 여부) / 영상형인데 cue 0(전사 필요) |
| **⚠️ 반출 상태** | 디스크 파일명·경로·크기 · localStorage 키를 비웠는지 — **보고하지 않고 세션을 끝내면 페이지 메모리와 함께 사라진다** |
| **자막 ↔ 기존 전사 차이** | 이미 전사가 들어 있던 항목에서 둘이 갈린 지점. 의미 반전은 **보고하지 않으면 사용자가 영영 모른다** |
| **전사 필요 여부 판정** | 전량 확보 → `transcribe` **불필요(과금 회피 N건)** / 일부 미확보 → 그 항목만 전사 |

**다음 단계 분기**

- 자막 **전량 확보** → 곧장 `prepare-script` → `create-note` (`transcribe` 건너뜀)
- **일부 미확보** → 그 항목만 `transcribe` → `prepare-script`
- 슬라이드형 미채록이 남았으면 → **사용자 수강 시 채록**이 유일한 경로이므로 목록으로 넘긴다


### `window.__scuTick` / `window.__scuLog` — 2초 폴링 전환 로거

수확 간격(10분) 사이에도 항목은 여러 번 바뀐다. **전환 자체를 2초 폴링으로 잡아 로그에 쌓아두면** 수확이 늦어도 그 사이가 비지 않는다.

```javascript
window.__scuLog = window.__scuLog || [];
clearInterval(window.__scuTick);                       // 중복 무장 방지
window.__scuTick = setInterval(() => {
  try {
    const s = window.__scuRead();
    const r = s.rows.find(x => x.sel) || {};
    // 선택 항목 + 재생 파일 + duration 확보 여부 = 전환 키
    // 퀴즈·요약 페이지는 본문을 스냅샷으로 남긴다 (채점 전/후를 각각 보존)
    const it = /평가하기|학습평가|정리하기|학습정리|학습개요|들어가기|생각해보기/.test(r.t || '');
    const cap = window.__scuCapture ? window.__scuCapture() : { len: 0 };
    const th = s.v ? 400 : 120;          // ⚠️ 영상이 없으면 본문이 짧다 — 학습개요 실측 230자
    if (it || cap.len > th) s.cap = cap;
    // ⚠️ 키에 글자수를 넣지 않으면 같은 퀴즈 페이지의 채점 전/후가 한 건으로 뭉개진다
    // ⚠️ cue 수를 넣지 않으면 트랙이 늦게 붙는 순간을 놓친다 (dur의 D/- 와 같은 이유)
    const cue = window.__scuHarvest ? ((window.__scuHarvest(false).cur || {}).n || 0) : 0;
    const key = (r.t || '') + '|' + (s.v ? s.v.file : '') + '|' + (s.v && s.v.dur ? 'D' : '-')
              + '|' + (s.cap ? s.cap.len : 0) + '|' + cue;
    if (key !== window.__scuKey) {
      window.__scuKey = key;
      window.__scuLog.push(s);
      if (window.__scuLog.length > 400) window.__scuLog.shift();
    }
  } catch (e) {}
}, 2000);
'logger armed';
```

- **키에 `dur` 확보 여부를 넣는 이유** — 전환 직후에는 메타데이터가 아직 안 붙어 `duration`이 `NaN`이다. 키가 파일명뿐이면 그 상태로 한 번만 기록되고 **길이를 영영 놓친다.** `D`/`-`를 넣으면 길이가 붙는 순간 같은 항목이 한 번 더 기록된다
- 전환 시에만 push하므로 한 주차 로그는 보통 수십 건이다. 상한 400은 폭주 방지용
- 로거는 **읽기만 한다.** 여기에 재생·시크·클릭 코드를 추가하지 말 것

**로거가 죽는 경우** — 페이지 새로고침, 플레이어를 닫고 강의실홈으로 이동, 탭 재로드. `window.__scuTick`이 사라지고 **`__scuLog`도 함께 날아간다.** 그래서 수확은 미루지 말고 매 틱에 스크립트로 옮긴다.

### 전체 정지 헬퍼 `window.__scuStop`

좌표 클릭 전에 **먼저 걸어두는 안전장치**다. `arm=true`면 0.5초마다 재정지해 자동재생·자동전환을 막는다.

```javascript
window.__scuStop = function (arm) {
  const stop = d => {
    try {
      d.querySelectorAll('video,audio').forEach(v => { v.autoplay = false; v.pause(); });
      d.querySelectorAll('iframe').forEach(f => { if (f.contentDocument) stop(f.contentDocument); });
    } catch (e) {}
  };
  stop(document);
  clearInterval(window.__scuGuard);
  if (arm) window.__scuGuard = setInterval(() => stop(document), 500);
  return arm ? 'stopped + guard armed' : 'stopped';
};
window.__scuStop(true)
```

⛔ **가드를 켠 채로 두고 나오지 말 것.** 사용자가 수강을 시작해도 계속 정지되어 **진도가 전혀 오르지 않는다.** 확인이 끝나면 즉시 해제하고 해제했음을 사용자에게 알린다.

```javascript
clearInterval(window.__scuGuard); window.__scuGuard = null; 'guard off'
```

| 국면 | 가드 |
|---|---|
| 좌표 클릭으로 플레이어를 여는 동안 | **켠다** (`__scuStop(true)`) |
| 열린 항목의 목차·길이를 읽는 동안 | 켠 채로 둔다 |
| 사용자가 수강을 시작하기 전 | **반드시 끈다** — 끄고 나서 "이제 재생하셔도 됩니다"라고 알린다 |

### ⛔ 좌표 클릭 사고 — 아코디언을 펼치려다 강의가 재생됐다

**2026-09-08 실제 사고.** 아코디언 헤더를 펼치려고 좌표 클릭했는데 **항목 플레이어가 열렸다.** 열리자마자 인트로가 재생되고, 끝나면서 **다음 항목으로 자동 전환·자동 재생**됐다. 사용자가 지시하지 않은 항목이 열리고 진도가 올라갔다 — 원칙 위반이다.

원인은 두 가지가 겹친 것이다.

- **헤더와 첫 항목 행은 좌표상 수십 px 차이**다
- **펼치는 순간 레이아웃이 즉시 밀린다** — 직전 스크린샷의 좌표는 그 시점에 이미 무효다

#### 재발 방지 규칙

| 하려는 것 | ⛔ 금지 | ✅ 대신 |
|---|---|---|
| 주차 아코디언 펼치기 | 좌표 클릭 | `.accordion-header` 요소를 특정해 프로그래밍 `.click()` — **펼치기는 스크립트로 동작한다**(1단계) |
| 목차 패널 읽기 | 좌표 클릭 | `__scuRead()` |
| 항목 플레이어 열기 | 무방비 좌표 클릭 | `__scuStop(true)` → 스크린샷 → **즉시** 좌표 클릭 → 확인 → 가드 해제 |

1. **좌표 클릭은 플레이어를 여는 순간에만 쓴다.** 그 외 모든 조작(펼치기·닫기·스크롤·패널 읽기)은 요소를 특정한다. 좌표 클릭이 필요한 이유는 `.tit.popup-btn`이 사용자 제스처를 요구하기 때문이며, 그 외에는 이유가 없다
2. **좌표 클릭 전에 `__scuStop(true)`를 먼저 건다.** 잘못 눌려 열려도 재생되지 않는다
3. **클릭 전에 무엇이 열릴지 말하고, 클릭 후에 무엇이 열렸는지 대조한다** — `__scuRead()`의 `sel`·`file`로 확인한다. 의도한 항목이 아니면 즉시 닫고 **사용자에게 보고**한다
4. **펼치기와 항목 클릭 사이에 스크린샷을 다시 찍는다.** 펼침으로 레이아웃이 이동했기 때문이다(모달을 닫았을 때와 같은 이유)
5. 의도치 않게 열려 **완료 처리된 항목은 8단계 보고에 반드시 포함**한다. 조용히 넘기지 않는다

### 운영 절차 — 장시간 강의를 10분 간격으로 수확

로거가 전환을 전부 기록하므로 **폴링 간격을 5분에서 10분으로 늘려도 놓치지 않는다.** 3단계의 「짧은 항목이 틱 사이를 지나간다」 문제도 이 로거가 해소한다.

1. **사용자가 수강을 시작하기 전에** 최상위 프레임에서 `__scuStop` → `__scuRead` → `__scuTick` 순으로 정의하고 `'logger armed'`를 확인한다
2. 가드가 켜져 있으면 **끄고**, 사용자에게 알린다 — 읽기만 한다는 것, 새로고침하면 로그가 사라진다는 것
3. `CronCreate cron="*/10 * * * *" recurring=true` — 매 틱에 아래 수확 스니펫 1회
4. 수확값을 스크립트에 반영한다. `splice(0)`으로 **꺼내가므로 중복이 생기지 않는다**
5. 전 항목이 확정되면 `CronDelete` → `clearInterval(window.__scuTick)` → **가드 해제 확인**

```javascript
(() => {
  const alive = !!window.__scuTick;
  const 수확 = (window.__scuLog || []).splice(0).map(s => {
    const r = s.rows.find(x => x.sel) || {};
    return { at: s.at, mi: r.mi, pi: r.pi, 항목: r.t,
             file: s.v && s.v.file, dur: s.v && s.v.dur };
  });
  const now = window.__scuRead ? window.__scuRead() : null;
  const cur = now ? (now.rows.find(x => x.sel) || {}) : {};
  return JSON.stringify({
    alive,                                        // false면 재무장 필요
    수확,                                          // 지난 10분간의 모든 전환
    현재: cur.t,
    남은초: now && now.v && now.v.dur ? Math.round(now.v.dur - now.v.cur) : null,
    현재모듈_하위전체: now                          // ⭐ 진입만으로 얻는 이름들
      ? now.rows.filter(r => r.ty === 'PAGE').map(r => r.pi + ':' + r.t) : []
  }, null, 1);
})()
```

- **`현재모듈_하위전체`가 이 절차의 주 수확물이다.** 재생을 기다리지 않고 그 모듈의 하위 목차명을 전부 가져온다
- **`alive: false`면 로거가 죽은 것이다** — 즉시 재무장하고, 죽어 있던 구간은 **"관측 공백"으로 표기**한다. 그 구간의 순번은 규칙으로만 배정된 것이므로 확인한 것처럼 적지 않는다
- `남은초`가 작으면 곧 전환된다. 다음 항목이 짧을 것 같아도 **로거가 잡으므로 `computer wait`로 붙어 있을 필요가 없다**
- 3~4틱 연속 무변화(퀴즈 대기 등)면 루프를 내려두고 사용자가 돌아올 때 다시 걸 것을 제안한다 — 로그는 이미 스크립트에 옮겨져 있어 잃을 것이 없다

### ⚠️ 출처 표기 — 로거 값과 목록 표기값은 다른 출처다

산출물에 초를 적을 때는 **어디서 읽은 값인지 함께 적는다.** 구분하지 않으면 "1주차는 반올림이었다" 같은 잘못된 반박이 성립한다(실제 발생).

| 값 | 출처 | 성격 | 표기 예 |
|---|---|---|---|
| `dur` | 플레이어 `video.duration` | **실측**, 소수 | `영상 245.43초` |
| 0단계 `강의초` | 강의실 목록 「학습시간/강의시간」 | **명목**, 정수 | `강의시간 1031초` |
| MP3 길이 | `ffprobe` | 실측, 정수 | `MP3 245초` |

- **상위 항목의 강의시간 = 하위 `video.duration`을 각각 내림해 합한 값**이다
  ```
  딥러닝 2주차 「손실 함수 표기」 1031 = 245(245.43) + 384(384.40) + 402(402.69)
    · 각항 반올림이면 1032 · 합계후내림도 1032 → 표기값과 불일치
  딥러닝 2주차 「수치 예측 실습」 2159 = 332(332.26) + 1827(1827.96)
  ```
  5과목 전수 민감도 검사에서 **floor일 때만 5과목 모두 해가 존재**했다(round·ceil은 전부 해 없음)
- ⚠️ **인트로 길이는 고정값이 아니다.** `doRandomIntroMedia.scu`는 랜덤이라 **로드마다 다르다** — 실측 13.11초로 기존 문서의 `18~22초` 범위 밖이었다. 관측한 인트로 길이를 그 항목의 값처럼 적지 말 것
- 포털이 집계에 쓰는 인트로 **명목값은 `상위 항목 강의시간 − 하위 MP3 내림 합`의 잔여로만 추정**된다. 적을 때는 반드시 `(잔여 추정)`을 붙인다 — **잔여값을 관측값처럼 제시했다가 검증에서 지적당한 사례가 있다**

### ⚠️ 0단계 셀렉터 재확인 필요

현행 0단계 스니펫은 `section.item` 셀렉터를 쓰는데, **2026-09-08 페이지 구조에서 그 셀렉터가 존재하는지는 미확인**이다. 이번에 확실히 동작한 것은 아래 경로다.

```javascript
const item = [...document.querySelectorAll('.accordion-item')]
  .find(e => e.querySelector('.week-circle')?.textContent.trim() === '{N}주차');
const head = item.querySelector('.accordion-header');                    // 주차명·출석인정기간·예상학습시간
const body = [...item.children].find(c => c !== head);                   // DIV.accordion-content
body.innerText.split('\n').map(s => s.trim()).filter(Boolean)
// 제목 / "To do"|"완료" / "[학습시간/강의시간]" / "• 0분0초/34분6초" / "[완료조건]" / "• …"
```

- `section.item`이 비면 **`innerText` 줄 단위 파싱으로 폴백**한다 — 이쪽은 실측에서 5과목 전부 동작했다
- ⚠️ **「노출 방식 3분류」는 낡았다.** 2주차 기준으로 **5과목 전부 인라인 노출**이며, 미노출로 적혀 있던 딥러닝·빅데이터도 `• 0분0초/34분6초` 형태로 그대로 나온다. 툴팁·미노출을 전제로 플레이어 경로부터 잡지 말고 **항상 인라인부터 확인**한다

## 3단계: 장시간 수강 모니터링 (선택)

주차 전체가 60분을 넘어 한 번에 다 볼 수 없다. 사용자가 시청하는 동안 5분 간격으로 패널만 읽는다.

```
CronCreate  cron="*/5 * * * *"  recurring=true
```

- 영상이 10~15분이므로 5분 간격이면 **모든 항목을 최소 두 번** 본다
- 루프는 **읽기만** 한다. 재생·일시정지·시크 금지
- 확정될 때마다 스크립트에 반영하고, 전부 끝나면 `CronDelete`로 종료
- ⚠️ 세션 종료 시 소멸한다. 사용자가 세션을 닫으면 다시 걸어야 한다
- ⚠️ 긴 프롬프트는 승인 분류기에 막힐 수 있다 → **지시를 파일에 두고 크론은 그 파일을 읽게** 한다. 매 틱 컨텍스트도 절약되고 진행 로그를 한곳에 쌓을 수 있다
- ⚠️ **새 크론을 먼저 걸고 기존 것을 지운다.** 반대로 하면 새 크론이 막혔을 때 감시가 비어버린다

### 자동 전환은 모듈 경계도 넘는다

영상이 끝나면 다음 항목으로 자동 전환되고 **상위 목차(모듈) 경계까지 넘어간다.** 실측에서 모듈1 마지막 → 모듈2 첫 항목 → `평가하기`까지 클릭 없이 진행됐다. 수동 개입이 필요했던 지점은 **`평가하기` → `정리하기` 단 한 번**(퀴즈가 게이트)뿐이었다.

⚠️ **단 영상이 아닌 상호작용 페이지(`평가하기`·`정리하기`)는 자동 전환되지 않는다.** 영상은 끝나면 넘어가지만 퀴즈 페이지는 멈춘다.

→ **수동 이동 수단은 플레이어 우하단의 `‹` `›` 화살표다.** 목차 패널에는 현재 상위 항목의 하위만 나오고 다른 상위 항목 링크가 없다. **강의실홈으로 되돌아갈 필요가 없다**(URL 항목만 예외 — 아래 절).

⛔ 넘기는 것도 수강 행위다 — **사용자 지시 없이 화살표를 누르지 않는다.**

### ⚠️ URL(외부링크) 항목은 플레이어에서 전환되지 않는다

영상이 끝나고 다음이 URL 항목이면 자동 전환이 멈추고 모달이 뜬다.

> 다음 URL 아이템은 강의실홈 1주차에서 학습할 수 있습니다.

→ 플레이어를 닫고 **강의실홈에서 그 항목을 직접 클릭**한다. 새 탭으로 외부 사이트가 열리며 열람 완료 처리된다. 뜬 탭은 닫는다.

⚠️ **이 처방은 URL 항목 전용이다.** `평가하기`·`정리하기`처럼 자동 전환이 멈추는 다른 경우에는 강의실홈으로 돌아가지 않고 **플레이어 우하단 `‹` `›` 화살표**로 넘어간다.

### ⚠️ 순차 잠금 — 건너뛰면 모달로 막힌다

앞 항목이 미완료인데 뒤를 클릭하면:

> 동일주차내 '1주차내 (X)' 아이템이 미완료입니다. 'X' 아이템부터 학습을 진행해 주시기 바랍니다.

- 과목마다 강도가 다르다 — 문제해결·AWS·GitHub는 엄격하다

**⚠️ 완료되지 않은 항목 뒤로는 `›` 화살표도 막힌다 (2026-09-09 빅데이터분석실무 2주차 실측)**

> 현재 콘텐츠 아이템의 학습 완료가 되지 않아 다음 콘텐츠 아이템으로 이동할 수 없습니다.

- 앞서 「빅데이터는 모듈 안에서 자유 점프가 됐다」고 적었으나 **그것은 그 항목들이 이미 완료 상태였기 때문**이다.
  미완료 항목에서는 같은 과목도 막힌다 — **과목 성질이 아니라 완료 상태의 문제다**
- ⛔ **이 잠금은 `학습평가`·`학습정리` 채록을 직접 막는다.** 두 구역은 주차 마지막에 있어
  선행 영상을 **실제로 완료(강의시간 50% 이상)**해야만 도달한다
- 자막은 이 잠금과 무관하다 — 영상 항목은 **로드만으로** cue가 실리므로 미완료 항목의 자막도 받을 수 있다.
  막히는 것은 **그 뒤로 넘어가는 것**뿐이다
- 따라서 순서는 ① 자막을 먼저 전량 수확(무료·빠름) → ② 사용자가 수강해 잠금 해제 → ③ 평가·정리 채록
- ⛔ **AWS·GitHub는 1주차 첫 항목이 「과목 공지 읽고 게시판 글 1개 이상 작성」이다.**
  이 항목을 완료하기 전에는 어떤 강의도 열리지 않는다.
  **게시판 글 작성은 사용자 본인이 한다** — 대신 쓰지 않는다.
  대신 **과목공지를 읽어 요약과 초안을 제공**할 수는 있다 (`collect-week` 참조)

### ⚠️ 주차 목록의 완료 상태는 갱신이 지연된다

수강 직후에도 `To do`로 보이다가 나중에 반영된다. 실제 상태는 **강의실 재진입 후** 읽는다. 지연된 표시를 보고 "진도가 안 쌓였다"고 단정하지 말 것.

### ⚠️ 짧은 항목은 5분 틱 사이를 그냥 지나간다

1~2분짜리 항목은 두 틱 사이에 시작하고 끝나 **길이를 관측하지 못한다**(GitHub `학습개요` 48초에서 실제 발생 — 순번 규칙으로만 배정할 수밖에 없었다).

- 현재 영상의 남은 시간과 **다음 항목의 예상 길이**를 보고, 짧을 것 같으면
  `computer wait`를 10초씩 이어 붙여 **틱 중간에 한 번 더 확인**한다
- 놓쳤으면 규칙으로 배정하되 **"길이 직접 미확인"으로 표기**한다 — 확인한 것처럼 적지 않는다

### 변화 없는 틱이 길게 이어지면

퀴즈 대기처럼 사용자 입력이 없으면 움직이지 않는 지점이 있다. 3~4틱 연속 무변화면 **루프를 내려두고 사용자가 돌아올 때 다시 거는 것**을 제안한다. 진행 상태는 스크립트와 과목 `CLAUDE.md`에 이미 있으니 잃을 것이 없다.

## 4단계: MP3 길이와 대조 — 확정 근거

**영상 길이와 MP3 길이는 초 단위로 정확히 일치한다.** 7건 전수 검증에서 오차 최대 1초(반올림). 이것이 매칭의 확정 근거이며, 여기에 맞으면 추측이 아니다.

⭐ **세 번째 근거 — 자막 마지막 cue의 `endTime`.** 자막을 수확했으면 `endTime ≈ video.duration`이 성립하므로, **MP3를 아직 받지 못한 주차에서도** 길이 대조가 가능하다(실측: 재생 900초 시점에 이미 1963초 분량 390 cue 적재). 표기는 출처를 병기한다 — `자막 1963.0초` / `영상 1963.2초` / `MP3 1963초`.

```bash
for f in 강의녹음/*_{주차}_*.mp3; do
  printf "%s %s\n" "$(ffprobe -v error -show_entries format=duration \
    -of default=nw=1:nk=1 "$f" | cut -d. -f1)" "$(basename "$f")"
done | sort -n
```

| 하위 목차 | 영상 | MP3 | 판정 |
|---|---:|---:|---|
| 학습개요 | 29초 | `_01` 29초 | ✅ |
| 오리엔테이션 | 769초 | `_02` 769초 | ✅ |
| 머신러닝 | 1358초 | `_04` 1357초 | ✅ 반올림 1초차 |

**어떤 MP3와도 길이가 맞지 않으면 MP3 없는 항목**으로 처리한다.

## 5단계: MP3 없는 항목 처리

| 항목 | 판별 근거 | 처리 |
|---|---|---|
| **인트로** | `currentSrc`가 **`doRandomIntroMedia.scu`** — 공용 랜덤 타이틀 클립. **길이로 판별 금지** — 로드마다 다르다(실측 13.11초, 문서 구범위 18~22초 밖) | `##` 번호 없이 기록 |
| **학습개요** | ⚠️ **과목마다 다르다 — 실물로 판별한다.** 딥러닝은 **32초 영상**(MP3 있음), 빅데이터분석실무는 **슬라이드**(MP3 없음) | 영상이면 `##(N)` 부여 + 자막 수확 · 슬라이드면 번호 없이 기록 + **본문 채록** |
| **생각해보기** | 과목에 따라 **영상일 수도, 슬라이드일 수도** 있다 | `<video>` 유무로 판별 |
| **학습평가** | 퀴즈 페이지, `<video>` 자체가 없음 | 번호 없이 기록 + **채록 필수** |
| **학습정리** | 요약 슬라이드, `<video>` 없음 | 번호 없이 기록 + **채록 필수** |

**판별은 이름이 아니라 실물로 한다.** `학습개요`가 어느 과목에선 슬라이드지만 `생각해보기`는 빅데이터분석실무에서 **86초 영상이고 `_01`이었다.** 이름만 보고 "부속 항목이니 MP3 없겠지"라고 넘기면 순번이 밀린다.

```javascript
// MP3 없는 항목 판정: 영상이 없거나, 있어도 랜덤 인트로면 MP3 없음
const noMp3 = !v || /doRandomIntroMedia/.test(v.src);
```

> 첫 MP3를 목차 첫 줄에 기계적으로 붙이면 **전체가 한 칸씩 밀린다.** 반드시 길이로 확인할 것.

## 6단계: 학습평가·학습정리 채록 — 유일한 경로

두 구역은 **슬라이드형이라 자막도 MP3도 없다.** 자막이 본문 정본이 된 뒤에도 이 구역만은 **DOM 채록만이 유일한 경로**이며, 오히려 근거가 강해졌다 — 지금 받아두지 않으면 강의노트를 완성할 수 없다.

⚠️ **유형 판별이 먼저다.** `<video>`가 있으면 자막(정본) → MP3 전사 순으로 본문을 얻고, `<video>` 자체가 없을 때만 이 절의 채록 경로로 간다. 이름으로 유형을 단정하지 않는다.

- **학습개요** — 슬라이드. `학습목표`·`학습내용`이 있고 강의노트 `## 학습개요`의 정본이 된다.
  4분 이하라 **열면 완료되는 항목**이므로 사용자 동의 후에 연다
- **학습평가** — 퀴즈를 풀어야 다음으로 넘어간다. **기본은 문항만 채록하고 답을 클릭하지 않는 것**이다 —
  퀴즈 풀이는 사용자 본인의 행위다. 사용자가 답을 알려주면 정답·해설을 스크립트에 적어둔다.
  **사용자가 명시적으로 대신 풀라고 지시하면** 전사·교안에서 근거를 찾아 답을 확정한 뒤 진행한다 — 찍지 않는다.
  근거는 셋이다 — ① 이 퀴즈는 배점 항목이 아닌 **형성평가**이고, ② **정답·해설은 `정답확인` 이후에만 렌더**되어 강의노트 `## 학습평가`의 유일한 복원 경로이며, ③ 그렇게 완료 처리된 항목은 **8단계 보고에 반드시 포함**한다.

  ⚠️ 퀴즈 DOM은 `maui-component` 커스텀 컴포넌트이고 **`el.click()` 단독으로는 반응하지 않는다** — 플레이어 열기와 같은 계통이다.
  `pointerdown` → `mousedown` → `pointerup` → `mouseup` → `click`을 **해당 iframe의 `defaultView`에서 만들어** 대상과 부모 양쪽에 발사해야 한다(아래 「퀴즈 자동 채점」 절).

  ⛔ **전 문항을 `forEach`/`for await`로 한 번에 처리하지 말 것** — 빈 결과가 돌아온다(실측). 선택과 확인을 **문항마다 별도 동기 호출**로 나눈다.
  ⛔ **버튼을 `정답확인` 텍스트로 고르지 말 것** — 버튼이 문항당 2개(`정답확인`·`다시풀기`)라 이미 채점된 문항의 버튼도 계속 매치되어 항상 1번 문항을 누른다. **위치 인덱스**로 매핑한다.

  문항 유형에 따라 셀렉터 계열이 갈리므로 **실물을 먼저 조회해 분기한다.**

| 유형 | 선택지 | 버튼 |
|---|---|---|
| 번호 배지형 객관식 | `.maui-component-type-item` 안의 `.item-select-option-no` — `.item-option-row`(행 전체) 클릭은 **아무 일도 하지 않는다** | 항목 안에서 탐색 |
| O/X형 | `div.component-data-field` 중 `textContent`가 `O`/`X` (`input` 0개) | `span.maui-border-button` |

  → 실행 코드는 아래 「⚠️ 퀴즈 자동 채점 — 위치 인덱스·이벤트 디스패치·동기 분할」 절에 있다.

#### ⚠️ 정답·해설 추출 — `정답확인`을 기준으로 자르지 말 것

채점하면 **`정답확인` 버튼의 텍스트가 사라진다.** 그래서 `indexOf('정답확인')` 기준으로 뒤를 잘라내면 `-1`이 나와 **"해설 없음"으로 오판한다**(2026-09-01 실제 사고 — "이 과목은 정답을 표시하지 않는다"고 사용자에게 잘못 보고했다).

**`정답` / `해설` 라벨 자체를 정규식으로 잡는다.** 단 아래 두 결함을 반드시 함께 막는다.

⚠️ **반대 방향의 오매치 버그** — 부정 전방탐색이 없으면 버튼 텍스트 `정답확인`을 정답으로 읽는다(실측 오탐 `정답:"확인"`). 위 절단 버그와 **같은 토큰을 둘러싼 반대 실패**이며, 한쪽만 고치면 다른 쪽에 걸린다.

⚠️ **정답과 해설을 한 패턴에 묶지 말 것** — 해설을 필수로 만들면 해설 없는 문항에서 매치 전체가 실패해 **정답까지 `?`로 나온다.**

```javascript
const RE_ANS  = /(?:^|\n)[ \t]*정답(?!\s*확인)[ \t]*[:：][ \t]*(.+)/;   // 부정 전방탐색 필수
const RE_ANS2 = /(?:^|\n)[ \t]*정답(?!\s*확인)[ \t]*\n[ \t]*(.+)/;      // 라벨과 값이 줄바꿈으로 갈릴 때
const RE_EXP  = /(?:^|\n)[ \t]*해설[ \t]*[:：]?[ \t]*([\s\S]+?)(?=\n[ \t]*(?:Quiz\.|문제[ \t]*\d|정답|다시풀기|정답확인)|$)/;
```

→ 문항 번호(`Quiz.01` 형식 포함) 분할까지 붙인 완성본은 아래 「퀴즈 자동 채점」 절에 있다.

- 채점 직후에는 렌더가 늦을 수 있다 → **3~4초 기다린 뒤** 읽는다
- ⚠️ **해설이 붙는 규칙은 퀴즈 유형마다 다르다 — 과목 공통이 아니다**
  - **O/X형** — 거짓 진술 문항에만 해설이 붙고 참 진술은 정답만 나온다(딥러닝 2주차 Q1·Q4 거짓=해설 / Q2·Q3 참=없음, 문제해결 1주차 동일)
  - **번호 배지형 객관식** — **전 문항에 해설이 붙는다**(빅데이터분석실무 2주차 4문항 전수 실측)
  - ⛔ 2026-09-08에 이를 「과목 공통 패턴」으로 적었다가 다음 날 4지선다에서 반증됐다. **유형을 먼저 판별한 뒤 규칙을 적용할 것**
- ⛔ **빈 해설을 "추출 실패"로 오판하지 말 것.** 해설 공백은 정상이며 문항의 진위와 결부돼 있다. **정답 라벨까지 없을 때만** "비공개"를 의심하고, 그 판단도 위 정규식으로 재확인한 뒤에 한다
- 기록은 스킬이 고른 답이 아니라 **강의실이 표시한 공식 값**으로 한다. 둘이 다르면 그 사실을 함께 적는다

#### ⚠️ 퀴즈 자동 채점 — 위치 인덱스·이벤트 디스패치·동기 분할

⛔ **사용자가 명시적으로 "대신 풀어라"라고 지시했을 때만 이 절을 쓴다.** 기본값은 위 그대로 **문항만 채록하고 답은 사용자가 푼다**

| 자동화가 정당화되는 근거 | 내용 |
|---|---|
| 정답·해설은 **`정답확인`을 누른 뒤에만 렌더된다** | 누르기 전에는 화면에 존재하지 않는다 — 읽어서 얻을 수 있는 값이 아니다 |
| 그 텍스트가 강의노트 `## 학습평가`의 **유일한 복원 경로**다 | 이 구역은 MP3가 없어 전사로 복원되지 않는다(6단계 도입부) |
| 이 퀴즈는 배점 항목이 아닌 **형성평가**다 | 목적은 점수 취득이 아니라 정답·해설 텍스트 확보다 |

- 답은 전사·교안에서 **근거를 찾아 확정한 뒤** 클릭한다 — 찍지 않는다
- 클릭 전에 **무엇을 어떤 근거로 고를지** 사용자에게 알리고, 클릭 후 **강의실이 표시한 공식 정답과 대조**한다
- 자동 채점으로 완료 처리된 항목은 **8단계 보고에 반드시 포함**한다
- 「이 도구들은 읽기 위한 것이다」 전제의 **유일한 예외가 이 절이다** — 상태를 바꾸는 코드는 여기 밖으로 나가지 않는다

**실측 기준** — 2026-09-08 딥러닝 2주차 `평가하기`, O/X 4문항

**1. DOM — 표준 폼이 아니다 (`input` 0개)**

| 대상 | 셀렉터 | 실측 |
|---|---|---|
| 입력 요소 | `input` | **0개** — 라디오·체크박스가 아니다 |
| 선택지 | `div.component-data-field` | `textContent`가 **정확히 `O` 또는 `X`** · 부모는 `div.maui-component-core` |
| 버튼 | `span.maui-border-button` | **문항당 2개** `[정답확인, 다시풀기]` → 4문항 = **8개** |

⚠️ **문항 유형에 따라 셀렉터 계열이 갈린다. 한쪽으로 덮어쓰지 말고 실물을 먼저 조회해 분기한다**

| 유형 | 선택지 | 버튼 |
|---|---|---|
| 번호 배지형 객관식 | `.maui-component-type-item` 안의 `.item-select-option-no` (행 전체 `.item-option-row`는 무반응) | 항목 안에서 탐색 |
| **O/X형** (딥러닝 2주차) | `div.component-data-field` 중 `O`/`X` | `span.maui-border-button` |

**2. ⚠️ 함정 — 버튼이 문항당 2개라 텍스트 필터가 무너진다**

- `정답확인` 텍스트로 버튼을 고르면 **이미 채점한 문항의 버튼도 계속 매치되어** `confs[0]`이 언제나 1번 문항을 가리킨다
- 2번 문항을 누르려다 1번을 다시 눌러 **헛돈다** — 실제로 이 함정에 걸렸다
- ⛔ **텍스트 필터 금지. 위치 인덱스로 매핑한다**

**O/X형 (선택지 2개)**

| 문항 `k` (0-based) | 선택지 `O` | 선택지 `X` | 정답확인 | 다시풀기 |
|---|---|---|---|---|
| 매핑 | `opts[2k]` | `opts[2k+1]` | `btns[2k]` | `btns[2k+1]` |

- `opts` = `component-data-field` 중 `O`/`X`만 남긴 목록 · `btns` = `span.maui-border-button` **전체** 목록

**번호 배지형 객관식 (선택지 n개 · 실측 4지선다)**

| 문항 `k` (0-based) | 선택지 `i`번(1-based) | 정답확인 | 다시풀기 |
|---|---|---|---|
| 매핑 | `opts[n*k + (i-1)]` | `btns[2k]` | `btns[2k+1]` |

- `opts` = **`.item-select-option-no`** 전체 목록(번호 배지) — ⛔ `.item-option-row`(행)는 클릭해도 무반응
- `n` = 문항당 선택지 수 = `opts.length / 문항수`. 문항수는 `.maui-component-type-item` 개수
- 실측(빅데이터분석실무 2주차): 문항 4 · `opts` 16 · `btns` 8 → `n=4`, Q1의 ③ = `opts[2]`, Q3의 ② = `opts[9]`
- ⚠️ **버튼 매핑은 두 유형이 같다**(`btns[2k]`) — 선택지 매핑만 다르다
- 매 호출마다 목록을 **다시 만든다** — 채점으로 DOM이 갱신되므로 캐시하면 인덱스가 어긋난다
- 호출 전 `opts.length === btns.length === 문항수 × 2`를 확인한다. 맞지 않으면 유형 분기부터 다시 본다

**3. ⚠️ 함정 — async 루프로 4문항을 한 번에 처리하면 빈 결과가 온다**

- 전 문항을 한 호출에 몰면 **결과가 비어서 돌아온다** — 실측 실패
- **동기 호출로 문항마다 나눠 실행한다. 선택과 확인도 각각 별도 호출이다**
- 4문항이면 **총 8회 호출** — `pick(0)` → `confirm(0)` → `pick(1)` → `confirm(1)` → …
- ⛔ `items.forEach(...)`·`for await`로 묶는 코드는 **실패 재현 코드**다

**4. 클릭은 `el.click()`으로 반응하지 않는다**

- `pointerdown` → `mousedown` → `pointerup` → `mouseup` → `click` 순으로 디스패치해야 한다
- 이벤트는 **그 iframe의 `defaultView`에서 생성**하고 `clientX`/`clientY`를 채운다
- **대상 요소와 그 부모 양쪽에** 발사한다
- 앞의 「`.click()`이 동작한다」는 서술은 이 실측으로 폐기됐다 — 플레이어 열기와 마찬가지로 합성 클릭이 필요하다

**헬퍼 정의 — 최상위 프레임에서 1회**

```javascript
window.__scuQuiz = (function () {
  const docs = [];
  (function collect(d) {
    docs.push(d);
    [...d.querySelectorAll('iframe')].forEach(f => {
      try { if (f.contentDocument) collect(f.contentDocument); } catch (e) {}
    });
  })(document);

  // ⚠️ 플레이어 문서는 .toc-row 보유로 특정한다 — '본문이 가장 긴 문서' 휴리스틱 금지
  const d = docs.find(x => x.querySelector('.toc-row'));
  if (!d) return { err: 'player doc not found (.toc-row 없음)' };
  const W = d.defaultView;                       // ⚠️ 이벤트는 그 iframe의 window로 만든다

  const real = el => {                           // el.click() 단독으로는 반응하지 않는다
    if (!el) return false;
    const r = el.getBoundingClientRect();
    const opt = { bubbles: true, cancelable: true, composed: true, view: W,
                  clientX: r.left + r.width / 2, clientY: r.top + r.height / 2,
                  button: 0, buttons: 1, pointerId: 1, pointerType: 'mouse', isPrimary: true };
    const P = W.PointerEvent || W.MouseEvent, M = W.MouseEvent;
    for (const t of [el, el.parentElement]) {     // 대상과 부모 양쪽에 발사
      if (!t) continue;
      t.dispatchEvent(new P('pointerdown', opt));
      t.dispatchEvent(new M('mousedown',  opt));
      t.dispatchEvent(new P('pointerup',   opt));
      t.dispatchEvent(new M('mouseup',    opt));
      t.dispatchEvent(new M('click',      opt));
    }
    return true;
  };

  // ⚠️ 목록은 호출할 때마다 새로 만든다 — 채점하면 DOM이 갱신된다
  const opts = () => [...d.querySelectorAll('div.component-data-field')]
    .filter(e => /^[OX]$/.test((e.textContent || '').trim()));
  const btns = () => [...d.querySelectorAll('span.maui-border-button')]; // [정답확인,다시풀기]×문항

  return {
    d, W, real, opts, btns,
    n: () => Math.min(opts().length, btns().length) / 2,
    // 문항 k(0-based) 선택 — O = opts[2k] · X = opts[2k+1]
    pick: (k, ox) => { const o = opts(), el = ox === 'O' ? o[2 * k] : o[2 * k + 1];
                       return real(el) ? `Q${k + 1} 선택 ${ox}` : `Q${k + 1} 선택지 없음`; },
    // 문항 k 채점 — ⚠️ 텍스트 필터가 아니라 위치 인덱스 btns[2k]
    conf: k => { const b = btns();
                 return real(b[2 * k]) ? `Q${k + 1} 정답확인` : `Q${k + 1} 버튼 없음`; }
  };
})();
window.__scuQuiz.err ||
  `문항=${window.__scuQuiz.n()} 선택지=${window.__scuQuiz.opts().length} 버튼=${window.__scuQuiz.btns().length}`;
```

**문항별 선택 + 확인 — ⚠️ 반드시 한 호출에 한 동작씩**

```javascript
// 호출 ①  __scuQuiz.pick(0, 'X')     ← 근거로 확정한 답만 넣는다
// 호출 ②  __scuQuiz.conf(0)
// 호출 ③  __scuQuiz.pick(1, 'O')
// 호출 ④  __scuQuiz.conf(1)   … 문항 수 × 2 회
window.__scuQuiz.pick(0, 'X')
```

- 각 호출의 반환 문자열로 **의도한 문항이 처리됐는지 매번 대조**한다
- 채점 직후에는 렌더가 늦다 → `conf(k)` 다음 **3~4초 기다린 뒤** 다음 문항으로 간다
- 한 문항이라도 `선택지 없음`·`버튼 없음`이 나오면 **중단하고 유형 분기를 다시 확인한다** — 밀어붙이면 엉뚱한 문항을 누른다

**5. 결과 추출 — 문항번호·정답·해설 **세 개의 독립 정규식****

⚠️ 문항 번호 표기는 **`Quiz.01` / `Quiz.02`** 다. `문제 N`·`N.`만 받는 정규식은 **0건**을 반환한다

⚠️ **`정답` 라벨 정규식이 버튼 텍스트 `정답확인`을 정답으로 오인한다** — 실측 오탐 `정답:"확인"`. **부정 전방탐색이 필수**다. 바로 위 절의 절단 버그(`indexOf('정답확인')`로 잘라 `-1`)와 **방향이 반대인 오매치 버그**이며, 둘 다 같은 토큰을 둘러싼 실패다. 한쪽만 고치지 말 것

⚠️ **정답과 해설을 한 패턴에 묶지 말 것** — 해설을 필수로 만들면 해설 없는 문항에서 매치 전체가 실패해 **정답까지 `?`가 된다**

```javascript
(() => {
  const s0 = ((window.__scuQuiz.d.body || {}).innerText || '').replace(/\r/g, '');

  // ① 문항 번호 — 화면 표기 3형식. Quiz./문제 를 먼저 쓰고, 0건일 때만 'N.' 폴백
  const A = /(?:^|\n)[ \t]*(?:Quiz\.?[ \t]*0*(\d+)|문제[ \t]*0*(\d+))[ \t]*(?=\n|$)/g;
  const B = /(?:^|\n)[ \t]*0*(\d+)[ \t]*[.)][ \t]*/g;          // 본문 숫자 오탐이 잦다
  const scan = re => { const out = []; let m; re.lastIndex = 0;
    while ((m = re.exec(s0))) out.push({ no: +(m[1] || m[2]), at: m.index, end: re.lastIndex });
    return out; };
  let marks = scan(A); if (!marks.length) marks = scan(B);
  const chunks = marks.length
    ? marks.map((m, i) => ({ no: m.no,
        s: s0.slice(m.end, i + 1 < marks.length ? marks[i + 1].at : s0.length) }))
    : [{ no: 1, s: s0 }];                                       // 폴백: 화면 표기가 없을 때만 인덱스 라벨

  // ② 정답 — ⚠️ (?!\s*확인) 이 없으면 '정답확인' 버튼을 정답으로 읽는다
  const RE_ANS  = /(?:^|\n)[ \t]*정답(?!\s*확인)[ \t]*[:：][ \t]*(.+)/;
  const RE_ANS2 = /(?:^|\n)[ \t]*정답(?!\s*확인)[ \t]*\n[ \t]*(.+)/;   // 라벨과 값이 줄바꿈으로 갈릴 때
  // ③ 해설 — 정답과 분리된 독립 패턴. 없어도 정답 추출에 영향을 주지 않는다
  const RE_EXP  = /(?:^|\n)[ \t]*해설[ \t]*[:：]?[ \t]*([\s\S]+?)(?=\n[ \t]*(?:Quiz\.|문제[ \t]*\d|정답|다시풀기|정답확인)|$)/;

  return chunks.map(c => {
    const a = c.s.match(RE_ANS) || c.s.match(RE_ANS2), e = c.s.match(RE_EXP);
    return `Q${String(c.no).padStart(2, '0')} 정답: ${a ? a[1].trim() : '(미표시)'}`
         + ` / 해설: ${e ? e[1].trim().replace(/\s+/g, ' ') : '(없음 — 참 진술이면 정상)'}`;
  }).join('\n');
})()
```

**6. ⚠️ 빈 해설은 추출 실패가 아니다 — 단 규칙은 퀴즈 유형마다 다르다**

| 유형 | 해설 | 실측 |
|---|---|---|
| **O/X형** | 거짓 진술 문항에만 | 딥러닝 2주차 Q1·Q4(거짓)=해설 / Q2·Q3(참)=없음 · 문제해결 1주차 동일 |
| **번호 배지형 객관식** | **전 문항** | 빅데이터분석실무 2주차 4문항 전수 |

- ⛔ **「과목 공통 패턴」으로 일반화하지 말 것** — 2026-09-08에 그렇게 적었다가 다음 날 4지선다에서 반증됐다
- 번호 배지형에서 해설이 비면 그건 **정상이 아니라 추출 실패**다 — 정규식·대기시간을 의심한다
- ⛔ 해설이 비었다고 "추출 실패"·"정답 비공개 과목"으로 **오판하지 말 것** — 정답 라벨까지 없을 때만 비공개를 의심하고, 그 판단도 위 정규식으로 재확인한 뒤에 한다
- 스크립트에는 `해설: (없음)`이 아니라 **해설 줄을 생략**하고, 보고에서 "참 진술 문항이라 해설 없음"으로 밝힌다

**실측 산출물 — 딥러닝 2주차 학습평가**

| 문항 | 진술 | 진위 | 공식 정답 | 공식 해설 |
|---|---|---|---|---|
| Quiz.01 | 예측 결과값이 이산값이면 회귀 문제 | 거짓 | ② X | 모델이 예측하는 결과값이 연속값이면 회귀 문제에 해당함 |
| Quiz.02 | 전체 훈련 데이터 1회 학습 = 에포크 | 참 | ① O | — |
| Quiz.03 | 손실 함수 = 예측값과 타겟값의 차이 | 참 | ① O | — |
| Quiz.04 | `fit()`이 여러 배열에서 요소를 하나씩 꺼냄 | 거짓 | ② X | `zip()` 함수에 대한 설명임 |

**7. 스냅샷 — 퀴즈 문서는 `.toc-row`로 특정하고 dedup 키에 글자수를 넣는다**

- ⛔ **"본문 텍스트가 가장 긴 문서" 휴리스틱 금지** — 바깥 강의실 문서(2699자)를 잡는다. 재생 중 플레이어 문서는 **134자**에 불과하다
- 퀴즈·요약 슬라이드가 렌더되면 그 문서 텍스트가 **400자를 넘는다**
- 전환 로거의 스냅샷 조건은 **(선택 항목이 `평가하기`/`정리하기`/`학습개요`/`들어가기`/`생각해보기`) 또는 (글자수 > 임계값)** 으로 둔다
- ⚠️ **임계값은 고정 400이 아니다** — `__scuRead`가 `v = null`을 주는(영상 없는) 항목은 본문이 짧다. **영상이 있으면 400, 없으면 120**(`const th = s.v ? 400 : 120;`). 학습개요 실측 230자가 400 조건에 걸려 유실됐다
- **dedup 키에 글자수를 넣으면 채점 전/후가 각각 남는다** — 넣지 않으면 같은 퀴즈 페이지가 한 건으로 뭉개져 정답·해설이 유실된다

```javascript
window.__scuCapture = function () {
  const docs = [];
  (function collect(d) { docs.push(d);
    [...d.querySelectorAll('iframe')].forEach(f => {
      try { if (f.contentDocument) collect(f.contentDocument); } catch (e) {}
    });
  })(document);
  const d = docs.find(x => x.querySelector('.toc-row'));   // ⚠️ 길이 휴리스틱 금지
  const t = d ? ((d.body || {}).innerText || '').replace(/[ \t]+\n/g, '\n').trim() : '';
  return { len: t.length, text: t };
};
JSON.stringify({ len: window.__scuCapture().len })
```

**8. ⚠️ 상위 항목 간 이동 — 플레이어 우하단 `‹` `›` 화살표**

- ⚠️ **`평가하기`·`정리하기`처럼 영상이 아닌 상호작용 페이지는 자동 전환되지 않는다** — 영상 항목은 끝나면 넘어가지만 **퀴즈 페이지는 멈춘다**. 「자동 전환은 모듈 경계도 넘는다」가 유일하게 깨지는 지점이다
- 목차 패널에는 **현재 상위 항목의 하위만** 렌더되고 다른 상위 항목 링크가 없다 → 패널로는 이동할 수 없다
- 이동 수단은 **플레이어 우하단의 `‹` `›` 화살표**다. **강의실홈으로 되돌아갈 필요가 없다**
- ⚠️ 「강의실홈에서 직접 클릭」 처방은 **URL(외부링크) 항목 전용**이다 — 퀴즈·요약 페이지에 이식하지 말 것
- 화살표도 `.click()`에 반응하지 않으면 위 `__scuQuiz.real()`을 쓰고, 그래도 안 되면 좌표 클릭 규칙(`__scuStop(true)` 선행 → 스크린샷 → 즉시 클릭)을 따른다
- ⛔ **다음 항목으로 넘기는 것도 수강 행위다** — 사용자 지시 없이 화살표를 누르지 않는다
- ⚠️ **예외는 「자막 수확」의 완료 항목 순회 하나다** — 이미 완료된 항목은 `paused` 상태로 로드되어 진도가 오르지 않는다(실측). **완료 항목에 한해, 사용자 지시 아래** 화살표 순회를 허용한다. `To do` 항목에는 확장 금지

- **학습정리** — 요약 슬라이드. 이미 수강 완료한 페이지라면 열어서 읽어도 진도 영향이 없다

**세 항목 모두 지금 채록하지 않으면 복원 경로가 없다.** **자막에도**, 전사에도, 교안에도, 어디에도 없다.

⛔ **"본문 텍스트가 가장 긴 문서" 휴리스틱을 쓰지 말 것** — 바깥 강의실 문서(2699자)를 잡는다. 재생 중 플레이어 문서는 **134자**에 불과하다. 문구 매칭도 학습정리 전용이라 퀴즈 페이지를 놓친다. **`.toc-row` 보유 여부로 특정한다**(`__scuRead`와 같은 기준).

```javascript
window.__scuCapture = function () {
  const docs = [];
  (function collect(d) { docs.push(d);
    [...d.querySelectorAll('iframe')].forEach(f => {
      try { if (f.contentDocument) collect(f.contentDocument); } catch (e) {}
    });
  })(document);
  const d = docs.find(x => x.querySelector('.toc-row'));   // ⚠️ 길이 휴리스틱 금지
  const t = d ? ((d.body || {}).innerText || '').replace(/[ \t]+\n/g, '\n').trim() : '';
  return { len: t.length, text: t };
};
JSON.stringify({ len: window.__scuCapture().len })
```

## 7단계: 스크립트에 반영

`prepare-script` 형식을 그대로 따른다. 확정된 것만 채우고 **미확인은 빈칸으로 둔다.**

확정 근거를 `←` 주석으로 남긴다. 나중에 검증할 수 있고, 다음 주차에서 오프셋을 재계산할 근거가 된다.

```
<빅데이터분석실무 1주차 학습목차>

# 들어가기
## 인트로                ← 영상 22초 · MP3 없음 (doRandomIntroMedia = 공용 랜덤 타이틀)
## 학습개요              ← 슬라이드 · 영상·MP3 없음 · 채록 완료
## (1)생각해보기         ← 영상 86초 = 15521541_1_01.mp3 85초 ✅
---
# 빅데이터 개요 및 활용
## (2)데이터와 정보      ← 영상 677초 = 15521541_1_02.mp3 676초 ✅
## ( )데이터베이스       ← 순번 미확정
---
# 평가하기
## 학습평가              ← 퀴즈 페이지 · 영상·MP3 없음 · 채록 필요
---
# 정리하기
## 학습정리              ← 요약 슬라이드 · 영상·MP3 없음 · 채록 필요

※ 미배정 MP3: _03(649초 10:49) · _04(918초 15:18) …
   ⛔ 전사 내용으로 목차명·순번을 추정해 채우지 말 것
```

**하위 목차명은 확인됐지만 순번은 미확정**인 상태가 정상이다. 그때는 `## ( )제목`으로 두어 이름은 살리고 번호만 비운다. 이름까지 지우면 다시 열어야 한다.

### ⚠️ 파일 수정 시 인덱스 기반 편집 금지

학습목차 구역과 본문 구역에 **`## 학습평가` 같은 동일 문자열이 두 번** 나온다. `s.index('## 학습평가')` 로 자르면 목차 쪽을 잡아 **파일 뒷부분이 통째로 날아간다**(2026-08-31 2회 발생).

- **소스(전사 파일)에서 재생성**하는 방식을 기본으로 한다
- 부분 수정이 필요하면 `←` 주석까지 포함한 **유일한 문자열**을 앵커로 쓴다
- 수정 후 **구역 개수와 파일 크기를 검증**한다

학습목차 구역은 두 태그 사이가 경계이므로 **구역 전체를 재생성**하는 것이 가장 안전하다.

```python
i, j = s.index('<{과목} {N}주차 학습목차>'), s.index('<{과목} {N}주차 강의녹음 스크립트>')
s = s[:i] + new_toc_block + '\n' + s[j:]          # 본문 구역은 손대지 않는다
# 검증
body = s[s.index('강의녹음 스크립트'):]
assert len(re.findall(r'^## \(\d\)', body, re.M)) == 기대_구역수
```

⚠️ `io.open(f,'w',...)`에 **buffering 인자를 잘못 넘기면 예외 전에 파일이 잘릴 수 있다.** 쓰기 전에 `shutil.copy2`로 백업하고, 검증 통과 후 백업을 지운다.


## 8단계: 보고

- 확정된 `##(N)` 과 근거(영상 길이 = MP3 길이)
- **이번 작업으로 완료 처리된 항목** — 사용자가 아니라 스킬이 열어 완료된 것이 있으면 반드시 밝힌다
- **길이를 직접 확인하지 못하고 규칙으로만 배정한 순번** — 있으면 반드시 구분해 밝힌다
- **사용자 조치가 필요한 항목** — 게시판 글, 계정 생성(GitHub·AWS Academy), 외부 사이트 가입,
  과제·토론 마감. 이런 것들은 스킬이 대신하지 않으므로 목록으로 넘긴다
- 미확정 항목과 **확인 방법** — "N주차 X 항목을 수강하시면 읽어서 채우겠습니다"
- 채록된 학습평가 문항 수 · 학습정리 유무
- **자막 확보 현황** — 항목별 `{cue 수, 총 자수, 마지막 cue endTime}` · **자막 없는 항목과 그 이유**(슬라이드형 / 영상형인데 cue 0)
- ⚠️ **자막 반출 상태** — 디스크 파일명·경로·크기, localStorage 키를 비웠는지. **보고하지 않고 세션을 끝내면 페이지 메모리와 함께 사라진다**
- **자막 ↔ 기존 전사 차이** — 이미 전사가 들어 있던 항목에서 둘이 갈린 지점. 의미 반전은 보고하지 않으면 사용자가 영영 모른다
- 다음 단계 — **자막 전량 확보면 `transcribe`를 건너뛰고** 곧장 `prepare-script` → `create-note`(과금 회피 N건). **미확보 항목이 남았으면 그 항목만** `transcribe` → `prepare-script` → `create-note`
