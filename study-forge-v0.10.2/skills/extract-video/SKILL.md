---
name: extract-video
description: >
  강의영상 MP4에서 슬라이드 프레임 캡처, 오디오 추출, 다글로(daglo) 전사, 스크립트 TXT 생성을 수행하는 스킬 (v0.7.0).
  사용자가 "영상에서 슬라이드 뽑아줘", "MP4 처리해줘", "영상에서 오디오 추출해줘",
  "강의영상 분석해줘", "extract-video" 등을 요청할 때 사용한다.
  ffmpeg으로 프레임과 오디오를 추출하고, 다글로 MCP로 전사하여 스크립트 TXT의 ##(N) 구역에 삽입한다.
version: 0.7.0
---

# 강의영상 처리 스킬 (다글로 MCP)

강의영상 MP4에서 슬라이드 프레임 캡처, 오디오 추출, 다글로(daglo) 전사를 수행하고, 전사 결과를 스크립트 TXT의 `##(N)` 구역에 자동 삽입한다. 전사 후 LLM 후처리로 전문 용어 오인식 교정 및 환각 제거를 수행한다.

## ⚠️ 실행 전 반드시 지킬 2가지

1. **유료 크레딧 소모** — 다글로 전사는 유료다. `start_transcription(dry_run=False)`를 호출하기 **전에 반드시 사용자 승인을 받는다**. 주차 단위 처리는 영상이 여러 개라 크레딧이 배수로 소모되므로, **대상 파일 목록과 개수를 먼저 제시하고 확인받는다**.
2. **클라우드 업로드** — 강의 오디오가 다글로 서버로 전송된다. 로컬 처리가 아니다. 외부 반출이 곤란한 강의면 진행 전 사용자에게 확인한다.

> 프레임 캡처·오디오 추출(ffmpeg)은 전부 로컬이며 무료다. 과금 지점은 **전사 시작**뿐이다. 따라서 **프레임 작업을 먼저 하고 전사는 승인 후에** 진행해도 된다.

## 의존성 및 환경

**로컬 도구**:
- **ffmpeg**: 오디오 추출 및 슬라이드 프레임 캡처 (설치: `apt-get install -y ffmpeg`)

**MCP 서버**:
- **다글로 MCP**: 전역 `~/.claude.json`에 등록된 MCP 서버 (워크스페이스 `.mcp.json`에는 없음)
  - `mcp__daglo__upload_file(file_path)` → `fileMetaId` 발급 (무료, 전사의 선행 단계)
  - `mcp__daglo__start_transcription(file_meta_ids[], language, topic, use_dictionary, use_speaker_diarization, dry_run)` → ⚠️ 유료
  - `mcp__daglo__get_file_status(file_meta_id)` → 상태 폴링
  - `mcp__daglo__get_transcript(file_meta_id, with_time, save_path)` → 평문 + 세그먼트 회수
  - `mcp__daglo__transcribe_file(file_path, confirm=True, ...)` → 원스톱. **단일 파일**에 적합
  - 경로: **Mac 절대 경로** 사용 (VM 마운트 경로 아님)

### 전사 옵션 기본값 (강의 녹음 기준)

| 옵션 | 값 | 이유 |
|------|-----|------|
| `language` | `ko-KR` | 한국어 강의 |
| `topic` | `IT` | 전공 분야에 맞게 조정 (전문용어 인식률에 영향) |
| `use_dictionary` | `True` | 다글로 계정 사전 활용 |
| `use_speaker_diarization` | **`False`** | 강의는 사실상 단일 화자. 화자 라벨이 붙으면 `##(N)` 구역이 오염됨 |
| `with_time` | **`False`** | 타임스탬프가 섞이면 스크립트 본문이 오염됨. 평문으로 받아 그대로 삽입 |

> **whisper-terms.txt의 역할 변경 (중요)**: 다글로에는 whisper의 `initial_prompt`에 해당하는 인자가 **없다**. 따라서 `whisper-terms.txt`는 더 이상 전사 엔진에 사전 힌트로 전달되지 않으며, **7단계 LLM 후처리의 참조 용어집으로만** 사용한다. 엔진 단계에서 용어 인식률을 올리려면 **다글로 웹에서 계정 사전에 전문 용어를 등록**하고 `use_dictionary=True`로 쓴다. 파일명은 기존 과목 폴더 호환을 위해 `whisper-terms.txt` 그대로 유지한다.
>
> 슬라이드 프레임(8~10단계)에서 읽어낸 화면 속 용어는 후처리 교정의 강력한 근거가 된다 — 영상이 있는 이 스킬에서는 프레임을 먼저 훑고 후처리하면 정확도가 올라간다.

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

    ⚠️ 다글로에는 initial_prompt가 없으므로 이 용어집은 전사 엔진에 전달되지 않는다.
    7단계 LLM 후처리에서 오인식 교정의 참조 기준으로만 사용한다.
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

