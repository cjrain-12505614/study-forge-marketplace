---
name: transcribe
description: >
  강의녹음 MP3 파일을 whisper-mcp MCP 서버로 텍스트 스크립트(TXT)로 변환하는 스킬 (v0.3.0).
  영상 없이 MP3만 단독으로 존재하는 경우에 사용한다.
  영상이 있는 경우에는 extract-video 스킬을 사용하면 오디오 추출 + 전사 + ##(N) 삽입까지 한 번에 처리된다.
  사용자가 "스크립트 변환해줘", "MP3 변환", "녹음 텍스트로 바꿔줘", "transcribe" 등을 요청할 때 사용한다.
version: 0.6.0
---

# MP3 → 스크립트 변환 스킬 (whisper-mcp)

강의녹음 MP3 파일을 whisper-mcp MCP 서버(Mac 로컬 whisper-cpp)로 텍스트 변환하여 스크립트 TXT의 `##(N)` 구역에 삽입한다. 과목별 `whisper-terms.txt`를 `initial_prompt`로 전달하여 전문 용어 인식률을 높이고, 전사 후 LLM 후처리로 오인식 교정 및 환각 제거를 수행한다.

> **영상이 있는 경우**: `extract-video` 스킬을 사용하세요. 오디오 추출 → whisper-mcp 전사 → `##(N)` 삽입까지 한 번에 처리됩니다.
> **이 스킬(transcribe)은**: 영상 없이 MP3만 별도로 존재하는 경우의 대안 경로입니다.

## 의존성 및 환경

- **whisper-mcp**: Mac 로컬에서 실행되는 MCP 서버
  - 엔진: whisper-cpp (모델: medium 권장 — 환각 없음 + LLM 후처리로 용어 교정)
  - 비동기 API:
    - `mcp__whisper-mcp__transcribe_async(audio_path, options, output_path)` → job_id 즉시 반환
    - `mcp__whisper-mcp__check_job(job_id)` → 상태 폴링 (queued / processing / completed / failed)
  - **⚠️ options.model 기본값이 `base.en`** — 반드시 `medium`을 명시 지정
  - `options.initial_prompt`: 과목별 전문 용어를 전달하여 인식률 향상
  - `output_path`: iCloud 경로 지정 시 토큰 초과 잘림 방지
  - 타임아웃: 60초 MCP 타임아웃으로 인해 30-60초 간격으로 폴링 필요
  - 경로: Mac 절대 경로 사용 (VM 마운트 경로 아님)

- **iCloud Drive**: 워크스페이스 폴더가 iCloud에 위치하여 VM과의 동기화에 지연 가능
  - 파일이 보이지 않으면 Mac Finder에서 해당 폴더를 먼저 열어 다운로드 트리거 필요

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

    whisper-mcp의 initial_prompt에 전달할 전문 용어 목록을 반환한다.
    과목 폴더 루트에 whisper-terms.txt가 있으면 내용을 읽어 반환한다.
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

whisper-mcp는 Mac 로컬 경로에서만 파일에 접근 가능합니다. VM의 마운트 경로를 실제 Mac 절대 경로로 변환해야 합니다.

```python
def vm_to_mac_path(vm_path):
    """VM 마운트 경로 → Mac iCloud 로컬 경로 변환

    예시:
      입력:  /sessions/.../mnt/[4-1] 파이썬데이터분석/강의녹음/15521532_4_01.mp3
      출력:  /Users/cjrain/Library/Mobile Documents/com~apple~CloudDocs/보관함(iCloud)/SCU/[4-1] 파이썬데이터분석/강의녹음/15521532_4_01.mp3
    """
    # VM 경로에서 과목명 및 파일명 추출
    # 예: /sessions/.../mnt/[4-1] 파이썬데이터분석/강의녹음/15521532_4_01.mp3
    #  → 상대경로: [4-1] 파이썬데이터분석/강의녹음/15521532_4_01.mp3

    parts = vm_path.split('/mnt/', 1)
    if len(parts) < 2:
        raise ValueError(f"Invalid VM path: {vm_path}")

    relative_path = parts[1]  # [4-1] 파이썬데이터분석/강의녹음/15521532_4_01.mp3

    mac_base = '/Users/cjrain/Library/Mobile Documents/com~apple~CloudDocs/보관함(iCloud)/SCU'
    mac_path = os.path.join(mac_base, relative_path)
    return mac_path
```

## 4단계: whisper-mcp 비동기 전사

모든 MP3를 whisper-mcp의 `transcribe_async`로 제출하고, `check_job`으로 폴링하여 완료를 기다립니다.

**⚠️ 중요**: `options.model`을 반드시 명시해야 합니다. 기본값이 `base.en`이므로 생략하면 한국어 전사 품질이 극도로 저하됩니다.

