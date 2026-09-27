---
name: ta
description: >
  학습관리 조교 — 현재 학습 상태를 자동 진단하고 다음에 할 일을 안내하는 스킬.
  사용자가 "오늘 뭐 공부하지", "다음에 뭐 해야 돼", "학습 도와줘", "조교",
  "공부 시작", "뭐부터 하면 돼", "이번 주 할 일" 등을 요청할 때 사용한다.
  사용자가 어떤 커맨드를 써야 할지 몰라도 조교가 현황을 분석해서 구체적인 행동을 제안한다.
version: 0.2.0
---

# 학습관리 조교 (TA) 스킬

사용자가 "뭐 해야 돼?", "공부 시작" 같은 자연어로 말하면, 전체 과목의 학습 상태를 자동 진단하고 **지금 당장 해야 할 구체적인 행동**을 우선순위와 함께 안내한다.

사용자가 어떤 커맨드가 있는지 몰라도 괜찮다. 조교가 알아서 분석하고 제안한다.

## 핵심 원칙

1. **진단 먼저, 제안은 구체적으로** — "공부하세요"가 아니라 "/create-note 머신러닝 3주차" 수준으로 제안
2. **한 번에 1~3개만 제안** — 선택지를 줄여서 행동으로 이어지게
3. **이유를 짧게 설명** — 왜 이걸 먼저 해야 하는지 한 줄로
4. **사용자가 골라서 바로 실행** — "1번 할게" 하면 해당 커맨드를 즉시 실행

## 1단계: 전체 과목 상태 스캔

progress 스킬과 동일한 방식으로 전체 과목을 스캔한다.

```python
import os
import re
import unicodedata
from datetime import datetime

SESSION_BASE = '/sessions/{session_id}'
MNT = os.path.join(SESSION_BASE, 'mnt')
SYSTEM_DIRS = {'uploads', '.claude', '.skills', '.local-plugins',
               '.cowork-lib', '.cowork-perm-req', '.cowork-perm-resp'}

def find_course_folders():
    folders = []
    for item in os.listdir(MNT):
        full = os.path.join(MNT, item)
        if not os.path.isdir(full):
            continue
        if item.startswith('.') or item in SYSTEM_DIRS:
            continue
        folders.append({'name': item, 'path': full})
    return folders

# 주차 번호 — 파일명 고정 패턴을 먼저 본다 (NFC 이름에 적용)
#   `[03주차] 과목.txt` · `03주차-강의노트.md` · `{과목코드}_{주차}_01.mp3` ·
#   `{과목코드}_{주차}_t_03_02_01.mp3`(문제해결 변형) · `[교안]과목_03.pdf`
# ⚠️ 옛 부분 문자열 스캔만 쓰면(w=1부터 첫 일치) `15521541_3_01.mp3`가 `01`에 먼저 걸려 1주차로,
#    `15521541_3_02.mp3`는 2주차로 잡힌다(실물 강의녹음·영상 30개 오배정 — v0.2.0 검증)
WEEK = re.compile(r'\[(\d{1,2})주차\]|^(\d{1,2})주차|_(\d{1,2})_(?:t_)?\d|_(\d{2})\.pdf$')


def week_of(name):
    """파일명에서 주차 번호(1~19)를 읽는다. 못 읽으면 None"""
    nfc = unicodedata.normalize('NFC', name)
    m = WEEK.search(nfc)
    if m:
        w = int(next(g for g in m.groups() if g))
        return w if 1 <= w <= 19 else None
    # 마지막 수단 — 옛 부분 문자열 스캔 (첫 일치). 고정 패턴이 없는 파일명에만 쓴다
    for w in range(1, 20):
        if f'{w:02d}' in nfc or f'_{w}_' in nfc or f'-{w}-' in nfc:
            return w
    return None


def scan_week_status(course_path):
    """주차별 자료 상태를 반환"""
    dirs = {
        '강의교안': ['.pdf'],
        '강의녹음': ['.mp3', '.m4a'],
        '강의영상': ['.mp4'],
        '스크립트': ['.txt'],
        '실습': ['.pdf'],
        '강의노트': ['.md'],
    }
    weeks = {}  # {week_num: {dir_name: True/False, ...}}

    for dir_name, exts in dirs.items():
        dir_path = os.path.join(course_path, dir_name)
        if not os.path.isdir(dir_path):
            continue
        for f in os.listdir(dir_path):
            if not any(f.lower().endswith(ext) for ext in exts):
                continue
            w = week_of(f)
            if w is None:
                continue
            weeks.setdefault(w, {})[dir_name] = True
            # 학습평가 검사(2단계)용으로 강의노트 본문·스크립트 파일 경로를 남긴다
            # iCloud 파일명은 NFD — 비교는 NFC로, 경로는 원본 그대로
            if dir_name == '강의노트' and '강의노트' in unicodedata.normalize('NFC', f):
                weeks[w].setdefault('강의노트_파일', []).append(os.path.join(dir_path, f))
            if dir_name == '스크립트':
                weeks[w].setdefault('스크립트_파일', []).append(os.path.join(dir_path, f))
    return weeks
```

