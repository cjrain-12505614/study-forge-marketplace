---
name: prepare-script
description: >
  강의 스크립트 TXT 파일에 학습목차(강의 세부목록)를 추가하고 구조화하는 스킬.
  사용자가 "스크립트 정리해줘", "학습목록 추가해줘", "스크립트에 목차 넣어줘",
  "prepare-script" 등을 요청하거나, 학습목차 텍스트를 붙여넣으며 정리를 요청할 때 사용한다.
  학습목차를 #/## 헤더로 구성하고, 영상 순번 ##(N)을 매기고, 스크립트 TXT에 저장한다.
  목차가 아직 확정되지 않았으면 confirm-toc 스킬을 먼저 실행한다 (v0.4.0).
version: 0.4.0
---

# 학습목차 + 스크립트 정리 스킬

사용자가 붙여넣은 학습목차를 구조화하여 스크립트 TXT 파일에 저장한다. 이 학습목차는 강의노트 작성 시 **제목 구조(#/##)와 가로선(---) 위치를 확정**하는 기준점이 된다.

## 시작 전 필수

1. 워크스페이스 `CLAUDE.md`와 **과목 폴더 `CLAUDE.md`**를 읽는다
2. 같은 종류의 **기존 산출물을 열어 형식을 확인**한다
3. 확인할 수 없는 값은 **비워 두고 채울 방법을 안내**한다 — 그럴듯한 추정값 금지

## 학습목차는 어디서 오는가

| 경로 | 상황 |
|---|---|
| **사용자 붙여넣기** | 사용자가 강의 사이트에서 복사해 준다 |
| **`confirm-toc` 결과** | 하위 목차가 수강해야만 보이는 강의실 구조일 때. 이 스킬의 선행 단계 |

⛔ **전사 내용을 읽고 목차명을 지어내지 말 것.** 전사 도입부가 "머신러닝을 살펴보겠습니다"라고 해서 목차명이 `머신러닝`인 것은 아니다. 목차가 없으면 **빈칸으로 두고** `confirm-toc`로 확보한다.

## 스크립트 파일 구조

스크립트 TXT 파일은 두 개의 구역으로 구성된다:

```
<과목명 N주차 학습목차>

#들어가기
##학습개요
---
#첫 번째 주제
##(1)첫 번째 주제 실습
---
#두 번째 주제
##(2)두 번째 주제 실습
---
#평가하기
##학습평가
---
#정리하기
##학습정리


<과목명 N주차 강의녹음 스크립트>

##(1)첫 번째 주제 실습
(여기에 전사 텍스트)


##(2)두 번째 주제 실습
(여기에 전사 텍스트)
```

### 구역 설명

- **학습목차 구역**: `<과목명 N주차 학습목차>` 태그 아래에 위치. 강의노트의 제목 구조를 확정함
- **강의녹음 스크립트 구역**: `<과목명 N주차 강의녹음 스크립트>` 태그 아래에 위치. `##(N)` 제목 아래에 전사된 텍스트가 들어감

### 학습목차 헤더 규칙

- `#제목` → 강의노트의 `# 제목` (최상위 항목)
- `##서브제목` → 강의노트의 `## 서브제목` (하위 항목)
- `##(N)서브제목` → 강의노트의 `## (N) 서브제목`. `(N)`은 영상 파일의 순번과 대응
  - 예: `##(1)pandas 데이터 형태 이해 실습` → 영상 `15521532_4_01.mp4`의 `_01`과 대응
  - 예: `##(3)DataFrame에서 필요한 데이터 선택 실습` → 영상 `_03`과 대응
- `---` → 강의노트에서 `#` 타이틀 그룹 간 가로선. 학습목차에 명시된 위치에만 삽입
- `#들어가기`, `##학습개요`, `#평가하기`, `##학습평가`, `#정리하기`, `##학습정리` → 영상 자료가 없어도 강의노트에 반드시 포함되는 필수 섹션

### 영상 순번 매핑

`##(N)` 의 `N`은 강의영상·MP3 파일명의 순번과 일치한다:
- 파일명 패턴: `{강의코드}_{주차}_{순번}.mp4` / `.mp3`
- 예: `15521532_4_01.mp4` → `##(1)`, `15521532_4_02.mp4` → `##(2)`
- 전사(transcribe) 시에도 이 순번 기준으로 `##(N)` 아래에 텍스트를 삽입함

#### ⚠️ 순번과 목차 순서는 어긋날 수 있다

**번호 없는 항목이 앞에 올 수 있다.** 매 주차 첫 영상은 18초 내외의 **`인트로`(타이틀 영상)** 이고, 여기에는 **MP3가 없다.** 목차상 첫 항목이지만 첫 MP3(`_01`)는 그다음 항목에 붙는다.

```
# 들어가기
## 인트로               ← 영상만 있음, MP3 없음 → 번호 없음
## (1)학습개요          ← 여기가 _01.mp3
```

`평가하기/학습평가`·`정리하기/학습정리`도 영상·MP3가 없어 번호를 붙이지 않는다.

**첫 MP3를 목차 첫 줄에 기계적으로 붙이면 전체가 한 칸씩 밀린다.** 순번 확정은 반드시 **영상 길이와 MP3 길이 대조**(`confirm-toc` 3단계)로 한다.

### ⚠️ 스크립트 수정 시 인덱스 기반 편집 금지

학습목차 구역과 강의녹음 스크립트 구역에 **`##학습평가` 같은 동일 문자열이 두 번** 나온다. `s.index('##학습평가')`로 자르면 목차 쪽을 잡아 **파일 뒷부분이 통째로 날아간다.**

- **소스에서 재생성**하는 방식을 기본으로 한다
- 부분 수정이 필요하면 앞뒤 문맥을 포함한 **유일한 문자열**을 앵커로 쓴다
- 수정 후 **구역 개수와 파일 크기를 검증**한다

## 1단계: 과목 및 주차 파악

과목 폴더 자동 인식 방법은 transcribe 스킬과 동일하다.

```python
import os, unicodedata

SESSION_BASE = '/sessions/{session_id}'
MNT = os.path.join(SESSION_BASE, 'mnt')

SYSTEM_DIRS = {'uploads', '.claude', '.skills', '.local-plugins',
               '.cowork-lib', '.cowork-perm-req', '.cowork-perm-resp'}

def nfc(s):
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

    os.path.join(course_path, '스크립트') 처럼 NFC 이름을 하드코딩하면
    NFD로 저장된 디렉토리를 찾지 못한다. 반드시 이 함수를 사용한다.
    """
    nfc_target = nfc(target_name)
    for sub in os.listdir(course_path):
        if nfc(sub) == nfc_target and os.path.isdir(os.path.join(course_path, sub)):
            return os.path.join(course_path, sub)
    return None
```

사용자 요청에서 과목명과 주차를 파악한다. 과목명의 일부만 입력해도 폴더명에 포함되면 매칭한다. 불명확하면 질문한다.

## 2단계: 학습목차 수집

사용자에게 학습목차 텍스트를 요청한다. 사용자는 이미 `#`/`##`/`---` 형식으로 작성하여 붙여넣는다.

학습목차 예시 (사용자가 붙여넣는 원본):
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

**이 형식이 강의노트의 최종 제목 구조를 확정한다.** 사용자가 붙여넣은 `#`/`##`/`---` 구조를 그대로 사용하며, 임의로 변형하지 않는다.

## 3단계: 학습목차 검증

사용자가 붙여넣은 학습목차를 검증한다:

- `#`으로 시작하는 줄이 1개 이상 있는지
- `##(N)` 형식의 영상 대응 항목이 있는지
- `---` 가로선이 `#` 그룹 사이에 있는지
- 필수 섹션(`#들어가기`/`##학습개요`, `#평가하기`/`##학습평가`, `#정리하기`/`##학습정리`)이 포함되어 있는지

누락된 필수 섹션이 있으면 사용자에게 알려준다 (자동 추가하지 않음).

```python
import re

def validate_outline(outline_text):
    """학습목차 검증"""
    lines = outline_text.strip().split('\n')
    issues = []

    has_h1 = any(l.strip().startswith('#') and not l.strip().startswith('##') for l in lines)
    has_numbered = any(re.match(r'##\(\d+\)', l.strip()) for l in lines)
    has_hr = any(l.strip() == '---' for l in lines)

    required_h1 = ['#들어가기', '#평가하기', '#정리하기']
    required_h2 = ['##학습개요', '##학습평가', '##학습정리']

    for req in required_h1 + required_h2:
        if not any(l.strip() == req for l in lines):
            issues.append(f"필수 섹션 누락: {req}")

    if not has_h1:
        issues.append("# 최상위 항목이 없음")
    if not has_numbered:
        issues.append("##(N) 영상 대응 항목이 없음")
    if not has_hr:
        issues.append("--- 가로선이 없음")

    return issues
```

## 4단계: 스크립트 파일 생성

학습목차와 강의녹음 스크립트 구역을 결합하여 TXT 파일을 생성한다.

```python
import os, re, unicodedata

def build_script_file(course_name, week, outline_text):
    """학습목차 + 스크립트 구역을 결합하여 TXT 파일 내용 생성"""
    # 학습목차에서 ##(N) 항목 추출
    numbered_sections = re.findall(r'(##\(\d+\).+)', outline_text)

    # 강의녹음 스크립트 구역 생성
    script_section = f"<{course_name} {week}주차 강의녹음 스크립트>\n\n"
    for section in numbered_sections:
        script_section += f"{section}\n\n\n\n\n"

    # 전체 파일 구성
    content = f"<{course_name} {week}주차 학습목차>\n\n"
    content += outline_text.strip()
    content += f"\n\n\n{script_section}"

    return content

def nfc(s):
    return unicodedata.normalize('NFC', s)

def save_script(course_path, week, content):
    """스크립트 파일 저장 (NFD-safe — resolve_subdir 사용)"""
    script_dir = resolve_subdir(course_path, '스크립트')
    if not script_dir:
        script_dir = os.path.join(course_path, '스크립트')
    os.makedirs(script_dir, exist_ok=True)

    filename = f'{week:02d}주차-스크립트.txt'

    # 기존 파일 탐색 (주차 번호로 매칭) — 원본 파일명 유지
    week_str = f'{week:02d}'
    for f in os.listdir(script_dir):
        nfc_name = nfc(f)
        if week_str in nfc_name and nfc_name.endswith('.txt'):
            filename = f  # 원본 파일명(NFD 가능) 유지
            break

    filepath = os.path.join(script_dir, filename)
    with open(filepath, 'w', encoding='utf-8') as fh:
        fh.write(content)

    print(f"스크립트 저장 완료: {nfc(filename)}")
    return filepath
```

### ⚠️ NFD 경로 안전 읽기+쓰기 (필수)

iCloud Drive의 한글 폴더명은 macOS NFD 인코딩으로 저장된다. NFC 문자열로 경로를 지정하면:
- **읽기 실패**: `os.path.exists()`, `os.path.isdir()`, Read/Glob 도구가 파일을 찾지 못함
- **쓰기 실패**: 같은 이름의 새 폴더가 별도로 생성되어 iCloud와 동기화되지 않음

- **절대 금지**: 하드코딩된 한글 경로 문자열로 Read/Write/Edit 도구 호출
- **반드시**: `os.listdir()` 또는 `resolve_subdir()`로 원본 경로 획득 → 그 결과를 도구에 전달
- **저장 후 검증**: NFD 경로에 파일이 존재하는지 확인하고, 없으면 NFC→NFD 복사 수행
- **전사(다글로) 후**: VM 재시작 가능성으로 인해 모든 경로를 `os.listdir()`로 재획득

## 5단계: 완료 안내

정리 완료 후 사용자에게 안내:
1. 스크립트 파일에 학습목차와 스크립트 구역이 저장됨
2. 학습목차의 `#`/`##`/`---` 구조가 강의노트의 제목 구조로 그대로 사용됨
3. `##(N)` 항목은 영상 파일 순번과 대응되며, 전사(transcribe) 시 해당 위치에 텍스트가 삽입됨
4. 다음 단계: `/transcribe` 또는 `/create-note` 커맨드로 진행

## 전체 워크플로우

```
1. 과목·주차 파악
2. 사용자에게 학습목차 텍스트 요청 (이미 #/##/--- 형식으로 작성됨)
3. 학습목차 검증 (필수 섹션, ##(N) 항목, --- 위치 확인)
4. 학습목차 + 강의녹음 스크립트 구역을 결합하여 TXT 파일 생성
5. 스크립트/ 폴더에 저장
```

## 주의사항

- 사용자가 붙여넣은 `#`/`##`/`---` 구조를 **그대로 보존**한다. 임의로 제목을 변경하거나 순서를 바꾸지 않음
- `##(N)` 순번은 영상 파일의 `_0N` 순번과 정확히 대응해야 함
- 이미 학습목차가 삽입된 스크립트(`<과목명 N주차 학습목차>` 태그 존재)는 덮어쓰기 전에 사용자에게 확인
- `#들어가기`/`##학습개요`, `#평가하기`/`##학습평가`, `#정리하기`/`##학습정리`는 영상 자료 없이도 필수로 포함
- 학습목차와 강의녹음 스크립트 구역 사이에 빈 줄 2개를 넣어 구분
