---
name: extract-video
description: >
  강의영상 MP4에서 슬라이드 프레임 캡처, 오디오 추출, whisper-mcp 전사, 스크립트 TXT 생성을 수행하는 스킬 (v0.3.0).
  사용자가 "영상에서 슬라이드 뽑아줘", "MP4 처리해줘", "영상에서 오디오 추출해줘",
  "강의영상 분석해줘", "extract-video" 등을 요청할 때 사용한다.
  ffmpeg으로 프레임과 오디오를 추출하고, whisper-mcp로 전사하여 스크립트 TXT의 ##(N) 구역에 삽입한다.
version: 0.6.0
---

# 강의영상 처리 스킬 (whisper-mcp)

강의영상 MP4에서 슬라이드 프레임 캡처, 오디오 추출, whisper-mcp 전사를 수행하고, 전사 결과를 스크립트 TXT의 `##(N)` 구역에 자동 삽입한다. 과목별 `whisper-terms.txt`를 `initial_prompt`로 전달하여 전문 용어 인식률을 높이고, 전사 후 LLM 후처리로 오인식 교정 및 환각 제거를 수행한다.

## 의존성 및 환경

**로컬 도구**:
- **ffmpeg**: 오디오 추출 및 슬라이드 프레임 캡처 (설치: `apt-get install -y ffmpeg`)

**MCP 서버**:
- **whisper-mcp**: Mac 로컬에서 실행되는 MCP 서버
  - 엔진: whisper-cpp (모델: medium 권장 — 환각 없음 + LLM 후처리로 용어 교정)
  - 비동기 API:
    - `mcp__whisper-mcp__transcribe_async(audio_path, options, output_path)` → job_id 즉시 반환
    - `mcp__whisper-mcp__check_job(job_id)` → 상태 폴링 (queued / processing / completed / failed)
  - **⚠️ options.model 기본값이 `base.en`** — 반드시 `medium`을 명시 지정
  - `options.initial_prompt`: 과목별 전문 용어를 전달하여 인식률 향상
  - `output_path`: iCloud 경로 지정 시 토큰 초과 잘림 방지
  - 경로: Mac 절대 경로 사용 (VM 마운트 경로 아님)

## 1단계: 과목 폴더 인식 및 영상 탐색

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

