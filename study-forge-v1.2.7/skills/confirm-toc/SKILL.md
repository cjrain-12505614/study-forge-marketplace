---
name: confirm-toc
description: >
  강의실 플레이어의 학습목차 패널을 읽어 하위 목차명을 확정하고, 영상 길이와 MP3 길이를 대조해
  ## (N) 순번 매칭을 근거 있게 확정하는 스킬 (v0.10.1).
  주경로는 **재생 없는 산술 확정**(항목 강의시간 ↔ MP3 길이 분할)이고, 플레이어는 하위 제목 채록과
  **공식 자막(textTracks) 수확**에 쓴다 — 자막은 전사보다 정확한 본문 정본이다.
  학습평가·학습정리처럼 MP3도 자막도 없는 구역의 내용도 이 단계에서 채록한다.
  학습평가는 매번 정답확인까지 자동으로 수행해 공식 정답(정답 행)과 공식 해설 원문을 회수한다
  (사용자 상시 정책 2026-09-17 · CLMS 평가하기/학습평가 한정).
  사용자가 "목차 확인해줘", "목차 채워줘", "학습목차 확정", "자막 받아줘", "캡션 수집",
  "학습평가 정답 확인", "confirm-toc" 등을 요청하거나, 강의를 수강하며 목차를 알려주겠다고 할 때 사용한다.
  prepare-script의 선행 단계이자, 전사 필요 여부를 결정하므로 transcribe의 선행 단계이기도 하다.
version: 0.10.1
---

# 학습목차 확정 스킬 (추정 금지)

`## (N)` 하위 목차명을 **추측 없이** 확정한다.

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

**3. 학습평가 정답을 추정으로 적지 말 것 — `정답확인`으로 공식 값을 회수한다 (v1.2.0)**

학습평가는 **매번 `정답확인`까지 채점**해 **정답 행**(`.passed-answer`/`.failed-answer` — 둘 다 정답 행)과 **공식 해설 원문**(`[data-field="explanation"]`)을 회수한다(사용자 상시 정책 2026-09-17 · 6단계). 건별 지시는 필요 없다.

- 채점 전 DOM에 **정답 라벨이 없는 유형**이 있다(문제해결 O/X — 해설 문장이 거짓 진술에만 있다). 누르지 않으면 「(추정)」만 남고, 사용자가 그 표기를 거부했다
- 해설 유무로 참·거짓을 짐작해 정답을 적는 것도 추정이다
- 회수하지 못한 문항은 `정답 미확보(사유)`로 남기고 8단계에서 보고한다 — 빈칸을 추정으로 채우지 않는다

**4. 학습평가 채점 정책을 다른 조작으로 넓히지 말 것**

- 적용 범위는 **CLMS `평가하기`/`학습평가`(형성평가)의 보기 선택·주관식 입력·`정답확인`**뿐이다
- ⛔ 적용하지 않는 것 — 영상 재생·수강 대행 · `›`/`‹` 이동 · AWS Academy 지식 점검(성적 과제) · OJ 제출 · 게시판·보드 글 · 수시·정기시험 · 사내교육 최종평가
- **`평가하기` 도달(앞 모듈 완료)은 사용자 수강에 달려 있다** — 정책은 도달한 뒤의 조작에만 적용된다. 도달하려고 재생·이동·잠금 우회를 대신하지 않는다
  - '도달'은 두 경우다 — ① **미완료 주차**: 사용자가 수강 흐름으로(또는 사용자 지시로) 플레이어에 `평가하기`를 연 상태. 앞 모듈이 완료됐다는 사실만으로는 에이전트가 미완료 `평가하기`를 열지 않는다(슬라이드형이라 여는 순간 열람 완료 = 사용자의 수강 기록이 된다) ② **완료 주차**: 강의실홈 목록에서 그 주차 `평가하기` 행이 이미 `완료`인 경우 — 상시 정책에 따라 **스킬이 강의실에 들어가 `평가하기`를 직접 열어 회수한다**(진도 변화 없음 · 강의실 입장은 참여도에 +1로 집계될 뿐이다 · 2026-09-17 문제해결 3주차 실행). 열기 전에 행 텍스트로 `평가하기`·`완료`를 확인하고, 아코디언·다른 항목을 누르지 않도록 요소를 특정해 스크린샷 좌표로 연다
- 채점 안전 절차(유휴 팝업 선검사 · 선택 등록 확인 뒤 `정답확인` · 한 호출에 한 동작 · 채점된 문항 재클릭 금지)는 한 단계도 생략하지 않는다 — 채점 뒤에는 재시도 수단이 없다(6단계 4-B)

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
| **하위 목차** `## (N)` | 상위 항목 **안으로 들어가야 나옴** | `들어가기` → `인트로`, `학습개요` |

- **MP3 1개 = 동영상 1개 = `## (N)` 1개**
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

⚠️ **「매 주차 첫 영상은 인트로」는 성립하지 않는다 — 과목뿐 아니라 주차마다 다르다.**

- 문제해결프로그래밍입문 **2주차에는 인트로가 아예 없다**(2026-09-09 실측) —
  `data-pageindex`가 **0부터 `학습개요`**로 시작하고 `doRandomIntroMedia.scu`가 등장하지 않는다.
  같은 과목 1주차도 인트로가 없었으므로 **과목 단위 특성**으로 보이나, 주차 단위로 확인하는 편이 안전하다
- 반대로 AWS·GitHub는 2주차에도 인트로가 있었다(각 20초·18초 — 역시 로드마다 다름)
- ⛔ **인트로 존재를 가정하고 `순번 = pi` 오프셋을 적용하면 전체가 한 칸 밀린다.**
  오프셋은 외우지 말고 **그 주차의 `pi=0` 항목이 무엇인지 실물로 확인**한 뒤 정한다

## 플레이어 실시간 채록 — iframe 리더와 전환 로거

2단계에서 플레이어를 열었으면, 이후는 **읽기 작업**이다. 여기서 쓰는 도구(`__scuRead`·`__scuHarvest`·`__scuTick`/`__scuLog`·`__scuStop`·`__scuCapture`)를 한 번 정의해두면 매 수확이 한 줄로 끝나고, 장시간 강의에서 전환을 놓치지 않는다.

⭐ **플레이어는 이름만 주는 창구가 아니다.** 항목을 로드하는 것만으로 그 항목의 **공식 자막 전량**이 `textTracks`에 실린다(재생 위치 900초에 1963초 분량 390 cue 실측). 같은 조작에서 본문 정본이 함께 나온다.

### ⚠️ 전제 — 이 도구들은 사용자가 수강하는 동안 **읽기 위한** 것이다

- **수강은 사용자 본인의 행위다.** 리더도 로거도 재생·시크·다음 항목 이동을 하지 않는다. 화면에 이미 떠 있는 것을 읽을 뿐이다
- 상태를 바꾸는 유일한 코드는 정지 헬퍼(`__scuStop`)이고, 그것은 진도를 **올리는** 방향이 아니라 **막는** 방향이다
- 상태를 건드리는 예외는 **둘**이며, **발동 조건이 서로 다르다**
  - **예외 1 — 6단계 「퀴즈 자동 채점」 (상시 정책)** — 보기 선택·주관식 입력·`정답확인` 클릭.
    사용자 상시 정책(2026-09-17)에 따라 `평가하기`에 도달하면 **매번 기본으로 수행하며 건별 지시가 필요 없다.**
    적용 범위는 **CLMS `평가하기`/`학습평가` 한정**이다(「⛔ 절대 하지 말 것 4」).
    `__scuIdle()`·탭 가시성 선검사와 **4-B 선택 확인 게이트**(선택 → `.selected` 확인 → `정답확인`, 각각 별도 호출 · 의도와 같은 선택만 채점)는 필수다
  - **예외 2 — 「자막 수확」의 `›` 화살표 순회** — **사용자가 명시적으로 지시했을 때만** 쓴다.
    ⚠️ **이미 완료된 항목에 한한다.** 완료 항목은 `paused` 상태로 로드되어 진도에 영향이 없다(실측). 미완료 항목에는 적용 금지
  - ~~둘 다 사용자가 명시적으로 지시했을 때만 쓴다~~ — **폐기(v1.2.0)** · 예외 1이 상시 정책으로 바뀌었다
