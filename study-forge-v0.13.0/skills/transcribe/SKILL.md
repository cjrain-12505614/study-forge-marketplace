---
name: transcribe
description: >
  강의녹음 MP3 파일을 다글로(daglo) MCP 서버로 텍스트 스크립트(TXT)로 변환하는 스킬 (v0.8.0).
  영상 없이 MP3만 단독으로 존재하는 경우에 사용한다.
  영상이 있는 경우에는 extract-video 스킬을 사용하면 오디오 추출 + 전사 + ##(N) 삽입까지 한 번에 처리된다.
  사용자가 "스크립트 변환해줘", "MP3 변환", "녹음 텍스트로 바꿔줘", "transcribe" 등을 요청할 때 사용한다.
version: 0.8.0
---

# MP3 → 스크립트 변환 스킬 (다글로 MCP)

강의녹음 MP3 파일을 다글로(daglo) MCP 서버로 텍스트 변환하여 스크립트 TXT의 `##(N)` 구역에 삽입한다. 전사 후 LLM 후처리로 전문 용어 오인식 교정 및 환각 제거를 수행한다.

> **영상이 있는 경우**: `extract-video` 스킬을 사용하세요. 오디오 추출 → 다글로 전사 → `##(N)` 삽입까지 한 번에 처리됩니다.
> **이 스킬(transcribe)은**: 영상 없이 MP3만 별도로 존재하는 경우의 대안 경로입니다.

## 시작 전 필수

1. 워크스페이스 `CLAUDE.md`와 **과목 폴더 `CLAUDE.md`**를 읽는다
2. 같은 종류의 **기존 산출물을 열어 형식을 확인**한다
3. 확인할 수 없는 값은 **비워 두고 채울 방법을 안내**한다 — 그럴듯한 추정값 금지

## ⚠️ 실행 전 반드시 지킬 2가지

1. **유료 크레딧 소모** — 다글로 전사는 유료다. `start_transcription(dry_run=False)` 또는 `transcribe_file(confirm=True)`를 호출하기 **전에 반드시 사용자 승인을 받는다**. 주차 단위 전사는 MP3가 여러 개라 크레딧이 배수로 소모되므로, **대상 파일 목록과 개수를 먼저 제시하고 확인받는다**.
2. **클라우드 업로드** — 강의 녹음이 다글로 서버로 전송된다. 로컬 처리가 아니다. 외부 반출이 곤란한 녹음이면 진행 전 사용자에게 확인한다.

> 업로드(`upload_file`) 자체는 과금되지 않는다. **과금 지점은 전사 시작**이다. 따라서 업로드까지 마친 뒤 승인을 받는 순서가 안전하다.

## 의존성 및 환경

- **다글로 MCP**: 전역 `~/.claude.json`에 등록된 MCP 서버 (워크스페이스 `.mcp.json`에는 없음)
  - `mcp__daglo__upload_file(file_path)` → `fileMetaId` 발급 (무료, 전사의 선행 단계)
  - `mcp__daglo__start_transcription(file_meta_ids[], language, topic, use_dictionary, use_speaker_diarization, dry_run)` → ⚠️ 유료
  - `mcp__daglo__get_file_status(file_meta_id)` → upload/transcript/summary 상태 폴링
  - `mcp__daglo__get_transcript(file_meta_id, with_time, save_path)` → 평문 + 세그먼트 회수
  - `mcp__daglo__transcribe_file(file_path, confirm=True, ...)` → 원스톱(업로드→전사→대기→회수). **단일 파일**에 적합
  - `mcp__daglo__list_folders` / `rename_board` / `get_board` → 결과 보드 정리용
  - 경로: **Mac 절대 경로** 사용 (VM 마운트 경로 아님)

- **iCloud Drive**: 워크스페이스 폴더가 iCloud에 위치하여 VM과의 동기화에 지연 가능
  - 파일이 보이지 않으면 Mac Finder에서 해당 폴더를 먼저 열어 다운로드 트리거 필요

### 전사 옵션 기본값 (강의 녹음 기준)

| 옵션 | 값 | 이유 |
|------|-----|------|
| `language` | `ko-KR` | 한국어 강의 |
| `topic` | `IT` | 전공 분야에 맞게 조정 (전문용어 인식률에 영향) |
| `use_dictionary` | `True` | 다글로 계정 사전 활용 |
| `use_speaker_diarization` | **`False`** | 강의는 사실상 단일 화자. 화자 라벨이 붙으면 `##(N)` 구역이 오염됨 |
| `with_time` | **`False`** | 타임스탬프가 섞이면 스크립트 본문이 오염됨. 평문으로 받아 그대로 삽입 |