## 2단계: 주차별 상태 판정

각 주차를 아래 상태 중 하나로 분류한다:

| 상태 | 조건 | 다음 액션 |
|------|------|-----------|
| `완료` | 교안 + 스크립트 + 노트 모두 있고, 스크립트 학습평가 채록본이 준비됐으며 노트 학습평가가 채록본과 같음(또는 학습평가 없는 주차) | 복습/퀴즈 제안 |
| `학습평가_정답필요` | 노트는 있지만 **스크립트 채록본이 미준비**(create-note 확인 5 기준 — 정답확인 채점 기록 없음·공식 정답/해설 미확인·추정 표지·문항 수 불일치). 스크립트를 대조할 수 없으면 노트 `## 학습평가`의 추정·미확인·미확보 표기, 정답 줄 누락, 문항 없음 중 하나 이상 | `/confirm-toc` 학습평가 **정답확인 회수**(감시 탭에 `평가하기`가 열려 있어야 함) → 노트 `## 학습평가` 절만 공식 정답·공식 해설로 갱신 |
| `학습평가_노트갱신` | 스크립트 채록본은 준비됐는데 노트 `## 학습평가`가 채록본과 다름(create-note 10단계 `check_note_quiz` 불일치 — 정답·해설 인용·서식) | `/create-note` 10단계 보강 — 노트 `## 학습평가` 절만 스크립트 채록본으로 갱신(`- 공식 해설 — 「원문」` / `- 공식 해설이 제공되지 않은 문항 — …` 서식). **강의실 불필요** |
| `노트_필요` | 교안 + 스크립트 있지만 노트 없음 | `/create-note` |
| `스크립트_필요` | 녹음/영상 있지만 스크립트 없음 | ⭐ **`/confirm-toc` 먼저** (자막 수확 · 학습평가 회수 · 무료 · 정본) → 자막 없는 항목만 `/transcribe` 또는 `/extract-video` |
| `자료_대기` | 교안만 있거나 녹음 없음 | 예습(`/preview`) 가능, 노트 작성은 대기 |
| `미시작` | 아무 자료도 없음 | 자료 업로드 안내 |

