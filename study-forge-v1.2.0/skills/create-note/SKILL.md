---
name: create-note
description: >
  강의 스크립트(TXT), 강의교안(PDF), 실습(PDF/ipynb), 영상 프레임을 종합하여 체계적인 마크다운 강의노트를 작성하는 스킬.
  반드시 사전 조건(영상 처리·전사·학습목차 정리·학습평가 공식 정답/해설 회수)이 완료된 상태에서 실행해야 한다.
  사용자가 "강의노트 작성해줘", "X주차 강의노트 만들어줘", "강의 내용 정리해줘", "create-note" 등을
  요청하거나, 스크립트/교안/실습 자료를 언급하며 정리를 요청할 때 사용한다.
  강의교안 PDF는 이미지로 변환 후 시각적으로 읽고, 실습은 ipynb(Read 직접)과 PDF(pdfminer/Read) 모두 지원한다.
  영상 MP4가 있으면 ffmpeg 프레임 추출 후 전수 분석이 필수이다.
  시각화가 효과적인 내용은 HTML → Playwright → PNG로 다이어그램을 생성하여 노트에 삽입한다.
  실행 환경(맥 네이티브 / VM)에 따라 폰트·PDF 변환 방식이 다르다.
  학습평가 절은 confirm-toc가 정답확인으로 회수한 공식 정답·공식 해설 원문으로만 채우며,
  채록본에 공식 정답이 없으면 노트를 쓰기 전에 회수부터 한다 — 추정 정답 금지 (v0.12.0).
version: 0.12.0
---

# 강의노트 작성 스킬

스크립트(TXT), 강의교안(PDF), 실습(PDF), 영상 프레임 — **5대 필수 참조 자료**를 종합해 체계적인 마크다운 강의노트를 작성한다. 텍스트만으로 설명하기 어려운 내용은 시각 자료(다이어그램/도표)를 생성하여 삽입한다.

> ## ⚠️ 필수: 아래 0~10단계를 반드시 순서대로 모두 수행할 것
>
> **단계를 건너뛰거나 순서를 바꾸면 안 된다.** 각 단계의 상세 지침은 아래 `## N단계:` 섹션에 있다.
>
> | 단계 | 작업 | 핵심 |
> |------|------|------|
> | **0** | 사전 조건 확인 | 전사 완료 + 학습목차 완료 + **학습평가 공식 정답·해설 확보(추정 0)** 체크. 정답이 없으면 `confirm-toc`로 먼저 회수. 이미 완료된 전처리는 재실행 금지 |
> | **1** | 과목 폴더 인식 + 주차 파악 | `os.listdir()` + `nfc()` NFD 안전 패턴 |
> | **2** | 파일 탐색 | 스크립트/교안/실습 PDF 경로 확보 (특수문자 경로 안전 처리) |
> | **3** | 스크립트 TXT 읽기 | 학습목차 파싱 → 노트 `#`/`##` 골격 확정 + 전사 텍스트 추출 |
> | **4** | 강의교안 PDF → 이미지 변환 + 읽기 | `pdftoppm -r 110`, 10~15페이지씩 Read |
> | **5** | 실습 PDF 텍스트 추출 | `pdfminer` (실패 시 이미지 변환 fallback) |
> | **6** | **영상 프레임 전수 분석** | **모든 프레임** 읽기 → 분류 → `## (N)`별 보강 내용 정리 |
> | **7** | 강의노트 작성 | 학습목차 골격 + 5대 소스 종합 (전사 텍스트 = 최우선) · 학습평가 = 공식 정답 + 공식 해설 원문 |
> | **8** | 시각 자료 생성 | HTML → Playwright → PNG (환경별 폰트 분기, SVG 금지) |
> | **9** | 파일 저장 | NFD 안전 경로로 `강의노트/` 폴더에 저장 + `img/` 폴더에 PNG 복사 |
> | **10** | **통합 검증** | 교안·전사·실습·영상 프레임 전체와 노트 대조 + 학습평가 공식 정답 기계 대조 → 누락·오류 보강 → 최종 저장 |
>
> **특히 6단계(영상 프레임 전수 분석)와 10단계(통합 검증)를 절대 생략하지 않는다.**
> 진행 상황을 사용자에게 **"[N단계] 작업명 진행 중..."** 형식으로 반드시 알려주며 수행한다.

## 시작 전 필수

1. 워크스페이스 `CLAUDE.md`와 **과목 폴더 `CLAUDE.md`**를 읽는다
2. 같은 종류의 **기존 산출물(기존 주차 강의노트)을 열어 형식을 확인**한다 — 제목 스타일·표 사용·이미지 배치가 과목마다 다르다
3. 확인할 수 없는 값은 **비워 두고 채울 방법을 안내**한다 — 그럴듯한 추정값 금지
   - ⛔ **학습평가 정답은 이 「비워 두고 안내」로 넘기지도 않는다** — 공식값만 쓴다. 해설 유무 패턴(「거짓 진술에만 해설」)이나 강의 내용으로 정답을 짐작하지 않으며, 공식값이 없으면 **노트보다 `confirm-toc` 회수가 먼저**다(아래 확인 5)

## 필수 참조 자료 (5대 소스)