> **whisper-terms.txt의 역할 변경 (중요)**: 다글로에는 whisper의 `initial_prompt`에 해당하는 인자가 **없다**. 따라서 `whisper-terms.txt`는 더 이상 전사 엔진에 사전 힌트로 전달되지 않으며, **7단계 LLM 후처리의 참조 용어집으로만** 사용한다. 엔진 단계에서 용어 인식률을 올리려면 **다글로 웹에서 계정 사전에 전문 용어를 등록**하고 `use_dictionary=True`로 쓴다. 파일명은 기존 과목 폴더 호환을 위해 `whisper-terms.txt` 그대로 유지한다.

## 1단계: 과목 폴더 자동 인식

마운트된 폴더 중 시스템 폴더(`.`으로 시작하거나 `uploads`)를 제외한 폴더를 과목 폴더로 인식한다.

```python
import os
import unicodedata

SESSION_BASE = '/sessions/{session_id}'
MNT = os.path.join(SESSION_BASE, 'mnt')

SYSTEM_DIRS = {'uploads', '.claude', '.skills', '.local-plugins',
               '.cowork-lib', '.cowork-perm-req', '.cowork-perm-resp'}

def nfc(s):
    """macOS NFD 인코딩 → NFC 정규화"""
    return unicodedata.normalize('NFC', s)

def find_course_folders():
    """마운트된 과목 폴더 목록 반환"""
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

사용자가 과목을 지정하지 않았으면 과목 목록을 보여주고 선택하게 한다.

## 2단계: MP3 파일 탐색 및 순번 추출

MP3 파일명은 영상 파일과 동일한 패턴을 따른다: `{과목코드}_{주차}_{순번}.mp3`

```python
import os, re

def resolve_subdir(course_path, target_name):
    """NFD 안전 서브디렉토리 해석 — os.listdir()로 실제 이름 획득 후 매칭

    os.path.join(course_path, '강의녹음') 처럼 NFC 이름을 하드코딩하면
    NFD로 저장된 디렉토리를 찾지 못한다. 반드시 이 함수를 사용한다.
    """
    nfc_target = nfc(target_name)
    for sub in os.listdir(course_path):
        if nfc(sub) == nfc_target and os.path.isdir(os.path.join(course_path, sub)):
            return os.path.join(course_path, sub)
    return None

def load_whisper_terms(course_path):
    """과목 폴더의 whisper-terms.txt 로드 (NFD-safe)

    ⚠️ 다글로에는 initial_prompt가 없으므로 이 용어집은 전사 엔진에 전달되지 않는다.
    7단계 LLM 후처리에서 오인식 교정의 참조 기준으로만 사용한다.
    """
    for f in os.listdir(course_path):
        if nfc(f) == 'whisper-terms.txt':
            with open(os.path.join(course_path, f), 'r', encoding='utf-8') as fh:
                return fh.read().strip()
    return ''

def find_mp3_files(course_path, week=None):
    """강의녹음/ 폴더에서 MP3 파일 탐색 (NFD-safe)"""
    recording_dir = resolve_subdir(course_path, '강의녹음')
    if not recording_dir:
        return []

    mp3_files = []
    for f in sorted(os.listdir(recording_dir)):
        if not f.lower().endswith('.mp3'):
            continue
        if week is not None and f'_{week}_' not in f and f'_{week:02d}_' not in f:
            continue
        mp3_files.append(os.path.join(recording_dir, f))
    return mp3_files

def extract_sequence_number(filename):
    """파일명에서 마지막 순번 추출
    예: 15521532_4_01.mp3 → 1
    """
    name = os.path.splitext(os.path.basename(filename))[0]
    m = re.search(r'_(\d+)$', name)
    if m:
        return int(m.group(1))
    return None