> ⭐ **파일 존재만으로 `완료`를 주지 않는다** (v0.2.0) — 학습평가 정답을 해설 유무 패턴으로 짐작해 「(추정)」으로 적은 노트(2026-09-17 문제해결프로그래밍입문 3주차)가 파일 기준으로는 `완료`였다. 학습평가는 **항상 `정답확인`으로 공식 정답·공식 해설을 회수**해 노트에 넣는 것이 정책이다(2026-09-17 사용자 상시 정책)
>
> - 검사 대상은 **노트** `## 학습평가` 절이다. 노트가 없는 주차의 스크립트 채록본은 `create-note` 0단계 확인 5가 검사한다
>   - **노트가 있는 주차는 스크립트 채록본과 함께 대조한다**(create-note 3-C·10단계 함수 재사용 — `script_quiz_verdict()`) — 채록본 미준비면 `학습평가_정답필요`, 채록본은 준비됐는데 노트가 다르면 `학습평가_노트갱신`
>   - 함수는 create-note `SKILL.md`에서 불러 쓴다(`load_create_note_quiz()` — 3-B `iter_body_sections` · 3-C 전체 · 10단계 `check_note_quiz` 블록). ⛔ **ta에 복사본을 두지 않는다** — 기준이 갈라지면 두 스킬의 결론이 어긋난다
>   - `TA_SKILL_DIR`에는 스킬을 불러올 때 표시되는 기본 디렉터리(`Base directory for this skill`)를 넣는다 — create-note는 그 옆 `../create-note/SKILL.md`다
>   - ⚠️ 노트 표지만 보면 **표지 없이 자작 정답을 적은 노트를 못 잡는다** — v0.2.0 검증에서 딥러닝 1주차·문제해결 1주차(채록본에 채점 기록 없음)와 GitHub 1주차(해설 원문 구분 불가)가 `완료`로 나왔고, 같은 주차를 create-note는 미준비로 판정했다
> - `## 학습평가` 절이 없는 노트(`# 평가하기`가 없는 주차 — AWS)는 해당 없음
> - **보조 경로** — 스크립트가 없거나 읽지 못했거나 create-note 함수를 불러오지 못하면 노트 단독 표지 검사(`quiz_answer_issues()`)로 대체하고, 로드 실패는 `확인불가`에 적는다
>   - 판정 문자열은 절 전체에서 **표지 자리에 선 `추정`**(`(추정)` · `추정 —` · 줄 끝) · `추정함/했/하였/으로 판단` · `추측` · `짐작` · `미확인` · `미확보` · `공식 채점 전`, 정답 줄에서는 **`추정`·`추측`·`짐작`이 들어간 모든 형태**(`추정값` 포함)다
>   - **공식 해설 인용 줄**(`- 공식 해설 — 「…」`)과 **`#### 문제N` 바로 다음 지문 문단**은 과목 내용이라 표지 검사에서 뺀다 — 통계 용어(`점추정`·`추정량`·「통계적 추정 방법」)와 원문 속 「미확인」 오탐 방지
>   - ⚠️ 남는 오탐 — 내 불릿의 「모수 추정 — …」 같은 통계 용어는 의도된 `추정 —` 표지와 구분할 수 없다. 판정 사유를 보여 주어 사용자가 알아보게 한다(아래). 주 경로(채록본 대조)에서는 생기지 않는다
> - 판정 사유(`week_data['학습평가_문제']` — 앞 3건 + 나머지 건수)를 제안 메시지에 그대로 보여 준다 — 오탐이면 사용자가 바로 알아본다
> - 읽지 못한 노트·스크립트(iCloud 오프로드 등)는 결함으로 치지 않고 `week_data['확인불가']`로 따로 알린다 — Finder에서 열어 내려받은 뒤 다시 진단한다
> - **실측 (2026-09-17 · 5과목 실물, 읽기 전용)** — `학습평가_정답필요` = 딥러닝 1 · 문제해결 1 · GitHub 1 / `학습평가_노트갱신` = 딥러닝 2·3 · 문제해결 2 / `완료` = 빅데이터 1·2·3 · GitHub 2 · 문제해결 3 · AWS 1·2. 주차 번호 고정 패턴으로 교안·녹음·영상·스크립트·노트 271개 오배정 0건