| # | 소스 | 설명 | 우선순위 |
|---|------|------|----------|
| 1 | 스크립트 TXT — **본문 텍스트** (## (N) 아래) | 강사의 실제 설명. 교안에 없는 보충 설명·예시·맥락이 담김. **출처가 자막이면 정본**, 다글로·whisper 전사면 폴백 | **최우선** |
| 2 | 스크립트 TXT — 학습목차 | 강의노트의 #/## 제목 구조와 --- 위치를 확정 | 필수 |
| 3 | 강의교안 PDF | 슬라이드 레이아웃, 다이어그램, 표, 학습목표 등 시각 정보 | 필수 |
| 4 | 실습 PDF | 실습 코드, 실행 결과, 과제 설명 | 있으면 필수 |
| 5 | 영상 프레임 | 교안에 없는 판서, 데모, 추가 설명 화면 | 있으면 필수 |

> **본문 텍스트가 강의노트의 핵심 소스이다.** 강사가 실제로 한 설명이므로 교안에 없는 보충 설명·예시·맥락이 담겨 있다. 본문 없이 강의노트를 작성하면 교안 요약에 불과하므로, 반드시 본문이 채워진 상태에서 시작해야 한다.
>
> ⭐ **본문의 출처는 셋이고 신뢰도가 다르다** — ① **강의실 공식 자막(정본)** ② 다글로 전사 ③ whisper 로컬. ①이 확보돼 있으면 그것으로 충분하며 **전사를 추가로 돌릴 필요가 없다.**
> ⚠️ 본문이 없을 때의 조치 순서는 **`confirm-toc`(자막 수확 · 무료) → `extract-video`/`transcribe`(유료)**다. 자막을 확인하지 않고 유료 전사를 자동 실행하지 않는다.
> ⚠️ ③에서 온 본문은 **의미 반전**이 실측됐다(`금방 할 수 없고` → `금방 할 수 있고`) — 교안·자막과 교차 검증한다.

## 사전 조건 — 반드시 확인 (필수)

create-note를 실행하기 전에 아래 조건이 **모두 충족**되어야 한다. 하나라도 미충족이면 해당 선행 스킬을 먼저 실행하고 돌아온다.

### 확인 1: 오디오 전사 완료

스크립트 TXT의 `<강의녹음 스크립트>` 구역에서 `## (N)` 아래에 전사 텍스트가 있어야 한다.

- **완료 판단**: `## (N)` 바로 아래에 텍스트가 존재
- **미완료 판단**: `## (N)` 아래가 비어있거나 바로 다음 `##`이 옴
- **미완료 시 조치**: ① 먼저 과목 `자막/` 폴더와 `confirm-toc`(무료 자막 수확)으로 본문을 확보한다 → ② 자막 cue가 0인 항목만 `transcribe`/`extract-video`(다글로 · **유료 · 업로드**)를 **사용자 승인 후** 실행한다

### 확인 2: 학습목차 완료

스크립트 TXT의 `<학습목차>` 구역에 `#`/`##` 헤더가 구조화되어 있어야 한다.

- **완료 판단**: `<학습목차>` 구역에 `# 제목`, `## 서브제목` 패턴이 존재
- **미완료 시 조치**: `prepare-script` 스킬을 먼저 실행

### 확인 3: 실습 자료 존재 여부

`실습/` 폴더에서 해당 주차의 `.pdf` 또는 `.ipynb` 파일이 있는지 확인한다.

- **있으면**: 5단계에서 반드시 분석
- **없으면**: 실습 없이 진행 (사용자에게 안내)
- **`.ipynb` + `.pdf` 둘 다 있으면**: `.ipynb` 우선 사용

### 확인 4: 영상 프레임 (MP4가 있으면 프레임도 필수)

**영상 MP4 파일이 존재하면 프레임이 반드시 있어야 한다:**

- **MP4 있음 + 프레임 있음** → 6단계에서 전수 분석
- **MP4 있음 + 프레임 없음** → ❌ **진행 금지**. ffmpeg으로 프레임 추출 먼저 수행 (`extract_frames_ffmpeg()` 또는 `extract-video` 스킬)
- **MP4 없음** → 프레임 없이 진행 허용

### 확인 5: 학습평가 공식 정답·해설 확보 (2026-09-17 정책)

> 사용자 지시(2026-09-17) — 「학습평가 정답은 정답확인해서 해설까지 강의노트에 포함해야 해」
> → CLMS `평가하기/학습평가`는 `confirm-toc`가 **매번 정답확인까지** 채점해 공식 정답과 공식 해설 원문을 회수하고, create-note는 **그 회수본만** 노트에 옮긴다. 건별 지시는 필요 없다

목차에 `## 학습평가`가 있으면 스크립트의 **학습평가 채록본**(본문 `## 학습평가` 구역 · 구형은 목차 아래 `※ 학습평가 채록` 블록)을 `parse_quiz_capture()`(3-C)로 검사한다.

- **완료 판단** — 셋 다 충족
  - 채록본에 **정답확인 채점 기록**이 있다 (`정답확인 후/뒤` · `정답확인 채점 N문항` · `채점: Y/N` · `채점 N/N` · `passyn=Y/N` · `채점 검증 완료`)
    - `passed-answer`·`passyn`이라는 낱말만으로는 채점 기록이 아니다 — 방법 설명과 정본 템플릿의 `※` 줄에도 나온다
  - **모든 문항에 공식 정답**이 있다 — ①정본 형식이면 문항마다 `채점: Y/N` 줄도 있다
  - 문항마다 **공식 해설 원문**이 있거나 **`공식 해설 없음`이 명시**돼 있다
- **미완료 판단** — 하나라도 해당
  - 정답 줄 누락 · `정답 미확보(사유)`
  - 「추정·추측·짐작·미확인·미확보·공식 채점 전·이어서 채록·미채록·미채점·전사 근거 판단」 표지가 있다
    - 지문·보기·공식 해설 원문에서는 `(추정)`·`(추측)`·`추정 정답`·`공식 채점 전` 같은 명시 표지만 본다 — 낱말 `추정`은 보지 않는다(점추정·추정량·「모수를 추정한다」 등 통계 용어 오탐 방지)
  - 문항 수가 선언(채록본의 `N문항`·`N/N`, 목차 주석)과 다르다
  - 머리 `정답확인 채점 N문항`의 N이 채점 기록이 있는 문항 수와 다르다 (유휴 종료로 중간에 멈춘 채점)
  - 해설이 원문인지 보충인지 구분되지 않는다 (라벨 없는 해설에 강의실 채록 기록이 없음 · 구형 개조식 불릿)
- **해당 없음** — 목차에 `# 평가하기`/`## 학습평가`가 없는 주차 (AWS클라우드실습프로젝트 1~3주차) → `quiz_ready = None`
- **미완료 시 조치** — **노트 작성을 멈추고** `confirm-toc` 학습평가 회수(선택 → 그 문항의 `.selected` 확인 → 정답확인, 각각 별도 호출)를 먼저 한다. 묻지 않는다 — 완료 주차는 스킬이 강의실에서 `평가하기`를 직접 열어 회수하고, 미완료 주차는 사용자 수강으로 도달한 뒤 회수한다. 상세는 아래 「사전 조건이 미충족인 경우」 6번

> ⚠️ 적용 범위는 **CLMS `평가하기`/`학습평가`(형성평가) 한정**이며, CLMS `평가하기`/`학습평가` **외에는 전부** 적용하지 않는다 — 예: 영상 재생·수강 대행 · `›`/`‹` 이동 · AWS Academy 지식 점검(성적 과제) · OJ 제출 · 게시판·보드 글 · 수시·정기시험 · 사내교육 최종평가. `평가하기` 도달(앞 모듈 완료)은 **사용자 수강**에 달려 있으며, 정책은 도달 후의 조작에만 적용된다 — 단 **완료 주차**(강의실홈 행이 이미 `완료`)는 스킬이 강의실에 들어가 `평가하기`를 직접 연다(진도 변화 없음 · 아래 6번)

### 사전 조건 확인 코드

```python
import re

def check_prerequisites(script_content):
    """create-note 실행 전 사전 조건 확인

    ⚠️ 3-B의 `iter_body_sections()`와 3-C의 `find_quiz_capture()`·`parse_quiz_capture()`를
       함께 로드한 뒤 호출한다 (확인 5가 그 둘을 쓴다)

    Returns:
        dict: {
            'outline_ready': bool,      # 학습목차 완료 여부
            'transcripts_ready': bool,  # 전사 텍스트 완료 여부
            'quiz_ready': bool | None,  # 학습평가 공식 정답·해설 확보 여부 (None = 목차에 학습평가 없음)
            'quiz': dict | None,        # parse_quiz_capture() 결과 — 문항별 판정·problems
            'missing': list             # 미충족 항목 목록
        }
    """
    result = {'outline_ready': False, 'transcripts_ready': False,
              'quiz_ready': None, 'quiz': None, 'missing': []}

    # 확인 2: 학습목차
    outline_match = re.search(r'<[^>]+학습목차>', script_content)
    if outline_match:
        after_outline = script_content[outline_match.end():]
        # 학습목차 구역에 # 헤더가 있는지 확인
        script_tag = re.search(r'<[^>]+강의녹음\s*스크립트>', after_outline)
        outline_section = after_outline[:script_tag.start()] if script_tag else after_outline
        if re.search(r'^#[^#]', outline_section, re.MULTILINE):
            result['outline_ready'] = True
    if not result['outline_ready']:
        result['missing'].append('학습목차 (prepare-script 스킬 실행 필요)')

    # 확인 1: 전사 텍스트
    script_match = re.search(r'<[^>]+강의녹음\s*스크립트>', script_content)
    if script_match:
        after_script = script_content[script_match.end():]
        # `## (N)제목` 아래에 텍스트가 있는지 확인
        # ⚠️ 실제 스크립트는 `##`와 `(` 사이에 공백이 1칸 있다 — 공백을 허용하지 않으면 0건이 잡혀
        #    본문이 완비된 주차도 「전사 미완료」로 오판하고 불필요한 유료 전사로 이어진다
        # ⚠️ 번호 없는 `## 학습평가`·`## 학습정리`도 구역 경계로 잡아야
        #    마지막 번호 구역이 그 채록본을 흡수하지 않는다
        heads = list(re.finditer(r'(?m)^##(?!#)[ \t]*(?:\((\d+)\))?[^\n]*$', after_script))
        has_text = False
        for i, h in enumerate(heads):
            if not h.group(1):          # 번호 없는 구역은 전사 대상이 아니다
                continue
            end = heads[i + 1].start() if i + 1 < len(heads) else len(after_script)
            if len(after_script[h.end():end].strip()) > 10:  # 의미 있는 텍스트가 있는지
                has_text = True
                break
        result['transcripts_ready'] = has_text
    if not result['transcripts_ready']:
        result['missing'].append(
            '전사 텍스트 (① confirm-toc로 자막 수확(무료) → ② 자막이 없는 항목만 '
            'transcribe/extract-video — 유료·업로드, 사용자 승인 필수)')

    # 확인 5: 학습평가 공식 정답·해설 — 목차에 `## 학습평가`가 없으면 해당 없음(None)
    cap = find_quiz_capture(script_content)
    if cap is not None:
        quiz = parse_quiz_capture(cap['text'], cap['declared'])
        result['quiz'] = quiz
        result['quiz_ready'] = quiz['ready']
        if not quiz['ready']:
            result['missing'].append(
                '학습평가 공식 정답·해설 (confirm-toc 선택→.selected 확인→정답확인 회수 필요) — '
                + ' / '.join(quiz['problems'][:3]))

    return result
```

**사전 조건이 미충족인 경우:**
1. `prepare-script`(무료)와 학습평가 회수(`confirm-toc`, 무료 — 6번)만 자동으로 진행한다 — 사용자에게 "먼저 실행할까요?"라고 묻지 않는다
   (학습평가는 완료 주차면 강의실 입장·`평가하기` 열기부터 자동으로 하고, 미완료 주차는 사용자 수강으로 도달한 `평가하기`에서만 한다)
2. 본문이 비어 보이면 **먼저 판정을 의심한다** — 제목 표기(`## (N)`)를 못 읽어 오판하는 경우가 실제로 있었다. 파일을 직접 열어 `## (N)` 아래에 본문이 있는지 눈으로 확인한다
3. 본문이 정말 없으면 과목 `자막/` 폴더와 `confirm-toc`(무료 자막 수확)을 먼저 확인한다 — 자막이 있으면 전사는 필요 없다
4. 자막 cue가 0인 항목이 남을 때만 `transcribe`/`extract-video`(다글로 · **유료 · 클라우드 업로드**)를 쓰며, **대상 파일 목록·개수·옵션을 제시하고 사용자 승인을 받은 뒤에** 실행한다
5. 보고에 「자막 확보 N건 / 전사 필요 M건」을 함께 적는다
6. **학습평가 공식 정답·해설이 미확보면**(`quiz_ready is False`) 묻지 않고 **`confirm-toc` 학습평가 회수를 먼저** 한다(2026-09-17 정책)
   - 회수는 문항마다 `선택 → 그 문항의 .selected 확인 → 정답확인`을 **각각 별도 호출**로 하고, 채점 뒤 정답 행(`.passed-answer`/`.failed-answer`)과 `[data-field="explanation"]` 원문을 스크립트에 적는다 — 절차 정본은 `confirm-toc` 6~7단계
   - **완료 주차**(강의실홈에서 그 주차 `평가하기` 행이 이미 `완료`) — 스킬이 강의실에 들어가 `평가하기`를 **직접 열고** 회수한다. 진도 변화는 없고 강의실 입장이 참여도에 +1로 집계될 뿐이다(2026-09-17 문제해결 3주차 실행)
     - 열기 전에 행 텍스트로 `평가하기`·`완료`를 확인하고, 아코디언 펼치기는 요소를 특정해서, 항목 열기는 스크린샷 좌표로 한다(`confirm-toc` 「⛔ 절대 하지 말 것 4」 ②·2단계)
     - 강의실 세션(로그인)이 없으면 로그인은 사용자 몫이다 — 그때만 요청하고 **노트 작성을 보류**한다
   - 감시 탭의 플레이어에 그 주차 `평가하기`가 이미 열려 있으면 그대로 회수한다
   - **미완료 주차**는 사용자 수강으로 `평가하기`에 도달한 뒤 회수한다 — 영상 재생·`›` 이동을 대신하지 않는다
   - 회수할 수 없는 사정이 있고 사용자가 노트를 먼저 원하면 **그 문항만** `**정답** (미확보 — confirm-toc 회수 필요)`로 두고 보고한다. 추정값은 어떤 경우에도 쓰지 않는다
   - `problems`에 「구형 해설 불릿」만 남은 경우(정답은 공식) — 해설 원문만 다시 받으면 된다. 채점된 문항은 누르지 않고 결과만 읽는다

**사전 작업이 이미 완료된 경우 (중요):**
- 스크립트 TXT에 `## (N)` 아래 전사 텍스트가 이미 있으면 → extract-video/transcribe **절대 재실행하지 않음**
- 학습목차가 이미 구조화되어 있으면 → prepare-script **절대 재실행하지 않음**
- 사용자가 "오디오 추출/전사/스크립트 정리 끝남"이라고 명시하면 → 해당 단계 **절대 재실행하지 않음**
- 사용자가 명시적으로 "다시 해줘"라고 요청하는 경우에만 재실행
- 이미 완료된 전처리를 재실행하면 수 분~수십 분의 시간 낭비 + 기존 결과물 덮어쓰기 위험
- ⚠️ **예외 — 학습평가** — 채록본이 있어도 공식 정답 미확인 문항이 있으면 완료가 아니다. **그 문항만** `confirm-toc`로 회수한다. 이미 채점된 문항(`data-passyn` Y/N)은 **다시 누르지 않고** 정답 행·해설만 읽는다 (채점 뒤에는 재시도 수단이 없다)

## 사전 준비: 의존성 설치

```bash
pip install pdfminer.six --break-system-packages
apt-get update && apt-get install -y poppler-utils 2>/dev/null || true
```

## 1단계: 과목 폴더 인식 및 주차 파악

```python
import os
import unicodedata

SESSION_BASE = '/sessions/{session_id}'
MNT = os.path.join(SESSION_BASE, 'mnt')

SYSTEM_DIRS = {'uploads', '.claude', '.skills', '.local-plugins',
               '.cowork-lib', '.cowork-perm-req', '.cowork-perm-resp'}

def nfc(s):
    """macOS NFD 인코딩 → NFC 정규화 (한글 문자열 매칭 필수)"""
    return unicodedata.normalize('NFC', s)

def find_course_folders():
    """마운트된 과목 폴더 목록 반환 (시스템 폴더 제외)"""
    folders = []
    for item in os.listdir(MNT):
        full = os.path.join(MNT, item)
        if not os.path.isdir(full):
            continue
        if item.startswith('.') or item in SYSTEM_DIRS:
            continue
        folders.append({'name': nfc(item), 'path': full})
    return folders
```

사용자 요청에서 과목명과 주차 번호를 파악한다 (예: "파이썬데이터분석 3주차"). 과목명의 일부만 입력해도 폴더명에 포함되면 매칭한다.

**주의: 과목명 매칭 시 반드시 `nfc()` 정규화된 `name` 필드를 사용해야 한다.** macOS에서 한글 폴더명이 NFD(조합형 자모)로 저장되므로, 정규화 없이 `'머신러닝' in item`을 하면 매칭에 실패한다.

주차 번호를 2자리로 패딩: `01`, `02`, `03` ...

## 2단계: 파일 탐색 (특수문자 경로 안전 처리)

대괄호 `[`, `]` 등 특수문자가 포함된 경로는 반드시 `os.listdir()` + `os.path.join()` 패턴을 사용한다.

```python
import os
import unicodedata

def nfc(s):
    """macOS NFD → NFC 정규화"""
    return unicodedata.normalize('NFC', s)

def resolve_subdir(course_path, target_name):
    """NFD 안전 서브디렉토리 해석 — os.listdir()로 실제 이름 획득 후 매칭

    os.path.join(course_path, '스크립트') 처럼 NFC 이름을 하드코딩하면
    NFD로 저장된 디렉토리를 찾지 못한다. 반드시 이 함수를 사용한다.
    """
    nfc_target = nfc(target_name)
    for sub in os.listdir(course_path):
        if nfc(sub) == nfc_target and os.path.isdir(os.path.join(course_path, sub)):
            return os.path.join(course_path, sub)
    return None

def find_week_files(course_path, week):
    """주차별 파일 탐색 (NFD 안전 — 서브디렉토리도 os.listdir() 패턴)"""
    week_str = f'{week:02d}'
    files = {'script': None, 'lecture_pdf': None, 'practice_pdf': None}

    # 스크립트 (NFD-safe)
    script_dir = resolve_subdir(course_path, '스크립트')
    if script_dir:
        for f in os.listdir(script_dir):
            if week_str in nfc(f) and nfc(f).endswith('.txt'):
                files['script'] = os.path.join(script_dir, f)

    # 강의교안 (NFD-safe)
    lecture_dir = resolve_subdir(course_path, '강의교안')
    if lecture_dir:
        for f in os.listdir(lecture_dir):
            if week_str in nfc(f) and nfc(f).lower().endswith('.pdf'):
                files['lecture_pdf'] = os.path.join(lecture_dir, f)

    # 실습 (NFD-safe) — PDF와 ipynb 모두 검색
    practice_dir = resolve_subdir(course_path, '실습')
    if practice_dir:
        candidates = []
        for f in os.listdir(practice_dir):
            nfc_f = nfc(f)
            if week_str not in nfc_f:
                continue
            ext = nfc_f.lower().rsplit('.', 1)[-1] if '.' in nfc_f else ''
            if ext in ('pdf', 'ipynb'):
                candidates.append((ext, os.path.join(practice_dir, f)))
        # ipynb 우선, 없으면 pdf
        for ext in ('ipynb', 'pdf'):
            match = [c for c in candidates if c[0] == ext]
            if match:
                files['practice_pdf'] = match[0][1]
                break

    return files
```

**중요 (NFD 안전 읽기+쓰기):**
- `os.listdir()`가 반환하는 파일명은 NFD일 수 있으므로, 문자열 비교(`in`, `endswith`) 전에 반드시 `nfc()`로 정규화한다
- `os.path.join()`에는 원본 파일명(`f`)을 그대로 사용해야 실제 파일 시스템 경로와 일치한다
- **서브디렉토리 접근 시에도 반드시 `resolve_subdir()` 또는 `os.listdir()` 패턴을 사용한다** — `os.path.join(course_path, '스크립트')` 처럼 NFC 이름을 하드코딩하면 NFD 디렉토리를 찾지 못한다
- MCP 전사(다글로) 실행 후에는 VM 재시작/마운트 갱신이 발생할 수 있으므로, **경로를 캐시하지 말고 매번 `os.listdir()`로 재획득**해야 한다

파일이 없는 자료는 있는 것만으로 진행하되 사용자에게 안내한다.

## 3단계: 스크립트 TXT 읽기 — 학습목차 + 전사 텍스트

스크립트 파일은 대용량(50KB+)일 수 있다. 특수문자 경로 우회 후 청크로 나누어 읽는다.

```python
import shutil, os

def prepare_script(script_path, week):
    """스크립트를 임시 위치로 복사"""
    temp = os.path.join(SESSION_BASE, f'script_{week:02d}.txt')
    shutil.copy2(script_path, temp)
    size = os.path.getsize(temp)
    print(f"스크립트 크기: {size:,} bytes")
    return temp
```

Read 도구로 읽을 때 `limit=150`으로 청크 분할:
- 1차: `Read(file_path=temp, limit=150)`
- 2차: `Read(file_path=temp, offset=150, limit=150)`
- 필요시 계속

### 3-A: 학습목차 파싱 — 강의노트 제목 구조 확정 (필수)

스크립트 TXT의 `<과목명 N주차 학습목차>` 구역을 파싱하여 강의노트의 **제목 구조를 확정**한다. 이 구조는 강의노트의 `#`/`##` 헤더와 `---` 가로선 위치를 결정하므로, **반드시 파싱하고 그대로 따라야 한다.**

```python
import re

def clean_outline_title(raw):
    """목차 제목 줄에서 꼬리 주석을 떼어낸다

    실제 스크립트의 목차 줄에는 확정 근거가 함께 적혀 있다:
        `## (1)학습안내      ← 영상 980초 = 15521543_2_01.mp3 979.58초`
        `# B10869 문제풀이   [URL 항목 · 마감기한 2026-10-04 23:59]`
    이 꼬리말은 제목이 아니므로 노트 헤더에 들어가면 안 된다.
    ⚠️ 제목 자체의 마침표·괄호는 건드리지 않는다 (`# 강의에 사용한 코드 안내입니다.`)
    """
    title = re.split(r'\s*←', raw)[0]
    title = re.sub(r'\s*\[[^\]]*\]\s*$', '', title)
    return title.strip()


def parse_outline(script_content):
    """스크립트에서 학습목차 구역을 파싱하여 제목 구조 추출

    Returns:
        list of dict: 각 항목의 유형과 텍스트
        예: [
            {'type': 'h1', 'text': '들어가기'},
            {'type': 'h2', 'text': '학습개요'},
            {'type': 'hr'},
            {'type': 'h1', 'text': 'pandas 데이터 형태 이해'},
            {'type': 'h2_numbered', 'num': 1, 'text': 'pandas 데이터 형태 이해 실습'},
            {'type': 'hr'},
            ...
        ]
    """
    # 학습목차 구역 추출
    outline_match = re.search(
        r'<[^>]+학습목차>\s*\n(.*?)(?=\n\s*<[^>]+강의녹음|$)',
        script_content, re.DOTALL
    )
    if not outline_match:
        return None

    outline_text = outline_match.group(1)
    structure = []

    for line in outline_text.split('\n'):
        stripped = line.strip()
        if not stripped:
            continue
        if stripped == '---':
            structure.append({'type': 'hr'})
            continue
        # 제목이 아닌 줄은 건너뛴다 — `[자료 항목 …]`·`[URL 항목]` 대괄호 줄과 `※` 주석 줄
        if stripped.startswith('[') or stripped.startswith('※'):
            continue
        if stripped.startswith('##'):
            title = clean_outline_title(stripped[2:])
            # 실제 표기는 `##`와 `(` 사이에 공백 1칸 — 공백이 없는 구형 표기도 함께 받는다
            m = re.match(r'\((\d+)\)\s*(.+)', title)
            if m:
                structure.append({
                    'type': 'h2_numbered',
                    'num': int(m.group(1)),
                    'text': m.group(2)
                })
            else:
                structure.append({'type': 'h2', 'text': title})
        elif stripped.startswith('#'):
            title = clean_outline_title(stripped[1:])
            structure.append({'type': 'h1', 'text': title})

    return structure
```

### 학습목차 → 강의노트 제목 변환 규칙

학습목차의 각 항목은 아래 규칙에 따라 강의노트의 마크다운 헤더로 변환된다:

| 학습목차 항목 | 강의노트 마크다운 | 설명 |
|---|---|---|
| `# 제목` | `# 제목` | 최상위 헤더 (H1) |
| `## 서브제목` | `## 서브제목` | 서브 헤더 (H2) |
| `## (N)서브제목` | `## (N)서브제목` | 서브 헤더, `(N)`은 영상 순번 — **기존 노트가 번호를 유지하면 그대로 유지한다** |
| `---` | `---` | `#` 타이틀 그룹 간 가로선 |

> ⚠️ **번호를 뗄지는 그 과목의 기존 노트가 정한다.** 5과목 `01주차-강의노트.md`가 전부 `## (1)제목` 형태로 번호를 유지하고 있으므로, 같은 과목의 다음 주차에서 번호를 떼면 산출물 형식이 갈라진다. 「시작 전 필수」의 **기존 산출물 형식 확인**이 이 표보다 우선한다.
> ⚠️ **목차 줄의 꼬리 주석은 제목이 아니다** — `← 영상 980초 = ….mp3 979.58초`, `[URL 항목 · 마감기한 …]`, `※ …` 는 `clean_outline_title()`로 떼어낸 뒤 헤더로 쓴다.

### 필수 섹션 (내용이 없어도 제목은 반드시 작성)

아래 섹션은 대응하는 영상 자료가 없더라도 강의노트에 **제목을 반드시 포함**해야 한다:
- `# 들어가기` → `## 학습개요` (학습목표, 학습내용 등 교안에서 추출)
- `# 평가하기` → `## 학습평가` (**문항 + 공식 정답 + 공식 해설 원문까지 채운다** · 추정 금지 — 아래 「학습평가·학습정리」 참조)
- `# 정리하기` → `## 학습정리` (**내용까지 채운다**)

### 예시: 학습목차 → 강의노트 골격

학습목차 (실제 스크립트 표기 — `#`/`##` 뒤에 공백 1칸, 꼬리에 확정 근거 주석이 붙는다):
```
# 들어가기
## 학습개요
---
# pandas 데이터 형태 이해
## (1)pandas 데이터 형태 이해 실습      ← 영상 384초 = ….mp3 384.40초
---
# 테이블 데이터의 입출력
## (2)테이블 데이터의 입출력 실습       ← 영상 402초 = ….mp3 402.69초
---
# 평가하기
## 학습평가
---
# 정리하기
## 학습정리
```

생성되는 강의노트 골격:
```markdown
# 들어가기

## 학습개요

- 학습목표
  - (교안에서 추출)
- 학습내용
  - (교안에서 추출)

---

# pandas 데이터 형태 이해

## (1)pandas 데이터 형태 이해 실습

- (전사 텍스트 + 교안 + 실습 내용을 종합하여 작성)

---

# 테이블 데이터의 입출력

## (2)테이블 데이터의 입출력 실습

- (전사 텍스트 + 교안 + 실습 내용을 종합하여 작성)

---

# 평가하기

## 학습평가

(confirm-toc 채록본의 문항 · 공식 정답 · 공식 해설 원문 — 정답확인으로 회수한 값만)

---

# 정리하기

## 학습정리

(confirm-toc 채록본 원문 기반 — 채록본이 없을 때만 교안의 정리 페이지)
```

**핵심: 학습목차에 정의된 `#`/`##` 제목 순서와 `---` 위치를 정확히 따른다. 임의로 제목을 추가/삭제/변경하지 않는다.**

### 3-B: 전사 텍스트 추출

스크립트 TXT의 `<강의녹음 스크립트>` 구역에서 `## (N)` 별 전사 텍스트를 추출한다. 이 텍스트가 강의노트 본문의 **핵심 소스**이다.

```python
import re

def extract_transcripts(script_content):
    """스크립트에서 순번별 전사 텍스트 추출

    Returns:
        dict: {순번: 전사텍스트} 예: {1: "안녕하세요 오늘은...", 2: "이번에는..."}
    """
    script_match = re.search(r'<[^>]+강의녹음\s*스크립트>', script_content)
    if not script_match:
        return {}

    after = script_content[script_match.end():]
    return {num: text for num, _, text in iter_body_sections(after) if num and text}


def iter_body_sections(after):
    """본문 구역을 `## …` 제목 단위로 자른다

    - `## (N)제목`(실제 표기, 공백 1칸)과 `## (N)제목` 양쪽을 인식한다
    - 번호 없는 `## 학습개요`·`## 학습평가`·`## 학습정리`에서도 끊는다 —
      끊지 않으면 마지막 번호 구역이 그 채록본을 통째로 흡수한다

    Yields:
        (순번 또는 None, 제목, 본문)
    """
    heads = list(re.finditer(r'(?m)^##(?!#)[ \t]*(?:\((\d+)\))?[^\n]*$', after))
    for i, h in enumerate(heads):
        end = heads[i + 1].start() if i + 1 < len(heads) else len(after)
        num = int(h.group(1)) if h.group(1) else None
        title = re.sub(r'^##\s*(?:\(\d+\))?\s*', '', h.group(0)).strip()
        yield num, title, after[h.end():end].strip()


def extract_captured_sections(script_content):
    """번호 없는 채록 구역 추출 — `## 학습개요`·`## 학습평가`·`## 학습정리`

    이 구역들은 영상·MP3가 없어 전사로는 복원되지 않고 수강 중 채록이 유일한 출처다.
    7단계에서 해당 노트 섹션의 내용으로 쓴다.

    Returns:
        dict: {제목: 채록본} 예: {'학습평가': '...', '학습정리': '...'}
    """
    script_match = re.search(r'<[^>]+강의녹음\s*스크립트>', script_content)
    if not script_match:
        return {}

    after = script_content[script_match.end():]
    return {title: text for num, title, text in iter_body_sections(after) if not num and text}
```

### 3-C: 학습평가 채록본 파싱 — 공식 정답·해설 확인 (0·7·10단계 공용)

`학습평가` 채록본은 **과목·시기마다 적는 형식이 달라** 눈으로 읽으면 공식 정답과 내가 덧붙인 풀이를 섞기 쉽다. `parse_quiz_capture()`가 문항별로 **공식 정답 · 공식 해설 원문 · 보충 근거**를 갈라 주고, 노트를 써도 되는지 판정한다. 0단계 확인 5, 7단계 작성, 10단계 기계 대조가 같은 결과를 쓴다.

| 형식 | 실물 | 공식 정답 | 공식 해설 |
|---|---|---|---|
| ① confirm-toc 7단계 정본 | 앞으로의 채록 | `정답 ② X` | `공식 해설: 원문` · `공식 해설 없음` (보충은 `보충 근거:`, 채점은 `채점: Y`) |
| ② 한 줄형 | 딥러닝 2·3주차 · 문제해결 2·3주차 | `정답 X — …` | `— 공식 해설: 원문` · `— 공식 해설 없음(참 진술)` · 다음 줄 `(근거: …)`는 보충 |
| ③ 4지선다형 | 빅데이터 1~3주차 | `정답 3번 — …` | `—` 뒤 문장 (채록 기록이 「정답·해설」을 받았다고 적었을 때만 원문) |
| ④ 라벨형 | GitHub 2주차 | `정답 ① 보기` | `해설 원문` (③과 같은 조건) |
| ⑤ 구형 블록 | GitHub·문제해결 1주차 (목차 아래 `※ 학습평가 채록`) | `정답: ① O` | `해설` 아래 불릿 중 `- 공식: "원문"`만 — 나머지 불릿은 보충 |

⭐ **공식 정답의 조건은 「정답확인 채점 기록」이다** — 채록본에 `정답확인 후/뒤` · `정답확인 채점 N문항` · `채점: Y/N` · `채점 N/N` · `passyn=Y/N` · `채점 검증 완료` 중 하나가 없으면 정답 줄이 있어도 공식값으로 보지 않는다. `정답확인 없이`·`정답확인을 누르지 않고`·`정답확인을 누르면 …`은 채점 기록이 아니다.

- ⚠️ `passed-answer`·`passyn`이라는 **낱말만으로는 채점 기록이 아니다** — 방법 설명과 정본 템플릿의 `※` 줄에도 나온다(정책 이전의 문제해결 3주차 채록본은 머리가 「정답확인은 누르지 않았다」인데, v1.2.0 초안 파서가 방법 설명 줄의 `.passed-answer` 때문에 채점 기록으로 판정했다 — 2026-09-17 검증)
- ①정본 형식(문항마다 `채점:` 줄)이면 **`채점:` 줄이 없는 문항은 공식 정답으로 보지 않는다** — 유휴 종료로 중간에 멈춘 채록본을 걸러낸다
- 머리의 `정답확인 채점 N문항(Y a · N b)`은 **채점 기록이 있는 문항 수**와 대조한다 — 다르면 미준비

⭐ **추정 표지는 내가 적은 줄에서만 찾는다** — 지문·보기·공식 해설 원문은 과목 내용이라 통계 용어(`점추정`·`추정량`·「모수를 추정한다」)가 들어갈 수 있다. 그 줄들은 `(추정)`·`(추측)`·`추정 정답`·`공식 채점 전` 같은 명시 표지만 본다(`QUIZ_EST_CONTENT`).

```python
import re

# 채록본 판정에 쓰는 표지 — 내가 적은 줄(머리·주석·정답 줄·채점·보충 근거)에만 쓴다
# 「추정 없음」「추정 없이」「추정은 하지 않았다」「「(추정)」 표기 금지」 같은 부정 표현은 표지가 아니다
# 맨 `추정`은 앞뒤에 한글이 붙지 않은 낱말만 — 점추정·추정량 같은 통계 용어 오탐 방지 (ta QUIZ_FLAG와 같은 기준)
QUIZ_ESTIMATE = re.compile(
    r'(?<![가-힣])추정(?![가-힣]|\s*(?:없음|없이|0)|\s*은?\s*(?:하지|금지)|\)」)'
    r'|추정(?:함|했|하였|으로|값)|추측|짐작|(?:참|거짓) 진술로 보임|패턴으로 (?:판단|판정)'
    r'|(?:미확인|미확보)(?!\s*(?:없음|0|문항 없음))'
    r'|공식 채점 전|이어서 채록|미채록|미채점|전사 근거 판단')
# 과목 내용 줄(지문·보기·공식 해설 원문)용 — 내가 붙이는 명시 표지만 본다
# 통계 문항의 「구간 추정 방법」「모수를 추정한다」가 게이트를 막지 않도록 낱말 `추정`은 보지 않는다
QUIZ_EST_CONTENT = re.compile(r'\((?:추정|추측)\)|추정 정답|공식 채점 전')
# 정답확인 채점 기록 — 「정답확인 없이」「정답확인을 누르지 않고」「정답확인을 누르면 생긴다」는 채점 기록이 아니다
# ⚠️ `passed-answer`·`failed-answer`·`passyn`이라는 낱말만으로는 채점 기록이 아니다 —
#    방법 설명(「정답확인을 누르면 정답 행(.passed-answer)이 생긴다」)과 정본 템플릿의 `※` 줄에도 나온다
QUIZ_GRADED = re.compile(
    r'정답확인(?![ \t]*(?:없이|전|대기|예정|[은는을]?[ \t]*(?:버튼\S*[ \t]*)?(?:한 번도[ \t]*)?(?:누르지|누르면|안|하지|하면|사용자)))'
    r'[^\n·]{0,12}?(?:후|뒤|해서|해[ \t](?!보지|두지)|채점(?!하지|\s*전|\s*않|\s*예정))'
    r'|(?<!미)채점[ \t]*(?:[:：][ \t]*[YN]\b|\([YN]\)|\d+[ \t]*(?:문항|/)|검증 완료)'
    r'|passyn[ \t]*=[ \t]*"?[YN]\b')
# 라벨 없는 해설(`정답 3번 — …`·`해설 …`)을 공식 원문으로 인정하는 채록 기록
QUIZ_EXP_RECORD = re.compile(r'정답·해설|정답과 해설|data-field="explanation"')
QUIZ_ITEM = re.compile(
    r'^(?:[ \t]*(?:문제|Quiz|Self[ \t]?Check)'
    r'(?:[ \t]*0*(\d+)[ \t]*\.|\.[ \t]*0*(\d+)\.?)'
    r'|(\d+)\.)[ \t]+(.*)$')
_Q_ANS = re.compile(r'^정답(?!확인)[ \t]*[:：]?[ \t]*(.*)$')
_Q_OFFEXP = re.compile(r'^공식[ \t]*해설[ \t]*[:：][ \t]*(.*)$')
_Q_NOEXP = re.compile(r'^(?:공식[ \t]*해설[ \t]*없음|-[ \t]*공식 해설이 제공되지 않은)')
_Q_EXP = re.compile(r'^해설(?:[ \t]*[:：][ \t]*|[ \t]+|$)(.*)$')
_Q_GRADE = re.compile(r'^채점[ \t]*[:：][ \t]*([YN])?')
_Q_SUPP = re.compile(r'^보충[ \t]*근거[ \t]*[:：][ \t]*(.*)$')
_Q_OPT = re.compile(r'^(?:보기[ \t]*[:：]|[①-⑩]|\d{1,2}\)[ \t])')
_Q_LEGACY_OFF = re.compile(r'^-[ \t]*공식(?:[ \t]*해설)?[ \t]*(?:[:：]|—)[ \t]*(.*)$')
_Q_OX = {'O': 'O', 'Ｏ': 'O', '○': 'O', 'X': 'X', 'Ｘ': 'X', '×': 'X'}


def _quiz_unquote(s):
    """`- 공식: "원문"`의 바깥 따옴표만 뗀다 — 원문 안에 같은 따옴표가 또 있으면 두지 않는다"""
    s = s.strip()
    for o, c in (('"', '"'), ('“', '”'), ('「', '」')):
        if len(s) >= 2 and s[0] == o and s[-1] == c and s.count(o) + (s.count(c) if o != c else 0) == 2:
            return s[1:-1].strip()
    return s


def _quiz_closed(parts):
    j = ' '.join(parts)
    return j.count('"') % 2 == 0 and j.count('「') <= j.count('」')


def _quiz_options(lines):
    opts = {}
    for ln in lines:
        ln = re.sub(r'^보기[ \t]*[:：][ \t]*', '', ln.strip())
        for c, t in re.findall(r'([①-⑩])[ \t]*(.*?)(?=[ \t]*[①-⑩]|$)', ln):
            opts[ord(c) - ord('①') + 1] = t.strip()
        for n, t in re.findall(r'(?:^|[ \t]{2,})(\d{1,2})\)[ \t]*(.*?)(?=[ \t]{2,}\d{1,2}\)|$)', ln):
            opts.setdefault(int(n), t.strip())
    return [opts[k] for k in sorted(opts)]


def find_quiz_capture(script_content):
    """학습평가 채록본을 찾는다 — 스크립트마다 놓인 자리가 다르다

    - 기본: 본문 구역의 번호 없는 `## 학습평가` (confirm-toc 7단계 정본)
    - 구형: 목차 아래 `※ 학습평가 채록 …` 블록 (GitHub포트폴리오·문제해결프로그래밍입문 1주차)
      — 블록은 들여쓴 줄이 이어지는 데까지다

    Returns:
        None — 목차에 `## 학습평가`가 없다 (해당 없음 · 예: AWS클라우드실습프로젝트)
        dict — {'text': 채록본('' 이면 없음), 'source': 'body' | 'legacy_block' | None,
                'declared': 목차 주석의 문항 수 또는 None}
    """
    m = re.search(r'<[^>]+강의녹음\s*스크립트>', script_content)
    head = script_content[:m.start()] if m else script_content
    body = script_content[m.end():] if m else ''

    # 목차의 `## 학습평가 ← … N문항 …` — 꼬리 주석에서 문항 수를 읽는다
    om = re.search(r'(?m)^##[ \t]*학습평가(?=[ \t]|$)[^\n]*$', head)
    if not om:
        return None
    nums = [int(n) for n in re.findall(r'(\d+)\s*문항', om.group(0))]
    info = {'text': '', 'source': None, 'declared': max(nums) if nums else None}

    for num, title, text in iter_body_sections(body):
        if num is None and title.startswith('학습평가') and text:
            info.update(text=text, source='body')
            return info

    lm = re.search(r'(?m)^※[ \t]*학습평가[ \t]*채록[^\n]*$', head)
    if lm:
        block = [lm.group(0)]
        for line in head[lm.end():].split('\n')[1:]:
            if line.strip() and not line[:1].isspace():
                break
            block.append(line)
        info.update(text='\n'.join(block).strip(), source='legacy_block')
    return info


def parse_quiz_capture(text, declared=None):
    """스크립트 학습평가 채록본을 문항별로 파싱하고 노트 작성 준비 여부를 판정한다

    읽는 형식 (과목·시기마다 다르다 — 전부 실물에서 확인한 것):
      ① confirm-toc 7단계 정본     `1. 지문` / `보기: ① O  ② X` / `정답 ② X` / `공식 해설: 원문`
                                    · `공식 해설 없음` / `채점: Y (선택 ②)` / `보충 근거: …`
      ② 한 줄형 (딥러닝·문제해결)  `정답 X — 공식 해설: 원문` · `정답 O — 공식 해설 없음(참 진술)`
                                    · 다음 줄 `(근거: …)`는 보충
      ③ 4지선다형 (빅데이터)        `Quiz 1. 지문` / `① …  ② …` / `정답 3번 — 해설 원문`
      ④ 라벨형 (GitHub 2주차)       `정답 ① 보기` / `해설 원문`
      ⑤ 구형 블록 (1주차 일부)      `문제1. 지문` / `정답: ① O` / `해설` + `- …` 불릿
                                    — 불릿 중 `- 공식: "원문"`만 공식 해설로 인정한다

    판정 원칙:
      - 공식 정답 = 채록본에 **정답확인 채점 기록**(정답확인 후/뒤 · 정답확인 채점 N문항 · 채점: Y/N ·
        채점 N/N · passyn=Y/N · 채점 검증 완료)이 있을 때의 정답 줄뿐이다. 기록이 없으면 정답 줄이 있어도
        공식이 아니다. `passed-answer`·`passyn` 낱말만으로는 기록이 아니다(방법 설명·`※` 줄에도 나온다)
      - ①정본 형식(`채점:` 줄이 있는 문항이 하나라도 있음)이면 `채점:` 줄이 없는 문항은 미준비다.
        머리 `정답확인 채점 N문항(Y a · N b)`의 N은 채점 기록이 있는 문항 수와 같아야 한다
      - 라벨 없는 해설(③·④)은 채록 기록이 「정답·해설」을 강의실에서 받았다고 적었을 때만 원문으로 본다
      - 공식 해설은 원문이 있거나 `공식 해설 없음`이 명시돼야 한다 — 구형 불릿처럼
        원문과 보충이 섞여 구분할 수 없으면 미확인이다
      - 「추정·추측·짐작·미확인·미확보·공식 채점 전·이어서 채록·미채록·미채점·전사 근거 판단」이
        내가 적은 줄(머리·주석·정답 줄·채점·보충 근거)에 있으면 미준비. 지문·보기·공식 해설 원문은
        `(추정)`·`(추측)`·`추정 정답`·`공식 채점 전` 같은 명시 표지만 본다(통계 용어 오탐 방지)
      - 문항 수가 선언(채록본의 `N문항`·`N/N`, 목차 주석)과 다르면 미준비

    Args:
        text: find_quiz_capture()['text']
        declared: 목차 주석의 문항 수 (find_quiz_capture()['declared'])

    Returns:
        dict: {
            'items': [{'no', 'stem', 'kind'('ox'|'choice'|'short'|None), 'options',
                       'answer'(채록본 표기 그대로), 'answer_no', 'answer_text',
                       'official_answer'(공식일 때만, 아니면 None), 'passyn'('Y'|'N'|None),
                       'official_explanation'(원문 또는 None), 'no_official_exp'(bool),
                       'supplement'(보충 근거 목록), 'has_estimate'(bool), 'ready'(bool),
                       'issues'(list)}],
            'count', 'declared', 'graded_record', 'ready', 'problems',
            'summary': {'official_answer', 'official_exp', 'no_exp', 'estimate'}
        }
    """
    items, notes, cur = [], [], None

    def close():
        nonlocal cur
        if cur:
            items.append(cur)
        cur = None

    for raw in (text or '').split('\n'):
        s = raw.strip()
        m = QUIZ_ITEM.match(raw)
        if m:
            close()
            no = int(m.group(1) or m.group(2) or m.group(3))
            cur = {'no': no, 'stem': [m.group(4).strip()], 'notes': [], 'opts': [], 'raw': [raw],
                   'answer': None, 'unresolved': False, 'exp_flag': False, 'off': None,
                   'noexp': False, 'lexp': None, 'dash': None, 'ref': None, 'legacy': [],
                   'passyn': None, 'supp': [], 'tgt': 'stem'}
            continue
        if cur is None or (s and not raw[:1].isspace() and s[0] in '※⚠✅⭐'):
            close()
            notes.append(raw)
            continue
        cur['raw'].append(raw)
        if not s:
            if cur['tgt'] != 'legacy':
                cur['tgt'] = None
            continue

        a = _Q_ANS.match(s)
        if cur['answer'] is None and not cur['unresolved'] and a:
            v = a.group(1)
            if re.search(r'✅[ \t]*공식 해설 있음', v):
                cur['exp_flag'] = True
                v = re.sub(r'[ \t]*✅[ \t]*공식 해설 있음.*$', '', v)
            if v.startswith('미확보'):
                cur['unresolved'] = True
                cur['tgt'] = None
                continue
            head_, _, tail = v.partition(' — ')
            if tail and re.fullmatch(r'(?:[①-⑩][ \t]*)?(?:[OXＯＸ○×]|\d{1,2}번?)', head_.strip()):
                v = head_
                t = tail.strip()
                if _Q_NOEXP.match(t):
                    cur['noexp'], cur['tgt'] = True, None
                elif _Q_OFFEXP.match(t):
                    cur['off'], cur['tgt'] = [_Q_OFFEXP.match(t).group(1)], 'off'
                else:
                    cur['dash'], cur['tgt'] = [t], 'dash'
            else:
                cur['tgt'] = None
            cur['answer'] = re.split(r'[ \t]{2,}', v.strip())[0]
            continue

        before = cur['answer'] is None and not cur['unresolved']
        if before:
            if _Q_OPT.match(s):
                cur['opts'].append(s)
                cur['tgt'] = 'opts'
            elif s.startswith('('):
                cur['notes'].append(s)
            elif cur['tgt'] == 'stem':
                cur['stem'].append(s)
            else:
                cur['notes'].append(s)
            continue

        if _Q_NOEXP.match(s):
            cur['noexp'], cur['tgt'] = True, None
        elif _Q_OFFEXP.match(s):
            cur['off'], cur['tgt'] = [_Q_OFFEXP.match(s).group(1)], 'off'
        elif _Q_GRADE.match(s):
            cur['passyn'] = _Q_GRADE.match(s).group(1)
            cur['tgt'] = None
        elif _Q_SUPP.match(s):
            cur['supp'].append(_Q_SUPP.match(s).group(1))
            cur['tgt'] = 'supp'
        elif cur['tgt'] != 'legacy' and _Q_EXP.match(s):
            t = _Q_EXP.match(s).group(1).strip()
            ref = re.match(r'문제[ \t]*(\d+)[ \t]*(?:과|와)[ \t]*동일', t)
            if ref:
                cur['ref'], cur['tgt'] = int(ref.group(1)), None
            elif t:
                cur['lexp'], cur['tgt'] = [t], 'lexp'
            else:
                cur['tgt'] = 'legacy'
        elif cur['tgt'] == 'legacy':
            cur['legacy'].append(raw)
        elif s.startswith('('):
            cur['supp'].append(s[1:-1] if s.endswith(')') else s[1:])
            cur['tgt'] = 'supp'
        elif cur['tgt'] in ('off', 'lexp', 'dash', 'supp'):
            cur[cur['tgt']].append(s)
        else:
            cur['supp'].append(s)
            cur['tgt'] = 'supp'
    close()

    note_text = '\n'.join(notes)
    graded = bool(QUIZ_GRADED.search(note_text))
    exp_record = bool(QUIZ_EXP_RECORD.search(note_text))
    nums = [int(n) for n in re.findall(r'(\d+)\s*문항', note_text)]
    nums += [int(d) for _, d in re.findall(r'(?<![\d-])(\d{1,2})/(\d{1,2})(?![\d-])', note_text)]
    if declared:
        nums.append(declared)
    nums = [n for n in nums if n > 0]
    declared_n = max(nums) if nums else None

    out, by_no = [], {}
    for it in items:
        issues = []
        # 구형 불릿 — `- 공식: "원문"`만 공식 해설, 나머지는 보충
        legacy_off, legacy_supp, buf = None, [], None
        for ln in it['legacy']:
            ls = ln.strip()
            lo = _Q_LEGACY_OFF.match(ls)
            if buf is not None:
                buf.append(ls)
            elif _Q_NOEXP.match(ls):
                it['noexp'] = True
            elif lo and legacy_off is None:
                buf = [lo.group(1)]
            elif ls:
                legacy_supp.append(ls)
            if buf is not None and _quiz_closed(buf):   # 따옴표가 닫힐 때까지가 원문
                legacy_off, buf = ' '.join(buf), None
        if buf is not None:
            legacy_off = ' '.join(buf)
        if legacy_off is not None:
            it['off'] = [legacy_off]

        official_exp = _quiz_unquote(' '.join(it['off'])) if it['off'] else None
        supplement = [x for x in it['supp'] if x]
        unlabeled = it['lexp'] or it['dash']
        if official_exp is None and unlabeled:
            if graded and exp_record:
                official_exp = ' '.join(unlabeled)
            else:
                supplement = unlabeled + supplement
                issues.append('라벨 없는 해설 — 강의실 원문이라는 채록 기록 없음')
        if it['legacy']:
            supplement += legacy_supp
            if official_exp is None and not it['noexp']:
                issues.append('구형 해설 불릿 — 공식 원문과 보충이 구분되지 않음')
        if it['exp_flag'] and official_exp is None:
            issues.append('「공식 해설 있음」 표시인데 원문이 없음')

        opts = _quiz_options(it['opts'])
        stem = ' '.join(it['stem']).strip()
        ans = it['answer']
        a_no, a_text = None, None
        if ans:
            cm = re.match(r'^([①-⑩])[ \t]*(.*)$', ans)
            nm = re.match(r'^(\d{1,2})번?(?:[ \t]+(.*))?$', ans)
            if cm:
                a_no, a_text = ord(cm.group(1)) - ord('①') + 1, cm.group(2).strip()
            elif nm and opts:
                a_no, a_text = int(nm.group(1)), (nm.group(2) or '').strip()
            else:
                a_text = ans
            if not a_text and a_no and a_no <= len(opts):
                a_text = opts[a_no - 1]
            a_text = _Q_OX.get(a_text, a_text)
        opt_ox = opts and all(_Q_OX.get(o) for o in opts)
        if any('주관식' in n for n in it['notes']):
            kind = 'short'
        elif '(O/X)' in stem or opt_ox or (not opts and a_text in ('O', 'X')):
            kind = 'ox'
        elif len(opts) >= 3:
            kind = 'choice'
        else:
            kind = None

        # 추정 표지는 내가 적은 줄에서만 찾는다 — 지문·보기·공식 해설 원문(통계 용어 「추정」)은 뺀다
        official_lab = graded and exp_record          # ③·④ 라벨 없는 해설이 원문으로 인정되는 경우
        content = list(it['stem']) + list(it['opts']) + list(it['off'] or [])
        if official_lab:
            content += list(it['lexp'] or []) + list(it['dash'] or [])
        _skip = set(content)
        scan = []
        for r in it['raw']:
            rs = r.strip()
            if not rs or rs in _skip or QUIZ_ITEM.match(r) or _Q_OFFEXP.match(rs) or _Q_LEGACY_OFF.match(rs):
                continue
            if official_lab and _Q_EXP.match(rs):
                continue
            if _Q_ANS.match(rs):                      # 한 줄형 — `— 공식 해설: 원문`의 원문은 뺀다
                head_, sep, tail = rs.partition(' — ')
                t = tail.strip()
                if sep and (_Q_OFFEXP.match(t) or (official_lab and not _Q_NOEXP.match(t))):
                    rs = head_
            scan.append(rs)
        raw_text = '\n'.join(scan)
        has_est = (bool(QUIZ_ESTIMATE.search(raw_text))
                   or bool(QUIZ_EST_CONTENT.search('\n'.join(content)))
                   or it['unresolved'])
        official = a_text if (a_text and not has_est and (graded or it['passyn'])) else None
        if not ans:
            issues.append('정답 미확보' if it['unresolved'] else '정답 줄 없음')
        elif official is None and not has_est:
            issues.append('정답확인 채점 기록 없음 — 공식 정답으로 볼 수 없음')
        if has_est:
            issues.append('추정·미확인·미확보 표지')
        rec = {'no': it['no'], 'stem': stem, 'kind': kind, 'options': opts,
               'answer': ans, 'answer_no': a_no, 'answer_text': a_text,
               'official_answer': official, 'passyn': it['passyn'],
               'official_explanation': official_exp, 'no_official_exp': it['noexp'],
               'supplement': supplement, 'has_estimate': has_est,
               'ref': it['ref'], 'issues': issues}
        out.append(rec)
        by_no.setdefault(it['no'], rec)

    for rec in out:
        ref_no = rec.pop('ref') if rec.get('ref') is not None else None
        src = by_no.get(ref_no) if ref_no is not None else None
        if src is not None and src is not rec:
            rec['official_explanation'] = src['official_explanation']
            rec['no_official_exp'] = src['no_official_exp']
        if rec['official_explanation'] is None and not rec['no_official_exp']:
            if src is not None and src is not rec:     # `해설 문제M과 동일` — 참조 대상이 미확인
                rec['issues'].append(f'참조한 문제{ref_no}의 해설이 미확인')
            elif not any(i.startswith(('구형', '라벨 없는')) for i in rec['issues']):
                rec['issues'].append('공식 해설 원문도 「공식 해설 없음」 표시도 없음')
        rec['ready'] = bool(rec['official_answer']) and not rec['has_estimate'] and (
            rec['official_explanation'] is not None or rec['no_official_exp'])

    problems = []
    if not out:
        problems.append('채록본 없음 — confirm-toc로 학습평가 채록·채점 필요')
    if out and not graded:
        problems.append('정답확인 채점 기록 없음 (정답확인 후/뒤 · 정답확인 채점 N문항 · 채점: Y/N · '
                        '채점 N/N · passyn=Y/N · 채점 검증 완료)')
    if QUIZ_ESTIMATE.search(note_text):
        problems.append('채록본에 추정·미확인·미확보·이어서 채록 표지')
    if declared_n and out and declared_n != len(out):
        problems.append(f'문항 수 불일치 — 선언 {declared_n} · 채록 {len(out)}')
    seq = [r['no'] for r in out]
    if seq and seq != list(range(1, len(seq) + 1)):
        problems.append(f'문항 번호가 1..N 연속이 아님 — {seq}')
    for r in out:
        if not r['ready']:
            problems.append(f"문제{r['no']}: " + ' · '.join(r['issues'] or ['미준비']))

    # ①정본 형식 — 문항마다 `채점:` 줄이 있다. 채점 줄이 없는 문항은 채록본 전체의 기록으로 대신하지 않는다
    #   (유휴 종료 `.eco-popup`으로 중간에 멈춘 자동 채점 흐름)
    canon = any(r['passyn'] for r in out)
    if canon:
        for r in out:
            if r['official_answer'] and not r['passyn']:
                r['ready'] = False
                problems.append(f"문제{r['no']}: 정본 형식인데 `채점: Y/N` 줄 없음")
    # 머리 `정답확인 채점 N문항(Y a · N b)` — N = `채점:` 줄이 있는 문항 수 (정본이 아니면 전 문항)
    hm = re.search(r'정답확인 채점[ \t]*(\d+)[ \t]*문항'
                   r'(?:\([ \t]*Y[ \t]*(\d+)[ \t]*·[ \t]*N[ \t]*(\d+))?', note_text)
    if hm and out:
        graded_n = sum(1 for r in out if r['passyn']) if canon else len(out)
        if int(hm.group(1)) != graded_n:
            problems.append(f'채점 문항 수 불일치 — 머리 {hm.group(1)} · 채점 기록 {graded_n}')
        if hm.group(2) and int(hm.group(2)) + int(hm.group(3)) != int(hm.group(1)):
            problems.append('머리 Y+N 합이 채점 문항 수와 다름')

    summary = {'official_answer': sum(1 for r in out if r['official_answer']),
               'official_exp': sum(1 for r in out if r['official_explanation'] is not None),
               'no_exp': sum(1 for r in out if r['official_explanation'] is None and r['no_official_exp']),
               'estimate': sum(1 for r in out if r['has_estimate'])
                           + len(QUIZ_ESTIMATE.findall(note_text))}
    return {'items': out, 'count': len(out), 'declared': declared_n, 'graded_record': graded,
            'ready': bool(out) and not problems, 'problems': problems, 'summary': summary}
```

사용:

```python
def show_quiz_gate(script_content):
    """학습평가 판정을 사람이 읽을 수 있게 출력한다 — None이면 학습평가 없음 (AWS 등)"""
    cap = find_quiz_capture(script_content)
    if cap is None:
        return None
    quiz = parse_quiz_capture(cap['text'], cap['declared'])
    s = quiz['summary']
    print(f"학습평가 {quiz['count']}문항 · 공식 정답 {s['official_answer']}/{quiz['count']}"
          f" · 공식 해설 {s['official_exp']} · 없음 {s['no_exp']} · 추정 {s['estimate']}"
          f" → {'준비됨' if quiz['ready'] else '미준비'}")
    for p in quiz['problems']:          # 미준비 사유 → confirm-toc 회수 대상 (0단계 확인 5)
        print('  -', p)
    for it in quiz['items']:            # 7단계 학습평가 절의 재료
        print(' ', it['no'], it['kind'], it['official_answer'],
              it['official_explanation'] or ('공식 해설 없음' if it['no_official_exp'] else '?'))
    return quiz
```

> **실측 (2026-09-17 · 5과목 스크립트 14개 전수)** — 준비됨 8: 딥러닝 2·3 · 빅데이터 1·2·3 · GitHub 2 · 문제해결 2·3 / 미준비 3: 딥러닝 1(채점 기록 없음 · 「이어서 채록」) · 문제해결 1(채점 기록 없음 · 「전사 근거 판단」 · 1·4·5·6번 해설 구분 불가) · GitHub 1(정답은 공식 12/12, 해설이 구형 불릿이라 원문 구분 불가) / 해당 없음 3: AWS 1~3

## 4단계: 강의교안 PDF → 이미지 변환

강의교안 PDF는 슬라이드 레이아웃, 다이어그램, 표 등 시각 정보가 많으므로 이미지로 변환 후 Read 도구로 시각적으로 읽는다.

> **`pdf2image`가 아니라 `pdftoppm`을 직접 부른다.** poppler(=`pdftoppm`)는 대개 이미 깔려 있고, `pdf2image`는 그 위에 얹는 파이썬 래퍼일 뿐이라 없는 경우가 많다. 래퍼를 설치하러 가지 말고 바이너리를 바로 쓴다.

```bash
pdftoppm -png -r 110 "교안.pdf" "출력폴더/p"    # → p-01.png, p-02.png, ...
```

```python
import subprocess, os

def convert_lecture_pdf(pdf_path, week, dpi=110):
    """강의교안 PDF를 PNG로 변환 (poppler pdftoppm 직접 호출)"""
    output_dir = os.path.join(SESSION_BASE, f'pdf_lecture_{week:02d}')
    os.makedirs(output_dir, exist_ok=True)

    subprocess.run(['pdftoppm', '-png', '-r', str(dpi),
                    pdf_path, os.path.join(output_dir, 'p')], check=True)

    saved = sorted(os.path.join(output_dir, f)
                   for f in os.listdir(output_dir) if f.endswith('.png'))
    print(f"변환 완료: {len(saved)}페이지")
    return saved
```

변환된 이미지는 `SESSION_BASE` 아래 임시 디렉토리에 저장한다 (workspace가 아닌 세션 영역).

### 이미지 읽기 방법

- 10~15페이지씩 나누어 Read 도구로 읽기
- 각 묶음의 핵심 내용을 메모한 뒤 다음으로 넘어감
- 전체를 한 번에 읽으면 컨텍스트 과부하 발생

## 5단계: 실습 자료 분석 (PDF 또는 ipynb)

실습 자료는 `.pdf`(Colab PDF)와 `.ipynb`(Jupyter Notebook) 두 가지 형식이 존재한다.

### ipynb 파일 처리 (우선)

`.ipynb` 파일은 Read 도구로 직접 읽을 수 있다 (모든 셀 + 출력 포함).

```python
def is_ipynb(path):
    return unicodedata.normalize('NFC', path).lower().endswith('.ipynb')
```

**ipynb 파일이면**: `Read(file_path=path)` 한 번으로 모든 코드셀, 마크다운셀, 출력을 확인할 수 있다. pdfminer 불필요.

### PDF 파일 처리

실습 PDF는 코드와 텍스트 위주이므로 pdfminer로 텍스트를 추출한다. **단, pdfminer가 실패하는 PDF가 있으므로 반드시 fallback 처리를 포함한다.** PDF도 Read 도구로 직접 읽을 수 있으므로 (pages 파라미터 활용), pdfminer 실패 시 Read 도구 fallback을 사용한다.

```python
from pdfminer.high_level import extract_text
import subprocess, shutil, os

def extract_practice_text(pdf_path, week):
    """실습 PDF에서 텍스트 추출 (pdfminer 실패 시 이미지 변환 fallback)"""
    # 특수문자 경로 우회
    temp = os.path.join(SESSION_BASE, f'practice_{week:02d}.pdf')
    shutil.copy2(pdf_path, temp)

    # 1차 시도: pdfminer 텍스트 추출
    try:
        text = extract_text(temp)
        cleaned = text.strip()
        if len(cleaned) > 100:
            print(f"실습 텍스트 추출 완료 (pdfminer): {len(cleaned):,}자")
            return {'type': 'text', 'content': cleaned}
    except Exception as e:
        print(f"pdfminer 실패: {e}")

    # 2차 시도: 이미지 변환 후 시각적 읽기로 fallback
    print("pdfminer 실패 → 이미지 변환 fallback")
    output_dir = os.path.join(SESSION_BASE, f'pdf_practice_{week:02d}')
    os.makedirs(output_dir, exist_ok=True)

    subprocess.run(['pdftoppm', '-png', '-r', '110',
                    temp, os.path.join(output_dir, 'p')], check=True)
    saved = sorted(os.path.join(output_dir, f)
                   for f in os.listdir(output_dir) if f.endswith('.png'))

    print(f"실습 PDF 이미지 변환 완료: {len(saved)}페이지 → Read 도구로 시각적 읽기 필요")
    return {'type': 'images', 'paths': saved}
```

**반환값 처리:**
- `{'type': 'text', 'content': ...}` → 텍스트를 직접 사용
- `{'type': 'images', 'paths': [...]}` → 강의교안과 동일하게 Read 도구로 10~15페이지씩 시각적으로 읽기

## 6단계: 영상 프레임 전수 분석 — 보강 내용 추출 + 시각 참고

`extract-video` 스킬에서 캡처한 슬라이드 프레임을 **전수 확인**하여, 교안·전사만으로는 파악할 수 없는 **보강 내용을 추출**하고 **시각 참고자료로 활용**한다.

> **왜 전수 확인인가?** 대표 프레임 몇 개만 보면 판서·데모·추가 화면을 놓치기 쉽다.
> 프레임을 모두 읽어야 강의노트 작성 시 누락 없이 반영할 수 있고, 작성 후 별도 검증 단계가 불필요해진다.

### 6-A: 프레임 탐색

프레임은 두 가지 위치에 저장될 수 있다:
1. **`강의영상/frames_{주차:02d}/`** (Mac 로컬 표준 경로 — 우선 확인)
2. **`SESSION_BASE/video_frames_{주차:02d}_*`** (VM 세션 경로 — fallback)

```python
import os, re, unicodedata

def find_video_frames(course_path, week):
    """영상 프레임 디렉토리 탐색 (Mac 로컬 + VM 세션 경로 모두 확인)"""
    frames_by_seq = {}

    # 1차: 강의영상/frames_{week:02d}/ 확인 (Mac 로컬 표준 경로)
    video_dir = resolve_subdir(course_path, '강의영상')
    if video_dir:
        frames_dir_name = f'frames_{week:02d}'
        frames_dir = None
        for d in os.listdir(video_dir):
            if unicodedata.normalize('NFC', d) == frames_dir_name:
                frames_dir = os.path.join(video_dir, d)
                break

        if frames_dir and os.path.isdir(frames_dir):
            for f in sorted(os.listdir(frames_dir)):
                if not f.endswith('.jpg'):
                    continue
                # v01_frame_0001.jpg → seq=1
                m = re.match(r'v(\d+)_frame_', f)
                if m:
                    seq = int(m.group(1))
                    frames_by_seq.setdefault(seq, []).append(
                        os.path.join(frames_dir, f)
                    )

    # 2차: SESSION_BASE 경로 확인 (VM 환경 fallback)
    if not frames_by_seq:
        try:
            import glob
            pattern = os.path.join(SESSION_BASE, f'video_frames_{week:02d}_*')
            frame_dirs = sorted(glob.glob(pattern))
            for d in frame_dirs:
                seq = int(os.path.basename(d).split('_')[-1])
                jpgs = sorted([
                    os.path.join(d, f) for f in os.listdir(d) if f.endswith('.jpg')
                ])
                if jpgs:
                    frames_by_seq[seq] = jpgs
        except Exception:
            pass

    if frames_by_seq:
        total = sum(len(v) for v in frames_by_seq.values())
        print(f"영상 프레임 발견: {total}개 ({len(frames_by_seq)}개 순번)")
    else:
        print("영상 프레임 없음")

    return frames_by_seq
```

### 6-A-2: 프레임이 없으면 직접 추출

프레임 디렉토리가 없지만 **MP4 파일이 존재하면 ffmpeg으로 직접 추출**한다.

```python
import subprocess

def extract_frames_ffmpeg(course_path, week):
    """MP4 영상에서 프레임 직접 추출 (30초 간격)"""
    video_dir = resolve_subdir(course_path, '강의영상')
    if not video_dir:
        return {}

    output_dir = os.path.join(video_dir, f'frames_{week:02d}')
    os.makedirs(output_dir, exist_ok=True)

    for f in sorted(os.listdir(video_dir)):
        nfc_f = unicodedata.normalize('NFC', f)
        if not nfc_f.endswith('.mp4'):
            continue
        m = re.search(r'_(\d+)_(\d+)', nfc_f)
        if not m or int(m.group(1)) != week:
            continue
        seq = m.group(2)
        input_path = os.path.join(video_dir, f)
        output_pattern = os.path.join(output_dir, f'v{seq}_frame_%04d.jpg')
        subprocess.run([
            'ffmpeg', '-i', input_path,
            '-vf', 'fps=1/30,scale=1280:-1',
            '-q:v', '2', output_pattern
        ], capture_output=True)

    return find_video_frames(course_path, week)
```

### 6-B: 전수 읽기 및 보강 내용 추출

프레임이 존재하면 **순번별로 모든 프레임을 Read 도구로 읽는다** (대표 몇 개가 아님).

1. **순번(seq) 순서대로** 각 디렉토리의 프레임을 읽는다
2. 프레임을 읽으면서 아래 기준으로 **분류**한다:

| 분류 | 설명 | 조치 |
|------|------|------|
| 교안 슬라이드 반복 | 교안 PDF와 동일한 내용 | 별도 조치 불필요 (교안에서 이미 확보) |
| **판서·화이트보드** | 강사가 별도로 적은 설명, 공식, 그림 | **보강 내용으로 추출** → 해당 `## (N)` 섹션에 반영 |
| **데모·실행 화면** | 코드 실행 결과, 소프트웨어 조작 화면 | **보강 내용으로 추출** → 실습 섹션에 반영 |
| **추가 설명 화면** | 교안에 없는 별도 자료, 웹페이지, 참고 화면 | **보강 내용으로 추출** → 관련 섹션에 반영 |
| 전환 화면·로딩 | 의미 없는 전환 장면 | 무시 |

3. 추출된 보강 내용을 **`## (N)` 순번별로 정리**해 둔다

### 6-C: 보강 내용 정리 형식

프레임 분석 결과를 7단계(강의노트 작성)에서 바로 활용할 수 있도록 정리한다:

```
[영상 프레임 보강 내용]

## (1) - 해당 없음 (교안 슬라이드만)
## (2) - 판서: "정규화 3단계를 도식으로 그려 설명" → 1NF→2NF→3NF 흐름도
## (3) - 데모: "MySQL에서 실제 테이블 생성 후 정규화 적용" → 실습 코드+결과
## (5) - 추가 화면: "실무에서의 반정규화 사례" → 교안에 없는 보충 설명
...
```

이 정리본이 7단계에서 각 `## (N)` 섹션 내용을 채울 때 **4번째 소스**(전사→교안→실습→**영상 프레임 보강**)로 사용된다.

### 프레임이 없는 경우

프레임 디렉토리가 없을 때는 **MP4 유무로 갈린다** (0단계 「확인 4」와 같은 규칙):

- **MP4 있음** → ❌ 건너뛰지 않는다. 로컬 `ffmpeg`으로 프레임을 먼저 추출한다(`extract_frames_ffmpeg()`). 워크스페이스 CLAUDE.md가 「MP4 존재 시 프레임 없이 진행 금지」로 못박은 자리다
- **MP4 없음** → 이 단계를 건너뛰고 교안+본문+실습만으로 진행하며, 사용자에게 "영상 프레임 없이 진행합니다"를 안내한다

## 7단계: 강의노트 작성

### 제목 구조 — 학습목차 기반 (필수)

**강의노트의 `#`/`##` 헤더와 `---` 가로선은 스크립트의 학습목차에서 확정된 구조를 그대로 따른다.** 3-A단계에서 파싱한 학습목차 구조를 강의노트의 뼈대로 사용하고, 각 섹션 아래에 내용을 채운다.

### 내용 채우기 전략 — 우선순위 기반

각 `## (N)` 대응 섹션에 내용을 채울 때 아래 우선순위를 따른다:

| 우선순위 | 소스 | 역할 |
|----------|------|------|
| **1 (최우선)** | 전사 텍스트 (## (N)) | 강사의 실제 설명 — 본문의 뼈대. 교안에 없는 보충 설명·예시·맥락 포함 |
| 2 | 강의교안 PDF | 시각 자료, 다이어그램, 표, 핵심 키워드 보충 |
| 3 | 실습 PDF | 코드, 실행 결과, 실습 과제 |
| 4 | 영상 프레임 | 판서, 데모 화면, 교안에 없는 추가 설명 |

**작성 원칙:**
- `## 학습개요` → 강의교안 첫 페이지에서 학습목표와 학습내용 추출
- `## (N)` 대응 섹션 → **전사 텍스트를 기반으로** 교안 슬라이드 + 실습 코드 + 영상 프레임을 종합
- `## 학습평가` → **채록본의 문항 + 공식 정답 + 공식 해설 원문**(3-C `parse_quiz_capture()` 결과)에 강의 근거 보충을 붙인다. 공식값이 아닌 정답은 쓰지 않는다
- `## 학습정리` → **채록본 원문 기반**으로 채운다 (채록본이 없을 때만 교안 정리 페이지 · 전사 요약)
- 두 구역 모두 **제목만 남기지 않는다.** 아래 참조

#### ⚠️ 학습평가·학습정리는 내용까지 채운다

**제목만 있고 비어 있는 노트는 미완성이다.** 기존 노트 중에 이 두 구역이 빈 것이 있어도 **따라 하지 말 것** — 그건 정본이 아니라 누락이다.

두 구역은 **MP3·영상이 없어 전사로 복원되지 않는다.** 소스가 구역마다 다르다.

**학습평가 — 대체 출처가 없다**

| 항목 | 출처 |
|---|---|
| 문항 · 보기 · **공식 정답** · **공식 해설 원문** | `confirm-toc`가 **정답확인으로 회수**해 스크립트에 적은 채록본 **뿐** (정답 행 `.passed-answer`/`.failed-answer` · `[data-field="explanation"]`) |
| 보충 근거 (해설의 둘째 불릿부터) | 자막(전사) · 교안 · 실습 · 학습정리 — **보충 전용**이며 정답을 정하는 데 쓰지 않는다 |

- ⛔ 교안의 평가 문항·자막 내용·「거짓 진술에만 해설」 같은 패턴을 **정답의 출처로 쓰지 않는다**
- ⛔ 공식 정답이 없거나 추정이면 노트를 쓰지 않고 `confirm-toc` 회수를 먼저 한다 (0단계 확인 5)

**학습정리**

| 소스 | 우선순위 |
|---|---|
| `confirm-toc` 채록본 (스크립트에 기록됨) | 1 — 강의실 요약 슬라이드 원문 |
| 강의교안 마지막 페이지의 정리 | 2 |
| 전사 전체를 근거로 한 요약 | 3 |

**`학습평가`는 ADsP 기출 형식으로 쓴다** (`#### 문제N` → 지문 → 보기 → 정답 → 해설)

````markdown
## 학습평가

- 공통 지시문 — 학습한 내용을 바탕으로 다음 문제를 풀어보세요
- O/X 6문항
- 정답은 강의실에서 정답확인으로 채점해 확인한 공식 정답
- 공식 해설 제공 문항 — 2·4·5번

#### 문제1

리스트는 여러 값을 순서대로 저장할 수 있는 자료형이다.

- O
- X

**정답** O

**해설**

- 공식 해설이 제공되지 않은 문항 — 아래는 강의 내용을 근거로 정리한 것
- 강의 근거 — 변수는 하나의 공간에 하나의 값, 리스트는 하나의 이름에 공간을 나누어 여러 값을 가짐

#### 문제2

리스트의 인덱스는 1부터 시작한다.

- O
- X

**정답** X

**해설**

- 공식 해설 — 「리스트의 인덱스는 0부터 시작한다」
- 강의 근거 — 사람은 1부터 세지만 컴퓨터는 0부터 셈 → 첫 번째 원소가 `a[0]`

#### 문제3

다음 중 원천 데이터에 대한 정보를 습득하고자 할 때 필요한 정보에 해당하지 않는 것은?

1. 데이터의 보안
2. 데이터의 신속성
3. 데이터의 정확성
4. 데이터의 수집 가능성

**정답** 2 — 데이터의 신속성

**해설**

- 공식 해설 — 「원천 데이터에 대한 정보는 데이터의 수집 가능성, 보안, 정확성, 수집 난이도, 수집 비용 항목이 필요하다」
- 강의 근거 — 원천 데이터는 수집 가능 여부 · 보안 · 정확성 · 수집 난이도 · 비용을 확인함

#### 문제4

Git에서 파일 상태를 추적하는 명령어는 무엇인가요? (옵션제외 기본 명령어만 작성)

**정답** `git status`

**해설**

- 공식 해설 — 「"git status" 명령어를 사용하여 파일 상태를 추적할 수 있습니다」
````

- 머리 불릿 — 공통 지시문 · 유형 구성(혼재면 유형별 문항 번호) · 「정답은 강의실에서 정답확인으로 채점해 확인한 공식 정답」 · 공식 해설이 일부 문항에만 있으면 그 번호
- 지문·보기는 **채록본 원문 그대로** — O/X는 `- O` / `- X` 목록, 객관식은 `1. …` 번호 목록, 주관식은 보기 없음
- **정답 줄은 콜론 없이** — O/X `**정답** O` · 객관식 `**정답** 2 — 보기 텍스트` · 주관식 ``**정답** `git status` ``
- **해설 첫 불릿은 둘 중 하나**
  - 공식 해설이 있으면 `- 공식 해설 — 「원문」` — 「」 안은 **원문 그대로**(어미 변환·요약 금지) 두고 **끝 마침표만 뗀다**. 바깥 인용 부호는 「」로 통일한다(바깥 큰따옴표 금지 · 원문 안의 따옴표는 그대로)
  - 없으면 `- 공식 해설이 제공되지 않은 문항 — 아래는 강의 내용을 근거로 정리한 것` — 이때도 **정답 줄은 공식값**이다
- **보충 근거는 둘째 불릿부터 개조식**(마침표 없음) — 공식 해설 불릿과 섞지 않는다
- 공식 정답이 강의 설명과 어긋나면 `- ⚠️ 공식 정답과 강의 설명이 어긋남 — …` 불릿을 두고, `학습정리`까지 대조해 해소됐는지 적는다 (GitHub 2주차 Q3 선례)
- **채점 결과(Y/N)·선택한 보기·채점 방식은 노트에 넣지 않는다** — 학습 자료이기 때문이다. 스크립트와 과목 CLAUDE.md에만 둔다
- ⛔ 「(추정)」·「공식 채점 전」·「추정값」 표기 금지(정답 줄에는 `추정`·`추측`·`짐작` 어떤 형태도 금지 — 10단계 기계 대조가 잡는다. 지문·공식 해설 원문 속 통계 용어 `추정값`은 과목 내용이라 괜찮다) — 공식 정답이 없으면 노트를 쓰지 않고 `confirm-toc` 회수가 먼저다(0단계 확인 5). 사용자가 노트를 먼저 원한 예외에서만 그 문항을 `**정답** (미확보 — confirm-toc 회수 필요)`로 두고 보고한다
- 채록본 자체가 없으면 문항을 지어내지 않는다 — `confirm-toc`로 채록·채점부터 한다

> 폐기(v0.12.0) — 이전 예시의 `**정답**: X`(콜론) 표기와 「공식 해설 표시 없이 자작 풀이만 적는 해설」. 앞의 예시는 딥러닝 1주차의 **정답확인 기록이 없는** 채록본에서 온 것이었다

### 서식 규칙 (CLAUDE.md 참조)

아래 규칙은 프로젝트의 CLAUDE.md에서 정의된 표준 서식이다. CLAUDE.md에 다른 규칙이 있으면 그것을 우선 따른다.

### 문체

- 개조식으로 작성
- 문장 끝에 마침표 사용 금지
- 요약하지 말고 상세하게 빠짐없이 기록
- 출처 표기 금지 (슬라이드 번호, PDF 페이지 등)

### 마크다운 구조

```markdown
# 최상위 항목 (학습목차의 # 제목)

## 서브 항목 (학습목차의 ## 제목)

### 노트 정리 중 도출되는 큰 세부 항목

- 일반 항목
  - 서브 항목
    - 서브서브 항목

---  ← 학습목차에서 --- 가 있는 위치에만 삽입
```

### 코드 처리

- 강의 중 작성되는 코드는 코드블록으로 제공
- 코드블록은 계층 구조 없이 최상단 레벨에 배치 (서브 리스트 하위에 있으면 전체 복사 시 누락됨)

```python
# 예시: 코드블록은 항상 최상단 레벨
def example():
    pass
```

### 수식 처리

- 수학 기호나 복잡한 수식은 LaTeX로 작성
- LaTeX 수식은 `$`를 빼고 코드블록으로 작성 (복사 편의)

```latex
\sum_{i=1}^{n} x_i = x_1 + x_2 + \cdots + x_n
```

## 8단계: 시각 자료(다이어그램/도표) 생성 — 필수

**강의노트 작성 시 반드시 시각 자료 생성 가능 여부를 검토해야 한다.** 아래 기준에 해당하는 내용이 1개 이상 있으면 시각 자료를 생성하여 노트에 삽입한다.

### 시각 자료 생성 기준 (하나라도 해당하면 생성)

- 계층 구조 (예: AI ⊃ ML ⊃ DL)
- 프로세스 흐름도 (예: 데이터 전처리 파이프라인)
- 비교 도표 (예: Hold-out vs K-fold 방식 비교)
- 분류 체계 (예: 학습 유형 분류)
- 아키텍처/구조도 (예: 신경망 레이어 구조)
- 개념 관계도 (예: 과적합·과소적합 관계)
- 매트릭스/2×2 도표 (예: Known/Unknown 분석 매트릭스)
- 단계별 과정 (예: 방법론 5단계)

### 사전 준비

```bash
# Playwright + Chromium (최초 1회)
pip install playwright --break-system-packages
playwright install chromium
```

### ⚠️ 한글 폰트 — 환경부터 판별한다

**폰트 처리 방식이 환경에 따라 완전히 다르다.** 먼저 어디서 도는지 확인한다.

```python
import platform, subprocess
IS_MAC = platform.system() == 'Darwin'
```

| | **환경 A — 맥 네이티브** (기본) | **환경 B — VM/컨테이너** |
|---|---|---|
| 판별 | `platform.system() == 'Darwin'` | 그 외 |
| 한글 폰트 | **시스템에 이미 있다** | 없다 — □로 깨진다 |
| 처리 | `font-family`만 지정, **`@font-face` 불필요** | NanumGothic을 로컬 설치 후 `@font-face` |

#### 환경 A — 맥 네이티브 (검증 완료)

macOS Chromium은 시스템 한글 폰트를 그대로 쓴다. **폰트 파일을 설치할 필요도, `@font-face`를 쓸 필요도 없다.**

```python
BASE_STYLE = """
* { font-family: 'Apple SD Gothic Neo', AppleGothic, sans-serif; }
body { margin: 0; padding: 20px; }
"""
```

> 과거 지침은 VM 전제로 `koreanize-matplotlib`의 NanumGothic을 `~/.fonts/`에 설치하게 했다.
> **맥에서는 그 단계 전체가 불필요하다** — 설치해도 결과가 같고 시간만 든다.

#### 환경 B — VM/컨테이너

한글 폰트가 없어 SVG·HTML의 한글이 □로 깨진다. Google Fonts CDN은 네트워크 제한으로 막히고 `@fontsource/noto-sans-kr` npm 설치도 안 되므로, **로컬 폰트 파일 `@font-face`가 유일한 방법**이다.

```bash
pip install koreanize-matplotlib --break-system-packages
mkdir -p ~/.fonts
cp $(python3 -c "import koreanize_matplotlib,os;print(os.path.dirname(koreanize_matplotlib.__file__))")/fonts/NanumGothic*.ttf ~/.fonts/
fc-cache -f
```

```python
import os
FR = os.path.expanduser('~/.fonts/NanumGothic.ttf')
FB = os.path.expanduser('~/.fonts/NanumGothicBold.ttf')
BASE_STYLE = f"""
@font-face {{ font-family:'NanumGothic'; src:url('file://{FR}'); font-weight:400; }}
@font-face {{ font-family:'NanumGothic'; src:url('file://{FB}'); font-weight:700; }}
* {{ font-family:'NanumGothic', sans-serif !important; }}
body {{ margin:0; padding:20px; }}
"""
```

### 시각 자료 생성 파이프라인

HTML을 Playwright(Chromium)로 렌더링하여 PNG 스크린샷을 생성한다.
**SVG를 직접 마크다운에서 참조하면 안 된다** — Obsidian 등에서 SVG 렌더링이 불안정하고 한글이 깨진다.

```python
import asyncio, platform
from playwright.async_api import async_playwright

IS_MAC = platform.system() == 'Darwin'

async def create_visual(html_content, png_path, width=700, height=450):
    """HTML → Playwright Chromium → PNG 스크린샷"""
    args = [] if IS_MAC else ['--no-sandbox', '--disable-web-security']
    async with async_playwright() as p:
        browser = await p.chromium.launch(args=args)
        page = await browser.new_page(
            viewport={'width': width, 'height': height},
            device_scale_factor=2  # Retina 품질
        )
        await page.set_content(html_content)
        await page.wait_for_timeout(300 if IS_MAC else 1000)  # 폰트 로딩 대기
        await page.screenshot(path=png_path, type='png', full_page=True)
        await browser.close()
    return png_path

# 사용 예시:
# html = f"<html><head><style>{BASE_STYLE} ...</style></head><body>...</body></html>"
# asyncio.run(create_visual(html, '/path/to/output.png'))
```

핵심 포인트:
- `set_content(html)`로 HTML 문자열을 직접 주입 (파일 저장 불필요)
- `device_scale_factor=2`로 고해상도 출력
- 환경 B에서만 `--no-sandbox`·`--disable-web-security`(로컬 `file://` 폰트 접근용)와 긴 폰트 대기가 필요하다
- **생성 후 PNG를 Read로 열어 한글이 제대로 나왔는지 눈으로 확인**한다 — 깨짐은 조용히 발생한다

### HTML 템플릿 규칙

1. **한글 폰트**: 위 `BASE_STYLE`을 그대로 쓴다 (맥은 시스템 폰트, VM은 로컬 `@font-face`). **CDN·npm 금지**

```html
<!-- 맥 네이티브 -->
<style>* { font-family: 'Apple SD Gothic Neo', AppleGothic, sans-serif; }</style>
```

2. **크기**: `body`에 고정 `width`/`height` 지정 (기본 700×450)
3. **배경**: `#fafafa` 또는 `#ffffff` (노트에 삽입 시 자연스러운 배경)
4. **스타일**: gradient, box-shadow, border-radius 등 모던 CSS 적극 활용
5. **색상 팔레트 예시**:
   - 보라/인디고 계열: `#6366f1`, `#8b5cf6`
   - 파랑 계열: `#3b82f6`, `#2563eb`
   - 초록 계열: `#10b981`, `#059669`
   - 슬레이트: `#1e293b`, `#64748b`

### 강의노트에 삽입 방법

생성된 PNG를 강의노트의 `img/` 폴더에 저장하고 마크다운으로 참조한다.

```python
import shutil

def save_visual(course_path, week, png_path, visual_name):
    """시각 자료를 img 폴더에 저장"""
    img_dir = os.path.join(course_path, '강의노트', 'img')
    os.makedirs(img_dir, exist_ok=True)
    dest = os.path.join(img_dir, f'{visual_name}.png')
    shutil.copy2(png_path, dest)
    return dest
```

마크다운에서 상대 경로로 참조:

```markdown
![AI·ML·DL 계층 구조](img/ai-ml-dl-hierarchy.png)
```

### 주의사항

- **SVG를 마크다운에서 직접 참조하지 않는다** — Obsidian 등에서 렌더링 불안정 + 한글 깨짐
- Google Fonts CDN 사용 불가 (네트워크 제한) · `@fontsource/noto-sans-kr` npm 설치 불가
- **맥에서는 `@font-face`·폰트 설치가 불필요하다** — 시스템 폰트로 충분 (환경 A)
- VM에서만 `koreanize-matplotlib` 번들 NanumGothic.ttf를 로컬 `@font-face`로 참조 (환경 B)
- 이미지 폴더는 `강의노트/img/` (과거 `이미지/` 사용하지 않음)
- 마크다운 참조는 항상 `.png` 확장자: `![설명](img/파일명.png)`

## ⚠️ 파일 수정 시 인덱스 기반 편집 금지

스크립트 TXT와 강의노트에는 **`## 학습평가` 같은 동일 문자열이 두 번 이상** 나온다(학습목차 구역 + 본문 구역). `s.index('## 학습평가')`로 자르면 **앞쪽 목차를 잡아 파일 뒷부분이 통째로 날아간다.** 28KB 스크립트가 1.1KB가 된 사고가 실제로 있었다.

- **소스에서 재생성**하는 방식을 기본으로 한다
- 부분 수정이 필요하면 앞뒤 문맥을 포함한 **유일한 문자열**을 앵커로 쓴다 (`Edit` 도구는 유일하지 않으면 실패하므로 안전하다)
- 수정 직후 **파일 크기와 제목 개수를 검증**한다

```python
before = os.path.getsize(path)
# ... 수정 ...
after = os.path.getsize(path)
if after < before * 0.8:
    raise RuntimeError(f'파일이 {before:,} → {after:,} 로 급감 — 편집 오류 의심')
```

## 9단계: 파일 저장

### ⚠️ NFD 경로 안전 쓰기 (필수)

iCloud Drive의 한글 폴더명은 macOS NFD(조합형) 인코딩으로 저장된다. VM에서 NFC(완성형) 문자열로 경로를 직접 지정하면 **같은 이름의 새 폴더가 별도로 생성**되어 iCloud와 동기화되지 않는다.

**반드시 `os.listdir()`로 얻은 원본(NFD) 디렉토리명을 사용하여 경로를 구성**한 뒤, 그 경로로 파일을 저장해야 한다. Write/Edit 도구에 경로를 전달할 때도 마찬가지다.

```python
import os, shutil, unicodedata

def resolve_nfd_path(base, *sub_parts):
    """NFD 안전 경로 해석 — 각 경로 단계마다 os.listdir()로 실제 디렉토리명 획득

    iCloud 마운트 환경에서는 같은 한글 이름이 NFD/NFC 두 가지로 존재할 수 있다.
    이 함수는 os.listdir()가 반환하는 원본 이름을 사용하여 실제 파일시스템 경로를 구성한다.
    """
    current = base
    for part in sub_parts:
        nfc_part = unicodedata.normalize('NFC', part)
        found = False
        if os.path.isdir(current):
            for entry in os.listdir(current):
                if unicodedata.normalize('NFC', entry) == nfc_part:
                    current = os.path.join(current, entry)
                    found = True
                    break
        if not found:
            current = os.path.join(current, part)
    return current

def save_note(course_path, week, content):
    """강의노트를 강의노트/ 폴더에 저장 (NFD 안전)"""
    # NFD 원본 경로로 강의노트 디렉토리 해석
    note_dir = resolve_nfd_path(course_path, '강의노트')
    os.makedirs(note_dir, exist_ok=True)

    filename = f'{week:02d}주차-강의노트.md'
    temp = os.path.join(SESSION_BASE, filename)

    # Write 도구로 temp에 저장
    # ... (Write tool 사용) ...

    # 최종 위치로 복사 (NFD 경로)
    dest = os.path.join(note_dir, filename)
    shutil.copy2(temp, dest)
    print(f"강의노트 저장 완료: {dest}")
    return dest

def ensure_nfd_sync(base, course_keyword, sub_path, filename):
    """저장 후 NFD 경로 동기화 검증 — NFC 고스트 폴더에만 파일이 있으면 NFD로 복사"""
    nfd_dir = nfc_dir = None
    for d in os.listdir(base):
        full = os.path.join(base, d)
        nfc_name = unicodedata.normalize('NFC', d)
        if course_keyword not in nfc_name:
            continue
        target = os.path.join(full, sub_path)
        is_nfd = (d == unicodedata.normalize('NFD', d))
        if is_nfd:
            nfd_dir = target
        else:
            nfc_dir = target
    if nfc_dir and nfd_dir:
        nfc_file = os.path.join(nfc_dir, filename)
        nfd_file = os.path.join(nfd_dir, filename)
        if os.path.exists(nfc_file) and not os.path.exists(nfd_file):
            os.makedirs(nfd_dir, exist_ok=True)
            shutil.copy2(nfc_file, nfd_file)
            print(f"NFD 동기화: {filename} → NFD 경로로 복사 완료")
```

**주의:** Write/Edit 도구로 직접 저장할 때도 반드시 `resolve_nfd_path()` 또는 `os.listdir()`로 획득한 경로를 사용해야 한다. 하드코딩된 한글 경로 문자열(NFC)로 Write/Edit를 호출하면 iCloud 폴더가 아닌 별도의 NFC 폴더가 생성된다. 저장 후 반드시 `ensure_nfd_sync()`로 검증한다.

파일명 형식: `{00주차}-강의노트.md`

## 10단계: 통합 검증 — 전체 자료와 강의노트 대조 (필수)

강의노트 초안 저장 후, **교안·전사·실습·영상 프레임** 모든 자료를 강의노트와 대조하여 누락·오류·서식 문제를 확인하고 보강한다.

### 검증 항목

| 검증 대상 | 확인 내용 | 방법 |
|-----------|-----------|------|
| **교안 슬라이드** | 교안의 핵심 내용이 노트에 빠짐없이 반영되었는가 | 교안 이미지를 다시 훑으며 노트와 대조 |
| **전사 텍스트** | 강사가 강조한 설명·예시·보충이 노트에 포함되었는가 | 전사 텍스트의 주요 키워드가 노트에 존재하는지 확인 |
| **실습 PDF** | 실습 코드·과제·실행 결과가 노트에 반영되었는가 | 실습 내용과 노트의 실습 섹션 대조 |
| **영상 프레임** | 판서·데모·추가 화면의 내용이 노트에 반영되었는가 | 6단계에서 추출한 보강 내용이 실제로 노트에 들어갔는지 확인 |
| **순서·구조** | 학습목차 순서와 노트 `##` 헤더 순서가 일치하는가 | 학습목차 파싱 결과와 노트 헤더 비교 |
| **서식** | CLAUDE.md 서식 규칙(개조식, 들여쓰기, 코드블록 등)을 준수하는가 | 노트를 읽으며 서식 규칙 위반 여부 확인 |
| **시각 자료** | 8단계에서 생성한 PNG가 노트에 올바르게 참조되는가 | `![](img/...)` 경로가 실제 파일과 일치하는지 확인 |
| **학습평가** | 문항 수 = 채록 문항 수 · 전 문항 공식 정답 존재 · 노트 정답 = 채록본 공식 정답 · 공식 해설 원문 일치(또는 「제공되지 않은 문항」 명시) · 추정/미확인 표기 0 · `**정답**:` 콜론 0 | `parse_quiz_capture()` + `check_note_quiz()`로 **기계 대조** (아래) |

### 검증 절차

1. **교안 빠른 재확인**: 교안 이미지를 한번 더 훑으며 노트에 빠진 핵심 내용이 없는지 확인
2. **영상 프레임 보강 반영 확인**: 6단계에서 추출한 보강 내용 목록을 노트와 대조 — 실제로 반영되었는지 체크
3. **필수 섹션 존재 + 내용 확인**: `# 들어가기`/`## 학습개요`, `# 평가하기`/`## 학습평가`, `# 정리하기`/`## 학습정리`
   — 제목만 있고 **본문이 비어 있으면 미완성**이다. 채우거나, 채울 수 없는 사유를 보고한다
   — **학습평가는 공식 정답·공식 해설까지 있어야 완성이다.** 추정이 하나라도 있으면 미완성이다
4. **학습평가 기계 대조**: `check_note_quiz(노트, parse_quiz_capture(…))`가 빈 목록이어야 한다 (아래 코드)
5. **이미지 참조 유효성**: `img/` 폴더의 실제 파일과 노트 내 `![](img/...)` 경로 일치 여부
6. **서식 최종 점검**: 개조식, 코드블록 언어 태그, 표 정렬 등

### 학습평가 기계 대조 코드

```python
import re

# `추정값`은 통계 문항의 지문·해설에 나올 수 있어 절 전체에서는 보지 않는다 — 정답 줄에서만 본다(아래)
NOTE_QUIZ_FORBIDDEN = re.compile(
    r'\(추정\)|추정 정답|공식 채점 전|passyn|채점[ \t]*[:：][ \t]*[YN]\b|\*\*정답\*\*[ \t]*[:：]')
NOTE_FENCE = '`' * 3  # 코드 펜스 — 이 문서의 코드블록을 끊지 않도록 리터럴로 쓰지 않는다


def _note_norm(s):
    s = re.sub(r'\s+', ' ', (s or '').replace('**', '').replace('`', '')).strip()
    return s[:-1].rstrip() if s.endswith('.') else s


def _note_quiz_lines(note_md):
    """노트 `## 학습평가` 절을 [(줄, 펜스 안 여부)]로 — 제목이 없으면 None

    문항 지문의 코드블록에 `# 주석`이 있어도 절이 잘리지 않도록 펜스를 추적한다
    (펜스 밖의 `#`/`##`/`---`에서만 끊는다 · ta `quiz_section()`과 같은 기준)
    """
    lines = note_md.split('\n')
    start = next((i + 1 for i, ln in enumerate(lines)
                  if re.match(r'##[ \t]+학습평가[ \t]*$', ln)), None)
    if start is None:
        return None
    out, fence = [], False
    for ln in lines[start:]:
        if ln.lstrip().startswith(NOTE_FENCE):
            out.append((ln, True))          # 펜스 줄 자체도 「펜스 안」으로 친다
            fence = not fence
            continue
        if not fence and re.match(r'(?:#{1,2}[ \t]|---[ \t]*$)', ln):
            break
        out.append((ln, fence))
    return out


def check_note_quiz(note_md, quiz):
    """노트 `## 학습평가` 절을 스크립트 채록본(parse_quiz_capture 결과)과 기계 대조한다

    확인하는 것:
      - 채록본이 준비됨(`quiz['ready']`)이다 — 미준비면 그 사유를 앞에 싣는다(대조 결과만 보고 통과로 적지 않도록)
      - `#### 문제N` 수 = 채록 문항 수 · 번호 1..N (코드블록 안의 줄은 제목·경계로 보지 않는다)
      - `**정답** …` 줄이 문항마다 1개이고 콜론이 없으며 추정·추측·짐작이 없고 공식 정답과 같다
        (객관식은 번호, O/X는 O·X, 주관식은 백틱 안 문자열로 비교)
      - 공식 해설이 있는 문항은 `- 공식 해설 — 「원문」`이 원문과 같다 (공백·끝 마침표·강조 무시)
      - 공식 해설이 없는 문항은 `- 공식 해설이 제공되지 않은 문항 — …` 불릿이 있다
      - 채록본에 공식 해설 판정(원문·없음)이 없는 문항은 「대조 불가」로 싣는다
      - 「(추정)·추정 정답·공식 채점 전·passyn·채점: Y/N·**정답**:」이 절 전체에서 0건이다

    Returns:
        list[str]: 불일치 목록 (빈 목록이면 통과)
    """
    issues = []
    if not quiz['ready']:
        issues += ['채록본 미준비 — ' + p for p in quiz['problems'][:3]]
    sec_lines = _note_quiz_lines(note_md)
    if sec_lines is None:
        return issues + ['노트에 `## 학습평가` 절이 없음']
    sec = '\n'.join(ln for ln, _ in sec_lines)

    for f in NOTE_QUIZ_FORBIDDEN.findall(sec):
        issues.append(f'금지 표기 `{f}`')

    # 문항 분할 — 펜스 밖의 `#### 문제N`에서만 나누고, 블록에는 펜스 밖 줄만 이어 붙인다
    blocks, nums, cur = {}, [], None
    for ln, in_fence in sec_lines:
        if in_fence:
            continue
        hm = re.match(r'####[ \t]*문제[ \t]*(\d+)[ \t]*$', ln)
        if hm:
            cur = int(hm.group(1))
            nums.append(cur)
            blocks[cur] = []
            continue
        if cur is not None:
            blocks[cur].append(ln)
    blocks = {k: '\n'.join(v) for k, v in blocks.items()}
    if nums != list(range(1, len(nums) + 1)):
        issues.append(f'`#### 문제N` 번호가 1..N 연속이 아님 — {nums}')
    if len(nums) != quiz['count']:
        issues.append(f"문항 수 불일치 — 노트 {len(nums)} · 채록 {quiz['count']}")

    for it in quiz['items']:
        b = blocks.get(it['no'])
        if b is None:
            continue
        ans = re.findall(r'(?m)^\*\*정답\*\*[ \t]*(.*)$', b)
        if any(re.search(r'추정|추측|짐작', a) for a in ans):     # ta `guessed`와 같은 기준
            issues.append(f"문제{it['no']}: 정답 줄에 추정")
        if len(ans) != 1:
            issues.append(f"문제{it['no']}: `**정답**` 줄 {len(ans)}개")
        elif not it['official_answer']:
            issues.append(f"문제{it['no']}: 채록본에 공식 정답이 없는데 노트에 정답이 있음")
        else:
            v = ans[0].strip()
            tok = re.match(r'^(\d{1,2})\b', v)
            code = re.search(r'`([^`]+)`', v)
            ox = {'O': 'O', '○': 'O', 'X': 'X', '×': 'X'}.get(v.split(' ')[0])
            if tok and it['answer_no']:
                ok = int(tok.group(1)) == it['answer_no']
            elif ox:
                ok = ox == it['answer_text']
            elif code:
                ok = _note_norm(code.group(1)) == _note_norm(it['answer_text'])
            else:
                ok = _note_norm(v) == _note_norm(it['answer_text'])
            if not ok:
                issues.append(f"문제{it['no']}: 정답 불일치 — 노트 `{v}` · 공식 `{it['answer']}`")
        quotes = re.findall(r'(?m)^-[ \t]*공식 해설[ \t]*—[ \t]*「(.*)」[ \t]*$', b)
        if it['official_explanation'] is not None:
            if not quotes:
                issues.append(f"문제{it['no']}: `- 공식 해설 — 「원문」` 불릿 없음")
            elif _note_norm(quotes[0]) != _note_norm(it['official_explanation']):
                issues.append(f"문제{it['no']}: 공식 해설 원문 불일치")
        elif it['no_official_exp']:
            if not re.search(r'(?m)^-[ \t]*공식 해설이 제공되지 않은 문항', b):
                issues.append(f"문제{it['no']}: `- 공식 해설이 제공되지 않은 문항 — …` 불릿 없음")
        else:
            issues.append(f"문제{it['no']}: 채록본에 공식 해설 판정 없음 — 대조 불가")
    return issues
```

> **실측 (2026-09-17 · 기존 노트 13개, 읽기 전용)** — 통과 5: 빅데이터 1·2·3 · GitHub 2 · 문제해결 3. 지적 — 딥러닝 2·3(옛 문구 「⚠️ 이 문항에는 공식 해설이 없다」 · 3건) · 문제해결 2(공식 해설을 큰따옴표로 인용 · 1건) · 딥러닝 1·문제해결 1(채록본에 공식 정답이 없는데 노트에 정답이 있음 · 3건 / 6건 + 해설 2건). GitHub 1은 정답 12/12가 공식과 같고, 해설은 채록본이 구형이라 대조하지 못한다(0건)
>
> **v1.2.0 수정 후 재측정 (같은 노트 13개)** — 통과 판정 5개(빅데이터 1·2·3 · GitHub 2 · 문제해결 3)와 딥러닝 2·3 · 문제해결 2 지적은 그대로다. **GitHub 1은 채록본 미준비로 지적**된다(미준비 사유 3건 + 해설 판정 없는 문항 「대조 불가」 12건 — 위의 0건은 해설 대조를 조용히 건너뛴 결과였다). 딥러닝 1 · 문제해결 1에도 미준비 사유 3건과 「대조 불가」 문항(3건 / 4건)이 붙는다. 노트 `## 학습평가` 절 안의 코드블록 `# 주석`에서 절이 잘리지 않는다

### 보강 및 최종 저장

검증 중 누락·오류 발견 시:
1. 해당 `##` 섹션에 내용 보강 (기존 내용 삭제 금지)
2. 필요시 시각 자료(8단계) 추가 생성
3. 9단계 절차로 파일 재저장

### 검증 보고

```
✅ 통합 검증 완료
- 교안 반영: ✓ (슬라이드 N장 중 N장 반영)
- 전사 텍스트: ✓ (## (N) 전체 섹션 커버)
- 실습 반영: ✓ / 해당 없음
- 영상 프레임: ✓ (N개 프레임 중 보강 N건 반영 확인)
- 시각 자료: ✓ (N개 PNG, 참조 경로 유효)
- 학습평가: ✓ (채록본 준비됨 · N문항 · 공식 정답 N/N · 공식 해설 M · 없음 K · 추정 0 · 기계 대조 불일치 0) / 해당 없음
- 서식: ✓
- 보강 사항: 없음 / N건 보강 완료
```

## 전체 워크플로우 (상단 표와 동일 — 구현 섹션 `## N단계:` 참조)

```
0. [사전 조건 확인] 전사 완료 + 학습목차 완료 + 학습평가 공식 정답·해설(확인 5) 체크 → 미충족 시 선행 스킬 실행 (학습평가는 confirm-toc 회수)
1. [과목·주차 파악] 과목 폴더 인식 + 주차 번호 확인
2. [파일 탐색] 스크립트/교안/실습 PDF 경로 확보 (NFD 안전 패턴)
3. [스크립트 읽기] 학습목차 파싱 → 노트 골격 확정 + 전사 텍스트 추출
4. [강의교안] PDF → 이미지 변환 + 순차 읽기
5. [실습 PDF] pdfminer 텍스트 추출 (실패 시 이미지 변환 fallback)
6. [영상 프레임 전수 분석] 모든 프레임 읽기 → 분류 → ## (N)별 보강 내용 정리 ← 생략 금지
7. [강의노트 작성] 학습목차 골격 + 5대 소스 종합 (전사 텍스트 = 최우선)
8. [시각 자료 생성] HTML → Playwright → PNG (환경별 폰트 분기, SVG 금지)
9. [파일 저장] NFD 안전 경로 → 강의노트/ 폴더 + img/ 폴더
10. [통합 검증] 교안·전사·실습·영상 프레임과 노트 대조 + 학습평가 기계 대조(check_note_quiz) → 누락 보강 → 최종 저장 ← 생략 금지
```

## 작성 전략

1. **사전 조건 확인 (필수)**: 전사 완료 + 학습목차 완료 + 학습평가 공식 정답·해설 확보 여부 체크. 미충족 시 선행 스킬 먼저 실행 (학습평가는 `confirm-toc` 정답확인 회수)
2. **학습목차 파싱 (필수)**: 스크립트의 학습목차를 파싱하여 `#`/`##`/`---` 골격 생성
3. **전사 텍스트 추출 (필수)**: 순번별 전사 텍스트를 추출하여 본문 작성의 핵심 소스로 사용
4. **학습개요 채우기**: 교안 첫 페이지에서 학습목표/학습내용 추출하여 `## 학습개요` 아래에 배치
5. **본문 섹션 채우기**: 각 `## (N)` 섹션에 대해 **전사 텍스트를 기반으로** 교안 슬라이드 + 실습 코드 + 영상 프레임 종합
6. 강의교안 이미지에서 다이어그램, 표, 시각 자료의 내용을 보충
7. 영상 프레임에서 교안에 없는 판서, 데모, 추가 설명 내용을 포착하여 반영
8. 실습 내용이 있으면 해당 항목 아래에 코드와 설명 추가
9. **필수 섹션 확인**: `# 들어가기`/`## 학습개요`, `# 평가하기`/`## 학습평가`, `# 정리하기`/`## 학습정리` 제목이 모두 있는지 확인 — `## 학습평가`는 문항마다 **공식 정답 + 공식 해설 원문(또는 제공되지 않음 명시)**까지 있는지 확인
10. **시각 자료 생성 검토**: 8단계 기준표에 해당하는 내용을 식별하고, 해당 내용마다 HTML → PNG 다이어그램을 생성하여 노트에 삽입
11. **통합 검증 (10단계)**: 교안·전사·실습·영상 프레임 전체와 강의노트를 대조 → 누락 내용, 순서 오류, 서식 문제 확인 → 보강 후 최종 저장

## 흔한 오류와 해결

| 오류 | 원인 | 해결 |
|------|------|------|
| `No such file or directory` | 경로에 `[`, `]` 포함 | `os.listdir()` + `os.path.join()` 패턴 |
| 한글 폴더/파일명 매칭 실패 | macOS NFD 인코딩 (자모 분리 저장) | `unicodedata.normalize('NFC', name)` 후 비교 |
| Read 도구 토큰 초과 | 스크립트 파일이 너무 큼 | `limit=150` 청크 읽기 |
| 강의교안 내용 추출 실패 | 이미지 기반 슬라이드 | `pdftoppm -png -r 110`으로 변환 후 시각적 읽기 |
| pdfminer 텍스트 추출 실패 | 폰트 임베딩 문제 ("Could not get FontBBox") | `pdftoppm`으로 이미지 변환 fallback (`extract_practice_text` 참조) |
| `pdftoppm: command not found` | poppler 미설치 | 맥 `brew install poppler` · 리눅스 `apt-get install -y poppler-utils` |
| `pdfminer.six` 미설치 | 라이브러리 없음 | `pip install pdfminer.six --break-system-packages` |
| 파일 복사 실패 | workspace 경로 특수문자 | `os.path.join(course_path, ...)` 패턴 |
| 한글 텍스트가 □로 표시 | **VM 등 CJK 폰트 없는 환경** | 8단계 「환경 B」 절차. 맥이라면 `@font-face` 없이 시스템 폰트로 해결된다 |
| Google Fonts CDN / @fontsource 로드 실패 | 네트워크 제한 + npm 설치 불가 | CDN을 쓰지 않는다 — 맥은 시스템 폰트, VM은 로컬 `@font-face` |
| Playwright 미설치 | 라이브러리 없음 | `pip install playwright --break-system-packages` + `playwright install chromium` |
| 영상 프레임 디렉토리 없음 | 프레임 미추출 | **MP4 있으면** 로컬 `ffmpeg`으로 먼저 추출(`extract_frames_ffmpeg()`) · **MP4 없을 때만** 프레임 없이 진행. ⛔ 프레임 목적으로 `extract-video`를 부르지 않는다(유료 전사가 함께 돈다) |
| 학습목차 파싱 실패 | 스크립트에 학습목차 태그 없음 | 교안 목차 또는 사용자 입력으로 제목 구조 확인 |
| **본문(전사·자막 텍스트)이 비어 보임** | ① 제목 파싱이 `## (N)`(공백 1칸)을 못 읽음 ② 자막 미수확 ③ 진짜 미전사 | ①이 가장 흔하다 — 정규식이 `^##[ \t]*\((\d+)\)`인지 확인 · ②는 `confirm-toc`(무료) · ③만 유료 전사이며 **사용자 승인 필수** |
| **학습평가 정답을 추정으로 적음** | 과목·유형에 따라 `[data-field="explanation"]`에 정답 표기가 없음 (문제해결 O/X — 거짓 진술에만 해설 문장) | 해설 유무로 짐작하지 않는다. `confirm-toc`에서 선택 → `.selected` 확인 → 정답확인 후 정답 행(`.passed-answer`/`.failed-answer`)으로 회수 |
| **학습평가 채록본을 못 찾음 / 해설이 원문인지 모름** | 1주차 일부는 `## 학습평가` 대신 목차 아래 `※ 학습평가 채록` 블록이고, 해설이 개조식 불릿이라 공식 원문과 보충이 섞여 있음 | `find_quiz_capture()`가 두 자리를 모두 찾는다. `problems`에 「구형 해설 불릿」이 나오면 해설 원문을 `confirm-toc`로 다시 받는다(채점된 문항은 누르지 않음) |
| **파일 저장 후 사용자 워크스페이스에 안 보임** | **iCloud NFD/NFC 인코딩 불일치** | **`resolve_nfd_path()` 사용 + 저장 후 `ensure_nfd_sync()` 검증** |
| **서브디렉토리(스크립트/, 강의교안/ 등) 못 찾음** | **NFC 하드코딩 경로로 `os.path.isdir()` 실패** | **`resolve_subdir()` 또는 `os.listdir()` 패턴으로 서브디렉토리 해석** |
| **전사 후 경로 무효화** | **MCP 전사 호출이 VM 재시작/마운트 갱신 유발** | **전사 완료 후 `os.listdir()`로 경로 재획득** |
| **파일 저장 후 사용자 워크스페이스에 안 보임** | **iCloud NFD/NFC 인코딩 불일치 — NFC 경로로 Write/Edit 시 별도 고스트 폴더 생성** | **`resolve_nfd_path()` 사용 + 저장 후 `ensure_nfd_sync()` 검증** |