```

## 3단계: VM 경로 → Mac 로컬 경로 변환

다글로 MCP는 Mac 로컬에서 실행되므로 Mac 절대 경로에서만 파일에 접근 가능하다. VM의 마운트 경로를 실제 Mac 절대 경로로 변환해야 한다.

```python
def vm_to_mac_path(vm_path):
    """VM 마운트 경로 → Mac iCloud 로컬 경로 변환

    예시:
      입력:  /sessions/.../mnt/[4-1] 파이썬데이터분석/강의녹음/15521532_4_01.mp3
      출력:  ~/Library/Mobile Documents/com~apple~CloudDocs/보관함(iCloud)/SCU/[4-1] 파이썬데이터분석/강의녹음/15521532_4_01.mp3
    """
    parts = vm_path.split('/mnt/', 1)
    if len(parts) < 2:
        raise ValueError(f"Invalid VM path: {vm_path}")

    relative_path = parts[1]  # [4-1] 파이썬데이터분석/강의녹음/15521532_4_01.mp3

    # 홈 경로를 하드코딩하지 않는다 — 맥 이관 시 조용히 깨진다
    mac_base = os.path.join(
        os.path.expanduser('~'),
        'Library/Mobile Documents/com~apple~CloudDocs/보관함(iCloud)/SCU'
    )
    mac_path = os.path.join(mac_base, relative_path)
    return mac_path
```

## 4단계: 다글로 전사 (업로드 → 승인 → 전사 → 회수)

주차 단위 전사는 MP3가 여러 개이므로 **원스톱 `transcribe_file`을 파일마다 반복하지 않고**, 업로드를 일괄로 끝낸 뒤 `start_transcription`에 `file_meta_ids` 배열을 한 번에 넘긴다. 승인 게이트를 **정확히 1회**만 거치기 위해서도 이 구조가 낫다.

### 4-1. 업로드 (무료)

```python
def upload_all_for_week(course_path, week):
    """해당 주차의 모든 MP3를 다글로에 업로드 → {fileMetaId: (순번, 파일명)}

    업로드는 과금되지 않는다. 과금 지점은 4-3 전사 시작이다.
    """
    mp3_files = find_mp3_files(course_path, week)
    if not mp3_files:
        print(f"{week}주차 MP3 파일이 없습니다")
        return {}

    print(f"{week}주차 MP3 {len(mp3_files)}개 발견 — 다글로 업로드 시작")

    meta_map = {}  # {fileMetaId: (순번, 파일명)}
    for mp3_path in mp3_files:
        seq = extract_sequence_number(mp3_path)
        if seq is None:
            print(f"  순번 추출 실패: {nfc(os.path.basename(mp3_path))}")
            continue

        mac_path = vm_to_mac_path(mp3_path)
        result = mcp__daglo__upload_file(file_path=mac_path)
        fid = result['fileMetaId']

        meta_map[fid] = (seq, nfc(os.path.basename(mp3_path)))
        print(f"  ##({seq}) 업로드 완료: {nfc(os.path.basename(mp3_path))} (id: {fid})")

    return meta_map
```

### 4-2. ⚠️ 승인 게이트 (필수 — 건너뛰지 말 것)

전사를 시작하기 전에 다음을 사용자에게 제시하고 **명시적 승인**을 받는다:

```
다글로 전사를 시작합니다 — 유료 크레딧이 소모됩니다.

  대상: {과목명} {주차}주차
  파일: {N}개
    ##(1) 15521532_4_01.mp3  (42.3MB)
    ##(2) 15521532_4_02.mp3  (38.1MB)
  옵션: ko-KR / topic=IT / 사전 사용 / 화자분리 없음 / 타임스탬프 없음

진행할까요?
```

승인 없이 `dry_run=False`로 호출하지 않는다. 사용자가 거부하면 업로드된 파일은 그대로 두고 종료한다(전사만 하지 않으면 과금되지 않는다).

### 4-3. 전사 시작 (⚠️ 유료 — 승인 후에만)

```python
def start_transcription_for_week(meta_map, topic='IT'):
    """승인 후 일괄 전사 시작. ⚠️ dry_run=False 는 과금된다."""
    if not meta_map:
        return

    ids = list(meta_map.keys())
    # ⚠️ 서버 상한 5개 — 6개 이상이면 400 "Maximum of 5 fileMetaIds are allowed"
    for i in range(0, len(ids), 5):
        mcp__daglo__start_transcription(
            file_meta_ids=ids[i:i+5],
            language='ko-KR',
            topic=topic,                # ⚠️ 서버 enum. 임의 문자열은 400
            use_dictionary=True,
            use_speaker_diarization=False,  # 강의 = 단일 화자, ##(N) 오염 방지
            dry_run=False                   # ⚠️ 사용자 승인 후에만 False
        )
    print(f"전사 시작: {len(ids)}개 작업")