```python
import os
import re

# ── ① 주 경로 — 스크립트 채록본 대조 (create-note 3-C·10단계 함수를 그대로 불러 쓴다) ──
# ⛔ ta에 복사본을 두지 않는다 — 판정 기준이 갈라지면 두 스킬의 결론이 어긋난다
#    (v0.2.0 검증: 노트 표지만 본 ta는 딥러닝·문제해결·GitHub 1주차를 `완료`로, create-note는 미준비로 판정했다)
# ta 스킬의 기본 디렉터리 — 스킬을 불러올 때 표시되는 「Base directory for this skill」 값을 넣는다
TA_SKILL_DIR = '{ta 스킬 기본 디렉터리}'
CN_QUIZ_NAMES = ('iter_body_sections', 'find_quiz_capture', 'parse_quiz_capture', 'check_note_quiz')
FENCE = '`' * 3  # 코드 펜스 — 이 문서의 코드블록을 끊지 않도록 리터럴로 쓰지 않는다
_CN_QUIZ = {}


def load_create_note_quiz(skill_dir=None):
    """create-note SKILL.md의 3-B `iter_body_sections` · 3-C 전체(`find_quiz_capture`·`parse_quiz_capture`) ·
    10단계(`NOTE_QUIZ_FORBIDDEN`·`_note_norm`·`check_note_quiz`) 블록을 한 네임스페이스에서 실행해 돌려준다

    Returns: dict(네임스페이스) · 실패(파일 없음·`TA_SKILL_DIR` 미설정·실행 오류)면 None → 노트 단독 검사로 대체
    """
    base = skill_dir or TA_SKILL_DIR
    if '{' in base:
        return None
    path = os.path.normpath(os.path.join(base, '..', 'create-note', 'SKILL.md'))
    if path in _CN_QUIZ:
        return _CN_QUIZ[path]
    ns = {'__name__': 'create_note_quiz'}
    want = re.compile(r'^def (?:' + '|'.join(CN_QUIZ_NAMES) + r')\b', re.M)
    try:
        with open(path, encoding='utf-8') as fh:
            src = fh.read()
        for block in re.findall(FENCE + r'python\n(.*?)' + FENCE, src, re.S):
            if want.search(block):
                exec(compile(block, path, 'exec'), ns)
        if not all(callable(ns.get(n)) for n in CN_QUIZ_NAMES):
            ns = None
    except Exception:
        ns = None
    _CN_QUIZ[path] = ns
    return ns


def script_quiz_verdict(week_data, skill_dir=None):
    """스크립트 학습평가 채록본과 노트를 create-note 기준(확인 5 · 10단계)으로 대조한다

    Returns:
        None                       — 대조 불가(스크립트 없음·읽기 실패·함수 로드 실패) → 노트 단독 검사로 대체
        ('해당없음', [])            — 목차에 `## 학습평가`가 없다 (AWS 등)
        ('학습평가_정답필요', 사유)  — 채록본 미준비 → 강의실에서 정답확인 회수
        ('학습평가_노트갱신', 사유)  — 채록본은 준비됐는데 노트가 채록본과 다르다 → 강의실 불필요
        ('통과', [])
    """
    scripts = week_data.get('스크립트_파일', [])
    if not scripts:
        return None
    cn = load_create_note_quiz(skill_dir)
    if cn is None:
        week_data.setdefault('확인불가', []).append(
            'create-note 학습평가 함수 로드 실패(TA_SKILL_DIR 확인) — 노트 단독 검사로 대체')
        return None
    cap, read_any = None, False
    for path in scripts:
        try:
            with open(path, encoding='utf-8') as fh:
                text = fh.read()
        except OSError:
            week_data.setdefault('확인불가', []).append(os.path.basename(path))
            continue
        read_any = True
        cap = cn['find_quiz_capture'](text)
        if cap is not None:
            break
    if not read_any:
        return None
    if cap is None:
        return ('해당없음', [])
    quiz = cn['parse_quiz_capture'](cap['text'], cap['declared'])
    if not quiz['ready']:
        return ('학습평가_정답필요', ['채록본 미준비 — ' + p for p in quiz['problems']])
    issues = []
    for path in week_data.get('강의노트_파일', []):
        try:
            with open(path, encoding='utf-8') as fh:
                issues += cn['check_note_quiz'](fh.read(), quiz)
        except OSError:
            week_data.setdefault('확인불가', []).append(os.path.basename(path))
    if issues:
        return ('학습평가_노트갱신', issues)
    return ('통과', [])