```python
import time

async def transcribe_all_for_week_async(course_path, week):
    """해당 주차의 모든 MP3를 whisper-mcp로 비동기 전사

    Returns:
        dict: {순번: 전사텍스트} 예: {1: "안녕하세요...", 2: "이번 시간에는..."}
    """
    mp3_files = find_mp3_files(course_path, week)
    if not mp3_files:
        print(f"{week}주차 MP3 파일이 없습니다")
        return {}

    # 과목별 전문 용어 로드 (initial_prompt용)
    terms = load_whisper_terms(course_path)
    if terms:
        print(f"whisper-terms.txt 로드됨 ({len(terms)} chars)")

    print(f"{week}주차 MP3 {len(mp3_files)}개 발견 — whisper-mcp 제출 시작")

    # Step 1: 모든 MP3를 비동기로 제출 (job_id 즉시 반환)
    job_map = {}  # {job_id: (순번, Mac 경로)}
    for mp3_path in mp3_files:
        seq = extract_sequence_number(mp3_path)
        if seq is None:
            print(f"  순번 추출 실패: {nfc(os.path.basename(mp3_path))}")
            continue

        # VM 경로를 Mac 로컬 경로로 변환
        mac_path = vm_to_mac_path(mp3_path)

        # output_path: iCloud 경로에 저장 (토큰 초과 잘림 방지)
        mac_output_path = mac_path + '.txt'

        # whisper-mcp 비동기 제출 — model과 initial_prompt 명시
        job_id = mcp__whisper_mcp__transcribe_async(
            audio_path=mac_path,
            output_path=mac_output_path,
            options={
                'model': 'medium',         # ⚠️ 기본값 base.en — 반드시 명시 (medium: 환각 없음)
                'language': 'ko',
                'temperature': 0,
                'initial_prompt': terms     # 과목별 전문 용어
            }
        )
        job_map[job_id] = (seq, nfc(os.path.basename(mp3_path)))
        print(f"  ##({seq}) 제출: {nfc(os.path.basename(mp3_path))} (job_id: {job_id})")

    if not job_map:
        print("제출할 MP3 파일이 없습니다")
        return {}

    # Step 2: 모든 작업이 완료될 때까지 폴링 (30-60초 간격)
    transcripts = {}
    completed_jobs = set()
    poll_interval = 30  # 초

    print(f"\n전사 진행 중 (총 {len(job_map)}개 작업, {poll_interval}초 간격 폴링)...")
    while len(completed_jobs) < len(job_map):
        for job_id in job_map:
            if job_id in completed_jobs:
                continue

            result = mcp__whisper_mcp__check_job(job_id)
            seq, filename = job_map[job_id]

            if result['status'] == 'completed':
                transcripts[seq] = result.get('text', '')
                completed_jobs.add(job_id)
                print(f"  ##({seq}) 완료: {filename} ({len(result.get('text', '')):,} chars)")
            elif result['status'] == 'failed':
                print(f"  ##({seq}) 실패: {filename} — {result.get('error', 'Unknown error')}")
                completed_jobs.add(job_id)
            # 'queued' 또는 'processing' 상태는 계속 폴링

        if len(completed_jobs) < len(job_map):
            time.sleep(poll_interval)

    return transcripts
```

**주의사항**:
- `transcribe_async`는 MCP 도구이므로 Python 코드 내에서 직접 호출 가능
- Mac 경로(`/Users/...`)를 사용해야 whisper-mcp가 파일에 접근 가능
- 모든 job_id를 먼저 수집한 후 폴링을 시작하여 병렬 처리 효율화
- 60초 MCP 타임아웃 때문에 30-60초 간격의 폴링 필요

## 5단계: iCloud 오프로드 처리

일부 파일이 iCloud 오프로드로 인해 Mac에서 보이지 않을 수 있습니다.

```python
import subprocess

def ensure_icloud_download(mac_path):
    """파일이 Mac에 다운로드되도록 강제

    Finder에서 폴더를 열면 iCloud 동기화가 시작됨
    """
    folder = os.path.dirname(mac_path)
    try:
        # macOS: open 명령으로 Finder에서 폴더 열기
        subprocess.run(['open', folder], check=True)
        print(f"  Finder에서 {folder}를 열었습니다 — iCloud 동기화를 기다려주세요 (1-2분)")
        time.sleep(3)  # Finder 열리는 시간 대기
    except Exception as e:
        print(f"  경고: Finder 열기 실패 — {e}")
```

## 6단계: 스크립트 TXT에 전사 텍스트 삽입

전사 결과를 스크립트 TXT의 `##(N)` 구역에 삽입합니다.

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

## 6-0단계: ⚠️ whisper-mcp 후 경로 재획득 (필수)

whisper-mcp 호출 시 서브에이전트/세션이 생성될 수 있으며, VM 재시작 또는 마운트 갱신으로 인해 **이전에 캐시한 경로가 무효화**될 수 있다. whisper-mcp 전사 완료 후에는 반드시 다음을 수행한다:

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

### 처리 규칙

1. **전문 용어 교정**: `whisper-terms.txt`의 용어를 참조하여 음성적으로 유사한 오표기를 올바른 전문 용어로 치환
   - 예: "Psykinon" → "Scikit-learn", "원화 인코딩" → "원핫인코딩", "kegl" → "Kaggle"