```

**두 인자는 서버가 값을 검증한다 — 임의로 넣으면 400이다.**

| 인자 | 제약 | 위반 시 |
|---|---|---|
| `file_meta_ids` | **요청당 최대 5개** | `Maximum of 5 fileMetaIds are allowed` |
| `topic` | **서버 enum** — `IT` 등 정해진 값만 | `topic must be a valid enum value` |

> `topic`에 `딥러닝`·`파이썬 프로그래밍` 같은 과목명을 넣으면 실패한다. 과목이 무엇이든 **`IT`** 를 쓴다.
> 전공 용어 인식률은 `topic`이 아니라 **다글로 웹 계정 사전 등록 + `use_dictionary=True`** 로 올린다.

### 4-4. 상태 폴링 및 전사문 회수

```python
import time

def collect_transcripts(meta_map, poll_interval=30, max_wait_sec=3600):
    """전사 완료를 폴링하고 전사문을 회수

    Returns:
        dict: {순번: 전사텍스트} 예: {1: "안녕하세요...", 2: "이번 시간에는..."}
    """
    transcripts = {}
    done = set()
    waited = 0

    print(f"\n전사 진행 중 (총 {len(meta_map)}개, {poll_interval}초 간격 폴링)...")
    while len(done) < len(meta_map) and waited < max_wait_sec:
        for fid, (seq, filename) in meta_map.items():
            if fid in done:
                continue

            status = mcp__daglo__get_file_status(file_meta_id=fid)
            state = status.get('transcriptStatus') or status.get('status')

            if state in ('COMPLETED', 'completed', 'SUCCESS'):
                # with_time=False → 타임스탬프 없는 평문 회수
                res = mcp__daglo__get_transcript(file_meta_id=fid, with_time=False)
                transcripts[seq] = res.get('plain_text', '')
                done.add(fid)
                print(f"  ##({seq}) 완료: {filename} ({len(transcripts[seq]):,} chars)")
            elif state in ('FAILED', 'failed', 'ERROR'):
                print(f"  ##({seq}) 실패: {filename} — {status.get('message', 'Unknown error')}")
                done.add(fid)
            # 그 외(대기/처리중)는 계속 폴링

        if len(done) < len(meta_map):
            time.sleep(poll_interval)
            waited += poll_interval

    if waited >= max_wait_sec:
        print(f"⚠️ 최대 대기 시간 초과 — 미완료 {len(meta_map) - len(done)}건")
        print("   fileMetaId로 나중에 get_file_status → get_transcript 재시도 가능")

    return transcripts
```

**주의사항**:
- Mac 경로(`/Users/...`)를 사용해야 다글로 MCP가 파일에 접근 가능
- 업로드를 모두 마친 후 전사를 일괄 시작해야 승인 게이트가 1회로 끝난다
- 폴링이 타임아웃돼도 전사는 서버에서 계속 진행된다 — `fileMetaId`를 보존해 두면 나중에 회수 가능
- 단일 파일 1건만 처리할 때는 `mcp__daglo__transcribe_file(file_path=..., confirm=True)` 원스톱이 더 간단하다

### 4-5. ⚠️ 다건 회수는 MCP 도구 반복 대신 모듈 직접 호출

`get_transcript`는 `plain_text`와 `segments`를 **중복으로** 반환한다. MCP 도구로 30~40건을 회수하면 같은 내용이 두 번씩 컨텍스트에 실려 **대화가 폭증**한다.

주차 여러 개를 한꺼번에 회수할 때는 프로젝트 모듈을 직접 호출해 **파일로만** 떨어뜨린다.

```python
import sys, os
sys.path.insert(0, os.path.expanduser('~/보관함(Local)/Workspace/daglo-mcp/src'))
from daglo_mcp.server import _client
from daglo_mcp.tools import scripts as S

c = _client()
for fid, out in targets:                       # out = 저장할 TXT 경로
    S.get_transcript(c, fid, with_time=False, save_path=out)