def _brief(reasons, n=3):
    """제안 메시지용 — 앞 n건 + 나머지 건수"""
    return reasons[:n] + ([f'… 외 {len(reasons) - n}건'] if len(reasons) > n else [])


# ── ② 보조 경로 — 노트 단독 표지 검사 (스크립트를 대조할 수 없을 때만) ──
# 노트 학습평가 절의 결함 표기 (정답 줄 밖에서도 결함으로 보는 것)
# 맨 `추정`은 앞뒤에 한글이 붙지 않고 표지 자리(`(추정)` · `추정 —` · 줄 끝)에 선 것만 —
# 점추정·추정량·추정값·「통계적 추정 방법」 같은 통계 용어 오탐 방지
QUIZ_FLAG = re.compile(
    r'(?m)(?<![가-힣])추정(?![가-힣])(?=\s*[)\]—]|$)'
    r'|추정(?:함|했|하였|으로 판단)|추측|짐작|미확인|미확보|공식 채점 전')
# 과목 내용 줄 — 표지 검사에서 뺀다 (공식 해설 인용 줄 · `#### 문제N` 바로 다음 지문 문단)
OFFICIAL_QUOTE = re.compile(r'^-[ \t]*공식 해설[ \t]*—[ \t]*「.*」[ \t]*$')
# `**정답** O` · `**정답**: O` · `**정답:** O` 모두 받는다
ANSWER_LINE = re.compile(r'(?m)^\*\*정답[:：]?\*\*[:：]?[ \t]*(.*)$')
QUESTION_HEAD = re.compile(r'(?m)^#{3,4}[ \t]*문제[ \t]*\d+')


def quiz_section(note_text):
    """노트의 `## 학습평가` 절 본문. 제목이 없으면 None
    코드블록 안의 `# 주석` 줄을 절 경계로 오인하지 않도록 펜스를 추적한다"""
    lines = note_text.splitlines()
    start = next((i + 1 for i, ln in enumerate(lines)
                  if re.match(r'##[ \t]+학습평가[ \t]*$', ln)), None)
    if start is None:
        return None
    out, fence = [], False
    for ln in lines[start:]:
        if ln.lstrip().startswith(FENCE):
            fence = not fence
        elif not fence and re.match(r'(?:#{1,2}[ \t]|---[ \t]*$)', ln):
            break
        out.append(ln)
    return '\n'.join(out)


def _strip_quiz_content(sec):
    """표지 검사용 — 공식 해설 인용 줄과 `#### 문제N` 바로 다음 지문 문단(빈 줄까지)을 뺀다"""
    out, in_stem, started = [], False, False
    for ln in sec.split('\n'):
        if QUESTION_HEAD.match(ln):
            out.append(ln)
            in_stem, started = True, False
            continue
        if in_stem:
            if ANSWER_LINE.match(ln):          # 지문 없이 정답 줄이 바로 오면 지문 구간 끝
                in_stem = False
            elif not ln.strip():
                in_stem = not started
                continue
            else:
                started = True
                continue
        if OFFICIAL_QUOTE.match(ln):
            continue
        out.append(ln)
    return '\n'.join(out)


def quiz_answer_issues(note_text):
    """노트 학습평가 절의 공식 정답 결함 목록 (보조 경로). 절이 없으면 [] (해당 없음)"""
    sec = quiz_section(note_text)
    if sec is None:
        return []
    issues = []
    n_q = len(QUESTION_HEAD.findall(sec))
    answers = [a.strip() for a in ANSWER_LINE.findall(sec)]
    if n_q == 0:
        issues.append('문항 없음(학습평가 미채록)')
    if len(answers) < n_q:
        issues.append(f'정답 줄 누락 {n_q - len(answers)}건')
    empty = sum(1 for a in answers if not a)
    if empty:
        issues.append(f'빈 정답 줄 {empty}건')
    guessed = sum(1 for a in answers if re.search(r'추정|추측|짐작', a))
    if guessed:
        issues.append(f'정답 줄에 추정 {guessed}건')
    flags = sorted(set(QUIZ_FLAG.findall(_strip_quiz_content(sec))))
    if flags:
        issues.append('추정·미확인 표기: ' + ', '.join(flags))
    return issues