- ⛔ **예외 1은 재생·`›`/`‹` 이동 권한을 주지 않는다** — 채점 조작에만 적용된다. 이동은 예외 2 또는 사용자 지시(동행 수강)를 따른다
- 그 외 어떤 도구에도 클릭·재생 코드를 추가하지 말 것. 자막 수확기의 `textTracks.mode` 변경은 **읽기 조작**이며 재생·진도와 무관하다
- 로거를 걸기 전에 사용자에게 알린다 — 무엇을 읽는지, 탭을 새로고침하면 로그가 사라진다는 것,
  **`평가하기`에 도달하면 전 문항 채점을 수행한다는 것**(예외 1)

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
| **개별 순번** `## (N)` | 4단계 길이 대조 (`video.duration` ↔ MP3) | 그 항목이 재생될 때 |

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
window.__scuNS = '{과목코드}_{주차}';          // ⚠️ 먼저 정한다 — 예: '15521541_2' · 자리표시자 그대로면 헬퍼가 거부한다
// __scuNS는 그 주차 MP3 파일명 앞의 `{과목코드}_{주차}`를 복사해 쓴다(5과목 공통 · 문제해결 `15521530_1_t_…`도 앞 두 토큰) — 손으로 치지 않는다
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
        const spoken = cues.filter(c => c.t);                      // ⚠️ 끝의 빈 cue는 duration을 ~3초 넘는다
        store[file] = {
          dur:   isFinite(x.duration) ? +x.duration.toFixed(2) : null,
          end:   spoken.length ? spoken[spoken.length - 1].e : null,  // 마지막 「발화」 cue 기준
          chars: cues.reduce((n, c) => n + c.t.length, 0),
          cues
        };
      }
    }
  }
  const saved = save !== false ? window.__scuBackup() : null;     // 'saved N files' · 'SAVE FAILED …' · 'NS 미설정 …'
  return {
    cur,                                                           // 지금 열려 있는 항목
    saved,
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
- `cues`에는 빈 cue까지 **원본 그대로** 둔다(원본 보존). 빈 cue를 빼는 것은 VTT·본문으로 **쓸 때**다(아래 C 「VTT로 쓸 때」)

#### C. 영속 — localStorage 자동 백업과 blob 반출

**수확물이 페이지 메모리에만 있으면 새로고침 한 번에 사라진다.** 반출까지가 수확이다.

```javascript
// ⚠️ 자리표시자 키(`scuCap:{과목코드}_{주차}`)로 읽고 쓰지 않는다 — 과목 간 오염(B절)
window.__scuBackup = function () {
  if (!window.__scuNS || /[{}]/.test(window.__scuNS)) return 'NS 미설정 — __scuNS를 실제 값으로 (B절) · 현재: ' + window.__scuNS;
  try {
    localStorage.setItem('scuCap:' + window.__scuNS, JSON.stringify(window.__scuCap || {}));
    return 'saved ' + Object.keys(window.__scuCap || {}).length + ' files';
  } catch (e) { return 'SAVE FAILED: ' + e.message; }             // 용량 초과 시 즉시 디스크 반출
};

window.__scuRestore = function () {
  if (!window.__scuNS || /[{}]/.test(window.__scuNS)) return 'NS 미설정 — __scuNS를 실제 값으로 (B절) · 현재: ' + window.__scuNS;
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
  if (!window.__scuNS || /[{}]/.test(window.__scuNS)) return 'NS 미설정 — __scuNS를 실제 값으로 (B절) · 현재: ' + window.__scuNS;
  localStorage.removeItem('scuCap:' + window.__scuNS);
  return 'purged ' + window.__scuNS;
};
```

⭐ **blob 다운로드는 동작한다 — 227KB 반출 성공(실측).** 이것은 2단계 「⚠️ 프로그래밍 방식 `.click()`은 통하지 않는다」의 **명시적 예외**다.

| 대상 | 프로그래밍 클릭 | 이유 |
|---|---|---|
| `.tit.popup-btn` · 교안 다운로드 버튼 | ⛔ 조용히 무시됨 | 포털이 **사용자 제스처**를 요구 |
| 퀴즈 `maui-component` (보기 배지 · `정답확인`) | ⚠️ `.click()` 단독은 무반응 · 합성 pointer·mouse 이벤트는 **날짜·과목마다 결과가 갈림**(보장 없음) | 등록 여부는 `sel(k)`/`selNo(k)`와 `data-passyn`으로만 판정한다 — 미등록이면 스크린샷 좌표 클릭(6단계 4·4-B) |
| **페이지가 스스로 만든 blob 앵커** (`URL.createObjectURL` → `a.click()`) | ✅ **동작한다** | 포털 코드를 거치지 않는다 |

- **에이전트 맥락을 거치지 않으므로 대용량에 유리하다** — cue 원본을 통째로 내려도 대화가 폭증하지 않는다
- localStorage 백업은 **같은 오리진이면 강의실을 이동해도 생존**한다(실측 — 빅데이터 자막 4건이 딥러닝 강의실로 이동 후 복원)
- ⚠️ **그 생존성이 그대로 오염 위험이다** — 반드시 `scuCap:{과목코드}_{주차}` 네임스페이스를 쓰고, 디스크 반출을 확인한 뒤 `__scuPurge()`로 비운다

**⚠️ 연속 반출은 「차단」이 아니라 「지연」된다 — 성급한 판정 금지 (2026-09-09 실측)**

한 호출에서 blob 앵커를 3개 연달아 클릭했더니 **첫 파일만 즉시 저장되고 2·3번째가 보이지 않았다.**
`.crdownload` 잔재도 오류도 없어 「Chrome 다중 다운로드 차단」으로 판정했는데 — **틀렸다.**
**약 12분 뒤 2·3번째가 한꺼번에 도착했다.** Chrome의 다중 다운로드 허용 처리에 걸려 큐에 있었을 뿐이다.

- ⛔ **그 사이 「차단됐다」고 보고하고 재시도까지 하는 바람에 `파일 (1).vtt` 중복본이 생겼다.**
  큐가 풀리면 **첫 시도분과 재시도분이 모두 저장된다**
- **판정 규칙** — 다운로드가 안 보이면 **차단으로 단정하지 말고**
  ① 파일마다 호출을 나누고 ② 수 분 뒤 다시 확인한다. 그때도 없으면 아래 폴백으로 간다
- ⛔ **다운로드 폴더를 확인하기 전에는 「반출 완료」라고 보고하지 않는다.**
  `a.click()`이 예외 없이 끝나는 것은 저장 성공의 증거가 아니다
- **정리** — 회수 후 `파일 (N).확장자` 패턴의 중복본을 지우고 원본만 남긴다.
  크기가 같은지(브라우저측 `blob.size` 대조) 확인하면 어느 쪽을 남겨도 무방함이 확인된다

**폴백 — 작은 자막은 응답으로 분할 회수한다**

```javascript
JSON.stringify(window.__scuCap['<파일>.mp4'].slice(0, 9))    // 9~10 cue씩
```

- `javascript_tool` 응답에는 **약 1,900자 상한**이 있다(실측 — 21 cue를 요청하면 17번째에서 잘린다).
  cue 하나가 대략 90자이므로 **9~10개씩** 끊으면 안전하다
- 잘린 응답을 그대로 파일로 쓰면 **말없이 손상된 VTT**가 된다 → 회수 후 **cue 수와 마지막 cue의
  종료 시각을 영상 길이와 대조**해 전량인지 검증한다
- 검증 지표: **마지막 발화 cue 종료 시각 ≈ `video.duration`**(실측 977.92 / 980, 245.32 / 247, 205.02 / 206).
  크게 모자라면 부분 수확이다
- ⚠️ **「마지막 cue」가 아니라 「마지막 발화 cue」다** — 끝에 빈 cue가 붙은 트랙은 그 종료 시각이
  `duration`을 **넘는다**(아래). 빈 cue로 비교하면 넘치는 값을 「전량 확보」로 잘못 읽는다
- 반출한 VTT의 **바이트 수를 브라우저측 `blob.size`와 대조**하면 무결성이 한 번 더 확인된다

**VTT로 쓸 때 — 빈 cue는 뺀다 (2026-09-14 딥러닝 3주차 실측)**

일부 트랙은 **마지막 cue가 텍스트 없는 빈 cue**이고, 그 종료 시각이 `video.duration`보다 **약 3초 뒤**에 있다.

| 딥러닝 3주차 | `duration` | 마지막 발화 cue 종료 | 빈 cue 종료 | 초과 |
|---|---|---|---|---|
| (6) | 1003.30 | 1001.69 | 1006.39 | +3.09초 |
| (7) | 431.30 | 429.86 | 434.36 | +3.06초 |
| (8) | 586.42 | 585.28 | 589.68 | +3.26초 |
| (9) | 459.96 | 458.98 | 463.28 | +3.32초 |
| (10) | 1502.00 | 1500.12 | 1505.12 | +3.12초 |

- (1)~(5)에는 없었다 — **트랙마다 있을 수도 없을 수도 있다.** 원본 이상이며 본문 정보가 없다
- ✅ **VTT와 본문에는 빈 cue를 넣지 않는다** — 기존 `자막/` VTT(딥러닝 2·3주차 20개)가 전부 빈 cue 0개인 것과 맞춘다.
  cue 번호는 빈 cue를 뺀 뒤 1부터 다시 매긴다
- cue 수를 보고할 때는 **원본 수와 기록 수를 함께** 적는다(예: 원본 1,138 · 빈 cue 5 · 기록 1,133)

```python
def write_vtt(cues, path):
    """cues: [{'s','e','t'}] 원본 · 빈 cue는 여기서 뺀다"""
    def ts(sec):
        ms = int(round(sec * 1000))
        h, ms = divmod(ms, 3_600_000); m, ms = divmod(ms, 60_000); s, ms = divmod(ms, 1000)
        return f'{h:02d}:{m:02d}:{s:02d}.{ms:03d}'
    kept = [c for c in cues if (c['t'] or '').strip()]
    out = ['WEBVTT', '']
    for i, c in enumerate(kept, 1):
        out += [str(i), f"{ts(c['s'])} --> {ts(c['e'])}", c['t'].strip(), '']
    with open(path, 'w', encoding='utf-8') as f:
        f.write('\n'.join(out))
    return {'raw': len(cues), 'kept': len(kept), 'dropped_empty': len(cues) - len(kept)}
```

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
- 순회 중 **`평가하기`**에 닿으면 — 스크립트에 공식 정답(채점 기록)이 이미 있으면 지나간다. 없으면 **헬퍼를 먼저 (재)정의**하고
  `__scuQuiz.probe()`·`res(k)`로 **채점 상태부터 읽고**, 채점돼 있으면 읽기만(`save(k)`), 초기화돼 있으면 채점 루프를 탄다(예외 1 · 6단계 「이미 채점된 문항 · 완료 주차 재오픈」).
  옛 헬퍼는 교체된 플레이어 문서를 계속 본다 — `probe().stale`이 `true`면 재정의가 빠진 것이다

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
| 빈 cue(침묵) | 파일당 **0~1개** — 딥러닝 3주차는 트랙 **끝**에만 있었다(C 「VTT로 쓸 때」) | 경계 신호로 못 쓴다 |

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
- ⚠️ **역할 분담** — 이 스킬은 **cue 원본(`startTime`/`endTime`/`text`)을 그대로 반출**하고, `## (N)` 아래 삽입용 문단화는 `prepare-script`/`transcribe`가 맡는다. 원본을 보존해야 규칙이 바뀌어도 재조립할 수 있다

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
| **슬라이드형** (학습평가·학습정리 등) | `<video>` 자체가 없음 | **DOM 채록만** (`__scuCapture`) · **학습평가는 여기에 `정답확인` 채점(`__scuQuiz`)을 더해 공식 정답·해설을 회수**(6단계) | — | ⛔ **없다** |
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
| **학습평가 채점 결과** | 8단계의 「학습평가 채점 결과」와 같다 — 문항 수 · `Y`/`N` 수 · 공식 정답 N/N · 공식 해설 있음/없음 · 좌표 클릭 전환 · 근거 없음(첫 보기) · 회수하지 못한 문항과 사유 |

**다음 단계 분기**

- 자막 **전량 확보** → 곧장 `prepare-script` → `create-note` (`transcribe` 건너뜀)
- **일부 미확보** → 그 항목만 `transcribe` → `prepare-script`
- 슬라이드형 미채록이 남았으면 → **사용자 수강 시 채록**이 유일한 경로이므로 목록으로 넘긴다
- **학습평가 공식 정답을 회수하지 못한 문항이 남았으면** → `create-note`로 넘기지 않고 **회수를 먼저** 한다.
  미완료 주차는 사용자 수강으로 `평가하기`에 도달한 뒤 회수한다(create-note 0단계 게이트가 같은 조건으로 막는다)


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
    // ⚠️ 유휴 종료 팝업이 뜬 시점을 로그에 남긴다 — 그 뒤의 조작은 기록되지 않았을 수 있다 (3단계)
    s.idle = window.__scuIdle ? window.__scuIdle() : null;
    const key = (r.t || '') + '|' + (s.v ? s.v.file : '') + '|' + (s.v && s.v.dur ? 'D' : '-')
              + '|' + (s.cap ? s.cap.len : 0) + '|' + cue + '|' + (s.idle ? 'IDLE' : '');
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

**로거가 살아 있어도 헛도는 경우** — 사용자가 **다른 창·탭에서** 강의실을 다시 열었을 때다. 로거는 원래 탭을 계속 읽으므로 `alive: true`인데 전환이 멈춘다. 로그에 `IDLE`이 찍힌 뒤 변화가 없으면 이것부터 의심한다(3단계 「다른 창·탭에서 다시 열면」).

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
- 3~4틱 연속 무변화면 루프를 내려두고 사용자가 돌아올 때 다시 걸 것을 제안한다 — 로그는 이미 스크립트에 옮겨져 있어 잃을 것이 없다
- 멈춘 이유가 **`평가하기` 도달**이면 감시 루프(크론)를 내리고 **6단계 「학습평가 자동 채점 루프」로 전환**한다 —
  v1.2.0부터 퀴즈는 사용자 입력을 기다리는 지점이 아니다(상시 정책). 페이지 로거(`__scuTick`)는 읽기만 하므로 켜 둬도 되고, 채점 전/후 스냅샷이 함께 남는다
  - 무변화 예시였던 ~~(퀴즈 대기 등)~~ — **폐기(v1.2.0)** · 위 무변화 조건에서 뺐다

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

영상이 끝나면 다음 항목으로 자동 전환되고 **상위 목차(모듈) 경계까지 넘어간다.** 실측에서 모듈1 마지막 → 모듈2 첫 항목 → `평가하기`까지 클릭 없이 진행됐다. 수동 개입이 필요했던 지점은 **`평가하기` → `정리하기` 단 한 번**뿐이었다 — `평가하기`가 영상이 아닌 상호작용 페이지라 자동 전환되지 않기 때문이며, **퀴즈 풀이가 게이트인 것은 아니다**(아래 v1.1.5 정정).

⚠️ **단 영상이 아닌 상호작용 페이지(`평가하기`·`정리하기`)는 자동 전환되지 않는다.** 영상은 끝나면 넘어가지만 퀴즈 페이지는 멈춘다.

⚠️ **`평가하기`에서 `›`가 모달 없이 조용히 멈추는 일이 있다** — 잠금 모달이 뜨는 다른 경우와 달라
**클릭이 빗나간 것으로 오인하기 쉽다.** 헤더(`… | 평가하기`)가 그대로인지로 판정하고, 좌표를
의심해 반복 클릭하지 말 것.

⛔ **원인은 퀴즈 풀이가 아니다 — v1.1.4의 「퀴즈를 풀어야 넘어간다」는 틀렸다(v1.1.5 정정).**
실제 게이트는 **`평가하기` 자신의 완료 반영**이다. `평가하기`는 슬라이드형이라 **열람만으로 완료**되지만
그 완료가 서버에 반영되기까지 시간이 걸리고(「주차 목록의 완료 상태는 갱신이 지연된다」와 같은 현상),
**그 지연 동안 `›`가 조용히 막힌다.**

- **실증(2026-09-09 GitHub 2주차)** — 처음엔 `›`가 멈췄다. 잠시 뒤 강의실에 재진입하니 `평가하기`가
  이미 `완료`였고, **퀴즈를 한 문항도 풀지 않은 상태에서 `›`를 누르자 `정리하기`가 그대로 열렸다**
- → **`정리하기`로 넘어가는 데 퀴즈 풀이는 필요 없다.** `›` 막힘은 완료 반영 지연이므로 **기다렸다가 다시 시도**하거나,
  강의실에 재진입해 `평가하기`의 완료 표시를 확인한 뒤 다시 연다
- ⛔ **`›` 막힘을 풀려고 퀴즈를 누르지 않는다** — 채점은 이동 게이트를 여는 수단이 아니다
- ⭐ **퀴즈 채점은 이와 별개로 상시 정책에 따라 항상 수행한다**(v1.2.0 · 6단계) — 공식 정답·해설을 노트에 넣기 위해서다.
  순서는 **전 문항 채점·결과 회수·백업(`save`·`exportQuiz`) → `평가하기` 완료 반영 확인 → `›`로 `정리하기`**다
  (`›`는 사용자 지시·동행 수강 아래 — 채점 정책이 이동 권한을 주지는 않는다)
- ~~「막혔다 → 퀴즈를 풀어야겠다」로 넘어가지 말 것. 불필요하게 대신 푸는 경로로 빠지는 함정이다~~ — **폐기(v1.2.0)** ·
  채점은 이제 정책상 항상 하므로 「불필요한」 경로가 아니다. 남는 규칙은 바로 위 「이동 게이트를 풀려고 누르지 않는다」다

→ **수동 이동 수단은 플레이어 우하단의 `‹` `›` 화살표다.** 목차 패널에는 현재 상위 항목의 하위만 나오고 다른 상위 항목 링크가 없다. **강의실홈으로 되돌아갈 필요가 없다**(URL 항목만 예외 — 아래 절).

⛔ 넘기는 것도 수강 행위다 — **사용자 지시 없이 화살표를 누르지 않는다.**

### ⚠️ 플레이어를 통과하지 못하는 항목 유형이 있다 — URL만이 아니다

영상이 끝나고 다음이 **비영상 항목**이면 자동 전환이 멈추고 모달이 뜬다.
**모달 문구가 항목 유형을 그대로 말해 준다** — 유형별로 문구만 다르고 처방은 같다.

| 항목 유형 | 모달 문구 | 실측 |
|---|---|---|
| URL(외부링크) | 「다음 **URL 아이템**은 강의실홈 N주차에서 학습할 수 있습니다」 | 문제해결 1·2주차 |
| 멀티미디어보드(과제 제출형) | 「다음 **멀티미디어보드 아이템**은 강의실홈 N주차에서 학습할 수 있습니다」 | AWS 2주차 `모듈 1 지식 점검`(2026-09-09) |

⛔ **「URL 항목만 예외」로 외우지 말 것.** 문구의 `… 아이템은 강의실홈 …에서 학습할 수 있습니다`
패턴을 보고 **비영상 항목 일반의 신호**로 읽는다. 앞으로 다른 유형이 더 나올 수 있다.

→ 처방은 동일하다 — 플레이어를 닫고 **강의실홈에서 그 항목을 직접 클릭**한다.
  URL형은 새 탭으로 외부 사이트가 열리며 열람 완료 처리된다(뜬 탭은 닫는다).
  과제 제출형은 **제출이 사용자 본인의 행위**이므로 여는 것까지만 한다.

**실측 보강 (2026-09-09 문제해결프로그래밍입문 2주차 · URL 항목 6개 연속)**

- 플레이어 안에서 **뒤로(`‹`) 이동도 URL 항목에서 멈춘다** — 「이전 URL 아이템은 강의실홈
  2주차에서 학습할 수 있습니다」. 앞뒤 어느 방향이든 URL 항목은 플레이어를 통과하지 못한다
- 강의실홈에서 연속 클릭하면 **새 탭이 매번 생기지 않고 같은 탭이 재사용된다**(`target` 고정).
  탭이 6개 쌓일 것을 걱정할 필요가 없다
- **클릭 직후 목록은 여전히 `To do`로 보인다** — 완료 표시는 **강의실 재진입 후** 반영된다
  (「주차 목록의 완료 상태는 갱신이 지연된다」와 같은 현상). 표시를 보고 다시 누르지 말 것
- ⛔ **URL 항목 클릭은 출석에 집계되는 열람 행위다.** 되돌릴 수 없으므로
  **누르기 전에 사용자 승인을 받는다** — 몇 개를 왜 누르는지 함께 제시한다
- 항목이 **채점 대상 과제로 연결되는 경우**(교내 OJ 문제 등) 열람과 제출은 다르다.
  **여는 것까지가 스킬의 몫이고, 제출은 사용자 본인의 행위다**

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
- 자막 자체는 **항목을 열 수만 있으면 로드만으로** 전량 실린다(재생 완주 불필요)
- ⛔ **다만 「자막은 잠금과 무관하다」는 과잉 주장이다.** 여는 것 자체가 막히면 자막도 못 받는다.
  2026-09-09 문제해결프로그래밍입문 2주차 실측 — 강의실홈에서 `입력`을 직접 클릭했더니
  「동일주차내 '2주차내 (들어가기)' 아이템이 미완료입니다」로 **열리지도 않았다**
- **잠금의 강도는 주차의 완료 상태가 정한다** — 이미 완료된 주차(딥러닝 2주차)는 어느 항목이든 열려
  `›` 순회로 10개를 1분에 수확했고, 미완료 주차는 첫 항목부터 순서대로만 열린다

**⭐ 잠금의 입자는 「항목」이 아니라 「모듈」이다 (2026-09-09 GitHub포트폴리오 2주차 실측)**

미완료 주차에서도 **목차 패널(`.toc-row`)의 하위 항목 점프는 같은 모듈 안에서 자유롭다.**

- `들어가기` 모듈에 들어간 뒤 사이드바에서 `지난 주 복습` → `학습개요` → `학습에 앞서`로
  **연달아 점프해 자막 3건을 재생 없이 수확**했다 — 모달이 뜨지 않았다
- 반면 **모듈 경계는 앞 모듈이 미완료인 동안 막힌다** — 그 상태에서 `›`를 눌러도 넘어가지 않고
  「현재 콘텐츠 아이템의 학습 완료가 되지 않아 다음 콘텐츠 아이템으로 이동할 수 없습니다」가 뜬다
- ⭐ **앞 모듈이 완료되면 곧바로 열린다** — `들어가기`의 마지막 영상이 끝까지 재생되어 모듈이
  `완료`로 바뀐 직후, 강의실홈에서 다음 모듈(`Git 설치 및 설정 방법`)을 클릭하니 **모달 없이 열렸고**
  그 안에서 하위 2개를 다시 자유롭게 점프해 자막을 받았다

→ **미완료 주차에서 재생 없이 얻을 수 있는 것은 「현재 열려 있는 모듈의 하위 전량」까지다.**
  그 다음 모듈로 가려면 앞 모듈을 **실제로 완료**해야 한다(4분 초과 항목은 50% 시청).
  즉 **모듈 단위로 「완료 → 무료 수확 → 완료 → 무료 수확」이 반복**된다.

- ⛔ 따라서 **미완료 주차의 자막 수확은 부분 수확으로 끝날 수 있다.** 8단계 보고에
  「확보 N건 / 잠금으로 미확보 M건」을 반드시 구분해 적고, 미확보분을 확보한 것처럼 쓰지 않는다
- 잠금 모달의 문구는 **직전 항목만 지목한다** — 문제해결 2주차에서 `평가하기`를 눌렀을 때
  앞의 6개 URL 항목이 전부 미완료였는데도 메시지는 바로 앞의 `B15552 문제풀이`만 지목했다.
  **메시지에 적힌 항목 하나만 처리하면 된다고 읽지 말 것** — 그 앞도 전부 밀려 있다
- ⛔ **AWS·GitHub는 1주차 첫 항목이 「과목 공지 읽고 게시판 글 1개 이상 작성」이다.**
  이 항목을 완료하기 전에는 어떤 강의도 열리지 않는다.
  **게시판 글 작성은 사용자 본인이 한다** — 대신 쓰지 않는다.
  대신 **과목공지를 읽어 요약과 초안을 제공**할 수는 있다 (`collect-week` 참조)

### ⭐ 표준 절차 — 주차 완료 상태로 경로가 갈린다

**먼저 그 주차가 완료됐는지 본다.** 두 경로는 비용이 10배 이상 차이 난다.

| 주차 상태 | 경로 | 비용 |
|---|---|---|
| **완료** | 플레이어를 열고 `›`로 순회하며 항목마다 수확 | 항목당 5~10초 (딥러닝 2주차 10개 ≈ 1분) |
| **미완료** | **사용자와 함께 재생하며 동행 모니터링** | 실제 수강 시간 |

- **완료 주차의 학습평가** — 스크립트에 공식 정답(채점 기록)이 없으면 `평가하기`를 열고 **헬퍼를 먼저 (재)정의**한 뒤 `__scuQuiz.res(k)`(또는 `probe()`·`next()`)로
  **채점 상태부터 읽는다**(옛 헬퍼는 교체된 문서를 계속 본다 — `probe().stale`). 이미 채점돼 있으면 읽기만 하고(`save(k)`), 초기화돼 있으면 채점 루프를 탄다
  (재오픈하면 **과거 선택(`.selected`)은 남고 `data-passyn`·정답 행만 초기화**된다 — 2026-09-14 딥러닝 3주차 1회 + 2026-09-17 문제해결 1주차·딥러닝 1주차·GitHub 1주차 3회. 본 결과를 8단계에 적는다).
  완료 주차의 `평가하기`는 **스킬이 직접 연다**(행이 이미 `완료`라 진도 변화가 없다 · 「⛔ 절대 하지 말 것 4」 ②) — 미완료 주차의 `평가하기`는 사용자 수강 흐름으로만 연다

#### 미완료 주차의 표준 방식 — 「같이 보며 자동 전환을 따라간다」

⛔ **잠금을 우회하려 하지 말 것.** 건너뛰기·직접 클릭은 모달로 막히고, 시도할수록 오클릭 위험만 는다.

1. **첫 항목부터 순서대로** 연다 (엄격 과목은 이것 말고 다른 진입점이 없다)
2. 슬라이드형(`학습개요` 등)은 **열람만으로 완료**되어 다음 항목을 연다 — 여기서 채록도 함께 한다
3. 영상 항목은 **재생한다.** 사용자가 함께 수강하는 동안 스킬은 **읽기만** 한다
4. 영상이 끝나면 **자동으로 다음 항목으로 전환**된다 — 그 전환을 따라가며 항목마다 자막을 수확한다
5. 모니터링은 **영상 길이에 맞춘 간격**으로 배경 대기를 걸고 주기적으로 수확·보고한다
   (10분 이하 단위로 끊어 걸면 연결이 끊겨도 유실이 적다)
6. `평가하기`·`정리하기`는 주차 마지막이라 **앞 영상을 모두 완료해야 도달**한다
7. **`평가하기`에 도달하면 6단계 「학습평가 자동 채점 루프」를 실행한다**(상시 정책 — 사전 채록 `scan` → 문항별 `pick`/`fill` → `selNo`/`sel` → `conf` → `save` → `exportQuiz`).
   감시 크론은 내려 두고, 채점 전에 문항별 선택 답·근거 표를 한 번 제시한 뒤 기다리지 않고 진행한다.
   **표를 제시하는 같은 메시지에서 「지금부터 학습평가를 채점하니 퀴즈 화면은 누르지 말아 달라」고 알린다**(승인 대기는 하지 않는다 — 동행 수강 중 사용자 조작과 겹치지 않게 하려는 것이다)
8. 채점이 끝나면 결과를 사용자에게 알린다. `›`로 `정리하기`를 여는 것은 **사용자 지시(동행 수강을 맡긴 세션 지시 포함) 아래에서만** 한다 —
   채점을 마쳤다는 사실은 `›`를 누를 근거가 아니다(「⛔ 절대 하지 말 것 4」 · 6단계 「8. 상위 항목 간 이동」 — 채점 정책은 `›` 권한을 주지 않는다).
   열리면 **`__scuSummary()`로 채록**한다
   (`›`가 조용히 막히면 반복 클릭하지 말고 완료 반영을 기다린다 · 3단계 「자동 전환은 모듈 경계도 넘는다」)

- ⚠️ **수강은 사용자 본인의 행위다.** 이 절차는 사용자가 함께 볼 때만 쓴다 —
  혼자 돌려놓고 진도를 쌓는 용도가 아니다
- 자막·채록물은 매 수확마다 `localStorage`에 자동 백업되므로 **연결이 끊겨도 유실되지 않는다**

#### ⚠️ 유휴 세션 종료 — `.eco-popup` (2026-09-14 딥러닝 3주차 실측)

한동안 조작이 없으면 **플레이어 iframe 안에** 팝업이 뜬다.

> 장시간 사용하지 않아 학습을 종료합니다. 다시 접속 하여 주시기 바랍니다.

- 화면이 그대로 보여도 **학습 세션은 이미 끝난 것**이다 — 이 상태의 조작(퀴즈 선택·`정답확인`·`›`)은 **기록되지 않을 수 있다**
- ⛔ 팝업을 닫고 그 자리에서 이어 가지 말 것 → **사용자에게 항목을 다시 열어 달라고** 한다(여는 것은 사용자의 수강 행위다).
  이때 **「감시 중인 그 탭에서」 열어 달라고 함께 말한다**(바로 아래 절)
- ✅ **상태를 바꾸는 조작 전에는 매번 먼저 검사한다** — 6단계 `__scuQuiz`는 이 함수가 없으면 정의를 거부하고, 팝업이 떠 있으면 조작을 거부한다
- 판정은 **「보이는 `.eco-popup`」 + 문구**로 한다. 팝업이 평소에도 숨김 상태로 DOM에 있는지는 확인하지 못했으므로 클래스 존재만으로 판정하지 않는다
  - 「보이는」은 `getBoundingClientRect` 크기로 본다. **탭 hidden일 때만 계산 스타일(문서 안 조상 포함 — `display:none`·`visibility:hidden`)로 보완**한다(v1.2.0) — 탭 hidden이면 rect가 0으로 나오기 때문이다(2026-09-17 실측).
    visible 탭에서의 판정은 그전과 같다(전환 로거도 같은 함수를 쓴다)
- ⚠️ **`null`은 탭이 visible일 때만 「팝업 없음」의 확실한 증거다** — hidden 탭은 rect가 0이라 위 보완(계산 스타일)에 기댄다.
  그래서 상태를 바꾸는 조작은 헬퍼 `guard`가 **탭 hidden을 먼저 거부**한다(6단계 `__scuQuiz`)

```javascript
window.__scuIdle = function () {
  const docs = [];
  (function collect(d) { docs.push(d);
    [...d.querySelectorAll('iframe')].forEach(f => {
      try { if (f.contentDocument) collect(f.contentDocument); } catch (e) {}
    });
  })(document);                                         // ⚠️ 매번 새로 순회한다 — iframe이 교체된다
  for (const d of docs) for (const p of d.querySelectorAll('.eco-popup')) {
    const r = p.getBoundingClientRect(), t = (p.textContent || '').replace(/\s+/g, ' ').trim();
    // 탭 hidden이면 rect가 0으로 나온다(2026-09-17) — 그때만 문서 안 조상까지 계산 스타일로 판정한다(자기 요소만 보면 숨은 조상을 놓친다)
    const styled = () => { const W = d.defaultView; if (!W) return false;
      for (let e = p; e; e = e.parentElement) { const c = W.getComputedStyle(e); if (c.display === 'none' || c.visibility === 'hidden') return false; }
      return true; };
    const shown = (r.width && r.height) || (document.visibilityState !== 'visible' && styled());
    if (shown && /장시간 사용하지 않아/.test(t)) return t;   // 보이는 팝업만
  }
  return null;
};
window.__scuIdle()      // null이 아니면 중단 → 사용자에게 같은 탭에서 재오픈 요청
```

#### ⚠️ 사용자가 다른 창·탭에서 다시 열면 보이지 않는다

- Chrome MCP(`claude-in-chrome`)는 **자기 탭 그룹 안의 탭만** 본다. 사용자가 유휴 종료 뒤 **다른 창이나 새 탭에서** 강의실을 다시 열면
  그 탭은 그룹 밖이라 `tabs_context_mcp`에 나오지 않고, 읽기·수확은 **낡은 원래 탭**을 계속 향한다
- 수집기(`__scuTick` 등)와 페이지 메모리는 **원래 탭에만** 있다. localStorage 백업은 같은 오리진이라 새 탭에서도
  `__scuRestore()`로 복원되지만, 새 탭에는 **수집기가 걸려 있지 않다**
- ✅ **재오픈을 부탁할 때 「지금 감시 중인 탭에서 열어 달라」고 명시한다** — 이미 다른 곳에서 열었다면 그 탭을 닫고 감시 탭에서 다시 열어 달라고 한다
- 어느 창·탭이 무엇인지 헷갈리면 `osascript`로 Chrome의 창·탭 목록을 본다(읽기 전용). 강의실 탭만 걸러 **다른 탭의 제목·주소를 맥락에 싣지 않는다**

```bash
osascript <<'EOF' | grep 'iscu\.ac\.kr'
set sep to " | "
tell application "Google Chrome"
  set out to ""
  repeat with w from 1 to count of windows
    set wi to window w
    repeat with t from 1 to count of tabs of wi
      set tb to tab t of wi
      set mark to ""
      if t = (active tab index of wi) then set mark to "*"
      set out to out & w & ":" & t & mark & sep & (title of tb) & sep & (URL of tb) & linefeed
    end repeat
  end repeat
  return out
end tell
EOF
```

- 출력은 `창:탭[*=그 창의 활성 탭] | 제목 | URL`이다(실측 `1:8* | 서울사이버대학교 | https://home.iscu.ac.kr/…`)
- ⚠️ `tell application "Google Chrome"` 블록 안에서 **`tab`은 탭 문자가 아니라 Chrome의 탭 객체**로 해석된다 —
  구분자로 `tab`을 쓰면 글자 `tab`이 박히고 필터가 깨진다(실측). 구분자는 **블록 밖에서 문자열로** 정한다

### ⚠️ 주차 목록의 완료 상태는 갱신이 지연된다

수강 직후에도 `To do`로 보이다가 나중에 반영된다. 실제 상태는 **강의실 재진입 후** 읽는다. 지연된 표시를 보고 "진도가 안 쌓였다"고 단정하지 말 것.

### ⚠️ 짧은 항목은 5분 틱 사이를 그냥 지나간다

1~2분짜리 항목은 두 틱 사이에 시작하고 끝나 **길이를 관측하지 못한다**(GitHub `학습개요` 48초에서 실제 발생 — 순번 규칙으로만 배정할 수밖에 없었다).

- 현재 영상의 남은 시간과 **다음 항목의 예상 길이**를 보고, 짧을 것 같으면
  `computer wait`를 10초씩 이어 붙여 **틱 중간에 한 번 더 확인**한다
- 놓쳤으면 규칙으로 배정하되 **"길이 직접 미확인"으로 표기**한다 — 확인한 것처럼 적지 않는다

### 변화 없는 틱이 길게 이어지면

사용자가 자리를 비우거나 영상이 아닌 항목에서 멈추면 움직이지 않는 지점이 생긴다. 3~4틱 연속 무변화면 **루프를 내려두고 사용자가 돌아올 때 다시 거는 것**을 제안한다. 진행 상태는 스크립트와 과목 `CLAUDE.md`에 이미 있으니 잃을 것이 없다.

- **`평가하기` 도달로 멈춘 것이면 기다리지 않는다** — 루프를 내리고 6단계 「학습평가 자동 채점 루프」로 전환한다(상시 정책 v1.2.0)
- ~~퀴즈 대기처럼 사용자 입력이 없으면 움직이지 않는 지점이 있다~~ — **폐기(v1.2.0)** · 퀴즈는 더 이상 사용자 입력 대기 지점이 아니다

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
| **학습개요** | ⚠️ **과목마다 다르다 — 실물로 판별한다.** 딥러닝은 **32초 영상**(MP3 있음), 빅데이터분석실무는 **슬라이드**(MP3 없음) | 영상이면 `## (N)` 부여 + 자막 수확 · 슬라이드면 번호 없이 기록 + **본문 채록** |
| **생각해보기** | 과목에 따라 **영상일 수도, 슬라이드일 수도** 있다 | `<video>` 유무로 판별 |
| **학습평가** | 퀴즈 페이지, `<video>` 자체가 없음 | 번호 없이 기록 + **채록 + `정답확인` 채점 필수**(공식 정답 행·공식 해설 원문 회수 · 6단계) |
| **학습정리** | 요약 슬라이드, `<video>` 없음 | 번호 없이 기록 + **채록 필수** |

**판별은 이름이 아니라 실물로 한다.** `학습개요`가 어느 과목에선 슬라이드지만 `생각해보기`는 빅데이터분석실무에서 **86초 영상이고 `_01`이었다.** 이름만 보고 "부속 항목이니 MP3 없겠지"라고 넘기면 순번이 밀린다.

```javascript
// MP3 없는 항목 판정: 영상이 없거나, 있어도 랜덤 인트로면 MP3 없음
const noMp3 = !v || /doRandomIntroMedia/.test(v.src);
```

> 첫 MP3를 목차 첫 줄에 기계적으로 붙이면 **전체가 한 칸씩 밀린다.** 반드시 길이로 확인할 것.

## 6단계: 학습평가 채점·채록 · 학습정리 채록 — 유일한 경로

두 구역은 **슬라이드형이라 자막도 MP3도 없다.** 자막이 본문 정본이 된 뒤에도 이 구역만은 **DOM 채록만이 유일한 경로**이며, 오히려 근거가 강해졌다 — 지금 받아두지 않으면 강의노트를 완성할 수 없다.

⭐ **학습평가는 매번 `정답확인`을 눌러 채점하고, 공식 정답(정답 행)과 공식 해설 원문을 스크립트에 기록한다**(사용자 상시 정책 2026-09-17).
과목·유형에 따라 채점 전 DOM에 정답 표기가 없어서(문제해결 O/X) **누르지 않으면 추정만 남기 때문이다 — 추정 표기는 사용자가 거부했다.**
적용 범위는 CLMS `평가하기`/`학습평가` 한정이다(「⛔ 절대 하지 말 것 4」). 실행 절차는 아래 「⚠️ 퀴즈 자동 채점」 절이다.

⚠️ **유형 판별이 먼저다.** `<video>`가 있으면 자막(정본) → MP3 전사 순으로 본문을 얻고, `<video>` 자체가 없을 때만 이 절의 채록 경로로 간다. 이름으로 유형을 단정하지 않는다.

- **학습개요** — 슬라이드. `학습목표`·`학습내용`이 있고 강의노트 `## 학습개요`의 정본이 된다.
  4분 이하라 **열면 완료되는 항목**이므로 사용자 동의 후에 연다
- **학습평가** — 퀴즈 페이지. **이동에는 풀이가 필요 없다** — `평가하기`는 열람만으로 완료되고, 반영되면 풀지 않아도 `›`로 `정리하기`가 열린다
  (2026-09-09 GitHub포트폴리오 2주차 실증 · 3단계 v1.1.5 정정). 채점은 이동과 별개로 아래처럼 **항상** 한다.
  - ① ⭐ **기본은 전 문항 채점이다(사용자 상시 정책 2026-09-17)** — 건별 지시가 필요 없다
  - ② 클릭 전에 문항·보기·`[data-field="explanation"]`을 **사전 채록**한다(`scan()` · 아래 「⭐ 사전 채록」)
  - ③ 답은 **근거 순**으로 정한다 — 채점 전 정답 라벨(`정답① ○` 꼴) → 자막·교안·`학습정리` → 그래도 없으면 **첫 보기**를 고르고
    **「근거 없음 — 첫 보기」로 보고**한다. 앞의 근거를 끝까지 찾은 뒤에만 첫 보기로 가고, 찍었다는 사실을 숨기지 않는다.
    **주관식은 첫 보기가 없다** — 라벨·자막·교안 근거가 없으면 입력·채점하지 않고 `정답 미확보(주관식·근거 없음)`로 보고한다. 지어낸 문자열로 채점하지 않는다
  - ④ **선택 → 그 문항 `.item-select-option-no.selected` 확인 → `정답확인`**을 각각 별도 호출로 한다(아래 4-B)
  - ⑤ **정답 행**(`.passed-answer`/`.failed-answer` — 둘 다 정답 행) · `data-passyn` · **해설 원문**을 회수한다(`save(k)`)
  - ⑥ 스크립트에는 **공식 값만** 적는다 — ⛔ 「(추정)」 금지. 회수하지 못한 문항은 `정답 미확보(사유)`(7단계 형식)
  - 이 퀴즈는 배점 항목이 아닌 **형성평가**다. 그래도 채점 기록은 강의실 학습 이력에 남고 되돌릴 수 없으므로,
    채점한 문항과 그 결과(`Y`/`N`)·근거 없음 선택·좌표 클릭 전환은 **8단계 보고에 반드시 포함**한다
  - ~~기본은 문항만 채록하고 답을 클릭하지 않는 것이다 — 퀴즈 풀이는 사용자 본인의 행위다. 사용자가 답을 알려주면 정답·해설을 스크립트에 적어둔다~~ ·
    ~~사용자가 명시적으로 대신 풀라고 지시하면 … 진행한다 — 찍지 않는다~~ ·
    ~~노트 작성도 … 대신 풀 이유가 되지 않는다 — 정답·해설은 처음부터 들어 있어 클릭 없이 회수된다~~ ·
    ~~대신 푸는 것은 사용자가 풀이 자체를 명시적으로 맡긴 때뿐~~ — **폐기(v1.2.0)** · 사용자 상시 정책(2026-09-17).
    라벨 없는 유형(문제해결 O/X)은 클릭 없이 정답이 회수되지 않았다. 「진도·이동은 채점의 이유가 되지 않는다」는 그대로 유효하다

  ⚠️ 퀴즈 DOM은 `maui-component` 커스텀 컴포넌트이고 **`el.click()` 단독으로는 반응하지 않는다** — 플레이어 열기와 같은 계통이다.
  `pointerdown` → `mousedown` → `pointerup` → `mouseup` → `click`을 **해당 iframe의 `defaultView`에서 만들어** 대상과 부모 양쪽에 발사하는 방식이
  **2026-09-08·09에는 동작했다**(아래 「퀴즈 자동 채점」 절).

  ⛔ **그러나 보장되지 않는다.** 2026-09-14 딥러닝 3주차 O/X에서는 같은 합성 이벤트가 **선택을 등록하지 못했고**,
  선택을 확인하지 않고 같은 호출에서 `정답확인`까지 눌러 **빈 답안이 오답(`data-passyn="N"`)으로 채점**됐다.
  실제 마우스 클릭(좌표)으로는 등록됐다.
  → **선택 후 그 문항 컨테이너의 `.item-select-option-no.selected`를 확인한 뒤에만 `정답확인`을 누른다.**

  ⛔ **전 문항을 `forEach`/`for await`로 한 번에 처리하지 말 것** — 빈 결과가 돌아온다(실측). 선택·선택 확인·채점·결과 회수를 **문항마다 별도 동기 호출**로 나눈다.
  ⛔ **버튼을 `정답확인` 텍스트로 고르지 말 것** — 버튼이 문항당 2개(`정답확인`·`다시풀기`)라 이미 채점된 문항의 버튼도 계속 매치되어 항상 1번 문항을 누른다.
  **문항 컨테이너 안의 버튼(첫 번째 = `정답확인`, 첫 실행 때 확인)**으로 매핑한다 — 전역 `btns[2k]`는 버튼 수가 문항 수 × 2일 때만 쓰는 폴백이다
  (~~위치 인덱스로 매핑한다~~ — v1.1.9까지의 주 경로 · v1.2.0에서 폴백으로 낮춤).

  문항 유형에 따라 셀렉터 계열이 갈리므로 **실물을 먼저 조회해 분기한다.**

| 유형 | 선택지 | 버튼 | 정답 표기 (채점 전 DOM `[data-field="explanation"]`) |
|---|---|---|---|
| 번호 배지형 객관식 | `.maui-component-type-item` 안의 `.item-select-option-no` — `.item-option-row`(행 전체) 클릭은 **아무 일도 하지 않는다** | 항목 안에서 탐색 | `정답③ …` (번호 + 보기) |
| O/X형 (GitHub·딥러닝) | `div.component-data-field` 중 `textContent`가 `O`/`X` (`input` 0개) · 번호 배지 `.item-select-option-no`도 2개 있다(`1`=O · `2`=X) — `.item-option-row` 클릭은 **무반응**(3주차) | `span.maui-border-button` | `정답① ○` (딥러닝은 `정답① O`) |
| **O/X형 (문제해결프로그래밍입문 3주차 6문항)** | 번호 배지 2개(`1`=O · `2`=X) — 선택·`정답확인` 모두 **스크린샷 좌표의 실제 클릭**으로 했다 | 문항 컨테이너 안 `span.maui-border-button` `[정답확인, 다시풀기]` | ⛔ **정답 라벨 없음.** 해설 문장은 **거짓 진술(2·4·5)에만** 있고 참 진술(1·3·6)은 `innerHTML`부터 비어 있으며 **채점 후에도 비어 있다** → 정답은 **채점 후 정답 행으로만** 확정된다 (2026-09-17) |
| **주관식 단답형** | **선택지 없음** (`.item-select-option-no` 0개) · 입력은 `[contenteditable]` | `span.maui-border-button` | `정답git status` (번호 없이 값만) |

- ⭐ **정답 표기 열이 비는 유형이 있다** — 「라벨이 있겠지」라고 가정하고 채점 전 DOM만 읽으면 문제해결 O/X에서는 **정답이 하나도 나오지 않는다.**
  공식 정답의 정본은 유형과 무관하게 **채점 후 정답 행**이다(아래 「⭐ 공식 정답의 정본」)
- **선택이 등록됐는지의 근거는 유형과 무관하게 하나다** — 그 문항 컨테이너의 `.item-select-option-no.selected`(주관식은 `[contenteditable]`의 값).
  이벤트 발사 함수가 `true`를 돌려준 것은 **증거가 아니다**

⛔ **한 퀴즈 안에 유형이 섞인다 — 「이 퀴즈는 O/X형」처럼 통째로 단정하지 말 것.**
GitHub포트폴리오 2주차는 12문항이 **4지선다 6 · O/X 4 · 주관식 2**로 혼재했다(2026-09-09 실측).

⛔ **따라서 전역 인덱스 공식(`opts[n*k+(i-1)]`)은 혼재 퀴즈에서 깨진다.**
선택지 수 `n`이 문항마다 다르기 때문이다. **문항 컨테이너(`[data-type="item"]`) 안에서
그 문항의 선택지만 다시 조회**하는 방식으로 매핑한다 — 유형 판별도 그 안에서 하면 된다.

```javascript
const it   = [...d.querySelectorAll('[data-type="item"]')][k];   // k번째 문항
const opts = [...it.querySelectorAll('.item-select-option-no')]; // 그 문항의 선택지만
const type = opts.length === 0 ? '주관식' : opts.length === 2 ? 'O/X' : '객관식';
```

  → 실행 코드는 아래 「⚠️ 퀴즈 자동 채점 — 상시 정책 · 문항 컨테이너 · 선택 확인 · 동기 분할」 절에 있다.

#### 보조 — 텍스트 스냅샷에서 정답·해설 라벨 읽기 (⚠️ `정답확인`을 기준으로 자르지 말 것)

> 이 절은 **텍스트 스냅샷 대조용 보조 경로**다. 공식 정답의 주 경로는 DOM 기반 `__scuQuiz.res(k)`의 **정답 행**이다(아래 「⭐ 공식 정답의 정본」).
> 정답 라벨이 텍스트에 **아예 없는 유형**(문제해결 O/X)이 있으므로, 이 정규식이 정답을 못 찾는 것은 실패가 아닐 수 있다.

채점하면 **`정답확인` 버튼의 텍스트가 사라진다.** 그래서 `indexOf('정답확인')` 기준으로 뒤를 잘라내면 `-1`이 나와 **"해설 없음"으로 오판한다**(2026-09-01 실제 사고 — "이 과목은 정답을 표시하지 않는다"고 사용자에게 잘못 보고했다).

**`정답` / `해설` 라벨 자체를 정규식으로 잡는다.** 단 아래 두 결함을 반드시 함께 막는다.

⚠️ **반대 방향의 오매치 버그** — 부정 전방탐색이 없으면 버튼 텍스트 `정답확인`을 정답으로 읽는다(실측 오탐 `정답:"확인"`). 위 절단 버그와 **같은 토큰을 둘러싼 반대 실패**이며, 한쪽만 고치면 다른 쪽에 걸린다.

⚠️ **정답과 해설을 한 패턴에 묶지 말 것** — 해설을 필수로 만들면 해설 없는 문항에서 매치 전체가 실패해 **정답까지 `?`로 나온다.**

```javascript
const RE_ANS  = /(?:^|\n)[ \t]*정답(?!\s*확인)[ \t]*[:：][ \t]*(.+)/;   // 부정 전방탐색 필수
const RE_ANS2 = /(?:^|\n)[ \t]*정답(?!\s*확인)[ \t]*\n[ \t]*(.+)/;      // 라벨과 값이 줄바꿈으로 갈릴 때
const RE_EXP  = /(?:^|\n)[ \t]*해설[ \t]*[:：]?[ \t]*([\s\S]+?)(?=\n[ \t]*(?:Quiz\.|문제[ \t]*\d|Self[ \t]*Check|정답|다시풀기|정답확인)|$)/;
```

→ 문항 번호(`Quiz.01`·`Self Check 01.` 형식 포함) 분할까지 붙인 완성본은 아래 「퀴즈 자동 채점」 절 5번에 있다.

- 채점 직후에는 렌더가 늦을 수 있다 → **3~4초 기다린 뒤** 읽는다
- ⚠️ **해설이 붙는 규칙은 퀴즈 유형마다 다르다 — 과목 공통이 아니다**
  - **O/X형** — 거짓 진술 문항에만 해설이 붙고 참 진술은 정답만 나온다(딥러닝 2주차 Q1·Q4 거짓=해설 / Q2·Q3 참=없음, 문제해결 1주차 동일)
  - **O/X형 — 문제해결프로그래밍입문** — **정답 라벨 자체가 없다.** 해설 문장은 거짓 진술(3주차 2·4·5번)에만 있고,
    참 진술(1·3·6번)은 채점 전 `innerHTML`부터 비어 있으며 **채점 후에도 비어 있다**(2026-09-17 6문항 실측).
    채점 후 거짓 진술 해설만 `display:block`이 된다
  - **번호 배지형 객관식** — **전 문항에 해설이 붙는다**(빅데이터분석실무 2주차 4문항 전수 실측)
  - ⛔ 2026-09-08에 이를 「과목 공통 패턴」으로 적었다가 다음 날 4지선다에서 반증됐다. **유형을 먼저 판별한 뒤 규칙을 적용할 것**
- ⛔ **빈 해설을 "추출 실패"로 오판하지 말 것.** 해설 공백은 정상이며 문항의 진위와 결부돼 있다
- ⛔ **정답 라벨이 없다고 비공개 과목인 것은 아니다** — 문제해결 O/X처럼 라벨이 원래 없는 유형이 있다.
  **`정답확인` 후 정답 행(`.passed-answer`/`.failed-answer`)에서 회수한다**
  - ~~정답 라벨까지 없을 때만 "비공개"를 의심한다~~ **폐기(v1.2.0)** — 라벨 부재는 비공개의 증거가 아니었다(2026-09-17 문제해결 3주차: 라벨 0 · 채점 후 정답 행 6/6)
- 기록은 스킬이 고른 답이 아니라 **강의실이 표시한 공식 값**으로 한다. 둘이 다르면 그 사실을 함께 적는다

#### ⭐ 사전 채록 — 클릭 전에 문항·보기·해설 원문을 받는다 (답 선택 근거·대조용 · 공식 정답의 정본은 채점 후 정답 행)

> ⛔ **폐기(v1.2.0)** — v1.1.4~v1.1.9의 이 절 제목 「정답·해설은 처음부터 DOM에 있다 — **누르지 않고 전량 채록한다**」와
> 「따라서 「대신 풀어야 정답을 얻는다」는 정당화는 성립하지 않는다 … 풀이는 사용자에게 남긴다」는
> **사용자 상시 정책(2026-09-17 — 학습평가는 매번 정답확인해 공식 정답·해설을 노트에 넣는다)**으로 폐기됐다.
> 사전 채록 자체는 그대로 한다 — 다만 **정답 라벨이 없는 유형**(문제해결 O/X)이 있어 공식 정답은 **채점 후 정답 행**으로 확정한다.

**2026-09-09 GitHub포트폴리오 2주차 실측 (12문항) — 라벨 있는 유형의 사전 채록 근거다.**

문항 컨테이너 안 **`[data-field="explanation"]`에 정답과 해설이 이미 들어 있다**(라벨 있는 유형).
`display:none`으로 숨겨져 있을 뿐이고, `정답확인`은 그것을 **보이게 만들 뿐**이다.

```javascript
// 아무것도 클릭하지 않은 상태에서 전 문항의 문항·보기·해설 원문을 받는다 (헬퍼의 scan()과 같은 계산)
[...d.querySelectorAll('[data-type="item"]')].map((it, k) => {
  const ex = (it.querySelector('[data-field="explanation"]')?.textContent || '')
               .replace(/\s+/g, ' ').trim();
  // 「정답…해설…」 한 덩어리로 붙어 나온다 · ⚠️ 해설은 선택 — 참 진술 O/X(딥러닝)는 `정답① O`만 있다
  const m = ex.match(/^정답\s*(.*?)(?:\s*해설\s*(.*))?$/);
  return {
    no: k + 1,                              // 문항 번호(1부터)
    q:    (it.querySelector('[data-field="question"]')?.textContent || '').replace(/\s+/g,' ').trim(),
    stmt: (it.querySelector('[data-field="example"]')?.textContent || '').replace(/\s+/g,' ').trim(),   // 딥러닝 O/X — question은 공통 지시문, 진술은 example
    opts: [...it.querySelectorAll('.item-option-row')]
             .map(r => (r.textContent || '').replace(/\s+/g,' ').trim()),
    labeled:     !!m,                       // 라벨 없는 유형(문제해결 O/X)은 false
    answer:      m ? m[1] : null,           // ⛔ 라벨이 없으면 null — 해설 문장을 정답 칸에 넣지 않는다
    explanation: m ? (m[2] || '') : ex,     // 라벨이 없으면 원문 전체가 해설(참 진술이면 빈 문자열)
  };
});
```

- ⛔ **v1.1.9까지의 코드 결함(v1.2.0 수정)** — `answer: m ? m[1] : ex, explanation: m ? m[2] : ''`는
  라벨이 없는 유형에서 **해설 문장을 `answer` 칸에 넣고**, 참 진술이면 `answer`를 **빈 문자열**로 두었다.
  그 값이 그대로 「(추정)」의 근거로 쓰일 수 있었다. 또 해설을 필수로 둔 정규식이라 `정답① O`만 있는 참 진술은
  라벨이 있는데도 매치에 실패했다(위 「정답과 해설을 한 패턴에 묶지 말 것」과 같은 함정)
- ⭐ **클릭 없이 받아진다** — 12문항 전량을 `정답확인` 한 번 누르지 않고 채록했고,
  그때 모든 문항의 `data-passyn`은 `null`(미채점)이었다
- **라벨이 있는 유형은 사전 정답(`answer`)을 `pick`의 근거로 쓴다** — 그리고 채점은 그대로 한다(상시 정책).
  사전 채록은 채점을 대신하지 않는다
- 4지선다는 `정답③ …`처럼 **번호가 붙고**, O/X는 `정답① ○`, 주관식은 `정답git status`처럼
  **번호 없이 값만** 나온다
- ⚠️ **문제해결 O/X는 정답 라벨 없이 해설 문장만 있다**(거짓 진술에만) — `labeled: false`가 정상이며,
  해설이 있다는 사실을 「거짓 진술이니 X」로 읽어 답을 정하는 것은 **추정**이다. 공식 정답은 채점 후 정답 행이다
- ⚠️ **`정답`과 `해설` 사이에 구분자가 없다** — 위 정규식처럼 `해설` 라벨을 경계로 쪼갠다

**✅ 검증됨 — 사전 채록한 정답이 채점 결과와 완전히 일치한다(2026-09-09)**

같은 퀴즈를 **클릭 전에 채록**해 두고, 나중에 사용자 지시로 **실제로 12문항을 풀어** 대조했다.

| 항목 | 결과 |
|---|---|
| 채점 결과 | **12/12 `data-passyn="Y"`** (주관식 2문항 포함) |
| 객관식 10문항 | 사전 채록 정답 번호 = 채점 후 `.passed-answer` 행 — **10/10 일치** |

→ **라벨 있는 유형에서 사전 채록값은 답 선택 근거로 신뢰해도 된다(검증됨).** 노트의 공식 정답은 **채점 후 정답 행**으로 확정한다.

- **딥러닝 3주차 O/X 3문항(2026-09-14)도 3/3 일치** — Q2·Q3는 `passed-answer` 행, 빈 답안으로 채점된 Q1은
  `failed-answer` 행이 사전 채록 정답(`① O` · `② X` · `② X`)과 같았다
- ~~누르지 않고 채록한 값으로 노트를 써도 안전하다~~ **폐기(v1.2.0)** — 라벨 없는 유형이 확인됐고(문제해결 O/X), 사용자 정책이 공식 정답·해설을 매번 채점으로 확정하도록 바뀌었다

> ⛔ **v1.1.3의 「정답·해설은 `정답확인` 이후에만 렌더된다」는 틀렸다.** 그때는
> `[data-field="explanation"]`을 조회하지 않고 `[data-field="solution"]`·`commentary`만
> 찾아보고 없다고 판단했다. **없는 게 아니라 다른 이름이었다.**

#### ⭐ 공식 정답의 정본 — 채점 결과 마커

`정답확인` 후 문항 컨테이너에 붙는 마커가 **노트에 적는 공식 정답의 근거**다. 헬퍼 `__scuQuiz.res(k)`가 한 번에 읽는다(아래 「퀴즈 자동 채점」).

> ~~참고 — 채점 결과 마커 (직접 풀 때만 의미가 있다)~~ · ~~사용자가 명시적으로 대신 풀라고 지시해 실제로 클릭한 경우~~ —
> **폐기(v1.2.0)** · 사용자 상시 정책(2026-09-17)으로 학습평가는 매번 채점하므로, 이 마커가 공식 정답의 정본이 됐다.

| 대상 | 근거 | 의미 |
|---|---|---|
| 정답 보기 (내 답이 맞았을 때) | `.item-option-row`에 **`passed-answer`** 클래스 | 그 행이 정답이다 |
| 정답 보기 (내 답이 **틀렸거나 비었을 때**) | `.item-option-row`에 **`failed-answer`** 클래스 | **그 행이 정답이다** (2026-09-14 딥러닝 3주차) |
| 채점 결과 | `[data-type="item"]`의 **`data-passyn`** (`Y` 또는 `N`) | 내가 고른 답의 정오 |
| 내가 고른 보기 | 그 행 안 `.item-select-option-no`에 `selected` | 선택 상태 |

- 이 **마커들은 `정답확인`을 눌러야 생긴다**(미클릭 문항엔 부재, 실측)
- ⭐ **`정답확인` 후 정답 행(`.item-option-row.passed-answer, .item-option-row.failed-answer`)의 보기 텍스트(`res(k).official`)와 번호(`officialNo`)가 노트에 적는 공식 정답이다.**
  사전 채록값과 다르면 **이 값을 쓰고** 불일치를 스크립트에 기록한다
  - ⚠️ 행의 `textContent`에는 **번호 배지가 붙어 나온다**(`1O` · `2X` · `2데이터의 신속성` — 요소 사이에 공백이 없다). 헬퍼는 배지를 뺀 보기 텍스트(`optText`)를 돌려준다(v1.2.0)
  - **사전 라벨과의 대조는 번호끼리** 한다 — 라벨 번호는 `①`~`⑩`(O/X·GitHub) 또는 `N번`(빅데이터 실측 `정답2번`)에서 뽑는다
  - ~~정답 자체는 위 절로 이미 알 수 있으므로, 이 마커는 채점 여부·정오 확인 용도로만 쓴다~~ **폐기(v1.2.0)** — 라벨 없는 유형(문제해결 O/X)은 이 마커가 **유일한** 정답 근거였다(2026-09-17 6/6 `passed-answer`)
- **주관식은 정답 행이 없다** — 채점 후 `[data-field="explanation"]`의 **정답 라벨**(`res(k).answer`)을 공식 정답으로 쓰고,
  라벨이 없으면 **「공식 정답 미확보(주관식·라벨 없음)」로 보고**한다. 추정하지 않는다(⚠️ 라벨 없는 과목의 주관식은 미실측)
- ⭐ **`passed-answer`·`failed-answer`는 둘 다 「그 행이 공식 정답」이라는 뜻이다.** pass/fail은 **내 채점 결과**를 말할 뿐
  그 행의 정오가 아니다 — `failed-answer`가 붙은 행을 「틀린 보기」로 읽지 말 것. 정답 행은 `.passed-answer, .failed-answer`로 찾는다
- ⚠️ **채점 뒤에는 재시도 수단이 없었다** — 딥러닝 3주차 Q1이 빈 답안으로 `N` 채점된 뒤 `정답확인`·`다시풀기` 버튼이
  **둘 다 `display:none`**이었다. 「틀리면 다시풀기로 고치면 된다」를 전제로 성급하게 누르지 말 것
- 같은 날 앞서 플레이어 항목을 **다시 열었을 때는 채점 상태가 초기화돼 있었다**(2026-09-14 · 2026-09-17 3과목 1주차에서 재확인 — **선택은 남고 `passyn`·정답 행만 초기화**, 초기화된 문항은 다시 채점됐다),
  완료 주차는 스킬이 직접 다시 연다(「⛔ 절대 하지 말 것 4」 ②) · 미완료 주차는 사용자 수강 흐름으로만 연다
  - ~~재오픈은 사용자가 할 일이다~~ — v1.2.0 정정 · 완료 주차는 상시 정책으로 스킬이 연다
- ⚠️ `innerText`는 채점된 문항의 버튼을 **숨겨서 빼버린다** — 텍스트만 보면 「버튼이 사라졌다」로
  보이지만 `querySelectorAll`에는 그대로 잡힌다(가시성만 `display:none`).
  **텍스트 유무로 채점 여부를 판정하지 말 것**
- 기록은 스킬이 고른 답이 아니라 **강의실이 표시한 공식 값**으로 한다

⚠️ **공식 정답이 한 항목의 자막과 어긋날 수 있다 — 공식 값이 정본이다.**
GitHub 2주차 Q3 「Git을 설치한 후 환경변수를 설정해야 한다」의 공식 정답은 **○**인데,
`Git 설정 및 기본 검증` 자막은 「설정은 이름과 전자 우편 두 가지만」이라 말한다. 그 한 항목만 보면 ×가 나온다.

⭐ **그러나 `학습정리`가 판정을 뒤집는다** — 같은 주차의 정리 슬라이드에
「Windows에서 Git 설치 방법과 **환경변수 설정 방법**」이 학습 내용으로 명시돼 있다.
**공식 정답이 옳았고, 한 항목의 자막만으로 추론한 쪽이 틀렸다.**

→ **퀴즈 답을 자막으로 검증할 때는 그 항목만 보지 말고 `학습정리`까지 대조한다.**
  그래도 어긋나면 **공식값을 쓰고 불일치를 스크립트에 함께 적는다.**

- 공식 정답 = **채점 후 정답 행**(위 「⭐ 공식 정답의 정본」)
- 강의 근거로 고른 답이 `N`으로 채점되면 **정답 행의 공식 값을 쓰고**, 고른 답·근거·불일치를 스크립트에 기록한다(노트에는 공식 값과 「⚠️ 공식 정답과 강의 설명이 어긋남」 불릿만)

#### ⚠️ 퀴즈 자동 채점 — 상시 정책 · 문항 컨테이너 · 선택 확인 · 동기 분할

⭐ **학습평가에서는 이 절을 항상 실행한다(사용자 상시 정책 2026-09-17). 건별 지시는 필요 없다.**
사용자 지시 원문 — 「학습평가 정답은 정답확인해서 해설까지 강의노트에 포함해야 해. 항상 자동화하도록 관련 스킬을 업데이트해.」

> ~~사용자가 명시적으로 "대신 풀어라"라고 지시했을 때만 이 절을 쓴다. 기본값은 문항만 채록하고 답은 사용자가 푼다~~ — **폐기(v1.2.0)**

| 자동화가 정당화되는 근거 | 내용 |
|---|---|
| ⛔ ~~정답·해설은 `정답확인` 이후에만 렌더된다~~ | **폐기(v1.1.4)** — `[data-field="explanation"]`에 처음부터 있다. 이 근거로 자동 채점을 정당화하지 말 것 |
| ⛔ ~~`평가하기`는 퀴즈를 풀어야 다음으로 넘어간다~~ | **폐기(v1.1.5)** — 열람만으로 완료되고, 반영되면 풀지 않아도 `›`로 `정리하기`가 열린다. 진도·이동을 이유로 자동 채점을 정당화하지 말 것 |
| ⭐ **사용자 상시 정책 (2026-09-17)** | 공식 정답(정답 행)과 공식 해설 원문을 **노트에 넣기 위해 매번 `정답확인`한다** — 건별 지시 불필요 |
| ⭐ **정답 라벨이 DOM에 없는 유형이 있다** (문제해결 O/X · 2026-09-17) | 누르지 않으면 **「(추정)」만 남는다** — 사용자가 거부했다. v1.2.0부터 「(추정)」 정답은 금지 |
| 이 퀴즈는 배점 항목이 아닌 **형성평가**다 | 채점해도 점수가 걸린 행위가 아니다 — 그래도 근거 순서대로 답하고, 근거 없는 선택은 **숨기지 않고 보고**한다 |

⛔ **적용 범위 — CLMS `평가하기`/`학습평가`(형성평가) 한정. 과잉 확장 금지**

- 적용하지 않는 것 — 영상 재생·수강 대행 · `›`/`‹` 이동 · AWS Academy 지식 점검(성적 과제) · OJ 제출 · 게시판·보드 글 · 수시·정기시험 · 사내교육 최종평가
- **`평가하기` 도달(앞 모듈 완료)은 사용자 수강에 달려 있다** — 이 정책은 **도달한 뒤의 조작**에만 적용된다. 도달하려고 재생·이동을 대신하지 않는다
- '도달'은 ① 미완료 주차 — 사용자가 수강 흐름으로(또는 지시로) `평가하기`를 연 상태, ② 완료 주차 — 강의실홈 행이 이미 `완료`인 `평가하기`(스킬이 직접 연다)다(「⛔ 절대 하지 말 것 4」)
- 채점 기록은 강의실 학습 이력에 남고 **되돌릴 수 없다**(위 「⭐ 공식 정답의 정본」 — 재시도 수단 없음) → 아래 안전 절차를 한 단계도 생략하지 않는다

**답 선택 근거 — 이 순서로 정한다**

1. 채점 전 DOM에 **정답 라벨**이 있으면(`정답① ○` 꼴 — GitHub·딥러닝·빅데이터) 그 값(`scan()`의 `pre.answer`)
2. 자막·교안·`학습정리` 근거 — 한 항목의 자막만 보지 말고 `학습정리`까지 대조한다(위 GitHub Q3).
   ⚠️ **미완료 주차에서는 `학습정리`가 `평가하기` 뒤라 채점 시점에 볼 수 없다** — 근거 표에 `학습정리 미대조`를 적고 교안의 정리 쪽으로 대신 대조한다
   (스크립트에 이미 채록된 `학습정리`가 있으면 그것을 쓴다)
3. 그래도 없으면 **첫 보기**를 고르고 **「근거 없음 — 첫 보기」로 보고**한다 — 찍었다는 사실을 숨기지 않는다.
   오답이어도 정답 행에 `failed-answer`가 붙어 **공식 정답은 회수된다**
   - **주관식은 첫 보기가 없다.** 라벨·자막·교안 근거가 없으면 **입력·채점하지 않고** `정답 미확보(주관식·근거 없음)`로 보고한다. 지어낸 문자열로 채점하지 않는다
     (라벨 없는 과목의 주관식은 채점해도 공식 정답이 나오지 않으므로 `N` 이력만 남는다 — 아래 「주관식」)

- 시작 전에 **문항별 선택 답·근거 표를 한 번 제시하고 승인 대기 없이 진행**한다. 끝나면 **공식 정답과 대조해 보고**한다
  - 표에는 문항마다 **실제로 확인한 출처**(라벨 · 자막 항목 · 교안 쪽 · `학습정리` 대조 여부)를 적는다 — 확인하지 않은 출처를 적지 않는다
  - **표를 제시하는 같은 메시지에서 「지금부터 학습평가를 채점하니 퀴즈 화면은 누르지 말아 달라」고 알린다**(승인 대기는 하지 않는다).
    동행 수강 중 사용자의 선택·입력이 에이전트 조작과 겹치면 **의도하지 않은 선택이 되돌릴 수 없게 채점**된다 — 헬퍼 `conf`가 의도(`want`)와 다른 선택을 거부하는 것과 짝을 이룬다
- 자동 채점한 문항은 **8단계 보고에 반드시 포함**한다 — **빈 답안·오답으로 채점된 문항이 생겼으면 그 사실도** 함께 적는다
- 스크립트에는 **공식 값만** 적는다 — ⛔ 「(추정)」 금지. 채점하지 못한 문항은 `정답 미확보(사유)`로 남기고 보고한다
- 「이 도구들은 읽기 위한 것이다」 전제의 **첫 번째 예외(상시 정책)가 이 절이다** — 퀴즈 상태를 바꾸는 코드는 여기 밖으로 나가지 않는다
- ⛔ **조작 전에 `__scuIdle()`로 유휴 종료 팝업부터 확인한다**(3단계) — 세션이 끝난 뒤의 클릭은 기록되지 않을 수 있다
- ⛔ **선택은 「등록 확인」까지가 한 단계다** — `.item-select-option-no.selected`를 보기 전에는 `정답확인`을 누르지 않는다(아래 4-B)
- ⛔ **이미 채점된 문항(`data-passyn` `Y`/`N`)은 다시 누르지 않는다** — 결과만 읽는다(헬퍼 `guard`가 거부한다)

**실측 기준** — 2026-09-08 딥러닝 2주차 `평가하기`, O/X 4문항 · ⛔ **반례** 2026-09-14 딥러닝 3주차 O/X 3문항(합성 선택 미등록 — 4-B) ·
**2026-09-17 문제해결프로그래밍입문 3주차 O/X 6문항**(정답 라벨 없음 · 선택·`정답확인` 전부 스크린샷 좌표 실제 클릭 · 6/6 `Y`)

**1. DOM — 표준 폼이 아니다 (`input` 0개)**

| 대상 | 셀렉터 | 실측 |
|---|---|---|
| 입력 요소 | `input` | **0개** — 라디오·체크박스가 아니다 |
| 선택지 | `div.component-data-field` | `textContent`가 **정확히 `O` 또는 `X`** · 부모는 `div.maui-component-core` |
| 번호 배지 | 문항 컨테이너 안 `.item-select-option-no` | O/X도 2개(`1`=O · `2`=X) · **선택되면 `selected`가 붙는다** |
| 버튼 | `span.maui-border-button` | **문항당 2개** `[정답확인, 다시풀기]` → 4문항 = **8개** · 문제해결 3주차는 채점 후 **문항 컨테이너 안에** 2개가 있었고 `다시풀기`는 `display:none`(2026-09-17) |
| 채점 결과 | 문항 컨테이너 `data-passyn` · 정답 행 `.item-option-row.passed-answer`/`.failed-answer` | `정답확인` 뒤에만 생긴다(위 「⭐ 공식 정답의 정본」) |
| 해설 | 문항 컨테이너 안 `[data-field="explanation"]` | 채점 전 `display:none` — `textContent`로는 읽힌다(비어 있는 문항도 있다) |

⚠️ **문항 유형에 따라 셀렉터 계열이 갈린다. 한쪽으로 덮어쓰지 말고 실물을 먼저 조회해 분기한다**

⭐ **주 경로는 문항 컨테이너 `items()[k]` 안에서 찾는 것이다** — 유형이 섞여도 깨지지 않는다

| 유형 | 선택지 (컨테이너 안) | 버튼 (컨테이너 안) |
|---|---|---|
| 번호 배지형 객관식 | `.item-select-option-no`의 `[i-1]` (행 전체 `.item-option-row`는 무반응) | 첫 `span.maui-border-button` = `정답확인` |
| **O/X형** (딥러닝 2·3주차 · 문제해결 3주차) | `.item-select-option-no`의 `[i-1]` — `1`=O · `2`=X · 배지가 없으면(`?`) **중단**(미관측 DOM — `conf`가 선택을 확인할 근거가 없다) | 첫 `span.maui-border-button` = `정답확인` |
| **주관식 단답형** (GitHub 2주차 11·12번) | 선택지 없음 — `[contenteditable]`에 값을 입력(`fill`) | 첫 `span.maui-border-button` = `정답확인` |

- ⚠️ **전 문항의 첫 버튼이 `정답확인`인지는 첫 실행 때 한 번 확인한다** — 헬퍼 `probe()`의 `btnTexts`(전 문항 `btn(k)` 텍스트 분포 · 버튼이 없으면 `(없음)`)에 **`정답확인` 외의 키가 하나라도 있으면 중단**하고 실물을 본다.
  `textContent` 기준이라 채점된 문항의 숨은 `정답확인`도 `정답확인`으로 읽힌다(`innerText`는 숨김 버튼을 뺀다 · 2026-09-17 실측과 일치). `firstBtn`(Q1만)은 호환용으로 남겼다
- `conf`는 버튼 글자가 **정확히 `정답확인`일 때만** 누른다(화이트리스트 · v1.2.0) — ~~첫 버튼이 `다시…`면 거부~~(블랙리스트였다)
- 컨테이너 안에 버튼이 없을 때만 전역 `btns[2k]`로 폴백하며, 그때도 **버튼 수 = 문항 수 × 2**일 때만 쓴다(헬퍼 `btn(k)`)

**주관식 입력 — 실증된 방법(2026-09-09, 2문항 모두 정답 처리됨)**

```javascript
const ce = it.querySelector('[contenteditable]');
ce.focus();
ce.textContent = 'git status';                       // 값 주입
for (const t of ['input', 'change', 'keyup', 'blur'])   // 프레임워크에 변경을 알린다
  ce.dispatchEvent(new W.Event(t, { bubbles: true }));
```

- 선택지 클릭과 달리 **합성 마우스 이벤트가 필요 없다** — 값 주입 + 이벤트 발사로 충분했다
- 헬퍼 `fill(k, text)`가 이 코드를 담았다 — 입력 기록(`fill`)과 의도(`want = 'text:…'`)를 저장하고, 입력 후 `sel(k)`을 읽고 `conf(k)`로 채점한다(다른 유형과 같은 순서)
- ⚠️ **`sel(k)`의 `text:…`는 주입한 글자를 되읽을 뿐 등록 증거가 아니다** — 프레임워크가 입력 이벤트를 받았는지와 무관하게 나온다.
  **주관식의 등록 여부는 채점 뒤 `passyn`으로만 안다.** 라벨과 같은 값을 넣고도 `N`이면 `res(k).inputSuspect`가 `true`다 → 8단계에 「입력 미등록 의심(재시도 수단 없음)」으로 보고한다
- ⚠️ **입력칸에 원래 있던 글자(`scan` 시점)는 입력으로 치지 않는다** — `fill` 또는 실제 키 입력 뒤에만 채점한다(헬퍼 `typed`). 미관측 가능성(자리표시 문구 등)을 막는 게이트다
- 주 입력법은 `fill`이다(2026-09-09 실증 2/2). `inputSuspect`가 **실제로 관측되면** 그다음 채점부터 computer `type`(실제 키 입력)으로 전환을 검토한다 —
  그때는 `intend(k, text)`로 의도를 먼저 기록하고 입력한다(헬퍼가 실제 키 입력을 입력으로 인정한다). 관측 결과는 아래 표에 한 행씩 누적한다

| 날짜 | 퀴즈 | 주관식 입력 방식 | 결과 |
|---|---|---|---|
| 2026-09-09 | GitHub포트폴리오 2주차 11·12번 | `textContent` 주입 + `input`·`change`·`keyup`·`blur` | 2/2 `Y` · `inputSuspect` 해당 없음 |

- 입력값의 근거는 사전 라벨(`정답git status`)이 있으면 **그 문자열 그대로**다 — 대소문자·공백 차이로 `N`이 날 수 있다

⛔ **유형이 한 퀴즈 안에 섞이므로 전역 인덱스 공식을 쓰지 말고 문항 컨테이너 안에서 조회할 것**(위 6단계 표 참조).

**2. ⚠️ 함정 — 버튼이 문항당 2개라 텍스트 필터가 무너진다 · 주 경로는 문항 컨테이너**

- `정답확인` 텍스트로 버튼을 고르면 **이미 채점한 문항의 버튼도 계속 매치되어** `confs[0]`이 언제나 1번 문항을 가리킨다
- 2번 문항을 누르려다 1번을 다시 눌러 **헛돈다** — 실제로 이 함정에 걸렸다
- ⛔ **텍스트 필터 금지.** 버튼은 **문항 컨테이너 안의 첫 `span.maui-border-button`**으로 고른다(v1.2.0) —
  ~~위치 인덱스로 매핑한다~~ 전역 위치 인덱스 `btns[2k]`는 **버튼 수가 문항 수 × 2일 때만 쓰는 폴백**으로 낮췄다

| 대상 | 주 경로 — 문항 컨테이너 `items()[k]` 안 |
|---|---|
| 선택지 `i`번 (1-based) | `.item-select-option-no`의 `[i-1]` — O/X는 `1`=O · `2`=X |
| 정답확인 | 첫 `span.maui-border-button` (첫 실행 때 텍스트 확인) |
| 다시풀기 | 두 번째 — ⛔ 누르지 않는다(채점 뒤 숨겨져 재시도 수단이 없었다) |

아래 전역 표는 **단일 유형 퀴즈의 교차 확인·폴백용**이다(v1.1.9까지의 주 경로 · 실측 기록으로 보존).

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
- 개수 검증식 `opts.length === btns.length === 문항수 × 2`는 **O/X 전용 퀴즈에서만** 성립한다 — 4지선다는 `opts = 문항수 × 4`, 혼재 퀴즈는 어느 식도 맞지 않는다.
  맞지 않으면 유형 분기부터 다시 보고, 주 경로(컨테이너)로 간다

**3. ⚠️ 함정 — async 루프로 4문항을 한 번에 처리하면 빈 결과가 온다**

- 전 문항을 한 호출에 몰면 **결과가 비어서 돌아온다** — 실측 실패
- **동기 호출로 문항마다 나눠 실행한다. 선택·선택 확인·채점·결과 회수도 각각 별도 호출이다** — 한 호출에 한 동작
- 문항당 **4회 호출(문항 수 × 4)** — `pick(k, i)` → `selNo(k)` → `conf(k)` → `save(k)`(= `res(k)` 저장 + 반환)
  - 주관식은 `fill(k, text)` → `sel(k)` → `conf(k)` → `save(k)`
  - 진행 판정 `next()`는 읽기 전용이라 횟수에 넣지 않는다
  - 좌표 선택으로 전환하면 `focus(k)`·스크린샷·좌표 클릭·`selNo(k)`·`stray()`가, 정답확인 좌표 재시도(4-B 7)면 `save(k)` 2회 · `coordConf(k)` · 스크린샷 · `zoom` · 좌표 클릭 · `save(k)`가 더해진다
  - ~~4문항이면 총 12회 호출 — `pick(0)` → `sel(0)` → `conf(0)` → …~~ (v1.1.8~v1.1.9 — 결과 회수 호출이 없었다)
- ⛔ `items.forEach(...)`·`for await`로 묶는 코드는 **실패 재현 코드**다

**4. 클릭은 `el.click()`으로 반응하지 않는다 — 합성 이벤트는 「1차 시도」이지 보장이 아니다**

- `pointerdown` → `mousedown` → `pointerup` → `mouseup` → `click` 순으로 디스패치한다
- 이벤트는 **그 iframe의 `defaultView`에서 생성**하고 `clientX`/`clientY`를 채운다
- **대상 요소와 그 부모 양쪽에** 발사한다(선택 — `real()`)
  - ⛔ **단, `정답확인`은 되돌릴 수 없으므로 v1.2.0부터 대상에만 1회 발사(`realOne`)한다** — 부모에는 버블링으로 전달된다.
    버튼 핸들러가 부모에 걸려 있으면 이중 발사가 곧 이중 제출이 되고, 이벤트가 동기로 나가 서버 반영 전에 두 번째가 나간다.
    반응하지 않으면 **재발사하지 않고** 4-B 7(좌표 재시도)로 간다
- 앞의 「`.click()`이 동작한다」는 서술은 2026-09-08 실측으로 폐기됐다 — 합성 이벤트가 **필요**하다. 단 **충분하지는 않다**(4-B)

| 날짜 | 퀴즈 | 합성 이벤트로 선택 | 비고 (v1.2.0부터 `정답확인` 단일 발사 `realOne` 반응 여부도 적는다) |
|---|---|---|---|
| 2026-09-08 | 딥러닝 2주차 O/X 4 | ✅ 동작 | 이 절의 원 실측 |
| 2026-09-09 | 빅데이터분석실무 2주차 4지선다 4 | ✅ 동작 | 자동 채점 4/4 정답 |
| 2026-09-09 | GitHub포트폴리오 2주차 혼재 12 | ✅ 동작 | 자동 채점 12/12 정답(주관식 2는 입력 방식) |
| **2026-09-14** | **딥러닝 3주차 O/X 3** | ⛔ **선택 미등록** | 실제 마우스 클릭으로 선택·채점 |
| **2026-09-17** | **문제해결프로그래밍입문 1주차 O/X 6** (정답 라벨 없음 · 재오픈 — 과거 선택 유지) | — (선택은 이미 등록돼 있어 발사 안 함) | `intend` → `conf`의 **`realOne` 정답확인 6/6 반영** · 6/6 `Y` · 좌표 클릭 불필요 · v1.2.0 `hidden()`이 `visibilityState`로 막아 rect 판정으로 바꿔 실행(v1.2.1) |
| **2026-09-17** | **딥러닝 1주차 O/X 3** (정답 라벨 있음 · 재오픈 — 과거 선택 유지) | — (선택 이미 등록) | `realOne` 정답확인 **3/3 반영** · 3/3 `Y` · 진술은 `[data-field="example"]` |
| **2026-09-17** | **문제해결프로그래밍입문 3주차 O/X 6** (정답 라벨 없음) | — **미시도** | 선택·`정답확인` 전부 **스크린샷 좌표 실제 클릭** → **6/6 `Y`** · 첫 클릭은 스크린샷 직후 화면이 23px 움직여 보기 사이 빈칸을 눌렀고 `.selected`가 생기지 않았다 → **선택 확인 게이트가 빈 답안 채점을 막았다** |

⛔ **「O/X 합성 클릭은 검증됐다」로 읽지 말 것.** 위 ✅는 그날 그 퀴즈에서 동작했다는 기록일 뿐이고,
같은 과목·같은 유형(딥러닝 O/X)에서 6일 뒤 반증됐다. 원인은 밝혀지지 않았다.

- **이후 채점마다 날짜·퀴즈·합성 동작 여부를 이 표에 한 행씩 누적한다** — 상시 정책이라 표본이 매주 쌓인다
- 미등록 원인 가설(규칙 아님) — `real()`이 대상과 부모에 **두 번** 발사해 토글식 선택이 해제됐을 수 있다.
  검증하려면 헬퍼의 `realOne(el)`(대상에만 1회 — 선택에는 진단 전용, `정답확인`에는 v1.2.0부터 기본)을 선택에 **한 번만** 시도하고 결과를 이 표에 적는다. 반복하지 않는다

**4-B. ⛔ 선택 등록을 확인하기 전에는 `정답확인`을 누르지 않는다 (2026-09-14 딥러닝 3주차 사고)**

무슨 일이 있었나

- `__scuQuiz.pick()`(v1.1.8 헬퍼)이 O/X `div.component-data-field`와 그 부모에 pointer·mouse 이벤트를 발사했다 —
  그러나 그 문항의 `.item-select-option-no`에 **`selected`가 끝내 붙지 않았다**
- 행 전체 `.item-option-row`를 눌러도 **아무 일도 일어나지 않았다**
- **선택 확인 없이 같은 호출에서 `정답확인`까지 눌러** 빈 답안이 채점됐다 → Q1 `data-passyn="N"`,
  정답 행에 `failed-answer`, 재시도 버튼 없음(위 「채점 결과 마커」)
- ✅ computer 도구의 **실제 마우스 클릭**으로 ①·② 번호 배지를 누르자 선택이 등록됐고,
  Q2·Q3는 선택과 `정답확인`을 모두 실제 클릭으로 해 **정답(`Y`)** 처리됐다

규칙

1. `__scuIdle()` — `null`이 아니면 **중단**하고 사용자에게 같은 탭에서 재오픈을 요청한다(3단계).
   탭이 hidden이면 그 `null`은 증거가 약하다 — **스크린샷으로 탭을 앞으로 가져온 뒤** 조작한다(헬퍼 `guard`가 hidden을 먼저 거부한다)
2. `pick(k, …)` — **선택만** 한다. 발사 **전에** 의도(`want`)와 발사 표시(`pickAt`)를 저장한다(저장 실패면 발사하지 않는다).
   합성 이벤트를 쓰지 않고 좌표 클릭만 하는 경로는 `intend(k, i)`로 **의도만 기록**한 뒤 규칙 4로 간다
3. **별도 호출로 `selNo(k)`(또는 `sel(k)`)** — 그 문항 컨테이너의 선택 상태를 읽는다. `selNo`는 번호(1부터)라 `pick`의 `i`와 바로 비교된다. **의도한 보기가 아니면 멈춘다**
   (다른 보기를 눌러 바로잡는 것은 **선택 단계에서만** 허용한다 — `정답확인` 뒤에는 수단이 없다)
4. `selNo(k)`가 `null`이면 **합성 이벤트를 반복하지 말고 실제 마우스 클릭으로 전환**한다 —
   `__scuStop(true)` 선행 → `focus(k)`로 문항을 화면 중앙에 두고 → 스크린샷 → 그 문항의 번호 배지를 **즉시** 좌표 클릭 → **`selNo(k)`와 `stray()` 재확인** —
   k 밖에 새 선택이 생겼거나(이웃 문항 배지 오클릭 — `focus(k)` 화면에는 위아래 문항이 함께 보인다) k가 의도와 다르면 **중단하고 보고**한다
   (`next()`는 합성 선택을 이미 쏜 문항에 `pick` 대신 `click`을 돌려준다 — 합성 이벤트 반복 금지)
   - ⛔ **좌표 클릭 직전의 헬퍼 호출은 반드시 `focus(k)`다**(정답확인이면 `coordConf(k)` — 규칙 7). 거부 문구(문서 교체·hidden·유휴·채점됨·발사됨)가 나오면
     **스크린샷을 찍었더라도 클릭하지 않는다.** 스크린샷에 `.eco-popup`·잠금 모달·기타 팝업이 보이면 **어느 버튼도 누르지 않고 중단**한다 — 팝업의 확인 버튼이 학습을 종료시킬 수 있다
   - ⚠️ **좌표는 스크린샷에서만 읽는다** — `getBoundingClientRect`를 iframe 체인으로 합산한 좌표는 **콘텐츠 확대 때문에 화면 좌표와 약 1.15배 어긋났다.**
     스크린샷 직후 화면이 **23px 움직여** 보기 사이 빈칸을 누른 적도 있다(2026-09-17 — `.selected`가 생기지 않았고 이 게이트가 빈 답안 채점을 막았다).
     그래서 **스크린샷 → 즉시 클릭 → `selNo(k)` 재확인**이 한 묶음이다. 헬퍼에 좌표 계산 함수(`badgeRect`)를 두지 않는다
   - ⚠️ 탭이 뒤에 있을 때 문항 rect가 **0**으로 나왔다가 스크린샷(탭 활성화) 뒤 정상화됐다 — rect 0을 「문항 없음」으로 읽지 않는다. `visibilityState`는 그 뒤에도 `hidden`으로 남으므로 판정에 쓰지 않는다(v1.2.1)
   - 클릭 뒤 헤더가 `… | 평가하기` 그대로인지 함께 본다(아코디언·`›` 오클릭 방지). 루프가 끝나거나 중단되면 정지 가드를 **해제**한다(규칙 9 · `__scuStop` 절)
   - 좌표 클릭 뒤에도 `null`이면 **루프를 중단하고 보고**한다
5. `selNo(k)`가 의도한 보기일 때만 `conf(k)` — 헬퍼의 `conf`는 **선택이 없거나, 의도 기록(`want`)이 없거나(사용자 조작·오클릭), 선택 ≠ 의도면 누르지 않고 거부**한다
6. `정답확인`이 합성 이벤트(대상 1회 · `realOne`)에 반응하지 않으면 **규칙 7의 경로로만** 좌표 클릭한다
   - ~~`정답확인`도 합성 이벤트에 반응하지 않으면 같은 방식(스크린샷 → 좌표 클릭)으로 누른다~~ — v1.2.0에서 규칙 7로 좁혔다(재확인 없는 좌표 클릭은 이중 채점 위험)
7. **3~4초 뒤 `save(k)`** — `res(k)`로 `data-passyn`·정답 행·해설 원문을 회수해 기록하고 그 값을 돌려준다.
   `passyn`이 `null`이면 **바로 누르지 않는다.** 서버 반영이 늦을 뿐일 수 있다(채점이 반영되면 버튼이 숨고 레이아웃이 바뀌어, 그 자리의 해설이나 `다시풀기`를 누를 수 있다)
   1. 3~4초 간격으로 `save(k)`를 **두 번 더** 읽는다(약 10초)
   2. 그래도 `null`이면 `coordConf(k)` — 문서 교체·탭 가시성·유휴·채점됨·미발사를 검사하고, **재시도 기록(`coordAt`)을 남긴 뒤** 문항을 중앙에 둔다. 기록이 이미 있으면 거부한다(문항당 1회)
   3. 스크린샷(필요하면 `zoom` — 이것도 화면 캡처다)으로 **그 문항의** 버튼 글자가 `정답확인`인지 확인한 뒤에만 **즉시 한 번** 좌표 클릭한다.
      스크린샷과 클릭 사이에는 JS 호출·스크롤을 넣지 않는다(규칙 4)
   4. `정답확인`이 보이지 않거나(채점 반영으로 숨겨졌을 수 있다) · `다시풀기`가 보이거나 · 해설이 이미 펼쳐져 있거나 · 다른 문항 버튼과 구분되지 않으면 **누르지 않고** `save(k)`만 한다
   5. 3~4초 뒤 `save(k)` — 그래도 `null`이면 **중단하고 보고**한다
   - 좌표 클릭은 헬퍼 `guard`를 거치지 않는다 — 이중 채점 방지는 이 재확인과 `coordAt` 기록뿐이다
8. **이미 채점된 문항(`passyn` `Y`/`N`)은 헬퍼가 `pick`·`fill`·`intend`·`conf`·`focus`·`coordConf`를 거부한다** — `res`·`save`만 한다.
   `conf`를 이미 발사한 문항도 채점 반영 전까지 `pick`·`fill`·`intend`·`conf`·`focus`를 거부한다(이중 클릭 방지 — `next()`가 `wait`를, 좌표 재시도까지 소진했으면 `stop`을 돌려준다)
9. **루프를 중단하는 모든 경로에서는 보고하기 전에 정지 가드부터 해제한다** — 선택 미등록 · 좌표 재시도 소진 · `passyn` `null` · 버튼/입력칸/문항 없음 · 유휴 팝업 · hidden · `ask`/`mismatch`/문서 교체.
   `clearInterval(window.__scuGuard); window.__scuGuard = null` 을 실행하고 보고에 「정지 가드 해제」를 적는다.
   사용자는 같은 탭에서 다시 열어 수강을 이어 가므로, 가드가 남으면 영상이 0.5초마다 멈춰 **진도가 오르지 않는다**(`__scuStop` 절). `next()`의 `guard: true`가 그 신호다

⛔ **「선택 + 정답확인을 한 호출에」는 이번 사고의 재현 코드다.** 선택이 등록됐는지 볼 틈이 없다.

**헬퍼 정의 — 최상위 프레임에서 1회** (⚠️ 3단계 `__scuIdle`과 「B. 수확기」의 `__scuNS`를 먼저 정의한다 — 없으면 정의를 거부한다)

- **문항 컨테이너 기준**(`items()[k]`) · **채점 결과 회수**(`res`) · **영속**(`save` → `localStorage['scuQuiz:' + __scuNS]`) · **진행 판정**(`next`) (v1.2.0)
- ⛔ **헬퍼 안에서 상태를 바꾸는 루프를 돌리지 않는다** — 한 호출에 여러 동작을 넣으면 빈 결과가 오고, 선택 확인 전 채점 사고도 그렇게 났다.
  루프는 에이전트가 `k`마다 **별도 호출**로 돈다(`probe`·`scan` 안의 반복은 읽기 전용)
- 인자 `k`는 **0부터**, 반환의 `no`와 저장 키는 **문항 번호(1부터)**다

```javascript
window.__scuQuiz = (function () {
  if (typeof window.__scuIdle !== 'function') return { err: '__scuIdle 먼저 정의 (3단계 「유휴 세션 종료」)' };
  if (!window.__scuNS || /[{}]/.test(window.__scuNS))              // 자리표시자 그대로면 모든 과목이 같은 키를 쓴다
    return { err: '__scuNS 먼저 정의 — 자리표시자를 실제 값으로 (「__scuHarvest」 B절) · 현재: ' + window.__scuNS };
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
  // 합성 선택·정답확인을 발사한 문항 요소 — 최상위에 두어 헬퍼를 재정의해도 유지된다(rearm이 「같은 요소 = 재오픈 아님」을 가린다)
  window.__scuFiredEls = window.__scuFiredEls || new WeakSet();

  const fire = (targets, el) => {                // el.click() 단독으로는 반응하지 않는다
    const r = el.getBoundingClientRect();
    const opt = { bubbles: true, cancelable: true, composed: true, view: W,
                  clientX: r.left + r.width / 2, clientY: r.top + r.height / 2,
                  button: 0, buttons: 1, pointerId: 1, pointerType: 'mouse', isPrimary: true };
    const P = W.PointerEvent || W.MouseEvent, M = W.MouseEvent;
    for (const t of targets) {
      if (!t) continue;
      t.dispatchEvent(new P('pointerdown', opt));
      t.dispatchEvent(new M('mousedown',  opt));
      t.dispatchEvent(new P('pointerup',   opt));
      t.dispatchEvent(new M('mouseup',    opt));
      t.dispatchEvent(new M('click',      opt));
    }
    return true;
  };
  const real    = el => el ? fire([el, el.parentElement], el) : false;  // 선택 1차 시도 — 대상과 부모 양쪽 · 보장 없음
  const realOne = el => el ? fire([el], el) : false;                    // 대상에만 1회 — 정답확인(되돌릴 수 없다)은 이것만 쓴다 · 선택에는 진단 전용(4번 표)

  const clean  = s => (s || '').replace(/\s+/g, ' ').trim();
  // 보기 텍스트 — 행 textContent는 배지 번호가 붙어 나온다(요소 사이 공백 없음 → '1O' · '2데이터의 신속성')
  const optText = row => { const c = row.cloneNode(true);
    c.querySelectorAll('.item-select-option-no').forEach(x => x.remove()); return clean(c.textContent); };
  // 플레이어 iframe이 교체되면(재오픈·항목 전환) 옛 문서의 defaultView는 null이 된다(Chromium) — 옛 헬퍼는 죽은 문서를 본다
  const stale  = () => !d.defaultView;
  // 탭 hidden이면 rect가 0이다(2026-09-17) — 유휴 팝업·좌표 판정이 불확실하므로 상태 변경을 막는다
  // ⚠️ v1.2.1 — MCP 탭은 화면에 그려져 클릭이 되는 상태에서도 visibilityState가 'hidden'으로 남는다(2026-09-17 실측 3과목 · hasFocus true · 문항 rect 정상)
  //    visibilityState로 막으면 모든 조작이 거부된다 → 첫 문항이 실제로 그려졌는지(rect)로 판정한다
  const hidden = () => { const it = d.querySelector('[data-type="item"]'); if (!it) return false;
    const r = it.getBoundingClientRect(); return !(r.width && r.height); };
  // ⚠️ 목록은 호출할 때마다 새로 만든다 — 채점하면 DOM이 갱신된다
  const items  = () => [...d.querySelectorAll('[data-type="item"]')];      // 문항 컨테이너
  const it_    = k => items()[k];
  const btns   = () => [...d.querySelectorAll('span.maui-border-button')]; // 전역 — 폴백 전용
  const badges = k => [...((it_(k) && it_(k).querySelectorAll('.item-select-option-no')) || [])];
  const type   = k => {
    const n = badges(k).length;
    return n === 0 ? (it_(k) && it_(k).querySelector('[contenteditable]') ? '주관식' : '?')
         : n === 2 ? 'O/X' : '객관식';
  };
  const idle   = () => window.__scuIdle();
  const passyn = k => (it_(k) && it_(k).getAttribute('data-passyn')) || null;
  const graded = k => /^[YN]$/.test(passyn(k) || '');

  // 영속 — 오리진 공유라 네임스페이스 필수 (자막 scuCap과 같은 이유)
  const KEY   = 'scuQuiz:' + window.__scuNS;
  const store = () => { try { return JSON.parse(localStorage.getItem(KEY) || '{}'); } catch (e) { return {}; } };
  const put   = (k, patch) => {
    const s = store();
    s[k + 1] = Object.assign({}, s[k + 1] || {}, patch, { at: Date.now() });
    try { localStorage.setItem(KEY, JSON.stringify(s)); } catch (e) { return { err: 'SAVE FAILED: ' + e.message }; }
    return s[k + 1];
  };
  const pending = k => { const r = store()[k + 1]; return !!(r && r.confAt) && !graded(k); };
  // 에이전트가 고른 답 — pick·fill·intend가 저장한다. conf는 이것과 같은 선택만 채점한다
  const wantOf  = k => { const r = store()[k + 1]; return r && r.want != null ? r.want : null; };
  // 지문 — 딥러닝 O/X는 question이 공통 지시문(「다음 보기 내용이 맞으면 O…」)이고 진술은 [data-field="example"]에 있다(2026-09-17) → 둘을 잇는다
  const stem    = it => { const f = n => clean((it.querySelector(`[data-field="${n}"]`) || {}).textContent);
    const q = f('question'), e = f('example'); return e && e !== q ? (q ? q + ' | ' + e : e) : q; };
  const qText   = k => it_(k) ? stem(it_(k)) : '';
  // 저장 기록의 문항이 화면과 다르면 __scuNS가 틀린 것이다(다른 주차 기록이 섞인다)
  const qStale  = k => { const r = store()[k + 1], sc = r && (r.scan || r.scanAfter); return !!(sc && sc.q && sc.q !== qText(k)); };

  // 상태를 바꾸는 호출(pick·fill·intend·focus·conf)의 공통 거부 조건
  const guard = k => stale() ? '중단 — 플레이어 문서가 교체됨(재오픈·항목 전환) — 헬퍼 재정의'
    : hidden()   ? '중단 — 문항이 그려지지 않음(rect 0 · 유휴 팝업·좌표 판정 불확실) — 스크린샷으로 탭을 앞으로 가져온 뒤 probe()부터'
    : idle()     ? '중단 — 유휴 종료 팝업 (감시 탭에서 재오픈 요청 · 헬퍼 재정의)'
    : !it_(k)    ? `Q${k + 1} 없음 — 중단하고 유형 분기 재확인`
    : graded(k)  ? `Q${k + 1} 이미 채점됨(${passyn(k)}) — save(${k})만`
    : pending(k) ? `Q${k + 1} 정답확인 발사됨·채점 미반영 — 3~4초 간격 save(${k}) 최대 3회 → 그래도 null이면 coordConf(${k}) (4-B 7)`
    : null;

  // 버튼 — 컨테이너 안 첫 버튼(= 정답확인, 첫 실행 때 probe로 확인) → 없으면 전역 btns[2k](버튼 수 = 문항 수 × 2일 때만)
  const btn = k => {
    const own = it_(k) && it_(k).querySelector('span.maui-border-button');
    if (own) return own;
    const b = btns();
    return b.length === items().length * 2 ? b[2 * k] : null;
  };

  // ⭐ 선택 등록의 유일한 근거 — 이벤트 발사가 true를 돌려준 것은 증거가 아니다 (4-B)
  const sel = k => {
    const it = it_(k);
    if (!it) return undefined;
    const b = it.querySelector('.item-select-option-no.selected');
    if (b) return optText(b.closest('.item-option-row') || b);             // 배지 번호를 뺀 보기 텍스트
    const ce = it.querySelector('[contenteditable]');                       // 주관식 — ⚠️ 주입한 글자를 되읽을 뿐 등록 증거가 아니다
    return ce && clean(ce.textContent) ? 'text:' + clean(ce.textContent) : null;
  };
  // 선택된 배지의 번호(1부터) — pick(k, i)의 i와 같은 척도라 바로 비교된다
  const selNo = k => {
    const b = it_(k) && it_(k).querySelector('.item-select-option-no.selected');
    if (!b) return null;
    const i = badges(k).indexOf(b);
    return i >= 0 ? i + 1 : (parseInt(clean(b.textContent), 10) || clean(b.textContent));
  };
  // want와 같은 척도 — 주관식은 'text:…', 그 밖은 배지 번호
  const cur = k => type(k) === '주관식' ? sel(k) : selNo(k);
  // 주관식 입력 판정 — 의도·fill 기록과 같은 글자이거나, 사전 채록(scan) 때 글자와 달라졌을 때만(실제 키 입력 허용)
  // ⚠️ 입력칸에 원래 있던 글자(자리표시 문구 등 · 미관측)는 입력으로 치지 않는다
  const typed = (k, c) => { const r = store()[k + 1] || {};
    if (!c) return false;
    if (r.want != null && c === String(r.want)) return true;
    if (r.fill != null && c === 'text:' + clean(r.fill)) return true;
    return !!(r.scan && c !== r.scan.selected); };
  // 에이전트가 고르지 않은 선택 — 채점 안 된 문항 중 선택(입력)이 있고 의도와 다른 것(사용자 조작·오클릭) · 읽기 전용
  const stray = () => items().map((_, k) => k)
    .filter(k => !graded(k) && sel(k) && String(cur(k)) !== String(wantOf(k)))
    .map(k => ({ no: k + 1, sel: cur(k), want: wantOf(k) }));
  // 보기 번호(1부터) 또는 거부 문구 — pick·intend 공용
  const optNo = (k, i) => {
    const ox = i === 'O' || i === 'X', no = i === 'O' ? 1 : i === 'X' ? 2 : Number(i), t = type(k);
    if (!(no >= 1)) return `Q${k + 1} 보기 번호 오류: ${i}`;
    if (t === '?') return `Q${k + 1} 유형 불명(배지·입력칸 없음) — 중단하고 실물 확인`;   // 미관측 DOM — 발사하지 않는다
    if (t === '주관식') return `Q${k + 1} 주관식 — fill(${k}, text)을 쓴다`;
    if (ox && t === '객관식') return `Q${k + 1} O/X 문항이 아니다(보기 ${badges(k).length}개) — 번호로 지정`;
    if (!badges(k)[no - 1]) return `Q${k + 1} 보기 ${i} 없음 — 중단하고 유형 분기 재확인`;
    return no;
  };

  // 사전 채록 — 채점 전 DOM의 정답 라벨. ⚠️ 라벨 없는 유형(문제해결 O/X)은 labeled:false · answer:null
  const pre = k => {
    const e  = it_(k) && it_(k).querySelector('[data-field="explanation"]');
    const ex = clean(e && e.textContent);
    const m  = ex.match(/^정답\s*(.*?)(?:\s*해설\s*(.*))?$/);      // 해설은 선택 — 참 진술 O/X는 `정답① O`만
    return { labeled: !!m, answer: m ? m[1] : null, explanation: m ? (m[2] || '') : ex };
  };

  // ⭐ 채점 결과 — 읽기 전용 · 채점된 문항에도 쓴다. 공식 정답의 정본은 official(정답 행)
  const res = k => {
    if (stale()) return { no: k + 1, err: '플레이어 문서 교체 — 헬퍼 재정의 후 다시 읽는다' };   // 옛 채점 상태를 현재처럼 돌려주지 않는다
    const it = it_(k);
    if (!it) return { no: k + 1, err: '없음' };
    const e    = it.querySelector('[data-field="explanation"]');
    const r    = e ? e.getBoundingClientRect() : { width: 0, height: 0 };
    const rows = [...it.querySelectorAll('.item-option-row')];
    const hit  = rows.filter(x => x.matches('.passed-answer, .failed-answer'));
    const p    = pre(k), py = passyn(k), t = type(k);
    return {
      no: k + 1, type: t, passyn: py,                                       // no = 문항 번호(1부터) · 인자 k는 0부터
      official:   hit.map(optText),                                         // 정답 행의 보기 텍스트(배지 번호 제외)
      officialNo: hit.map(x => rows.indexOf(x) + 1),
      mark:       hit.map(x => x.classList.contains('passed-answer') ? 'passed' : 'failed'),
      src: hit.length ? '정답 행'
         : (t === '주관식' && py && p.labeled) ? '정답 라벨(주관식)'
         : py ? '미확보(정답 행·라벨 없음)' : '미채점',
      mine: sel(k), mineNo: selNo(k),
      labeled: p.labeled, answer: p.answer, explanation: p.explanation,     // 해설 원문(없으면 '')
      // ⚠️ 주관식 sel(k)은 주입한 글자를 되읽을 뿐 등록 증거가 아니다 — 라벨과 같은 값을 넣고도 N이면 입력 미등록 의심
      inputSuspect: t === '주관식' && py === 'N' && p.labeled && sel(k) === 'text:' + clean(p.answer),
      exp_visible: r.width > 0 && r.height > 0,                              // ⚠️ 탭 hidden이면 false로 나온다
      tab: document.visibilityState, drawn: !hidden()                     // 판정은 drawn — visibilityState는 참고값(MCP 탭은 늘 hidden)
    };
  };

  return {
    d, W, KEY, real, realOne, items, btns, btn, badges, type, pre, sel, selNo, res, store, stray,
    n: () => items().length,

    // 0) 첫 실행 확인 — 문항 수 · 유형 분포 · 전 문항 첫 버튼 텍스트 · 채점된 문항 · 사전 선택 · 저장 기록 대조
    probe: () => {
      const N = items().length, types = {}, btnTexts = {};
      let staleQ = 0;
      for (let k = 0; k < N; k++) {
        types[type(k)] = (types[type(k)] || 0) + 1;
        const b = btn(k), bt = b ? (clean(b.textContent) || '(빈 글자)') : '(없음)';
        btnTexts[bt] = (btnTexts[bt] || 0) + 1;                              // textContent 기준 — 채점된 문항의 숨은 정답확인도 잡힌다
        if (qStale(k)) staleQ++;
      }
      const b0 = N ? btn(0) : null;
      return {
        ns: window.__scuNS, n: N, types, stale: stale(),                     // stale true → 헬퍼 재정의
        btnInItem: items().filter(x => x.querySelector('span.maui-border-button')).length,
        btnAll: btns().length,
        btnTexts,                                                            // '정답확인' 외의 키가 하나라도 있으면 중단
        firstBtn: b0 ? clean(b0.textContent) : null,                          // 호환용(Q1만)
        graded: items().filter(x => /^[YN]$/.test(x.getAttribute('data-passyn') || '')).length,
        preSel: stray().map(x => x.no),                                      // 비어 있지 않으면 채점하지 않고 사용자에게 묻는다
        staleQ,                                                              // 0이 아니면 __scuNS 오류
        idle: idle(), tab: document.visibilityState, drawn: !hidden(), saved: Object.keys(store()).length
      };
    },

    // 1) 사전 채록(읽기 전용) — 문항별 기록은 localStorage에, 반환은 응답 상한에 맞춘 요약만
    scan: (a, b) => {
      if (stale()) return '중단 — 플레이어 문서가 교체됨 — 헬퍼 재정의';     // 죽은 문서의 내용을 기록하지 않는다
      const N = items().length;
      const from = a || 0, to = b == null ? N : Math.min(b, N), out = [];
      let failed = null;
      for (let k = from; k < to; k++) {
        const it = it_(k);
        const rec = {
          no: k + 1, type: type(k), q: stem(it),                              // 공통 지시문이면 진술(example)을 잇는다
          opts: [...it.querySelectorAll('.item-option-row')].map(optText),    // 배지 번호를 뺀 보기 텍스트
          passyn: passyn(k), selected: sel(k), pre: pre(k)
        };
        const pr = put(k, graded(k) ? { scanAfter: rec } : { scan: rec });   // 채점 전 기록을 덮지 않는다
        if (pr && pr.err) failed = pr.err;
        out.push(`Q${k + 1} ${rec.type} ${rec.passyn || '-'} `
          + `${rec.pre.labeled ? '라벨:' + rec.pre.answer : '라벨없음'}${rec.pre.explanation ? ' +해설' : ''} `
          + rec.q.slice(0, 40));
      }
      return ((failed ? failed + ' — 저장 안 됨\n' : '') + out.join('\n')).slice(0, 1900);   // 첫 줄 SAVE FAILED면 기록이 없다
    },

    // 3a) 선택 — i는 1부터 세는 보기 번호 · 'O'→1 · 'X'→2. ⚠️ 이벤트를 쏠 뿐이다 — 반드시 selNo(k)로 확인
    pick: (k, i) => {
      const g = guard(k); if (g) return g;
      const no = optNo(k, i);                                                 // 배지 없는 O/X('?')는 거부 — 미관측 DOM이라 텍스트 폴백도 두지 않는다
      if (typeof no !== 'number') return no;
      const el = badges(k)[no - 1];
      // 발사 전에 의도(want)와 발사 표시(pickAt)를 남긴다 — 저장 실패면 쏘지 않는다(의도 없는 선택은 conf가 거부해 채점 불가로 남는다)
      const pr = put(k, { want: no, pickAt: Date.now(), pickNo: no });
      if (pr && pr.err) return `Q${k + 1} 의도 기록 저장 실패 — 발사하지 않음 (${pr.err}) · 반출한 scuCap:/scuQuiz: 키를 정리한 뒤 재시도`;
      window.__scuFiredEls.add(it_(k));
      real(el);
      const ox = i === 'O' || i === 'X';
      return `Q${k + 1} 보기 ${no}${ox ? '(' + i + ')' : ''} 이벤트 발사 — selNo(${k})로 확인 (발사 성공은 증거가 아님)`;
    },

    // 3a'') 의도만 기록 — 합성 이벤트 없이 좌표 클릭(또는 주관식 실제 키 입력)만 쓰는 경로 · 이벤트를 쏘지 않는다
    intend: (k, i) => {
      const g = guard(k); if (g) return g;
      let want;
      if (type(k) === '주관식') want = 'text:' + clean(String(i));
      else { want = optNo(k, i); if (typeof want !== 'number') return want; }
      const pr = put(k, { want });
      if (pr && pr.err) return `Q${k + 1} 의도 기록 저장 실패 — 좌표 클릭하지 않는다 (${pr.err})`;
      return `Q${k + 1} 의도 ${want} 기록 — `
        + (type(k) === '주관식' ? `입력칸 클릭 → 실제 키 입력 → sel(${k})` : `focus(${k}) → 스크린샷 → 번호 배지 즉시 좌표 클릭 → selNo(${k}) · stray()`);
    },

    // 3a') 주관식 입력 — 합성 마우스 이벤트 불필요(2026-09-09 실증)
    fill: (k, text) => {
      const g = guard(k); if (g) return g;
      const ce = it_(k).querySelector('[contenteditable]');
      if (!ce) return `Q${k + 1} 입력칸 없음 — 주관식이 아니다`;
      const before = clean(ce.textContent);
      // 의도·입력 기록 — 입력칸의 기존 글자와 구분하는 근거(typed) · 저장 실패면 입력하지 않는다
      const pr = put(k, { want: 'text:' + clean(String(text)), fill: String(text), fillAt: Date.now() });
      if (pr && pr.err) return `Q${k + 1} 입력 기록 저장 실패 — 입력하지 않음 (${pr.err})`;
      ce.focus();
      ce.textContent = String(text);
      for (const t of ['input', 'change', 'keyup', 'blur']) ce.dispatchEvent(new W.Event(t, { bubbles: true }));
      return `Q${k + 1} 입력${before ? ` (기존 글자 '${before.slice(0, 30)}' 덮어씀)` : ''} — sel(${k})이 'text:${text}'인지 확인 (되읽기일 뿐 등록 증거는 아니다)`;
    },

    // 좌표 선택 전용 — guard를 통과할 때만 문항을 화면 중앙에 둔다(스크롤은 상태를 바꾸지 않는다) · 좌표는 스크린샷에서만 읽는다
    // ⚠️ 정답확인 좌표 재시도에는 쓰지 않는다 — 발사 뒤라 guard에 걸린다 → coordConf(k)
    focus: k => {
      const g = guard(k); if (g) return g;
      it_(k).scrollIntoView({ block: 'center' });
      return `Q${k + 1} 중앙 — 스크린샷에 팝업·모달이 보이면 누르지 않는다 · 번호 배지 즉시 좌표 클릭 → selNo(${k}) · stray()`;
    },

    // 3c) 채점 — ⛔ 선택이 없거나 · 의도 기록이 없거나 · 선택 ≠ 의도면 누르지 않는다 · 채점됐거나 이미 발사했으면 거부
    conf: k => {
      const g = guard(k); if (g) return g;
      const s = sel(k);
      if (!s) return `Q${k + 1} 선택 미등록 — 정답확인 보류 (좌표 클릭으로 선택 후 재시도)`;
      if (type(k) === '주관식' && !typed(k, s))
        return `Q${k + 1} 주관식 입력 미확인 — fill(${k}, text) 먼저 (입력칸에 원래 있던 글자는 입력으로 치지 않는다)`;
      const w = wantOf(k);
      if (w == null) return `Q${k + 1} 의도 기록 없음 — 에이전트가 고른 선택이 아니다(사용자 조작·오클릭?) · 정답확인 보류`;
      if (String(cur(k)) !== String(w)) return `Q${k + 1} 선택 ${cur(k)} ≠ 의도 ${w} — 정답확인 보류`;
      const b = btn(k);
      if (!b) return `Q${k + 1} 버튼 없음 — 중단하고 유형 분기 재확인`;
      const bt = clean(b.textContent);
      if (!/^정답\s*확인$/.test(bt)) return `Q${k + 1} 첫 버튼이 '${bt}' — 정답확인이 아니라 누르지 않음 · 버튼 매핑 재확인`;   // 화이트리스트
      const pr = put(k, { confAt: Date.now(), confSel: s });
      if (pr && pr.err) return `Q${k + 1} 발사 표시 저장 실패 — 누르지 않음 (${pr.err}) · 반출한 scuCap:/scuQuiz: 키를 정리한 뒤 재시도`;
      window.__scuFiredEls.add(it_(k));
      realOne(b);                                                             // ⛔ 대상에만 1회 — 되돌릴 수 없다(부모에는 버블링으로 간다)
      return `Q${k + 1} 정답확인 발사(대상 1회) (선택: ${s} · 버튼: ${bt}) — 3~4초 뒤 save(${k})`;
    },

    // 3c') 정답확인 좌표 재시도 준비 — 4-B 7 · 문항당 1회(coordAt) · 이벤트를 쏘지 않는다
    coordConf: k => {
      if (stale()) return '중단 — 플레이어 문서가 교체됨 — 헬퍼 재정의';
      if (hidden()) return '중단 — 문항이 그려지지 않음(rect 0) — 스크린샷으로 탭을 앞으로 가져온 뒤 probe()부터';
      if (idle()) return '중단 — 유휴 종료 팝업 (감시 탭에서 재오픈 요청)';
      const it = it_(k);
      if (!it) return `Q${k + 1} 없음`;
      if (graded(k)) return `Q${k + 1} 이미 채점됨(${passyn(k)}) — save(${k})만`;
      const r = store()[k + 1] || {};
      if (!r.confAt) return `Q${k + 1} 정답확인 발사 기록 없음 — conf(${k})부터`;
      if (r.coordAt) return `Q${k + 1} 좌표 재시도 소진 — 누르지 말고 중단·보고`;
      const pr = put(k, { coordAt: Date.now() });
      if (pr && pr.err) return `Q${k + 1} 재시도 기록 저장 실패 — 누르지 않음 (${pr.err})`;
      it.scrollIntoView({ block: 'center' });
      return `Q${k + 1} 좌표 재시도 기록 — 스크린샷(필요하면 zoom)으로 그 문항의 '정답확인' 글자를 확인한 뒤에만 즉시 1회 클릭 → 3~4초 뒤 save(${k}) · 안 보이면 누르지 않는다`;
    },

    // 3d) 결과 회수 + 기록 — res(k)를 저장하고 그 값을 돌려준다(읽기 + localStorage) · 저장 실패는 saveErr로 드러낸다
    save: k => {
      const r = res(k);
      if (r.err) return r;                                                    // 문서 교체·문항 없음 — 저장하지 않는다
      const pr = put(k, { res: r });
      return pr && pr.err ? Object.assign({ saveErr: pr.err }, r) : r;
    },

    // 진행 판정(읽기 전용) — 중단 뒤 재개를 안전하게 하고 이중 클릭을 막는다
    // guard: true면 정지 가드가 켜져 있다 — 중단·종료 보고 전에 해제한다(4-B 9)
    next: () => {
      const gd = !!window.__scuGuard;
      if (stale())  return { step: 'stop', why: '플레이어 문서 교체 — 헬퍼 재정의', guard: gd };
      if (hidden()) return { step: 'activate', why: '문항이 그려지지 않음(rect 0) — 스크린샷으로 탭을 앞으로 가져온 뒤 probe()', guard: gd };
      if (idle())   return { step: 'stop', why: '유휴 종료 팝업 — 감시 탭에서 재오픈 요청', guard: gd };
      const N = items().length, s = store();
      if (!N) return { step: 'stop', why: '문항 없음 — 헤더가 평가하기인지 확인', guard: gd };
      for (let k = 0; k < N; k++) {
        const r = s[k + 1] || {};
        if (qStale(k)) return { k, step: 'stop', why: '저장 기록의 문항이 화면과 다르다 — __scuNS 확인 후 헬퍼 재정의', guard: gd };
        if (graded(k)) {
          if (!(r.res && r.res.passyn)) return { k, step: 'save' };
          continue;
        }
        if (pending(k)) return r.coordAt
          ? { k, step: 'stop', why: '좌표 재시도 소진 — 누르지 말고 보고', guard: gd }
          : { k, step: 'wait', why: '정답확인 발사됨 — 3~4초 간격 save 최대 3회 → 그래도 null이면 coordConf (4-B 7)' };
        const t = type(k), c = sel(k);
        if (t === '주관식' ? typed(k, c) : c) {                             // 선택(입력)이 있다 — 누가 했는지 본다
          if (r.want == null) return { k, step: 'ask', why: '에이전트가 고르지 않은 선택 — 사용자 조작 또는 오클릭', guard: gd };
          return String(cur(k)) === String(r.want) ? { k, step: 'conf' }
            : { k, step: 'mismatch', why: `선택 ${cur(k)} ≠ 의도 ${r.want} — 4-B 규칙 3(바로잡기는 선택 단계에서만)`, guard: gd };
        }
        if (t === '주관식') return { k, step: 'fill' };                      // 입력칸에 원래 있던 글자는 입력이 아니다
        if (t === '?') return { k, step: 'stop', why: '유형 불명(배지·입력칸 없음) — 실물 확인', guard: gd };
        if (r.pickAt)                                                         // 합성 선택을 이미 쏘았는데 미등록 — 반복 금지
          return { k, step: 'click', why: `합성 선택 미등록 — __scuStop(true) → focus(${k}) → 스크린샷 → 배지 ${r.pickNo} 좌표 클릭 → selNo(${k}) · stray()` };
        return { k, step: 'pick' };
      }
      return { step: 'done', n: N, guard: gd };
    },

    // ⛔ 사용자가 재오픈했다고 확인하고, 초기화를 res(k)로 본 뒤에만 — 발사 표시(confAt·pickAt·coordAt)와 의도를 지운다
    //    wait가 오래 간다는 이유로 쓰지 않는다 — 발사 때와 같은 문항 요소면 거부한다
    rearm: k => {
      if (stale()) return '중단 — 플레이어 문서가 교체됨 — 헬퍼를 재정의한 뒤 rearm';
      if (graded(k)) return `Q${k + 1} 채점돼 있음(${passyn(k)}) — rearm 불필요`;
      if (window.__scuFiredEls.has(it_(k))) return `Q${k + 1} 발사 때와 같은 문항 요소 — 재오픈이 아니다 · rearm 거부`;
      const s = store(), r = s[k + 1];
      if (!r || !(r.confAt || r.pickAt)) return `Q${k + 1} 발사 표시 없음`;
      delete r.confAt; delete r.confSel; delete r.coordAt; delete r.pickAt; delete r.pickNo; delete r.want;
      try { localStorage.setItem(KEY, JSON.stringify(s)); } catch (e) { return 'SAVE FAILED: ' + e.message; }
      return `Q${k + 1} rearm — next()부터 다시`;
    },

    // 6) 디스크 반출 — 에이전트 맥락을 거치지 않는다(__scuExport와 같은 방식)
    exportQuiz: () => {
      const name = 'scu-quiz-' + window.__scuNS + '.json';
      const blob = new Blob([JSON.stringify(store(), null, 1)], { type: 'application/json' });
      const url  = URL.createObjectURL(blob);
      const a    = document.createElement('a');
      a.href = url; a.download = name;
      document.body.appendChild(a); a.click();
      setTimeout(() => { URL.revokeObjectURL(url); a.remove(); }, 1000);
      return name + ' · ' + blob.size + ' bytes — ~/Downloads 도착 확인 전에는 purgeQuiz 금지';
    },
    purgeQuiz: () => { localStorage.removeItem(KEY); return 'purged ' + KEY; }   // 반출 확인 후에만
  };
})();
window.__scuQuiz.err || JSON.stringify(window.__scuQuiz.probe());
```

| 함수 | 상태 변경 | 하는 일 |
|---|---|---|
| `probe()` | — | 문항 수 · 유형 분포(`O/X`·`객관식`·`주관식`·`?`) · 문서 교체(`stale`) · 전 문항 첫 버튼 텍스트 분포(`btnTexts`) · `firstBtn`(Q1 · 호환용) · 채점된 문항 수 · 사전 선택(`preSel`) · 저장 기록 불일치 문항 수(`staleQ`) · 유휴 · 탭 가시성 · 저장 문항 수 |
| `scan(a, b)` | 저장만 | 문항·보기(배지 번호 제외)·`passyn`·선택·사전 라벨(`pre`)을 문항별로 저장(채점 전 `scan` / 채점 후 `scanAfter`) · 반환은 1,900자 요약 · **저장 실패면 첫 줄 `SAVE FAILED`** |
| `pick(k, i)` | ⚠️ 선택 이벤트 | `i`는 1부터 · `'O'`→1 · `'X'`→2 · 대상은 컨테이너 안 배지 `[i-1]` · 발사 전에 **의도(`want`)·발사 표시(`pickAt`) 저장**(실패면 발사 안 함) · 배지가 없으면(`?`) 거부 — 미관측 DOM |
| `intend(k, i)` | 저장만 | **의도만 기록**(이벤트 없음) — 좌표 클릭만 쓰는 경로 · 주관식은 `intend(k, text)`로 실제 키 입력 전에 |
| `fill(k, text)` | ⚠️ 입력 | 주관식 `[contenteditable]` 값 주입 + `input`·`change`·`keyup`·`blur` · 입력 전에 **의도·입력 기록(`want`·`fill`) 저장** · 기존 글자를 덮으면 반환에 밝힌다 |
| `sel(k)` / `selNo(k)` | — | 선택 등록의 근거 — 보기 텍스트(배지 번호 제외 · 주관식은 `'text:…'` — 되읽기일 뿐 등록 증거 아님) / 배지 번호(1부터) |
| `stray()` | — | 채점 안 된 문항 중 선택이 있고 의도와 다른 문항 `[{no, sel, want}]` — 사용자 조작·오클릭 탐지 |
| `focus(k)` | 스크롤만 | **`guard` 통과 시에만** 문항을 화면 중앙에 둔다 — **좌표 선택 전용**(정답확인 재시도는 `coordConf`) |
| `conf(k)` | ⚠️ 채점 | 선택 없음 · 주관식 입력 미확인 · **의도 없음 · 선택 ≠ 의도** · 버튼 글자가 `정답확인`이 아니면(화이트리스트) · 발사 표시 저장 실패면 거부 · **대상 1회 발사**(`realOne`) · 발사 표시(`confAt`) |
| `coordConf(k)` | 저장·스크롤 | 정답확인 좌표 재시도 준비(4-B 7) — 문서 교체·hidden·유휴·채점됨·미발사면 거부 · 재시도 기록(`coordAt`)이 있으면 거부(문항당 1회) · 기록 후 중앙 정렬 |
| `res(k)` | — | `passyn` · 정답 행 보기 텍스트(`official`)·번호·`passed`/`failed` · 공식 정답 출처(`src`) · 내 선택 · 사전 라벨 · 해설 원문 · 주관식 입력 미등록 의심(`inputSuspect`) · 해설·탭 가시성 · 문서 교체면 `err` |
| `save(k)` | 저장만 | `res(k)`를 저장하고 그 값을 돌려준다 · 저장 실패면 `saveErr` · `err`면 저장하지 않는다 |
| `next()` | — | `pick`/`fill` · `click`(합성 선택 미등록 — 좌표 클릭으로) · `conf` · `ask`(에이전트가 고르지 않은 선택) · `mismatch`(선택 ≠ 의도) · `wait`(발사 후 채점 미반영) · `save` · `done` · `activate`(탭 hidden) · `stop`(문서 교체·유휴·문항 없음·유형 불명·저장 기록 불일치·좌표 재시도 소진) — `stop`·`activate`·`ask`·`mismatch`·`done`에는 `guard`(정지 가드 켜짐 여부 — **true면 보고 전에 해제**) |
| `rearm(k)` | 저장만 | **사용자가 재오픈했다고 확인하고** 초기화를 `res(k)`로 본 뒤에만 — 발사 표시(`confAt`·`pickAt`·`coordAt`)와 의도를 지운다 · **발사 때와 같은 문항 요소면 거부** |
| `exportQuiz()` / `purgeQuiz()` | 반출 / 삭제 | `scu-quiz-{NS}.json` blob 반출 · 도착을 확인한 뒤에만 비운다 |
| `real(el)` / `realOne(el)` | ⚠️ 이벤트 | 합성 pointer·mouse 5종 — 대상+부모(선택 1차 시도) / 대상만(정답확인 · 선택에는 진단 전용 · 4번 표) |

- `guard` — `pick`·`fill`·`intend`·`focus`·`conf`는 ① 플레이어 문서 교체 ② 탭 hidden ③ 유휴 종료 팝업 ④ 문항 없음 ⑤ 이미 채점됨(`Y`/`N`) ⑥ 발사 후 채점 미반영이면 **아무것도 하지 않고 거부 문구를 돌려준다**
  - ① 옛 헬퍼는 재오픈·항목 전환으로 교체된 문서를 계속 본다(옛 문서의 `defaultView`가 `null`) → **헬퍼를 재정의**한다
  - ② hidden 탭은 rect가 0이라 유휴 팝업·좌표 판정이 불확실하다 → **스크린샷으로 활성화한 뒤 `probe()`부터**
- 좌표 계산 함수(`badgeRect`)는 **두지 않는다** — 확대 배율로 약 1.15배 어긋났고 스크린샷 직후 23px 이동도 있었다(4-B 규칙 4). 좌표는 스크린샷에서만 읽는다
- ⚠️ **배지 없는 O/X(`type` = `?`)는 선택 확인 근거(`.selected`)가 없다** — 관측된 적 없는 DOM이므로 `pick`이 발사하지 않고 거부하며, `next()`가 `stop`을 돌려준다 → **중단하고 보고**한다
- 영속 쓰기(`put`)가 실패하면(같은 오리진에 `scuCap:*` 자막 백업이 쌓여 용량 초과 가능) **`pick`·`fill`·`intend`·`conf`·`coordConf`는 조작하지 않고 거부**하고, `save`는 `saveErr`, `scan`은 요약 첫 줄 `SAVE FAILED`로 드러낸다 —
  반출을 확인한 `scuCap:`/`scuQuiz:` 키를 정리한 뒤 재시도한다. 발사 표시 없이 누르면 이중 발사 방지(`wait`)가 사라지기 때문이다
- `src` — 정답 행이 있으면 `정답 행` · 주관식은 채점 후 라벨(`정답 라벨(주관식)`) · 둘 다 없으면 `미확보(…)` — ⛔ 미확보를 추정으로 채우지 않는다
- 합성 DOM(headless Chromium)에서 확인한 동작(v1.2.0 작성 시) — 선택 없는 `conf` 거부 · 발사 후 재발사 거부(`wait`) · 채점 후 `pick` 거부 · 유휴 팝업 시 전 조작 중단 ·
  오답 문항의 `failed-answer` 정답 행 회수 · 주관식 라벨 회수 · 라벨 없는 해설 분리 · 참 진술 `정답① O` 라벨 인식 · 전역 버튼 폴백 · `rearm` 뒤 재개. ⚠️ 실제 강의실 DOM에서의 검증은 다음 채점 때 한다
  - 검증 지적 반영 뒤 추가 확인(v1.2.0) — 보기 텍스트에서 배지 번호 제거(실측 `1O` 재현 DOM) · 자리표시자 `__scuNS` 거부 · 문서 교체 시 조작·결과 거부 ·
    탭 hidden 시 조작 거부(숨은 조상 안 팝업은 유휴로 읽지 않음) · 저장 실패 시 `conf` 거부·`saveErr` · 합성 선택 미등록 뒤 `click` · 주관식 자리표시 글자 거부·`inputSuspect` ·
    의도 없는 사전 선택 `ask`·불일치 `mismatch`·`preSel` · 이웃 문항 오클릭 `stray` · 좌표 재시도 1회 제한 · 같은 요소 `rearm` 거부 · `정답확인` 대상 1회 발사 ·
    저장 기록 문항 불일치 `stop` · `guard` 플래그 · 버튼 화이트리스트(114항목 중 113 통과).
    남은 1건은 설계상 한계다 — 합성 `input`을 무시하는 DOM에서도 주관식 `sel(k)`은 `text:…`를 돌려준다(되읽기일 뿐 등록 증거가 아니다 → 채점 뒤 `inputSuspect`로만 드러난다 · 위 「주관식 입력」)

**⭐ 학습평가 자동 채점 루프 — ⚠️ 반드시 한 호출에 한 동작씩**

0. **준비** — **조작 전 스크린샷으로 탭을 앞으로 가져온다**(hidden이면 rect 0 · 헬퍼가 거부한다) → `__scuIdle()`이 `null`인지, `__scuNS`가 설정됐는지, 헤더가 `… | 평가하기`인지 확인 → 헬퍼 정의 → `probe()`로 확인한다
   - **`drawn`이 `false`(문항 rect 0)면 조작하지 않는다** — 그려지지 않은 탭은 유휴 팝업·좌표 판정이 불확실하다. 스크린샷으로 탭을 앞으로 가져온 뒤 `probe()`를 다시 부른다
     - ⚠️ **`tab`(`visibilityState`)으로 판정하지 않는다** — MCP 탭은 그려져 클릭이 되는 상태에서도 `hidden`으로 남았다(2026-09-17 문제해결 1주차·딥러닝 1주차·GitHub 1주차 · `hasFocus` `true`). v1.2.0 헬퍼는 이것으로 막아 모든 조작이 거부됐다 → v1.2.1에서 rect 판정으로 바꿨다
   - `stale`이 `true`면 헬퍼를 재정의한다
   - `types`에 `?`가 있거나 **`btnTexts`에 `정답확인` 외의 키가 하나라도 있으면** 중단하고 실물을 본다
   - **`preSel`이 비어 있지 않으면 채점하지 않고 사용자에게 묻는다** — 사용자가 직접 풀던 중일 수 있다(에이전트가 고르지 않은 선택)
     - 예외(v1.2.1) — **완료 주차를 재오픈해 과거 선택이 남은 경우**(위 「재오픈」 — 사용자가 지금 풀고 있는 주차가 아니다)는, 남은 선택이 이번 근거 답(정답 라벨 → 자막·교안·학습정리)과 **모두 같을 때만** `intend(k, 그 답)`으로 의도를 기록하고 진행한다. 하나라도 다르면 멈추고 묻는다. 채택 사실은 8단계 보고에 적는다(2026-09-17 문제해결·딥러닝 1주차가 이 경로)
     - 과거 채점 기록(스크립트·과목 문서의 날짜·결과)이 있고 **채점 전 DOM의 정답 라벨이 공식 값인 유형**(GitHub·딥러닝·빅데이터)에서 해설 원문만 필요하면, 재채점하지 않고 `scan()`·`res()`로 읽기만 한다 — 이력만 겹친다(2026-09-17 GitHub 1주차)
   - **`saved`가 0이 아닌데 이 주차를 처음 채점하는 것이면 멈춘다.** `staleQ`가 0이 아니면 `__scuNS` 오류이므로, 고친 뒤 헬퍼를 재정의한다
1. **사전 채록** — `scan()`으로 저장하고, `__scuCapture()`로 채점 전 텍스트 스냅샷도 남긴다(7번)
2. **답·근거 표** — 위 「답 선택 근거」 순서(라벨 `pre.answer` → 자막·교안·`학습정리` → 근거가 없으면 첫 보기 + 「근거 없음 — 첫 보기」 · **주관식은 채점 생략 · 미확보 보고**).
   표는 사용자에게 **한 번 제시하고 기다리지 않고** 진행한다 — 같은 메시지에서 「퀴즈 화면은 누르지 말아 달라」고 알린다
3. **`next()`가 가리키는 `k`마다** 아래를 반복한다(`step`에 따라)
   1. `pick` → `pick(k, i)` · `fill` → `fill(k, text)`
   2. 별도 호출로 `selNo(k)`(주관식은 `sel(k)`) — 의도한 번호여야 한다. `null`이면 1~2초 뒤 한 번 더 읽는다.
      그래도 `null`이면 **합성 이벤트를 반복하지 않고 좌표 클릭**으로 간다(`next()`도 `click`을 돌려준다) — `__scuStop(true)` → `focus(k)` → 스크린샷 → 번호 배지 **즉시** 좌표 클릭 → `selNo(k)`·`stray()` 재확인(4-B 규칙 4).
      그래도 안 되면 **루프를 중단하고 보고**한다. 의도한 번호가 아니면 멈춘다(바로잡기는 선택 단계에서만)
   3. 별도 호출로 `conf(k)`
   4. 3~4초 뒤 `save(k)` — 반환의 `passyn`이 `null`이면 **바로 누르지 않고** 3~4초 간격으로 `save(k)`를 두 번 더 읽는다. 그래도 `null`이면 `coordConf(k)` → 스크린샷(필요하면 `zoom`)으로 그 문항의 `정답확인` 글자 확인 → **즉시 한 번** 좌표 클릭 → 3~4초 뒤 `save(k)`.
      버튼이 안 보이거나 구분되지 않으면 누르지 않는다. 그래도 `null`이면 중단한다(4-B 규칙 7 — 좌표 클릭은 헬퍼 `guard`를 거치지 않으므로 이중 채점 방지는 이 재확인과 `coordAt` 기록뿐이다)
   - `ask`(에이전트가 고르지 않은 선택) · `mismatch`(선택 ≠ 의도) → **채점하지 않고 멈춘다.** `ask`는 사용자에게 묻고, `mismatch`는 규칙 3(바로잡기는 선택 단계에서만)
   - `activate`(탭 hidden) → 스크린샷으로 활성화하고 `probe()`부터 · `stop` → 사유대로 중단·보고
   - 어느 호출에서든 `중단 — 유휴 종료 팝업`이 나오면 **즉시 멈추고** 정지 가드를 해제한 뒤(4-B 9) 감시 탭에서 재오픈을 요청한다. 재오픈 뒤에는 **헬퍼를 재정의**하고 `next()`부터 다시 본다
4. **검증** — `scan()`을 다시 불러 전 문항 `passyn`이 `null`이 아닌지 확인하고, `__scuCapture()`로 채점 후 스냅샷을 남겨 5번 보조 정규식으로 텍스트를 대조한다.
   정답 라벨 없는 유형의 해설은 정규식이 `(해설 라벨 없음 …)`으로 내는 것이 정상이다 — 해설 유무·원문은 `res(k).explanation`과 대조한다
5. **대조표** — 사전 정답(`labeled` 문항) · 내 선택(`mineNo`) · 공식 정답 행(`official`) · `passyn` · 해설 원문 · 해설 공백 여부
6. **반출·반영** — `exportQuiz()` → `~/Downloads`에 파일이 생겼는지 확인(지연 도착 — 몇 분 뒤 재확인 · 중복 재시도 금지) → `purgeQuiz()` → 7단계 스크립트 반영 → 8단계 보고.
   종료·중단 어느 경우든 **정지 가드를 해제**했는지 확인한다(`next()`의 `guard` · 4-B 9)

```javascript
// 호출 ①  __scuQuiz.next()              → {k: 0, step: 'pick'}  (읽기 전용)
// 호출 ②  __scuQuiz.pick(0, 2)          ← 보기 번호(1부터) · O/X는 pick(0, 'X')와 같다(1=O · 2=X) · 의도 저장 후 선택만 한다
// 호출 ③  __scuQuiz.selNo(0)            ← 2가 나와야 한다 · null이면 1~2초 뒤 한 번 더 → 그래도 null이면 좌표 클릭(4-B 4)
// 호출 ④  __scuQuiz.conf(0)             ← 선택 없음·의도 없음·선택≠의도·이미 발사·채점된 문항이면 헬퍼가 거부한다
// 호출 ⑤  (3~4초 뒤) __scuQuiz.save(0)  ← res(0)을 저장하고 돌려준다 · passyn이 null이면 4-B 7(save 2회 더 → coordConf)
// step 'click'    → __scuStop(true) → __scuQuiz.focus(0) → 스크린샷 → 배지 좌표 클릭 → __scuQuiz.selNo(0) · __scuQuiz.stray()
// 좌표만 쓸 때    → __scuQuiz.intend(0, 2) → focus(0) → 스크린샷 → 좌표 클릭 → selNo(0) · stray() → conf(0)
// step 'ask' / 'mismatch' → 채점하지 않고 멈춘다 · 'activate' → 스크린샷으로 탭 활성화 후 probe()
// 주관식   __scuQuiz.fill(4, 'git status') → __scuQuiz.sel(4) → __scuQuiz.conf(4) → __scuQuiz.save(4)
// guard: true 인 stop·done → 보고 전에 clearInterval(window.__scuGuard); window.__scuGuard = null (4-B 9)
JSON.stringify(window.__scuQuiz.next())
```

- 각 호출의 반환 문자열로 **의도한 문항이 처리됐는지 매번 대조**한다
- `selNo(k)`·`sel(k)`은 선택 직후 렌더가 늦을 수 있다 → `null`이면 **1~2초 뒤 한 번 더** 읽고, 그래도 `null`이면 **미등록으로 확정**하고 실제 클릭으로 간다
- 채점 직후에는 렌더가 늦다 → `conf(k)` 다음 **3~4초 기다린 뒤** `save(k)`로 `data-passyn`을 확인하고 다음 문항으로 간다
- 한 문항이라도 `보기 … 없음`·`버튼 없음`·`입력칸 없음`·`유형 불명`이 나오면 **중단하고 유형 분기를 다시 확인한다** — 밀어붙이면 엉뚱한 문항을 누른다 (→ 가드 해제 후 보고 · 4-B 9)
- `중단 — 유휴 종료 팝업`이 나오면 **그 자리에서 아무것도 누르지 않는다** — 사용자에게 **감시 중인 탭에서** 다시 열어 달라고 한다 (→ 가드 해제 후 보고 · 4-B 9)
- `저장 실패`가 나오면 조작은 일어나지 않았다 — 반출을 확인한 `scuCap:`/`scuQuiz:` 키를 정리한 뒤 같은 호출을 다시 한다
- ~~문항 수 × 3회 (`pick` → `sel` → `conf`)~~ — v1.1.8~v1.1.9의 호출 순서. 결과 회수(`save`)가 빠져 있었다

**주관식**

- 입력은 `fill(k, text)`로 한다(합성 마우스 이벤트 불필요 — GitHub 2주차 실증)
  - **`sel(k)`의 `text:…`는 주입한 글자를 되읽을 뿐 등록 증거가 아니다 — 주관식의 등록 여부는 채점 뒤 `passyn`으로만 안다.**
    `sel(k)`은 입력이 들어갔는지(주입 실패·다른 문항 입력) 확인하는 용도로만 읽고, 채점 뒤 `res(k).inputSuspect`가 `true`면 「입력 미등록 의심(재시도 수단 없음)」으로 보고한다
  - 입력칸에 원래 있던 글자(`scan` 시점)는 입력으로 치지 않는다 — `fill` 또는 실제 키 입력(`intend(k, text)` 뒤) 뒤에만 채점한다(`next()`는 `fill`을 돌려주고 `conf`는 거부한다)
- 정답 행이 없으므로 공식 정답은 **채점 후 `res(k)`의 라벨 정답**(`answer`, `src: '정답 라벨(주관식)'`)이다.
  라벨이 없는 과목이면 **「공식 정답 미확보(주관식·라벨 없음)」로 보고**하고 추정하지 않는다(⚠️ 미실측 영역)
- 입력값의 근거는 사전 라벨 → 자막·교안이다. 라벨이 있으면 **그 문자열을 그대로** 입력한다 — 대소문자·공백 차이로 `N`이 날 수 있다.
  **근거가 없으면 입력·채점하지 않고 `정답 미확보(주관식·근거 없음)`로 보고한다** — 주관식에는 첫 보기가 없다. 지어낸 문자열로 채점하지 않는다

**이미 채점된 문항 · 완료 주차 재오픈**

- **헬퍼를 먼저 (재)정의하고 `res(k)`를 읽는다**(옛 헬퍼는 교체된 문서를 계속 본다 — `probe().stale` · 교체됐으면 `res`가 `err`를 돌려준다).
  `passyn`이 `Y`/`N`이면 `guard`가 조작을 막으므로 `save(k)`만 한다 — 정답 행·해설은 그대로 회수된다
- 초기화돼 있으면(`passyn` `null` · 정답 행 없음) 일반 루프를 탄다. 저장소에 옛 발사 표시가 남아 `next()`가 `wait`(또는 `click`)만 돌려주면
  초기화를 `res(k)`로 확인한 뒤 `rearm(k)`하고 `next()`부터 다시 본다
  - ⛔ **`rearm`은 사용자가 재오픈했다고 확인한 뒤에만 쓴다.** `wait`가 오래 간다는 이유로 쓰지 않는다 — 같은 페이지의 채점 반영 지연과 재오픈 초기화는 `res(k)`만으로 구별되지 않는다.
    발사 때와 같은 문항 요소면 헬퍼가 거부한다(`__scuFiredEls`)
- 재오픈 뒤에는 **채점 상태(`passyn`·정답 행)가 초기화되고 과거 선택은 남는다**(관측 4회 — 2026-09-14 딥러닝 3주차 · 2026-09-17 문제해결·딥러닝·GitHub 1주차). 그래서 `probe()`의 `preSel`이 과거 선택으로 채워진다(아래 규칙). 다른 결과가 나오면 8단계 보고에 적는다
- 스크립트나 과목 `CLAUDE.md`에 **과거 채점 기록(날짜·결과)이 있는 주차**를 다시 열었는데 초기화돼 있으면, 재채점 전에 그 사실(채점 이력이 겹친다)을 사용자에게 알리고 8단계 보고에 적는다 — 승인 대기는 아니다(상시 정책)
- 재오픈 주체 — **완료 주차는 스킬이 직접 연다**(상시 정책 · 행이 이미 `완료` · 「⛔ 절대 하지 말 것 4」 ②), 미완료 주차는 사용자 수강 흐름으로만 연다. 어느 경우에도 채점하려고 영상 재생·`›` 이동을 대신하지 않는다

**5. 보조 추출 — 텍스트 스냅샷 대조용 · 주 경로는 DOM 기반 `res(k)` — 문항번호·정답·해설 **세 개의 독립 정규식****

- 공식 정답·해설은 `res(k)`·`save(k)`로 회수한다. 이 정규식은 **채점 전/후 `__scuCapture()` 텍스트를 대조**할 때만 쓴다
- ⚠️ 라벨 없는 유형(문제해결 O/X)에서는 정답이 `(라벨 없음)`으로 나오는 것이 정상이다 — 정답 행으로 확인한다
- ⚠️ 라벨 없는 유형은 해설도 `(해설 라벨 없음)`으로 나오는 것이 정상이다 — 채점 뒤 해설 문장이 보여도 `해설` 라벨이 없어서다. **해설 유무·원문은 `res(k).explanation`**으로 확인한다

⚠️ **문항 머리는 과목마다 다르다** — **`Quiz.01`**(딥러닝·빅데이터) / **`Self Check 01.`**(문제해결 3주차). `문제 N`·`N.`만 받는 정규식은 **0건**을 반환하고,
`Self Check`를 모르는 정규식은 본문 전체를 **청크 1개**로 뭉갠다(2026-09-17)

⚠️ **`정답` 라벨 정규식이 버튼 텍스트 `정답확인`을 정답으로 오인한다** — 실측 오탐 `정답:"확인"`. **부정 전방탐색이 필수**다. 바로 위 절의 절단 버그(`indexOf('정답확인')`로 잘라 `-1`)와 **방향이 반대인 오매치 버그**이며, 둘 다 같은 토큰을 둘러싼 실패다. 한쪽만 고치지 말 것

⚠️ **정답과 해설을 한 패턴에 묶지 말 것** — 해설을 필수로 만들면 해설 없는 문항에서 매치 전체가 실패해 **정답까지 `?`가 된다**

```javascript
(() => {
  const s0 = ((window.__scuQuiz.d.body || {}).innerText || '').replace(/\r/g, '');

  // ① 문항 번호 — 화면 표기 4형식. Quiz./문제/Self Check 를 먼저 쓰고, 0건일 때만 'N.' 폴백
  //    Self Check 뒤에 지문이 같은 줄로 붙는지는 미확인 — 그래서 이 대안에만 줄 끝 조건을 걸지 않는다
  const A = /(?:^|\n)[ \t]*(?:(?:Quiz\.?[ \t]*0*(\d+)|문제[ \t]*0*(\d+))[ \t]*(?=\n|$)|Self[ \t]*Check[ \t]*0*(\d+)\.?[ \t]*)/g;
  const B = /(?:^|\n)[ \t]*0*(\d+)[ \t]*[.)][ \t]*/g;          // 본문 숫자 오탐이 잦다
  const scan = re => { const out = []; let m; re.lastIndex = 0;
    while ((m = re.exec(s0))) out.push({ no: +(m[1] || m[2] || m[3]), at: m.index, end: re.lastIndex });
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
  const RE_EXP  = /(?:^|\n)[ \t]*해설[ \t]*[:：]?[ \t]*([\s\S]+?)(?=\n[ \t]*(?:Quiz\.|문제[ \t]*\d|Self[ \t]*Check|정답|다시풀기|정답확인)|$)/;

  return chunks.map(c => {
    const a = c.s.match(RE_ANS) || c.s.match(RE_ANS2), e = c.s.match(RE_EXP);
    return `Q${String(c.no).padStart(2, '0')} 정답: ${a ? a[1].trim() : '(라벨 없음 — res(k).official로 확인)'}`
         + ` / 해설: ${e ? e[1].trim().replace(/\s+/g, ' ') : '(해설 라벨 없음 — 해설 유무·원문은 res(k).explanation으로 확인)'}`;
  }).join('\n');
})()
```

**6. ⚠️ 빈 해설은 추출 실패가 아니다 — 단 규칙은 퀴즈 유형마다 다르다**

| 유형 | 정답 라벨 (채점 전 DOM) | 해설 | 실측 |
|---|---|---|---|
| **O/X형** (딥러닝) | 있음 — `정답① O` (GitHub O/X도 `정답① ○` 라벨이 있다 · 해설 분포는 미기록) | 거짓 진술 문항에만 | 딥러닝 2주차 Q1·Q4(거짓)=해설 / Q2·Q3(참)=없음 · 문제해결 1주차 동일(라벨 유무 미기록) · 딥러닝 3주차 Q2·Q3(거짓)=해설 / Q1(참)=없음 |
| **O/X형 — 문제해결프로그래밍입문** (3주차 6문항) | ⛔ **없음** | 거짓 진술 2·4·5에만 — **채점 후에도 1·3·6 해설 없음**(`innerHTML`부터 빈 칸) | 2026-09-17 전수 · 공식 정답 `O X O X X O`는 채점 후 정답 행으로만 확정 |
| **번호 배지형 객관식** | 있음 — `정답③ …` | **전 문항** | 빅데이터분석실무 2주차 4문항 전수 |

- ⛔ **「과목 공통 패턴」으로 일반화하지 말 것** — 2026-09-08에 그렇게 적었다가 다음 날 4지선다에서 반증됐다
- 번호 배지형에서 해설이 비면 그건 **정상이 아니라 추출 실패**다 — 정규식·대기시간을 의심한다
- ⛔ 해설이 비었다고 "추출 실패"·"정답 비공개 과목"으로 **오판하지 말 것** — **정답 라벨이 없는 것도 비공개의 증거가 아니다**(문제해결 O/X).
  공식 정답은 채점 후 정답 행으로 확정한다
  - ~~정답 라벨까지 없을 때만 비공개를 의심하고, 그 판단도 위 정규식으로 재확인한 뒤에 한다~~ **폐기(v1.2.0)**
- **해설이 없으면 `공식 해설 없음(참 진술)`이라고 명시한다** — 추출 실패와 구분하기 위해서다. 참/거짓 판정은 **채점 후 정답 행** 기준이다
  (실제 스크립트 관행 — 딥러닝 2·3주차 · 문제해결 2·3주차 `정답 O — 공식 해설 없음(참 진술)`)
  - ~~스크립트에는 `해설: (없음)`이 아니라 해설 줄을 생략하고, 보고에서 "참 진술 문항이라 해설 없음"으로 밝힌다~~ **폐기(v1.2.0)** — 생략하면 누락과 구분되지 않는다

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
- ⛔ **학습평가 채점 정책(v1.2.0 상시 정책)은 `›`/`‹` 이동 권한을 주지 않는다** — 정책은 `평가하기`에 도달한 뒤의 선택·`정답확인`에만 적용된다. 채점을 마쳐도 `정리하기`로 넘기는 것은 사용자 지시를 따른다

- **학습정리** — 요약 슬라이드. 이미 수강 완료한 페이지라면 열어서 읽어도 진도 영향이 없다

#### ⚠️ 학습정리 채록 — 태그가 없다. 텍스트 노드와 x좌표로 단계를 읽는다

**2026-09-14 딥러닝 3주차 실측.** `학습정리` 슬라이드는 `maui` 컴포넌트로 그려져 **`h1`~`h4`·`li`·`p` 태그가 하나도 없다.**
태그로 줄을 모으는 추출은 **빈 배열**을 돌려준다. 오류가 나지 않으므로 실패인 줄 모르기 쉽고, 실제로 그 빈 배열이
반출본(`__summary.lines: []`)에 그대로 들어갔다.

- `__scuCapture`(`innerText`)는 글자는 얻지만 **들여쓰기 단계를 잃는다** — 요약 슬라이드는 단계가 곧 구조다
- ✅ **TreeWalker로 텍스트 노드를 모으고, 부모 요소의 `getBoundingClientRect().left`로 단계를 정한다**

| x (실측) | 글자 크기·굵기 | 역할 | 노트 표기 |
|---|---|---|---|
| 390 | 60px · 600 / 18px · 400 | 머리글 `학습정리` / `이번 주차에서 학습한 주요 내용을 다시 한번 확인해보세요.` | 본문에서 뺀다 |
| **417** | **40px** · 600 | 절 제목 | `## 제목` |
| **437** | 18px · 400 | 1단 | `- ` |
| **459** | 18px · 400 | 2단 | `  - ` |
| **481** | 18px · 400 | 3단 | `    - ` |
| 0 | 14.5px | 슬라이드 밖 플레이어 UI(`강의영상 캡쳐` 등) | 뺀다 |

- ⚠️ **절대값을 외우지 말 것** — 창 너비·레이아웃에 따라 달라진다. 머리글과 x=0 줄을 뺀 뒤 **관측된 x값을 오름차순으로 순위화**해
  단계로 쓴다(실측 간격 20~22px). 글자 크기(40px 제목 / 18px 본문)가 순위 판정의 교차 확인이 된다
- 수식은 **유니코드 수학 문자**(`𝐿=−(𝑦log(𝑎)+…)`)로 들어 있다 — 채록에서는 **그대로** 옮긴다(LaTeX 변환은 노트 단계의 일)
- 한 줄이 여러 span으로 쪼개질 수 있다 → **같은 줄(y 근접)의 조각을 이어 붙이고**, 조각마다 잘라내지 말고 **합친 뒤에 한 번만** 공백을 정리한다
- 결과가 0줄이면 **추출 실패**다 — 「정리 없음」으로 보고하지 말고 **먼저 탭 가시성(`document.visibilityState`)을 본다.**
  hidden이면 rect가 0이라 **전 조각이 걸러진다** → 스크린샷으로 활성화한 뒤 다시 부른다. 그다음 문서 특정(`.toc-row`)을 다시 본다

```javascript
window.__scuSummary = function () {
  const docs = [];
  (function collect(d) { docs.push(d);
    [...d.querySelectorAll('iframe')].forEach(f => {
      try { if (f.contentDocument) collect(f.contentDocument); } catch (e) {}
    });
  })(document);
  const d = docs.find(x => x.querySelector('.toc-row'));   // ⚠️ 길이 휴리스틱 금지
  if (!d) return { err: 'player doc not found (.toc-row 없음)' };
  const W = d.defaultView;

  const parts = [];
  const tw = d.createTreeWalker(d.body, W.NodeFilter.SHOW_TEXT);
  for (let n; (n = tw.nextNode());) {
    const el = n.parentElement;
    if (!el || !n.textContent.trim() || el.closest('.toc-row, script, style')) continue;
    const r = el.getBoundingClientRect();
    if (!r.width || !r.height) continue;                    // display:none 조상 아래는 크기가 0
    const cs = W.getComputedStyle(el);
    parts.push({ x: Math.round(r.left), y: Math.round(r.top),
                 fs: cs.fontSize, fw: cs.fontWeight, t: n.textContent.replace(/\s+/g, ' ') });
  }

  const lines = [];                                          // 같은 줄(y 근접)의 조각을 잇는다
  for (const p of parts) {
    const L = lines[lines.length - 1];
    if (L && Math.abs(L.y - p.y) <= 4) { L.t += p.t; L.x = Math.min(L.x, p.x); }
    else lines.push({ ...p });
  }
  return lines.map(l => `${l.x}|${l.fs}|${l.fw}|${l.t.trim()}`).filter(s => !/\|$/.test(s));
};
JSON.stringify(window.__scuSummary())
```

- 반환은 `x|글자크기|굵기|텍스트` 줄 배열이다 — 응답 상한(약 1,900자)에 걸리면 `slice`로 나눠 받는다
- 줄바꿈된 긴 항목은 텍스트 노드 하나라 **한 줄로 나온다**(부모 요소 기준 좌표). 같은 x에 연속으로 나오는 줄을 한 항목으로 합치지 말 것 — 별개 항목이다

**세 항목 모두 지금 채록하지 않으면 복원 경로가 없다.** **자막에도**, 전사에도, 교안에도, 어디에도 없다.

⚠️ **학습평가의 공식 정답은 채점해야만 나오는 유형이 있다**(문제해결 O/X — 채점 전 정답 라벨 없음) → **채록과 채점을 같은 방문에서 끝낸다.**
채점 뒤에는 재시도 수단이 없고, 재오픈했을 때 채점 상태가 유지되는지도 확정되지 않았다(「이미 채점된 문항 · 완료 주차 재오픈」).

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
## 학습평가              ← 퀴즈 페이지 · 영상·MP3 없음 · 채록·채점 필요
---
# 정리하기
## 학습정리              ← 요약 슬라이드 · 영상·MP3 없음 · 채록 필요

※ 미배정 MP3: _03(649초 10:49) · _04(918초 15:18) …
   ⛔ 전사 내용으로 목차명·순번을 추정해 채우지 말 것
```

**하위 목차명은 확인됐지만 순번은 미확정**인 상태가 정상이다. 그때는 `## ( )제목`으로 두어 이름은 살리고 번호만 비운다. 이름까지 지우면 다시 열어야 한다.

- 채점을 마치면 목차 주석을 `← 퀴즈 페이지 · 영상·MP3 없음 · 채록·채점 완료 6문항`처럼 바꾼다 — `create-note`가 주석의 `N문항`을 문항 수 대조에 쓴다

### ⭐ 학습평가 본문 형식 — 정본 (v1.2.0)

본문 구역의 번호 없는 `## 학습평가`에 적는다. `create-note`의 `parse_quiz_capture()`(3-C)가 이 형식을 **①정본**으로 읽고, 노트를 써도 되는지 판정한다.

```
## 학습평가
[MP3 없음 — 퀴즈 페이지. 2026-09-17 강의실에서 채록 · 정답확인 채점 6문항(Y 6 · N 0) · 공식 정답 = 채점 후 정답 행 · 채점 전 정답 라벨 없는 유형]

공통 지시문: 학습한 내용을 바탕으로 다음 문제를 풀어보세요. (O/X 6문항 · 화면 머리 「Self Check 0N.」)

1. 리스트는 여러 값을 순서대로 저장할 수 있는 자료형이다. (O/X)
   보기: ① O  ② X
   정답 ① O
   공식 해설 없음(참 진술)
   채점: Y (선택 ①)

2. 리스트의 인덱스는 1부터 시작한다. (O/X)
   보기: ① O  ② X
   정답 ② X
   공식 해설: 리스트의 인덱스는 0부터 시작한다.
   채점: Y (선택 ②)
   보충 근거: 자막 (N)제목 — 강의가 설명한 근거 요약

…

※ 정답 확인 방법 — 보기 선택(스크린샷 좌표 클릭) → `.item-select-option-no.selected` 확인 → 정답확인 → 정답 행(`.passed-answer`)·`data-passyn` 회수
※ 이 과목 O/X는 채점 전 `[data-field="explanation"]`에 정답 라벨이 없고, 공식 해설은 거짓 진술(2·4·5번)에만 있다
```

객관식·주관식·회수 실패는 이렇게 적는다.

```
1. 지문 원문
   ① 보기 원문
   ② 보기 원문
   ③ 보기 원문
   ④ 보기 원문
   정답 ③ 보기 원문
   공식 해설: 원문 그대로
   채점: N (선택 ① · 사유: 근거 없음 — 첫 보기)

11. 지문 원문
   (주관식 단답 — 직접 입력)
   정답 git status
   공식 해설: 원문 그대로
   채점: Y (입력 git status)

12. 지문 원문
   (주관식 단답 — 직접 입력)
   정답 미확보(주관식·라벨 없음)
```

| 줄 | 적는 것 | 출처 |
|---|---|---|
| 머리 `[…]` | 채록 날짜 · **`정답확인 채점 N문항(Y a · N b)`** — N = `채점:` 줄이 있는 문항 수(이미 채점돼 `save(k)`로 읽기만 한 문항 포함, `정답 미확보` 문항 제외) · 공식 정답 출처 · 사전 라벨 대조 `n/m 일치`(라벨 있는 유형) 또는 라벨 없음 | 8단계 보고와 같은 값 |
| `공통 지시문:` | 지시문 원문 · 유형 구성 · 화면 머리(`Quiz.0N` / `Self Check 0N.`) | 화면 |
| `N. 지문` | 지문 원문 · O/X면 끝에 `(O/X)` | `scan()`의 `q` |
| `보기:` / `① …` | 보기 원문 — O/X는 한 줄, 객관식은 한 줄에 하나 · 화면이 숫자 배지여도 `①`~`⑩`으로 적는다 | `scan()`의 `opts`(배지 번호를 뺀 보기 텍스트 — 번호는 순서로 붙인다) |
| `정답` | **정답 행** — `정답 ② X` · `정답 ③ 보기 원문` · 주관식은 채점 후 라벨 원문 `정답 git status` | `res(k).officialNo`(→ `①`~`⑩`) + `res(k).official`(보기 텍스트) · 주관식은 `res(k).answer` |
| `공식 해설:` / `공식 해설 없음(참 진술)` | 해설 원문 **그대로**(어미·마침표 유지) · 비었으면 없음을 **명시**(O/X 참 진술은 `(참 진술)`, 그 밖은 `공식 해설 없음`) | `res(k).explanation` |
| `채점:` | `Y`/`N` · 선택한 보기(주관식은 입력값) · `N`이면 사유(근거 없음 — 첫 보기 / 선택 미등록 / 강의 근거와 공식 불일치) | `res(k).passyn`·`mineNo` |
| `보충 근거:` | 자막 `(N)제목`·교안·`학습정리`에서 찾은 근거 — **공식 원문과 처음부터 다른 줄에** 둔다 | 스킬이 찾은 것 |
| `※` | 선택·채점 방식(합성 이벤트 / 좌표 클릭) · 정답 라벨 유무 · 해설 공백 문항 · 원문 오탈자 | 작업 기록 |

- ⛔ **「(추정)」·「추정값」·「공식 채점 전」 표기 금지.** 채점하지 못한 문항은 **`정답 미확보(사유)`**로 남기고 8단계에서 보고한다 — create-note 0단계 게이트가 이 문항이 남아 있는 한 노트 작성을 막는다
- ⛔ **머리 줄의 `정답확인 채점` 기록을 빼지 말 것** — create-note 파서는 채점 기록(`정답확인 후/뒤` · `정답확인 채점 N문항` · `채점: Y/N` · `채점 N/N` · `passyn=Y/N` · `채점 검증 완료`)이 없으면 정답 줄이 있어도 공식값으로 보지 않는다
  - `passed-answer`·`passyn`이라는 낱말만으로는 채점 기록이 아니다 — 방법 설명과 위 템플릿의 `※` 줄에도 나온다
  - 머리의 N은 `채점:` 줄이 있는 문항 수와 같아야 하고, `채점:` 줄이 하나라도 있으면 **공식 정답을 적은 문항마다** `채점:` 줄이 있어야 한다 — 어긋나면 create-note 게이트가 막는다(유휴 종료로 중간에 멈춘 채점을 걸러낸다)
  - 머리·`※`·`채점:`·`보충 근거:` 줄에 `추정`·`추측`·`짐작`·`미채점`을 쓰지 않는다(부정 표현 「추정 없음」은 괜찮다) — 게이트가 미준비로 본다
- **공식 원문과 보충을 한 줄에 섞지 않는다** — 옛 채록 메모의 공식 해설에 덧붙인 풀이가 섞여 원문을 다시 받아야 했던 일이 있다(2026-09-17 빅데이터분석실무 1주차). 공식 해설 줄에는 원문만 둔다
- 원문 오탈자는 고치지 않고 `※` 주석으로 표시한다(예: 딥러닝 3주차 「성능을 좋을 수」)
- 공식 정답과 강의 근거가 어긋나면 `보충 근거:`에 불일치와 **`학습정리` 대조 결과**를 함께 적는다(GitHub 2주차 Q3) — 정답 줄은 공식값 그대로다
- 주관식에서 채점 후에도 정답 라벨이 없으면 `정답 미확보(주관식·라벨 없음)`으로 적는다 — 입력값을 정답으로 옮기지 않는다(`Y`로 채점돼도 입력값은 강의실이 표시한 공식 표기가 아니다 · 라벨 없는 과목의 주관식은 미실측 — 6단계 「주관식」과 같은 규칙)
- `채점:` 줄(`Y`/`N`·선택 보기·사유)과 `※` 방식 기록은 **스크립트와 과목 `CLAUDE.md`에만** 둔다 — 강의노트에는 옮기지 않는다(create-note 몫)
- 기존 한 줄형(`정답 X — 공식 해설: 원문` · `정답 O — 공식 해설 없음(참 진술)` — 딥러닝 2·3주차 · 문제해결 2·3주차)도 create-note 파서가 그대로 읽는다. **새 채록은 위 정본 형식으로 쓴다**

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
assert len(re.findall(r'^##[ \t]*\(\d+\)', body, re.M)) == 기대_구역수   # `\d` 하나만 쓰면 (10) 이후를 놓친다
```

⚠️ `io.open(f,'w',...)`에 **buffering 인자를 잘못 넘기면 예외 전에 파일이 잘릴 수 있다.** 쓰기 전에 `shutil.copy2`로 백업하고, 검증 통과 후 백업을 지운다.


## 8단계: 보고

- 확정된 `## (N)` 과 근거(영상 길이 = MP3 길이)
- **이번 작업으로 완료 처리된 항목** — 사용자가 아니라 스킬이 열어 완료된 것이 있으면 반드시 밝힌다
- **길이를 직접 확인하지 못하고 규칙으로만 배정한 순번** — 있으면 반드시 구분해 밝힌다
- **사용자 조치가 필요한 항목** — 게시판 글, 계정 생성(GitHub·AWS Academy), 외부 사이트 가입,
  과제·토론 마감, AWS Academy 지식 점검 응시·캡처 제출, OJ 제출. 이런 것들은 스킬이 대신하지 않으므로 목록으로 넘긴다
  (학습평가 채점 정책의 대상이 아니다 — 「⛔ 절대 하지 말 것 4」)
- 미확정 항목과 **확인 방법** — "N주차 X 항목을 수강하시면 읽어서 채우겠습니다"
- **학습평가 채점 결과** (상시 정책 — 채점했으면 빠짐없이)
  - 문항 수 · 유형 구성 · **`Y`/`N` 수** · 공식 정답 회수 `N/N` · 공식 해설 있음 `M` / 없음 `K`
  - **좌표 클릭으로 전환한 문항**(합성 이벤트 미등록) — 6단계 4번 날짜별 표에 이번 행을 누적했는지
  - **근거 없이 첫 보기를 고른 문항**(「근거 없음 — 첫 보기」) — 찍었다는 사실을 숨기지 않는다 · **주관식 채점 생략 문항**(`정답 미확보(주관식·근거 없음)`)도 함께 적는다
  - **`N`으로 채점된 문항과 사유**(근거 없음 · 선택 미등록 · 강의 근거와 공식 불일치) — 강의실 이력에 남아 되돌릴 수 없다
  - **`inputSuspect` 문항** — 「입력 미등록 의심(재시도 수단 없음)」 · 6단계 「주관식 입력」 표에 관측을 누적했는지
  - **`ask`·`mismatch`로 멈춘 문항**(에이전트가 고르지 않은 선택 · 선택 ≠ 의도) · **좌표 재시도(`coordConf`)를 쓴 문항**과 결과 · `realOne` 정답확인 반응 여부(4번 표)
  - **사전 채록 정답과 공식 정답(정답 행)의 불일치** · **정답 라벨 부재 여부**(라벨 없는 유형이면 명시)
  - **유휴 팝업(`.eco-popup`)으로 중단된 문항** · **이미 채점돼 읽기만 한 문항**(재오픈 시 채점 상태가 유지됐는지·초기화됐는지 관측값)
  - **회수하지 못한 문항과 사유**(`정답 미확보`) — 남았으면 `create-note`로 넘기지 않는다
  - **퀴즈 반출 파일**(`scu-quiz-{과목코드}_{주차}.json` 경로·크기)과 localStorage `scuQuiz:` 키를 비웠는지 · **정지 가드 해제 여부**(종료·중단 모두 — 4-B 9)
- 학습정리 유무 · 채록 줄 수(`__scuSummary()` 결과가 0줄이면 「정리 없음」이 아니라 추출 실패로 보고 — hidden 탭 여부 먼저)
- ~~채록된 학습평가 문항 수 · 학습정리 유무~~ — v1.1.9까지의 항목 · 위 두 항목으로 나눴다
- **자막 확보 현황** — 항목별 `{cue 수, 총 자수, 마지막 cue endTime}` · **자막 없는 항목과 그 이유**(슬라이드형 / 영상형인데 cue 0)
- ⚠️ **자막 반출 상태** — 디스크 파일명·경로·크기, localStorage 키를 비웠는지. **보고하지 않고 세션을 끝내면 페이지 메모리와 함께 사라진다**
- **자막 ↔ 기존 전사 차이** — 이미 전사가 들어 있던 항목에서 둘이 갈린 지점. 의미 반전은 보고하지 않으면 사용자가 영영 모른다
- 다음 단계 — **자막 전량 확보면 `transcribe`를 건너뛰고** 곧장 `prepare-script` → `create-note`(과금 회피 N건). **미확보 항목이 남았으면 그 항목만** `transcribe` → `prepare-script` → `create-note`.
  **학습평가 공식 정답 미회수 문항이 남았으면 `create-note`보다 회수가 먼저다** — 미완료 주차는 사용자 수강으로 `평가하기`에 도달한 뒤, 완료 주차는 스킬이 `평가하기`를 직접 열어 `res(k)`부터 읽는다