```

이후 파일을 읽어 후처리한다. 한두 건이면 MCP 도구를 그대로 써도 된다.

### 4-6. 결과 보드를 강의 폴더로 이동

`start_transcription`에는 `folder_id` 인자가 **없다.** 전사 완료 후 보드를 옮긴다.

```python
c.patch('/boards/location', json={'boardIds': chunk, 'folderId': LECTURE_FOLDER_ID})
```

- 20건씩 나눠 보낸다
- ⚠️ `.env`의 `DAGLO_DEFAULT_FOLDER_ID`가 `회의` 등 **다른 폴더로 설정돼 있을 수 있다** — 값을 확인하고, 강의 전사는 `강의` 폴더로 이동시킨다

## 5단계: iCloud 오프로드 처리

일부 파일이 iCloud 오프로드로 인해 Mac에서 보이지 않을 수 있다. **업로드 전에** 확인한다.

```python
import subprocess

def ensure_icloud_download(mac_path):
    """파일이 Mac에 다운로드되도록 강제

    Finder에서 폴더를 열면 iCloud 동기화가 시작됨
    """
    folder = os.path.dirname(mac_path)
    try:
        subprocess.run(['open', folder], check=True)
        print(f"  Finder에서 {folder}를 열었습니다 — iCloud 동기화를 기다려주세요 (1-2분)")
        time.sleep(3)
    except Exception as e:
        print(f"  경고: Finder 열기 실패 — {e}")
```

## 6단계: 스크립트 TXT에 전사 텍스트 삽입

전사 결과를 스크립트 TXT의 `##(N)` 구역에 삽입한다.

```python
import re

def insert_transcripts_into_script(script_path, transcripts):
    """기존 스크립트 TXT의 ##(N) 아래에 전사 텍스트 삽입"""
    with open(script_path, 'r', encoding='utf-8') as f:
        content = f.read()

    script_match = re.search(r'(<[^>]+강의녹음\s*스크립트>)', content)
    if not script_match:
        print("경고: <강의녹음 스크립트> 구역을 찾을 수 없습니다")
        return False

    script_section_start = script_match.end()
    before = content[:script_section_start]
    after = content[script_section_start:]

    for seq in sorted(transcripts.keys()):
        text = transcripts[seq]
        pattern = rf'(##\({seq}\)[^\n]*\n)'
        replacement = rf'\g<1>{text}\n'
        after = re.sub(pattern, replacement, after, count=1)

    with open(script_path, 'w', encoding='utf-8') as f:
        f.write(before + after)

    print(f"전사 텍스트 삽입 완료: {len(transcripts)}개 순번")
    return True

def find_existing_script(course_path, week):
    """해당 주차의 기존 스크립트 파일 찾기 (NFD-safe)"""
    script_dir = resolve_subdir(course_path, '스크립트')
    if not script_dir:
        return None

    week_str_padded = f'{week:02d}주차'
    week_str = f'{week}주차'
    for f in os.listdir(script_dir):
        fn = nfc(f)
        if fn.endswith('.txt') and (week_str_padded in fn or week_str in fn):
            return os.path.join(script_dir, f)
    return None
```

## 6-0단계: ⚠️ 전사 후 경로 재획득 (필수)

MCP 전사 호출 시 서브에이전트/세션이 생성될 수 있으며, VM 재시작 또는 마운트 갱신으로 인해 **이전에 캐시한 경로가 무효화**될 수 있다. 전사 완료 후에는 반드시 다음을 수행한다:

1. `os.listdir(MNT)`로 과목 폴더 경로를 **다시 획득**
2. `resolve_subdir(course_path, '스크립트')`로 서브디렉토리 경로를 **다시 해석**
3. 이전 단계에서 저장한 변수(예: `script_path`, `recording_dir`)를 **재사용하지 않고 새로 구성**

## 6-1단계: ⚠️ NFD 경로 안전 쓰기 (필수)

iCloud Drive의 한글 폴더명은 macOS NFD 인코딩으로 저장된다. VM에서 NFC 문자열로 경로를 직접 지정하면 같은 이름의 새 폴더가 별도로 생성되어 iCloud와 동기화되지 않는다. 파일을 저장할 때는 반드시 `os.listdir()`로 얻은 원본(NFD) 디렉토리명을 사용하여 경로를 구성해야 한다.

- **절대 금지**: 하드코딩된 한글 경로 문자열로 Write/Edit 도구 호출
- **반드시**: `os.listdir()` → 원본 파일명으로 `os.path.join()` → 그 결과를 Write/Edit에 전달
- **저장 후 검증**: NFD 경로에 파일이 존재하는지 확인하고, 없으면 NFC→NFD 복사 수행