def classify_week(week_data):
    has_pdf = week_data.get('강의교안', False)
    has_audio = week_data.get('강의녹음', False) or week_data.get('강의영상', False)
    has_script = week_data.get('스크립트', False)
    has_note = week_data.get('강의노트', False)
    has_practice = week_data.get('실습', False)

    if has_note:
        # ① 주 경로 — 스크립트 채록본과 대조 (create-note 확인 5 · 10단계와 같은 결론)
        verdict = script_quiz_verdict(week_data)
        if verdict is not None:
            state, reasons = verdict
            if state in ('학습평가_정답필요', '학습평가_노트갱신'):
                week_data['학습평가_문제'] = _brief(reasons)
                return state
        else:
            # ② 보조 경로 — 스크립트가 없거나 대조할 수 없을 때만 노트 단독 표지 검사
            issues = []
            for path in week_data.get('강의노트_파일', []):
                try:
                    with open(path, encoding='utf-8') as fh:
                        issues += quiz_answer_issues(fh.read())
                except OSError:
                    # iCloud 오프로드 등 — 판정 불가로 기록하고 결함으로 치지 않는다
                    week_data.setdefault('확인불가', []).append(os.path.basename(path))
            if issues:
                week_data['학습평가_문제'] = issues
                return '학습평가_정답필요'

    if has_pdf and has_script and has_note:
        return '완료'
    elif has_pdf and has_script and not has_note:
        return '노트_필요'
    elif has_audio and not has_script:
        return '스크립트_필요'
    elif has_pdf and not has_audio:
        return '자료_대기'
    else:
        return '미시작'
```

## 3단계: 우선순위 결정

아래 순서로 우선순위를 매긴다:

### 우선순위 규칙 (높은 것부터)

1. **노트 작성 가능한데 안 한 것** (`노트_필요`) — 자료가 다 있으니 바로 할 수 있음
   - **같은 급: 학습평가 공식 정답이 빠진 노트** (`학습평가_정답필요`) — 노트가 있어도 정답이 공식값이 아니면 미완성이다. 강의실 세션(로그인된 크롬)이 필요하다 — 완료 주차는 `/confirm-toc`가 강의실에 들어가 `평가하기`를 직접 열어 회수하므로 바로 제안한다. 미완료 주차는 사용자 수강으로 `평가하기`에 도달한 뒤라야 회수된다
   - **같은 급: 노트 학습평가가 채록본과 다른 주차** (`학습평가_노트갱신`) — 공식 정답·해설은 이미 스크립트에 있으므로 **강의실 없이** 노트 `## 학습평가` 절만 고치면 된다. 가장 빨리 끝나는 일이라 같은 급 안에서는 먼저 제안해도 된다
2. **스크립트 변환이 필요한 것** (`스크립트_필요`) — `/confirm-toc`(자막·학습평가) 후 노트 작성 가능
3. **최근 완료된 주차의 복습** (`완료` 상태인데 복습 안 한 것) — 망각 곡선 고려
4. **다음 수업 예습** — 아직 자료만 올라온 주차
5. **시험 대비** — 시험 기간이 가까우면 우선순위 상승

### 같은 우선순위 안에서의 정렬

- 낮은 주차 > 높은 주차 (밀린 것부터)
- 여러 과목이면 가장 뒤처진 과목 먼저

## 4단계: 제안 메시지 작성

### 메시지 형식

상태 진단 결과를 간단히 보여주고, 구체적 행동을 1~3개 제안한다.