다글로 MCP는 Mac 로컬에서 실행되므로 Mac 절대 경로에서만 파일에 접근 가능하다. 추출된 MP3의 VM 마운트 경로를 실제 Mac 절대 경로로 변환해야 한다.

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

    relative_path = parts[1]
    # 홈 경로를 하드코딩하지 않는다 — 맥 이관 시 조용히 깨진다
    mac_base = os.path.join(
        os.path.expanduser('~'),
        'Library/Mobile Documents/com~apple~CloudDocs/보관함(iCloud)/SCU'
    )
    mac_path = os.path.join(mac_base, relative_path)
    return mac_path
```

## 5단계: 다글로 전사 (업로드 → 승인 → 전사 → 회수)

추출된 MP3(또는 기존 MP3)를 다글로로 전사한다. 주차 단위 처리는 파일이 여러 개이므로 **원스톱 `transcribe_file`을 파일마다 반복하지 않고**, 업로드를 일괄로 끝낸 뒤 `start_transcription`에 `file_meta_ids` 배열을 한 번에 넘긴다. 승인 게이트를 **정확히 1회**만 거치기 위해서도 이 구조가 낫다.

### 5-1. 업로드 (무료)

```python
def upload_all_for_week(course_path, week):
    """해당 주차의 모든 MP3를 다글로에 업로드 → {fileMetaId: (순번, 파일명)}

    업로드는 과금되지 않는다. 과금 지점은 5-3 전사 시작이다.
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

    print(f"{week}주차 MP3 {len(mp3_files)}개 발견 — 다글로 업로드 시작")

    meta_map = {}  # {fileMetaId: (순번, 파일명)}
    for mp3_path in mp3_files:
        seq = extract_sequence_number(mp3_path)
        if seq is None:
            print(f"  순번 추출 실패: {nfc(os.path.basename(mp3_path))}")
            continue

        # VM 경로를 Mac 로컬 경로로 변환
        mac_path = vm_to_mac_path(mp3_path)

        result = mcp__daglo__upload_file(file_path=mac_path)
        fid = result['fileMetaId']

        meta_map[fid] = (seq, nfc(os.path.basename(mp3_path)))
        print(f"  ##({seq}) 업로드 완료: {nfc(os.path.basename(mp3_path))} (id: {fid})")

    return meta_map
```

### 5-2. ⚠️ 승인 게이트 (필수 — 건너뛰지 말 것)

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

승인 없이 `dry_run=False`로 호출하지 않는다. 사용자가 거부하면 업로드된 파일은 그대로 두고 **프레임 캡처(8단계 이후)만 진행**한다 — 프레임 작업은 로컬이라 무료다.

### 5-3. 전사 시작 (⚠️ 유료 — 승인 후에만)

```python
def start_transcription_for_week(meta_map, topic='IT'):
    """승인 후 일괄 전사 시작. ⚠️ dry_run=False 는 과금된다."""
    if not meta_map:
        return

    mcp__daglo__start_transcription(
        file_meta_ids=list(meta_map.keys()),
        language='ko-KR',
        topic=topic,
        use_dictionary=True,
        use_speaker_diarization=False,  # 강의 = 단일 화자, ##(N) 오염 방지
        dry_run=False                   # ⚠️ 사용자 승인 후에만 False
    )
    print(f"전사 시작: {len(meta_map)}개 작업")
```

### 5-4. 상태 폴링 및 전사문 회수

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
- **전사를 기다리는 동안 8단계 프레임 캡처를 먼저 돌려도 된다** (로컬 작업이라 병행 가능)

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

> 다글로에는 `initial_prompt`가 없어 전사 엔진이 과목 용어를 미리 알지 못한다. 따라서 **이 후처리 단계의 중요도가 whisper 시절보다 높다** — 생략하지 말 것. 이 스킬은 슬라이드 프레임을 함께 확보하므로, 프레임에서 읽은 화면 속 용어를 교정 근거로 함께 활용한다.

### 처리 규칙

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
{슬라이드 프레임에서 읽어낸 화면 속 용어}

## 전사 텍스트
{다글로 출력}
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
1. 과목·주차 파악 → 강의영상/ 폴더에서 MP4 탐색 + whisper-terms.txt 로드(후처리용)
2. 영상 파일명에서 순번 추출 ({과목코드}_{주차}_{순번}.mp4)
3. 오디오 추출 → 강의녹음/ 폴더에 MP3 저장 (이미 있으면 건너뜀)  [로컬·무료]
4. VM 경로를 Mac 로컬 경로로 변환 + iCloud 오프로드 확인
5. 다글로 업로드 (무료) → fileMetaId 수집
6. ⚠️ 승인 게이트 — 대상·개수·옵션 제시 후 사용자 승인
7. start_transcription(dry_run=False) 일괄 전사 시작 (⚠️ 유료)
8. (병행 가능) 장면 전환 감지 → 슬라이드 프레임 캡처  [로컬·무료]
9. get_file_status 폴링 → get_transcript(with_time=False)로 평문 회수
10. LLM 후처리 — 전문 용어 교정 + 환각 제거 (프레임 속 용어 함께 참조)
11. 스크립트 TXT의 ##(N) 구역에 교정된 전사 텍스트 삽입
12. (선택) 타임스탬프 추출 및 매핑 / 프레임 시각적 읽기
13. 결과 정리 및 안내
```

> **핵심 변경 (v0.7.0)**: 전사 엔진을 whisper-mcp(로컬) → **다글로 MCP(클라우드)**로 전환. 유료 승인 게이트 신설, `initial_prompt` 부재로 `whisper-terms.txt`는 후처리 참조용으로 역할 축소, 화자분리·타임스탬프는 `##(N)` 오염 방지를 위해 기본 비활성. 프레임 캡처는 로컬·무료이므로 전사 대기 중 병행하거나 전사 거부 시에도 단독 수행 가능.

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
| `401 Invalid refresh token` | 다글로 토큰 만료 | 크롬에서 다글로 재로그인 후 토큰 재시드. 재시드 전까지 모든 다글로 호출 실패 |
| `QUOTA_EXCEEDED` | 크레딧/quota 소진 | 다글로 계정 크레딧 확인. 요약 quota는 전사와 별도 |
| FileNotFoundError | Mac에 MP3 파일이 없음 (iCloud 오프로드) | Mac Finder에서 강의녹음 폴더를 열어 iCloud 동기화 트리거 |
| `fileMetaId` 없음 | `upload_file` 실패 | 파일 크기·형식 확인, 다글로 인증 상태 확인 |
| 전사 상태가 계속 대기 | 서버 처리 지연 | 폴링 간격을 늘려 재시도. 타임아웃돼도 서버 전사는 계속되므로 `fileMetaId`로 나중에 회수 |
| 전사문에 화자 라벨이 섞임 | `use_speaker_diarization=True`로 호출됨 | 강의 전사는 반드시 `False`로 지정 |
| 전사문에 타임스탬프가 섞임 | `with_time=True`로 회수됨 | `get_transcript(with_time=False)`로 평문 회수 |
| 전문 용어가 대량 오인식 | `initial_prompt` 부재 (다글로 특성) | 7단계 LLM 후처리를 반드시 수행. 프레임 속 용어 참조. 다글로 웹 계정 사전에 용어 등록 권장 |
| VM 경로 변환 실패 | 과목명 형식 불일치 | 경로 패턴 확인: `/mnt/[4-1] 파이썬데이터분석/...` |
| 프레임이 0개 캡처됨 | threshold 너무 높음 | threshold를 0.2 또는 0.15로 낮춤 |
| 프레임이 수백 개 | threshold 너무 낮음 | threshold를 0.4~0.5로 높임 |
| 오디오 추출 실패 | 오디오 트랙 없음 | `-map a` 제거 후 재시도 |
| 경로 오류 | 특수문자/NFD | `os.listdir()` + `os.path.join()` + `nfc()` 패턴 |
| 파일 저장 후 사용자 워크스페이스에 안 보임 | iCloud NFD/NFC 인코딩 불일치 | `os.listdir()` 원본 경로 사용 + 저장 후 NFD 경로 검증 |
| 서브디렉토리(강의영상/, 강의녹음/) 못 찾음 | NFC 하드코딩 경로로 `os.path.isdir()` 실패 | `resolve_subdir()` 패턴으로 서브디렉토리 해석 |
| 전사 후 경로가 무효화됨 | MCP 호출이 VM 재시작/마운트 갱신 유발 | 전사 완료 후 `os.listdir()`로 모든 경로 재획득 |
| ##(N) 삽입 실패 | 스크립트에 해당 ##(N) 없음 | 스크립트에 ##(N) 구역이 있는지 확인, 없으면 새로 생성 |