## 7단계: LLM 후처리 (전문 용어 교정 + 환각 제거)

전사 텍스트를 스크립트 TXT에 삽입하기 **전에**, 다음 교정을 수행한다. Claude 자체가 후처리를 수행하므로 별도 API 호출은 불필요하다.

> 다글로에는 `initial_prompt`가 없어 전사 엔진이 과목 용어를 미리 알지 못한다. 따라서 **이 후처리 단계의 중요도가 whisper 시절보다 높다** — 생략하지 말 것.

### 처리 규칙

0. **화자 라벨 제거 (필수)**: `use_speaker_diarization=False`로 호출해도 평문에 `참석자 1: ` 접두가 붙어 나온다.
   옵션으로 막을 수 없으므로 **후처리에서 반드시 걷어낸다** — 남으면 `##(N)` 구역이 오염된다

```python
import re
text = re.sub(r'^\s*참석자\s*\d+\s*[:：]\s*', '', text, flags=re.M)
```

1. **전문 용어 교정**: `whisper-terms.txt`의 용어를 참조하여 음성적으로 유사한 오표기를 올바른 전문 용어로 치환
   - 예: "Psykinon" → "Scikit-learn", "원화 인코딩" → "원핫인코딩", "kegl" → "Kaggle"
2. **환각 제거**: 동일 문장이 3회 이상 연속 반복되면 1회만 남기고 제거
3. **변경 금지**: 문장 구조, 말투, 어순, 구어체 표현, 접속사, 감탄사는 절대 변경하지 않음

### 처리 방법