```markdown
## 📋 학습 현황 요약

| 과목 | 진행 | 다음 할 일 |
|------|------|-----------|
| 머신러닝 | 3/5주차 완료 | 4주차 노트 작성 |
| 파이썬데이터분석 | 2/4주차 완료 | 3주차 스크립트 준비 |
| 빅데이터기초수학 | 4/5주차 완료 | 2주차 학습평가 정답 회수 |
| ... | ... | ... |

## 🎯 지금 추천하는 작업

**1. 머신러닝 4주차 강의노트 작성** ⭐ 가장 급함
- 스크립트와 교안이 준비되어 있어서 바로 노트 작성 가능
- 실행: `/create-note 머신러닝 4주차`

**2. 빅데이터기초수학 2주차 학습평가 공식 정답 회수** ⭐ 같은 급
- 스크립트 채록본 미준비 — `정답확인 채점 기록 없음` — 공식 정답이 아니면 노트가 미완성
- 감시 탭에서 그 주차 `평가하기`를 열어 두면(또는 여는 것을 지시하면) `정답확인`으로 공식 정답·해설을 회수하고 노트 학습평가 절만 고침
- 실행: `/confirm-toc 빅데이터기초수학 2주차`

(노트만 채록본과 다른 주차라면 — `학습평가_노트갱신`)
- 노트 학습평가가 스크립트 채록본과 다름 — `문제2: - 공식 해설 — 「원문」 불릿 없음` — 강의실 불필요
- 실행: `/create-note 빅데이터기초수학 2주차` (10단계 보강 — 노트 `## 학습평가` 절만 갱신)

**3. 파이썬데이터분석 3주차 스크립트 준비**
- MP3가 올라와 있는데 스크립트가 없음 — 자막을 먼저 수확하고(무료) 자막 없는 항목만 전사(유료)
- 실행: `/confirm-toc 파이썬데이터분석 3주차`

> 번호로 선택하거나, 다른 작업을 말씀해 주세요!
```

## 5단계: 사용자 선택 → 즉시 실행

사용자가 "1번", "1", "첫 번째" 등으로 응답하면:
- 해당 작업의 커맨드를 자동으로 실행
- 예: "1번 할게" → `/create-note 머신러닝 4주차` 실행

사용자가 자유 텍스트로 응답해도 의도를 파악하여 적절한 커맨드로 연결:
- "복습하고 싶어" → 완료된 주차 중 가장 오래된 것으로 `/review`
- "퀴즈 풀자" → 완료된 주차 중 하나로 `/quiz`
- "시험 준비" → `/exam-summary` 또는 `/study-plan` 안내

## 요일별 기본 추천 패턴

강의 자료가 보통 **월요일에 오픈**된다는 가정 하에:

| 요일 | 기본 추천 |
|------|-----------|
| 월·화 | 새 주차 자료 처리 (confirm-toc(목차·자막·학습평가) → 자막 없는 항목만 transcribe → prepare-script → create-note) |
| 수·목 | 밀린 노트 작성 + 이번 주 복습 |
| 금 | 퀴즈·플래시카드로 정리 |
| 토·일 | 다음 주 예습 + 전체 진도 점검 |

이 패턴은 참고용이며, 실제 자료 상태가 우선한다.

## 전체 워크플로우

```
1. 전체 과목 폴더 스캔 (progress 로직 활용)
2. 주차별 상태 판정 (완료/학습평가정답필요/학습평가노트갱신/노트필요/스크립트필요/자료대기/미시작)
   — 학습평가는 스크립트 채록본과 노트를 create-note 기준으로 대조 (대조 불가 시 노트 단독 표지 검사)
3. 우선순위 결정 (밀린 작업 > 복습 > 예습)
4. 현황 요약 + 구체적 행동 1~3개 제안
5. 사용자 선택 시 해당 커맨드 즉시 실행
```

## 대화 예시

```
사용자: 오늘 뭐 공부하지?
조교: [전체 스캔 결과 + 추천 3개 제시]

사용자: 1번
조교: [해당 커맨드 실행]

사용자: 끝났어, 다음은?
조교: [업데이트된 상태로 다음 추천]
```