2. **환각 제거**: 동일 문장이 3회 이상 연속 반복되면 1회만 남기고 제거
3. **변경 금지**: 문장 구조, 말투, 어순, 구어체 표현, 접속사, 감탄사는 절대 변경하지 않음

### 처리 방법

각 순번(##(N))의 전사 텍스트에 대해 다음 프롬프트를 내부적으로 적용:

```
다음은 한국어 대학 강의의 음성 전사 텍스트입니다.
음성인식 엔진(whisper)의 한계로 전문 용어가 잘못 표기된 부분을 교정해 주세요.

## 교정 규칙
- 전문 용어의 오인식만 교정 (문장 구조, 말투, 어순은 절대 변경하지 않음)
- 아래 참조 용어를 기준으로 음성적으로 유사한 오표기를 올바른 용어로 치환
- 교정하지 않을 것: 구어체 표현, 접속사, 감탄사, 반복 표현
- 연속 반복 문장(환각)은 1회만 남기고 제거

## 참조 용어
{whisper-terms.txt 내용}

## 전사 텍스트
{whisper 출력}
```

교정 완료된 텍스트를 6단계에서 스크립트 TXT에 삽입한다.

## 8단계: 후처리 안내

변환 완료 후 사용자에게 안내:
1. 전사 텍스트가 스크립트 TXT의 `##(N)` 구역에 삽입되었음
2. 스크립트 TXT가 없었다면 `<강의녹음 스크립트>` 구역만 포함한 파일이 생성되었음
3. 다음 단계: `prepare-script` 스킬로 학습목차를 추가하여 스크립트를 완성
4. whisper-mcp 변환 특성상 오탈자가 있을 수 있으므로 검토 권장

## 전체 워크플로우

```
1. 과목 폴더 인식 (자동 또는 사용자 선택)
2. 주차 파악 → 강의녹음/ 폴더에서 MP3 탐색 + whisper-terms.txt 로드
3. MP3 파일명에서 순번 추출 ({과목코드}_{주차}_{순번}.mp3)
4. VM 경로를 Mac 로컬 경로로 변환
5. whisper-mcp의 transcribe_async로 모든 MP3 비동기 제출 (model + initial_prompt 명시)
6. check_job으로 30-60초 간격 폴링하여 완료 대기
7. iCloud 오프로드 확인 및 처리
8. LLM 후처리 — 전문 용어 교정 + 환각 제거
9. 스크립트 TXT의 ##(N) 구역에 교정된 전사 텍스트 삽입
10. 후처리 안내
```

## extract-video vs transcribe 사용 가이드

| 상황 | 사용할 스킬 |
|------|------------|
| 강의영상(MP4)이 있음 | `extract-video` — 오디오 추출 + 전사 + 프레임 캡처 |
| MP3만 있음 (영상 없음 또는 별도 녹음) | `transcribe` — MP3 전사만 수행 |
| 이미 MP3가 있고 영상도 있음 | `extract-video` — MP3가 이미 있으면 추출 건너뛰고 전사만 수행 |

## 흔한 오류와 해결

| 오류 | 원인 | 해결 |
|------|------|------|
| FileNotFoundError | Mac에 MP3 파일이 없음 | Mac Finder에서 강의녹음 폴더를 열어 iCloud 동기화 트리거 |
| whisper-mcp job_id 없음 | transcribe_async 호출 실패 | Mac의 whisper-mcp MCP 서버 실행 상태 확인 |
| check_job status='failed' | 전사 처리 중 오류 발생 | 파일 형식(MP3) 확인, 파일 손상 검사, whisper-mcp 로그 확인 |
| 부분 전사 또는 시간 초과 | 파일이 크거나 whisper-mcp 처리 지연 | 60초 폴링 타임아웃 고려, 재시도 |
| VM 경로 변환 실패 | 과목명 형식 불일치 | 경로 패턴 확인: `/mnt/[4-1] 파이썬데이터분석/...` |
| 경로의 한글 문자 인식 오류 | NFD/NFC 인코딩 불일치 | Python `unicodedata.normalize('NFC', path)` 적용 |
| 파일 저장 후 사용자 워크스페이스에 안 보임 | iCloud NFD/NFC 인코딩 불일치 | `os.listdir()` 원본 경로 사용 + 저장 후 NFD 경로 검증 |
| 서브디렉토리(강의녹음/, 스크립트/) 못 찾음 | NFC 하드코딩 경로로 `os.path.isdir()` 실패 | `resolve_subdir()` 패턴으로 서브디렉토리 해석 |
| whisper-mcp 후 경로가 무효화됨 | whisper-mcp가 VM 재시작/마운트 갱신 유발 | 전사 완료 후 `os.listdir()`로 모든 경로 재획득 |
| ##(N) 삽입 실패 | 스크립트에 해당 구역 없음 | 스크립트 파일 확인, 없으면 새로 생성 |