각 순번(##(N))의 전사 텍스트에 대해 다음 프롬프트를 내부적으로 적용:

```
다음은 한국어 대학 강의의 음성 전사 텍스트입니다.
음성인식 엔진의 한계로 전문 용어가 잘못 표기된 부분을 교정해 주세요.

## 교정 규칙
- 전문 용어의 오인식만 교정 (문장 구조, 말투, 어순은 절대 변경하지 않음)
- 아래 참조 용어를 기준으로 음성적으로 유사한 오표기를 올바른 용어로 치환
- 교정하지 않을 것: 구어체 표현, 접속사, 감탄사, 반복 표현
- 연속 반복 문장(환각)은 1회만 남기고 제거

## 참조 용어
{whisper-terms.txt 내용}

## 전사 텍스트
{다글로 출력}
```

교정 완료된 텍스트를 6단계에서 스크립트 TXT에 삽입한다.

## 8단계: 후처리 안내

변환 완료 후 사용자에게 안내:
1. 전사 텍스트가 스크립트 TXT의 `##(N)` 구역에 삽입되었음
2. 스크립트 TXT가 없었다면 `<강의녹음 스크립트>` 구역만 포함한 파일이 생성되었음
3. 다음 단계: `prepare-script` 스킬로 학습목차를 추가하여 스크립트를 완성
4. 전사 특성상 오탈자가 있을 수 있으므로 검토 권장
5. (선택) 다글로 보드명을 `rename_board`로 `{과목명} {주차}주차`처럼 정리하면 다글로 웹에서 찾기 쉬움

## 전체 워크플로우

```
1. 과목 폴더 인식 (자동 또는 사용자 선택)
2. 주차 파악 → 강의녹음/ 폴더에서 MP3 탐색 + whisper-terms.txt 로드(후처리용)
3. MP3 파일명에서 순번 추출 ({과목코드}_{주차}_{순번}.mp3)
4. VM 경로를 Mac 로컬 경로로 변환 + iCloud 오프로드 확인
5. 다글로 업로드 (무료) → fileMetaId 수집
6. ⚠️ 승인 게이트 — 대상·개수·옵션 제시 후 사용자 승인
7. start_transcription(dry_run=False) 일괄 전사 시작 (⚠️ 유료)
8. get_file_status 폴링 → get_transcript(with_time=False)로 평문 회수
9. LLM 후처리 — 전문 용어 교정 + 환각 제거
10. 스크립트 TXT의 ##(N) 구역에 교정된 전사 텍스트 삽입
11. 후처리 안내
```

> **핵심 변경 (v0.8.0)**: 다글로 서버 제약 반영 — `file_meta_ids` 5개 상한, `topic` 서버 enum(`IT`), `참석자 N:` 라벨 후처리 제거 필수화. 다건 회수 시 컨텍스트 폭증을 피하는 모듈 직접 호출 경로와 결과 보드 폴더 이동 절차 추가.
>
> **핵심 변경 (v0.7.0)**: 전사 엔진을 whisper-mcp(로컬) → **다글로 MCP(클라우드)**로 전환. 유료 승인 게이트 신설, `initial_prompt` 부재로 `whisper-terms.txt`는 후처리 참조용으로 역할 축소, 화자분리·타임스탬프는 `##(N)` 오염 방지를 위해 기본 비활성.

## extract-video vs transcribe 사용 가이드

| 상황 | 사용할 스킬 |
|------|------------|
| 강의영상(MP4)이 있음 | `extract-video` — 오디오 추출 + 전사 + 프레임 캡처 |
| MP3만 있음 (영상 없음 또는 별도 녹음) | `transcribe` — MP3 전사만 수행 |
| 이미 MP3가 있고 영상도 있음 | `extract-video` — MP3가 이미 있으면 추출 건너뛰고 전사만 수행 |

## 흔한 오류와 해결

| 오류 | 원인 | 해결 |
|------|------|------|
| `401 Invalid refresh token` | 다글로 토큰 만료 | 크롬에서 다글로 재로그인 후 토큰 재시드. 재시드 전까지 모든 다글로 호출 실패 |
| `QUOTA_EXCEEDED` | 크레딧/quota 소진 | 다글로 계정 크레딧 확인. 요약 quota는 전사와 별도 |
| FileNotFoundError | Mac에 MP3 파일이 없음 (iCloud 오프로드) | Mac Finder에서 강의녹음 폴더를 열어 iCloud 동기화 트리거 |
| `fileMetaId` 없음 | `upload_file` 실패 | 파일 크기·형식 확인, 다글로 인증 상태 확인 |
| 전사 상태가 계속 대기 | 서버 처리 지연 | 폴링 간격을 늘려 재시도. 타임아웃돼도 서버 전사는 계속되므로 `fileMetaId`로 나중에 회수 |
| 전사문에 `참석자 1:` 접두 | **`False`로 호출해도 붙는다** (다글로 특성) | 7단계 0번 정규식으로 제거 — 옵션으로는 막을 수 없다 |
| `Maximum of 5 fileMetaIds are allowed` | 한 요청에 6개 이상 전달 | 5개씩 분할 호출 (4-3 참조) |
| `topic must be a valid enum value` | `topic`에 과목명 등 임의 문자열 | `IT` 사용 |
| 전사문 회수 중 대화가 폭증 | `get_transcript`가 평문+세그먼트 중복 반환 | 다건은 모듈 직접 호출로 파일에만 저장 (4-5 참조) |
| 결과 보드가 엉뚱한 폴더에 쌓임 | `.env`의 `DAGLO_DEFAULT_FOLDER_ID`가 다른 폴더 | 전사 후 `PATCH /boards/location`으로 이동 (4-6 참조) |
| 전사문에 타임스탬프가 섞임 | `with_time=True`로 회수됨 | `get_transcript(with_time=False)`로 평문 회수 |
| 전문 용어가 대량 오인식 | `initial_prompt` 부재 (다글로 특성) | 7단계 LLM 후처리를 반드시 수행. 다글로 웹 계정 사전에 용어 등록 권장 |
| VM 경로 변환 실패 | 과목명 형식 불일치 | 경로 패턴 확인: `/mnt/[4-1] 파이썬데이터분석/...` |
| 경로의 한글 문자 인식 오류 | NFD/NFC 인코딩 불일치 | Python `unicodedata.normalize('NFC', path)` 적용 |
| 파일 저장 후 사용자 워크스페이스에 안 보임 | iCloud NFD/NFC 인코딩 불일치 | `os.listdir()` 원본 경로 사용 + 저장 후 NFD 경로 검증 |
| 서브디렉토리(강의녹음/, 스크립트/) 못 찾음 | NFC 하드코딩 경로로 `os.path.isdir()` 실패 | `resolve_subdir()` 패턴으로 서브디렉토리 해석 |
| 전사 후 경로가 무효화됨 | MCP 호출이 VM 재시작/마운트 갱신 유발 | 전사 완료 후 `os.listdir()`로 모든 경로 재획득 |
| ##(N) 삽입 실패 | 스크립트에 해당 구역 없음 | 스크립트 파일 확인, 없으면 새로 생성 |