def resolve_subdir(course_path, target_name):
    """NFD 안전 서브디렉토리 해석 — os.listdir()로 실제 이름 획득 후 매칭

    os.path.join(course_path, '강의영상') 처럼 NFC 이름을 하드코딩하면
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

def find_video_files(course_path, week=None):
    """강의영상/ 폴더에서 MP4 파일 탐색 (NFD-safe)"""
    video_dir = resolve_subdir(course_path, '강의영상')
    if not video_dir:
        return []

    videos = []
    for f in sorted(os.listdir(video_dir)):
        if f.lower().endswith(('.mp4', '.mkv', '.avi', '.mov')):
            if week is None or f'_{week}_' in f or f'_{week:02d}_' in f:
                videos.append(os.path.join(video_dir, f))
    return videos
```

## 2단계: 영상 파일명에서 순번 추출

영상 파일명은 `{과목코드}_{주차}_{순번}.mp4` 패턴을 따른다.
예: `15521532_4_01.mp4` → 주차=4, 순번=1

```python
import re

def extract_sequence_number(filename):
    """파일명에서 마지막 순번 추출

    패턴: {과목코드}_{주차}_{순번}.확장자
    예: 15521532_4_01.mp4 → 1
        15521532_4_02.mp3 → 2
    """
    name = os.path.splitext(os.path.basename(filename))[0]
    # 마지막 _ 뒤의 숫자가 순번
    m = re.search(r'_(\d+)$', name)
    if m:
        return int(m.group(1))
    return None

def extract_week_number(filename):
    """파일명에서 주차 번호 추출

    패턴: {과목코드}_{주차}_{순번}.확장자
    예: 15521532_4_01.mp4 → 4
    """
    name = os.path.splitext(os.path.basename(filename))[0]
    parts = name.split('_')
    if len(parts) >= 3:
        try:
            return int(parts[-2])
        except ValueError:
            pass
    return None
```

## 3단계: 오디오 추출

영상에서 오디오 트랙을 추출한다. 강의녹음/ 폴더에 동일 이름의 MP3가 이미 있으면 추출을 건너뛴다.

```python
import subprocess

def extract_audio(video_path, course_path):
    """MP4에서 오디오 트랙을 MP3로 추출 (영상과 동일 파일명)"""
    # 강의녹음 폴더 찾기 (NFD-safe — resolve_subdir 사용)
    recording_dir = resolve_subdir(course_path, '강의녹음')
    if not recording_dir:
        recording_dir = os.path.join(course_path, '강의녹음')
        os.makedirs(recording_dir, exist_ok=True)

    # 영상 파일명과 동일한 이름으로 MP3 저장
    base_name = os.path.splitext(os.path.basename(video_path))[0]
    output_path = os.path.join(recording_dir, f'{base_name}.mp3')

    # 이미 MP3가 존재하면 건너뛰기
    if os.path.exists(output_path):
        size_mb = os.path.getsize(output_path) / (1024 * 1024)
        print(f"이미 존재: {nfc(base_name)}.mp3 ({size_mb:.1f}MB) — 건너뜀")
        return output_path

    cmd = [
        'ffmpeg', '-i', video_path,
        '-q:a', '0', '-map', 'a',
        output_path, '-y'
    ]
    result = subprocess.run(cmd, capture_output=True, text=True)

    if result.returncode == 0:
        size_mb = os.path.getsize(output_path) / (1024 * 1024)
        print(f"오디오 추출 완료: {nfc(base_name)}.mp3 ({size_mb:.1f}MB)")
        return output_path
    else:
        print(f"오류: {result.stderr}")
        return None
```

## 4단계: VM 경로 → Mac 로컬 경로 변환

whisper-mcp는 Mac 로컬 경로에서만 파일에 접근 가능합니다. 추출된 MP3의 VM 마운트 경로를 실제 Mac 절대 경로로 변환해야 합니다.

```python
def vm_to_mac_path(vm_path):
    """VM 마운트 경로 → Mac iCloud 로컬 경로 변환

    예시:
      입력:  /sessions/.../mnt/[4-1] 파이썬데이터분석/강의녹음/15521532_4_01.mp3
      출력:  /Users/cjrain/Library/Mobile Documents/com~apple~CloudDocs/보관함(iCloud)/SCU/[4-1] 파이썬데이터분석/강의녹음/15521532_4_01.mp3
    """
    parts = vm_path.split('/mnt/', 1)
    if len(parts) < 2:
        raise ValueError(f"Invalid VM path: {vm_path}")

    relative_path = parts[1]
    mac_base = '/Users/cjrain/Library/Mobile Documents/com~apple~CloudDocs/보관함(iCloud)/SCU'
    mac_path = os.path.join(mac_base, relative_path)
    return mac_path
```

## 5단계: whisper-mcp 비동기 전사

추출된 MP3 (또는 기존 MP3)를 whisper-mcp로 비동기 전사합니다. 모든 MP3를 제출한 후 폴링하여 완료를 기다립니다.

**⚠️ 중요**: `options.model`을 반드시 명시해야 합니다. 기본값이 `base.en`이므로 생략하면 한국어 전사 품질이 극도로 저하됩니다.

```python
import time

def transcribe_all_for_week_async(course_path, week):
    """해당 주차의 모든 MP3를 whisper-mcp로 비동기 전사

    Returns:
        dict: {순번: 전사텍스트} 예: {1: "안녕하세요...", 2: "이번 시간에는..."}
    """
    # 강의녹음 폴더 찾기 (NFD-safe — resolve_subdir 사용)
    recording_dir = resolve_subdir(course_path, '강의녹음')
    if not recording_dir:
        return {}

    # 해당 주차 MP3 필터링
    mp3_files = []
    for f in sorted(os.listdir(recording_dir)):
        if not f.lower().endswith('.mp3'):
            continue
        if f'_{week}_' in f or f'_{week:02d}_' in f:
            mp3_files.append(os.path.join(recording_dir, f))

    if not mp3_files:
        print(f"{week}주차 MP3 파일이 없습니다")
        return {}

    # 과목별 전문 용어 로드 (initial_prompt용)
    terms = load_whisper_terms(course_path)
    if terms:
        print(f"whisper-terms.txt 로드됨 ({len(terms)} chars)")

    print(f"{week}주차 MP3 {len(mp3_files)}개 발견 — whisper-mcp 제출 시작")

    # Step 1: 모든 MP3를 비동기로 제출 (job_id 즉시 반환)
    job_map = {}  # {job_id: (순번, Mac 경로, 파일명)}
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

        if len(completed_jobs) < len(job_map):
            time.sleep(poll_interval)

    return transcripts
```

**주의사항**:
- `transcribe_async`는 MCP 도구이므로 Python 코드 내에서 직접 호출 가능
- Mac 경로(`/Users/...`)를 사용해야 whisper-mcp가 파일에 접근 가능
- 모든 job_id를 먼저 수집한 후 폴링을 시작하여 병렬 처리 효율화
- 60초 MCP 타임아웃 때문에 30-60초 간격의 폴링 필요

## 6단계: 스크립트 TXT에 전사 텍스트 삽입

전사된 텍스트를 스크립트 TXT의 `<강의녹음 스크립트>` 구역 내 대응하는 `##(N)` 아래에 삽입한다.

### 스크립트 TXT가 이미 존재하는 경우

학습목차가 이미 준비된 스크립트 TXT가 있으면, `<강의녹음 스크립트>` 구역의 `##(N)` 아래에 전사 텍스트를 삽입한다.

```python
import re

def insert_transcripts_into_script(script_path, transcripts):
    """기존 스크립트 TXT의 ##(N) 아래에 전사 텍스트 삽입

    Args:
        script_path: 스크립트 TXT 파일 경로
        transcripts: {순번: 전사텍스트} 딕셔너리
    """
    with open(script_path, 'r', encoding='utf-8') as f:
        content = f.read()

    # <강의녹음 스크립트> 구역 찾기
    script_match = re.search(
        r'(<[^>]+강의녹음\s*스크립트>)',
        content
    )
    if not script_match:
        print("경고: <강의녹음 스크립트> 구역을 찾을 수 없습니다")
        return False

    # ##(N) 패턴 찾아서 전사 텍스트 삽입
    # 강의녹음 스크립트 구역 내의 ##(N) 뒤에 텍스트 삽입
    script_section_start = script_match.end()
    before = content[:script_section_start]
    after = content[script_section_start:]

    for seq in sorted(transcripts.keys()):
        text = transcripts[seq]
        # ##(N) 패턴 바로 뒤(다음 줄)에 텍스트 삽입
        pattern = rf'(##\({seq}\)[^\n]*\n)'
        replacement = rf'\g<1>{text}\n'
        after = re.sub(pattern, replacement, after, count=1)

    new_content = before + after

    with open(script_path, 'w', encoding='utf-8') as f:
        f.write(new_content)

    print(f"전사 텍스트 삽입 완료: {len(transcripts)}개 순번")
    return True
```

### 스크립트 TXT가 없는 경우

스크립트 TXT 자체가 없으면, `<강의녹음 스크립트>` 구역만 포함한 기본 스크립트를 생성한다. 학습목차는 나중에 `prepare-script` 스킬로 추가한다.

```python
def create_script_with_transcripts(course_path, course_name, week, transcripts):
    """전사 텍스트로 스크립트 TXT 생성 (학습목차 구역은 비워둠)

    Args:
        course_path: 과목 폴더 경로
        course_name: 과목명 (NFC 정규화된)
        week: 주차 번호
        transcripts: {순번: 전사텍스트} 딕셔너리
    """
    # 스크립트 폴더 찾기/생성 (NFD-safe — resolve_subdir 사용)
    script_dir = resolve_subdir(course_path, '스크립트')
    if not script_dir:
        script_dir = os.path.join(course_path, '스크립트')
        os.makedirs(script_dir, exist_ok=True)

    # 스크립트 구역 생성
    lines = []
    lines.append(f'<{course_name} {week}주차 강의녹음 스크립트>')
    for seq in sorted(transcripts.keys()):
        lines.append(f'##({seq})')
        lines.append(transcripts[seq])

    content = '\n'.join(lines) + '\n'

    # 기존 스크립트 파일이 있는지 확인
    existing_script = find_existing_script(script_dir, week)
    if existing_script:
        # 기존 파일에 삽입 시도
        success = insert_transcripts_into_script(existing_script, transcripts)
        if success:
            return existing_script

    # 새 파일 생성 — 파일명은 기존 스크립트 명명 패턴을 따름
    filename = f'[{week:02d}주차] 스크립트.txt'
    filepath = os.path.join(script_dir, filename)

    with open(filepath, 'w', encoding='utf-8') as f:
        f.write(content)

    print(f"스크립트 생성: {nfc(filename)}")
    print("※ 학습목차는 prepare-script 스킬로 추가하세요")
    return filepath

def find_existing_script(script_dir, week):
    """해당 주차의 기존 스크립트 파일 찾기"""
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

## 8단계: 슬라이드 프레임 캡처 (장면 전환 감지)

영상에서 화면이 크게 바뀌는 시점(슬라이드 전환)을 감지하여 핵심 프레임만 캡처한다.

### 방법 A: ffmpeg scene 필터 (권장)

```bash
# 장면 전환 감지 — 변화율 0.3 이상인 프레임 캡처
ffmpeg -i "영상파일.mp4" -vf "select='gt(scene,0.3)'" -vsync vfr "frames/frame_%04d.jpg" -y
```

```python
import subprocess, os

def capture_slide_frames(video_path, seq, week, threshold=0.3):
    """장면 전환 감지로 슬라이드 프레임 캡처 (순번별 폴더 분리)"""
    output_dir = os.path.join(SESSION_BASE, f'video_frames_{week:02d}', f'seq_{seq:02d}')
    os.makedirs(output_dir, exist_ok=True)

    cmd = [
        'ffmpeg', '-i', video_path,
        '-vf', f"select='gt(scene,{threshold})'",
        '-vsync', 'vfr',
        os.path.join(output_dir, 'frame_%04d.jpg'),
        '-y'
    ]
    result = subprocess.run(cmd, capture_output=True, text=True)

    frames = sorted([
        os.path.join(output_dir, f)
        for f in os.listdir(output_dir)
        if f.endswith('.jpg')
    ])
    print(f"  ##({seq}) 프레임 캡처: {len(frames)}개")
    return frames
```

- `threshold`(0.0~1.0): 값이 낮을수록 더 많은 프레임 캡처
- 기본값 0.3은 슬라이드 전환 수준의 큰 변화만 감지
- 캡처가 너무 많으면 0.4~0.5로, 너무 적으면 0.2로 조절

### 방법 B: 일정 간격 캡처 (대안)

장면 감지가 잘 안 되는 경우 30초 간격으로 캡처:

```bash
ffmpeg -i "영상파일.mp4" -vf "fps=1/30" "frames/frame_%04d.jpg" -y
```

## 9단계: 타임스탬프 매핑

캡처된 프레임의 시간 정보를 추출하여 학습목록과 매핑한다.

```python
import subprocess, json, os

def get_frame_timestamps(video_path, threshold=0.3):
    """장면 전환 프레임의 타임스탬프 추출"""
    cmd_alt = [
        'ffmpeg', '-i', video_path,
        '-vf', f"select='gt(scene,{threshold})',showinfo",
        '-vsync', 'vfr',
        '-f', 'null', '-'
    ]
    result = subprocess.run(cmd_alt, capture_output=True, text=True)

    timestamps = []
    for line in result.stderr.split('\n'):
        if 'pts_time' in line:
            try:
                pts = float(line.split('pts_time:')[1].split()[0])
                minutes = int(pts // 60)
                seconds = int(pts % 60)
                timestamps.append({
                    'seconds': pts,
                    'display': f'{minutes:02d}:{seconds:02d}'
                })
            except (IndexError, ValueError):
                continue

    return timestamps

def format_timestamp_map(timestamps, frames):
    """타임스탬프와 프레임을 매핑하여 표시"""
    result = []
    for i, (ts, frame) in enumerate(zip(timestamps, frames)):
        result.append(f"| {i+1} | {ts['display']} | {os.path.basename(frame)} |")
    return result
```

## 10단계: 프레임 내용 분석

캡처된 슬라이드 프레임을 Read 도구로 시각적으로 읽어 내용을 파악한다.

- 10~15개씩 나누어 읽기
- 각 프레임의 핵심 내용(제목, 키워드, 다이어그램 설명)을 메모
- 중복 프레임(같은 슬라이드)은 제거

이 정보를 `create-note` 스킬에서 강의교안 PDF 대신 활용할 수 있다.

## 11단계: 결과 정리

### 출력물

1. **MP3 파일** → 강의녹음/ 폴더 저장 (영상과 동일 파일명)
2. **전사 텍스트** → 스크립트/ 폴더의 TXT 파일 `##(N)` 구역에 삽입
3. **슬라이드 프레임** → 세션 임시 폴더 저장 (create-note에서 참조)
4. **타임스탬프 맵** → 텍스트로 사용자에게 제공

### 타임스탬프 맵 예시

```
| # | 시간 | 주제 |
|---|------|------|
| 1 | 00:00 | 강의 시작 — 지난 주 복습 |
| 2 | 03:45 | 선형 회귀 개요 |
| 3 | 12:20 | 손실 함수 설명 |
| 4 | 25:10 | 실습: Python 코드 |
| 5 | 40:30 | Q&A |
```

## 전체 워크플로우

```
1. 과목·주차 파악 → 강의영상/ 폴더에서 MP4 탐색 + whisper-terms.txt 로드
2. 영상 파일명에서 순번 추출 ({과목코드}_{주차}_{순번}.mp4)
3. 오디오 추출 → 강의녹음/ 폴더에 MP3 저장 (이미 있으면 건너뜀)
4. Whisper 전사 → 순번별 텍스트 생성 (model + initial_prompt 명시)
5. LLM 후처리 — 전문 용어 교정 + 환각 제거
6. 스크립트 TXT의 ##(N) 구역에 교정된 전사 텍스트 삽입
7. (선택) 장면 전환 감지 → 슬라이드 프레임 캡처
8. (선택) 타임스탬프 추출 및 매핑
9. (선택) 프레임 시각적 읽기 → 슬라이드 내용 파악
10. 결과 정리 및 안내
```

> **핵심 변경 (v0.6.0)**: model을 medium으로 변경(환각 없음), whisper-terms.txt 기반 initial_prompt 전달, LLM 후처리(전문 용어 교정 + 환각 제거) 추가.

## new-week 워크플로우와의 연결

`extract-video`를 실행하면 MP3 + 전사 텍스트 + 슬라이드 프레임이 모두 준비되므로:
- 전사 텍스트는 이미 스크립트 TXT의 `##(N)` 아래에 삽입됨
- `prepare-script` → 학습목차만 추가하면 스크립트 완성
- `create-note` → 스크립트 + 강의교안 + 실습을 종합하여 강의노트 작성
- 슬라이드 프레임 → `create-note`에서 강의교안 PDF 대신 참조 가능

## 흔한 오류와 해결

| 오류 | 원인 | 해결 |
|------|------|------|
| `ffmpeg: command not found` | ffmpeg 미설치 | `apt-get install -y ffmpeg` |
| FileNotFoundError | Mac에 MP3 파일이 없음 | Mac Finder에서 강의녹음 폴더를 열어 iCloud 동기화 트리거 |
| whisper-mcp job_id 없음 | transcribe_async 호출 실패 | Mac의 whisper-mcp MCP 서버 실행 상태 확인 |
| check_job status='failed' | 전사 처리 중 오류 발생 | 파일 형식(MP3) 확인, 파일 손상 검사, whisper-mcp 로그 확인 |
| 부분 전사 또는 시간 초과 | 파일이 크거나 whisper-mcp 처리 지연 | 60초 폴링 타임아웃 고려, 재시도 |
| VM 경로 변환 실패 | 과목명 형식 불일치 | 경로 패턴 확인: `/mnt/[4-1] 파이썬데이터분석/...` |
| 프레임이 0개 캡처됨 | threshold 너무 높음 | threshold를 0.2 또는 0.15로 낮춤 |
| 프레임이 수백 개 | threshold 너무 낮음 | threshold를 0.4~0.5로 높임 |
| 오디오 추출 실패 | 오디오 트랙 없음 | `-map a` 제거 후 재시도 |
| 경로 오류 | 특수문자/NFD | `os.listdir()` + `os.path.join()` + `nfc()` 패턴 |
| 파일 저장 후 사용자 워크스페이스에 안 보임 | iCloud NFD/NFC 인코딩 불일치 | `os.listdir()` 원본 경로 사용 + 저장 후 NFD 경로 검증 |
| 서브디렉토리(강의영상/, 강의녹음/) 못 찾음 | NFC 하드코딩 경로로 `os.path.isdir()` 실패 | `resolve_subdir()` 패턴으로 서브디렉토리 해석 |
| whisper-mcp 후 경로가 무효화됨 | whisper-mcp가 VM 재시작/마운트 갱신 유발 | 전사 완료 후 `os.listdir()`로 모든 경로 재획득 |
| ##(N) 삽입 실패 | 스크립트에 해당 ##(N) 없음 | 스크립트에 ##(N) 구역이 있는지 확인, 없으면 새로 생성 |
