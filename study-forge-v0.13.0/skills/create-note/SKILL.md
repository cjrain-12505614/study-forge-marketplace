---
name: create-note
description: >
  강의 스크립트(TXT), 강의교안(PDF), 실습(PDF/ipynb), 영상 프레임을 종합하여 체계적인 마크다운 강의노트를 작성하는 스킬.
  반드시 사전 조건(영상 처리·전사·학습목차 정리)이 완료된 상태에서 실행해야 한다.
  사용자가 "강의노트 작성해줘", "X주차 강의노트 만들어줘", "강의 내용 정리해줘", "create-note" 등을
  요청하거나, 스크립트/교안/실습 자료를 언급하며 정리를 요청할 때 사용한다.
  강의교안 PDF는 이미지로 변환 후 시각적으로 읽고, 실습은 ipynb(Read 직접)과 PDF(pdfminer/Read) 모두 지원한다.
  영상 MP4가 있으면 ffmpeg 프레임 추출 후 전수 분석이 필수이다.
  시각화가 효과적인 내용은 HTML → Playwright → PNG로 다이어그램을 생성하여 노트에 삽입한다.
  실행 환경(맥 네이티브 / VM)에 따라 폰트·PDF 변환 방식이 다르다 (v0.10.0).
version: 0.10.0
---

# 강의노트 작성 스킬

스크립트(TXT), 강의교안(PDF), 실습(PDF), 영상 프레임 — **5대 필수 참조 자료**를 종합해 체계적인 마크다운 강의노트를 작성한다. 텍스트만으로 설명하기 어려운 내용은 시각 자료(다이어그램/도표)를 생성하여 삽입한다.

> ## ⚠️ 필수: 아래 0~10단계를 반드시 순서대로 모두 수행할 것
>
> **단계를 건너뛰거나 순서를 바꾸면 안 된다.** 각 단계의 상세 지침은 아래 `## N단계:` 섹션에 있다.
>
> | 단계 | 작업 | 핵심 |
> |------|------|------|
> | **0** | 사전 조건 확인 | 전사 완료 + 학습목차 완료 체크. 이미 완료된 전처리는 재실행 금지 |
> | **1** | 과목 폴더 인식 + 주차 파악 | `os.listdir()` + `nfc()` NFD 안전 패턴 |
> | **2** | 파일 탐색 | 스크립트/교안/실습 PDF 경로 확보 (특수문자 경로 안전 처리) |
> | **3** | 스크립트 TXT 읽기 | 학습목차 파싱 → 노트 `#`/`##` 골격 확정 + 전사 텍스트 추출 |
> | **4** | 강의교안 PDF → 이미지 변환 + 읽기 | `pdftoppm -r 110`, 10~15페이지씩 Read |
> | **5** | 실습 PDF 텍스트 추출 | `pdfminer` (실패 시 이미지 변환 fallback) |
> | **6** | **영상 프레임 전수 분석** | **모든 프레임** 읽기 → 분류 → `##(N)`별 보강 내용 정리 |
> | **7** | 강의노트 작성 | 학습목차 골격 + 5대 소스 종합 (전사 텍스트 = 최우선) |
> | **8** | 시각 자료 생성 | HTML → Playwright → PNG (환경별 폰트 분기, SVG 금지) |
> | **9** | 파일 저장 | NFD 안전 경로로 `강의노트/` 폴더에 저장 + `img/` 폴더에 PNG 복사 |
> | **10** | **통합 검증** | 교안·전사·실습·영상 프레임 전체와 노트 대조 → 누락·오류 보강 → 최종 저장 |
>
> **특히 6단계(영상 프레임 전수 분석)와 10단계(통합 검증)를 절대 생략하지 않는다.**
> 진행 상황을 사용자에게 **"[N단계] 작업명 진행 중..."** 형식으로 반드시 알려주며 수행한다.

## 시작 전 필수

1. 워크스페이스 `CLAUDE.md`와 **과목 폴더 `CLAUDE.md`**를 읽는다
2. 같은 종류의 **기존 산출물(기존 주차 강의노트)을 열어 형식을 확인**한다 — 제목 스타일·표 사용·이미지 배치가 과목마다 다르다
3. 확인할 수 없는 값은 **비워 두고 채울 방법을 안내**한다 — 그럴듯한 추정값 금지

## 필수 참조 자료 (5대 소스)

| # | 소스 | 설명 | 우선순위 |
|---|------|------|----------|
| 1 | 스크립트 TXT — 전사 텍스트 (##(N) 아래) | 강사의 실제 설명. 교안에 없는 보충 설명·예시·맥락이 담김 | **최우선** |
| 2 | 스크립트 TXT — 학습목차 | 강의노트의 #/## 제목 구조와 --- 위치를 확정 | 필수 |
| 3 | 강의교안 PDF | 슬라이드 레이아웃, 다이어그램, 표, 학습목표 등 시각 정보 | 필수 |
| 4 | 실습 PDF | 실습 코드, 실행 결과, 과제 설명 | 있으면 필수 |
| 5 | 영상 프레임 | 교안에 없는 판서, 데모, 추가 설명 화면 | 있으면 필수 |

> **전사 텍스트가 본문의 핵심 소스이다.** 강사가 실제로 한 설명이므로 교안에 없는 보충 설명·예시·맥락이 담겨 있다. 전사 텍스트 없이 강의노트를 작성하면 교안 요약에 불과하므로, 반드시 전사가 완료된 상태에서 시작해야 한다.

## 사전 조건 — 반드시 확인 (필수)

create-note를 실행하기 전에 아래 조건이 **모두 충족**되어야 한다. 하나라도 미충족이면 해당 선행 스킬을 먼저 실행하고 돌아온다.

### 확인 1: 오디오 전사 완료

스크립트 TXT의 `<강의녹음 스크립트>` 구역에서 `##(N)` 아래에 전사 텍스트가 있어야 한다.

- **완료 판단**: `##(N)` 바로 아래에 텍스트가 존재
- **미완료 판단**: `##(N)` 아래가 비어있거나 바로 다음 `##`이 옴
- **미완료 시 조치**: `extract-video` 또는 `transcribe` 스킬을 먼저 실행

### 확인 2: 학습목차 완료

스크립트 TXT의 `<학습목차>` 구역에 `#`/`##` 헤더가 구조화되어 있어야 한다.

- **완료 판단**: `<학습목차>` 구역에 `#제목`, `##서브제목` 패턴이 존재
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

### 사전 조건 확인 코드

```python
import re

def check_prerequisites(script_content):
    """create-note 실행 전 사전 조건 확인

    Returns:
        dict: {
            'outline_ready': bool,   # 학습목차 완료 여부
            'transcripts_ready': bool,  # 전사 텍스트 완료 여부
            'missing': list          # 미충족 항목 목록
        }
    """
    result = {'outline_ready': False, 'transcripts_ready': False, 'missing': []}

    # 확인 1: 학습목차
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

    # 확인 2: 전사 텍스트
    script_match = re.search(r'<[^>]+강의녹음\s*스크립트>', script_content)
    if script_match:
        after_script = script_content[script_match.end():]
        # ##(N) 아래에 텍스트가 있는지 확인
        sections = re.split(r'##\((\d+)\)[^\n]*\n', after_script)
        has_text = False
        for i in range(2, len(sections), 2):
            text = sections[i].strip() if i < len(sections) else ''
            if len(text) > 10:  # 의미 있는 텍스트가 있는지
                has_text = True
                break
        result['transcripts_ready'] = has_text
    if not result['transcripts_ready']:
        result['missing'].append('전사 텍스트 (extract-video 또는 transcribe 스킬 실행 필요)')

    return result
```

**사전 조건이 미충족인 경우:**
1. 해당 선행 스킬(extract-video, transcribe, prepare-script)을 자동 실행한다
2. 사용자에게 "먼저 실행할까요?"라고 묻지 않는다 — 파일 상태로 판단하면 충분

**사전 작업이 이미 완료된 경우 (중요):**
- 스크립트 TXT에 `##(N)` 아래 전사 텍스트가 이미 있으면 → extract-video/transcribe **절대 재실행하지 않음**
- 학습목차가 이미 구조화되어 있으면 → prepare-script **절대 재실행하지 않음**
- 사용자가 "오디오 추출/전사/스크립트 정리 끝남"이라고 명시하면 → 해당 단계 **절대 재실행하지 않음**
- 사용자가 명시적으로 "다시 해줘"라고 요청하는 경우에만 재실행
- 이미 완료된 전처리를 재실행하면 수 분~수십 분의 시간 낭비 + 기존 결과물 덮어쓰기 위험

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
        elif stripped.startswith('##'):
            title = stripped[2:]
            # ##(N)제목 패턴
            m = re.match(r'\((\d+)\)(.+)', title)
            if m:
                structure.append({
                    'type': 'h2_numbered',
                    'num': int(m.group(1)),
                    'text': m.group(2)
                })
            else:
                structure.append({'type': 'h2', 'text': title})
        elif stripped.startswith('#'):
            title = stripped[1:]
            structure.append({'type': 'h1', 'text': title})

    return structure
```

### 학습목차 → 강의노트 제목 변환 규칙

학습목차의 각 항목은 아래 규칙에 따라 강의노트의 마크다운 헤더로 변환된다:

| 학습목차 항목 | 강의노트 마크다운 | 설명 |
|---|---|---|
| `#제목` | `# 제목` | 최상위 헤더 (H1) |
| `##서브제목` | `## 서브제목` | 서브 헤더 (H2) |
| `##(N)서브제목` | `## 서브제목` | 서브 헤더, (N)은 영상 순번 (노트 제목에는 번호 제외) |
| `---` | `---` | `#` 타이틀 그룹 간 가로선 |

### 필수 섹션 (내용이 없어도 제목은 반드시 작성)

아래 섹션은 대응하는 영상 자료가 없더라도 강의노트에 **제목을 반드시 포함**해야 한다:
- `# 들어가기` → `## 학습개요` (학습목표, 학습내용 등 교안에서 추출)
- `# 평가하기` → `## 학습평가` (**내용까지 채운다** — 아래 「학습평가·학습정리」 참조)
- `# 정리하기` → `## 학습정리` (**내용까지 채운다**)

### 예시: 학습목차 → 강의노트 골격

학습목차:
```
#들어가기
##학습개요
---
#pandas 데이터 형태 이해
##(1)pandas 데이터 형태 이해 실습
---
#테이블 데이터의 입출력
##(2)테이블 데이터의 입출력 실습
---
#평가하기
##학습평가
---
#정리하기
##학습정리
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

## pandas 데이터 형태 이해 실습

- (전사 텍스트 + 교안 + 실습 내용을 종합하여 작성)

---

# 테이블 데이터의 입출력

## 테이블 데이터의 입출력 실습

- (전사 텍스트 + 교안 + 실습 내용을 종합하여 작성)

---

# 평가하기

## 학습평가

(교안의 평가 문항이 있으면 기록)

---

# 정리하기

## 학습정리

(교안의 정리 내용이 있으면 기록)
```

**핵심: 학습목차에 정의된 `#`/`##` 제목 순서와 `---` 위치를 정확히 따른다. 임의로 제목을 추가/삭제/변경하지 않는다.**

### 3-B: 전사 텍스트 추출

스크립트 TXT의 `<강의녹음 스크립트>` 구역에서 `##(N)` 별 전사 텍스트를 추출한다. 이 텍스트가 강의노트 본문의 **핵심 소스**이다.

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
    sections = re.split(r'##\((\d+)\)[^\n]*\n', after)

    transcripts = {}
    for i in range(1, len(sections), 2):
        seq = int(sections[i])
        text = sections[i + 1].strip() if i + 1 < len(sections) else ''
        if text:
            transcripts[seq] = text

    return transcripts
```

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
| **판서·화이트보드** | 강사가 별도로 적은 설명, 공식, 그림 | **보강 내용으로 추출** → 해당 `##(N)` 섹션에 반영 |
| **데모·실행 화면** | 코드 실행 결과, 소프트웨어 조작 화면 | **보강 내용으로 추출** → 실습 섹션에 반영 |
| **추가 설명 화면** | 교안에 없는 별도 자료, 웹페이지, 참고 화면 | **보강 내용으로 추출** → 관련 섹션에 반영 |
| 전환 화면·로딩 | 의미 없는 전환 장면 | 무시 |

3. 추출된 보강 내용을 **`##(N)` 순번별로 정리**해 둔다

### 6-C: 보강 내용 정리 형식

프레임 분석 결과를 7단계(강의노트 작성)에서 바로 활용할 수 있도록 정리한다:

```
[영상 프레임 보강 내용]

##(1) - 해당 없음 (교안 슬라이드만)
##(2) - 판서: "정규화 3단계를 도식으로 그려 설명" → 1NF→2NF→3NF 흐름도
##(3) - 데모: "MySQL에서 실제 테이블 생성 후 정규화 적용" → 실습 코드+결과
##(5) - 추가 화면: "실무에서의 반정규화 사례" → 교안에 없는 보충 설명
...
```

이 정리본이 7단계에서 각 `##(N)` 섹션 내용을 채울 때 **4번째 소스**(전사→교안→실습→**영상 프레임 보강**)로 사용된다.

### 프레임이 없는 경우

프레임 디렉토리가 없으면(extract-video 미실행) 이 단계를 건너뛰고 교안+전사+실습만으로 진행한다. 단, 사용자에게 "영상 프레임 없이 진행합니다"를 안내한다.

## 7단계: 강의노트 작성

### 제목 구조 — 학습목차 기반 (필수)

**강의노트의 `#`/`##` 헤더와 `---` 가로선은 스크립트의 학습목차에서 확정된 구조를 그대로 따른다.** 3-A단계에서 파싱한 학습목차 구조를 강의노트의 뼈대로 사용하고, 각 섹션 아래에 내용을 채운다.

### 내용 채우기 전략 — 우선순위 기반

각 `##(N)` 대응 섹션에 내용을 채울 때 아래 우선순위를 따른다:

| 우선순위 | 소스 | 역할 |
|----------|------|------|
| **1 (최우선)** | 전사 텍스트 (##(N)) | 강사의 실제 설명 — 본문의 뼈대. 교안에 없는 보충 설명·예시·맥락 포함 |
| 2 | 강의교안 PDF | 시각 자료, 다이어그램, 표, 핵심 키워드 보충 |
| 3 | 실습 PDF | 코드, 실행 결과, 실습 과제 |
| 4 | 영상 프레임 | 판서, 데모 화면, 교안에 없는 추가 설명 |

**작성 원칙:**
- `## 학습개요` → 강의교안 첫 페이지에서 학습목표와 학습내용 추출
- `##(N)` 대응 섹션 → **전사 텍스트를 기반으로** 교안 슬라이드 + 실습 코드 + 영상 프레임을 종합
- `## 학습평가`·`## 학습정리` → **제목만 남기지 않는다.** 아래 참조

#### ⚠️ 학습평가·학습정리는 내용까지 채운다

**제목만 있고 비어 있는 노트는 미완성이다.** 기존 노트 중에 이 두 구역이 빈 것이 있어도 **따라 하지 말 것** — 그건 정본이 아니라 누락이다.

두 구역은 **MP3·영상이 없어 전사로 복원되지 않는다.** 소스는 셋뿐이다.

| 소스 | 우선순위 |
|---|---|
| `confirm-toc` 채록본 (스크립트에 기록됨) | 1 — 실제 출제 문항 |
| 강의교안 마지막 페이지의 평가·정리 | 2 |
| 전사 전체를 근거로 한 요약 | 3 (학습정리 한정) |

**`학습평가`는 ADsP 기출 형식으로 쓴다.**

```
#### 문제1

딥러닝은 인공지능과 머신러닝을 포괄하는 종합적인 분야이다 (O/X)

**정답**: X

**해설**
- 포함 관계가 반대임 — 인공지능 ⊃ 머신러닝 ⊃ 딥러닝
- 딥러닝은 머신러닝의 한 갈래이며 가장 좁은 범위
```

- 문항 번호는 `#### 문제N`, 그 아래 지문·보기 → `**정답**` → `**해설**` 순
- **해설도 개조식** — 마침표 없이, 왜 그 답인지 근거를 전사·교안에서 끌어온다
- 채록본이 없으면 **빈칸으로 두고** "`confirm-toc`로 채록 필요"라고 보고한다. 문항을 지어내지 않는다

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

### 검증 절차

1. **교안 빠른 재확인**: 교안 이미지를 한번 더 훑으며 노트에 빠진 핵심 내용이 없는지 확인
2. **영상 프레임 보강 반영 확인**: 6단계에서 추출한 보강 내용 목록을 노트와 대조 — 실제로 반영되었는지 체크
3. **필수 섹션 존재 + 내용 확인**: `# 들어가기`/`## 학습개요`, `# 평가하기`/`## 학습평가`, `# 정리하기`/`## 학습정리`
   — 제목만 있고 **본문이 비어 있으면 미완성**이다. 채우거나, 채울 수 없는 사유를 보고한다
4. **이미지 참조 유효성**: `img/` 폴더의 실제 파일과 노트 내 `![](img/...)` 경로 일치 여부
5. **서식 최종 점검**: 개조식, 코드블록 언어 태그, 표 정렬 등

### 보강 및 최종 저장

검증 중 누락·오류 발견 시:
1. 해당 `##` 섹션에 내용 보강 (기존 내용 삭제 금지)
2. 필요시 시각 자료(8단계) 추가 생성
3. 9단계 절차로 파일 재저장

### 검증 보고

```
✅ 통합 검증 완료
- 교안 반영: ✓ (슬라이드 N장 중 N장 반영)
- 전사 텍스트: ✓ (##(N) 전체 섹션 커버)
- 실습 반영: ✓ / 해당 없음
- 영상 프레임: ✓ (N개 프레임 중 보강 N건 반영 확인)
- 시각 자료: ✓ (N개 PNG, 참조 경로 유효)
- 서식: ✓
- 보강 사항: 없음 / N건 보강 완료
```

## 전체 워크플로우 (상단 표와 동일 — 구현 섹션 `## N단계:` 참조)

```
0. [사전 조건 확인] 전사 완료 + 학습목차 완료 여부 체크 → 미충족 시 선행 스킬 실행
1. [과목·주차 파악] 과목 폴더 인식 + 주차 번호 확인
2. [파일 탐색] 스크립트/교안/실습 PDF 경로 확보 (NFD 안전 패턴)
3. [스크립트 읽기] 학습목차 파싱 → 노트 골격 확정 + 전사 텍스트 추출
4. [강의교안] PDF → 이미지 변환 + 순차 읽기
5. [실습 PDF] pdfminer 텍스트 추출 (실패 시 이미지 변환 fallback)
6. [영상 프레임 전수 분석] 모든 프레임 읽기 → 분류 → ##(N)별 보강 내용 정리 ← 생략 금지
7. [강의노트 작성] 학습목차 골격 + 5대 소스 종합 (전사 텍스트 = 최우선)
8. [시각 자료 생성] HTML → Playwright → PNG (환경별 폰트 분기, SVG 금지)
9. [파일 저장] NFD 안전 경로 → 강의노트/ 폴더 + img/ 폴더
10. [통합 검증] 교안·전사·실습·영상 프레임과 노트 대조 → 누락 보강 → 최종 저장 ← 생략 금지
```

## 작성 전략

1. **사전 조건 확인 (필수)**: 전사 완료 + 학습목차 완료 여부 체크. 미충족 시 선행 스킬 먼저 실행
2. **학습목차 파싱 (필수)**: 스크립트의 학습목차를 파싱하여 `#`/`##`/`---` 골격 생성
3. **전사 텍스트 추출 (필수)**: 순번별 전사 텍스트를 추출하여 본문 작성의 핵심 소스로 사용
4. **학습개요 채우기**: 교안 첫 페이지에서 학습목표/학습내용 추출하여 `## 학습개요` 아래에 배치
5. **본문 섹션 채우기**: 각 `##(N)` 섹션에 대해 **전사 텍스트를 기반으로** 교안 슬라이드 + 실습 코드 + 영상 프레임 종합
6. 강의교안 이미지에서 다이어그램, 표, 시각 자료의 내용을 보충
7. 영상 프레임에서 교안에 없는 판서, 데모, 추가 설명 내용을 포착하여 반영
8. 실습 내용이 있으면 해당 항목 아래에 코드와 설명 추가
9. **필수 섹션 확인**: `# 들어가기`/`## 학습개요`, `# 평가하기`/`## 학습평가`, `# 정리하기`/`## 학습정리` 제목이 모두 있는지 확인
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
| 영상 프레임 디렉토리 없음 | extract-video 미실행 | 프레임 없이 진행 (교안+스크립트+실습만 사용) |
| 학습목차 파싱 실패 | 스크립트에 학습목차 태그 없음 | 교안 목차 또는 사용자 입력으로 제목 구조 확인 |
| **전사 텍스트 없이 강의노트 작성 시도** | **extract-video/transcribe 미실행** | **사전 조건 확인에서 차단. 선행 스킬 먼저 실행** |
| **파일 저장 후 사용자 워크스페이스에 안 보임** | **iCloud NFD/NFC 인코딩 불일치** | **`resolve_nfd_path()` 사용 + 저장 후 `ensure_nfd_sync()` 검증** |
| **서브디렉토리(스크립트/, 강의교안/ 등) 못 찾음** | **NFC 하드코딩 경로로 `os.path.isdir()` 실패** | **`resolve_subdir()` 또는 `os.listdir()` 패턴으로 서브디렉토리 해석** |
| **전사 후 경로 무효화** | **MCP 전사 호출이 VM 재시작/마운트 갱신 유발** | **전사 완료 후 `os.listdir()`로 경로 재획득** |
| **파일 저장 후 사용자 워크스페이스에 안 보임** | **iCloud NFD/NFC 인코딩 불일치 — NFC 경로로 Write/Edit 시 별도 고스트 폴더 생성** | **`resolve_nfd_path()` 사용 + 저장 후 `ensure_nfd_sync()` 검증** |
