---
name: review
description: >
  강의노트를 기반으로 대화형 단계별 복습 세션을 진행하는 스킬.
  사용자가 "복습하자", "이번 주 복습", "review", "3주차 복습해줘",
  "강의 내용 다시 보자", "이해 안 되는 부분 있어" 등을 요청할 때 사용한다.
  강의노트를 섹션별로 나누어 한 단계씩 설명하고, 이해도 확인 질문을 던지며,
  사용자 응답에 따라 추가 설명 또는 다음 단계로 진행한다.
version: 0.1.0
---

# 대화형 복습 스킬

강의노트를 기반으로 섹션별 단계적 복습을 진행한다. 한꺼번에 전체를 쏟아내지 않고, 작은 단위로 설명 → 질문 → 피드백 → 다음 단계 순서로 진행한다.

## 핵심 원칙

- **한 번에 하나의 섹션만** 다룬다
- 각 섹션마다 **이해도 확인 질문**을 던진다
- 사용자가 질문하면 **충분히 답변**한 뒤 다음으로 넘어간다
- 사용자가 이미 아는 내용이면 **빠르게 건너뛴다**
- 절대 전체 내용을 한 번에 요약하지 않는다

## 1단계: 복습 대상 파악

과목과 주차를 파악하고, 해당 강의노트를 로드한다.

```python
import os

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

def load_note(course_path, week):
    note_dir = os.path.join(course_path, '강의노트')
    for f in os.listdir(note_dir):
        if f'{week:02d}' in f and f.endswith('.md'):
            return os.path.join(note_dir, f)
    return None
```

강의노트가 없으면 사용자에게 먼저 `/create-note`를 안내한다.

## 2단계: 섹션 분리

강의노트의 `#` 헤더를 기준으로 대단원을 나누고, 각 대단원 안의 `##` 헤더로 소단원을 나눈다.

```python
def split_sections(note_content):
    """강의노트를 대단원/소단원으로 분리"""
    sections = []
    current_major = None
    current_minor = None
    current_content = []

    for line in note_content.split('\n'):
        if line.startswith('# ') and not line.startswith('## '):
            # 이전 섹션 저장
            if current_major:
                sections.append({
                    'major': current_major,
                    'minor': current_minor,
                    'content': '\n'.join(current_content)
                })
            current_major = line[2:].strip()
            current_minor = None
            current_content = []
        elif line.startswith('## '):
            if current_content and current_major:
                sections.append({
                    'major': current_major,
                    'minor': current_minor,
                    'content': '\n'.join(current_content)
                })
            current_minor = line[3:].strip()
            current_content = []
        else:
            current_content.append(line)

    # 마지막 섹션
    if current_major and current_content:
        sections.append({
            'major': current_major,
            'minor': current_minor,
            'content': '\n'.join(current_content)
        })

    return sections
```

## 3단계: 복습 세션 진행

### 세션 시작

1. 총 섹션 수와 대단원 목록을 사용자에게 보여준다
2. "처음부터 할까요, 특정 부분부터 할까요?" 질문

### 각 섹션 진행 패턴

한 섹션을 다룰 때 아래 순서를 따른다:

#### A. 핵심 내용 제시 (간결하게)
- 해당 섹션의 핵심 개념을 3~5줄로 제시
- 전체 내용을 그대로 읽어주지 않음
- 중요 키워드를 강조

#### B. 이해도 확인 질문
- 해당 섹션과 관련된 질문 1개를 던진다
- 질문 유형은 섹션 내용에 따라 다양하게:
  - 개념 설명형: "~은 무엇인가요?"
  - 비교형: "~와 ~의 차이는?"
  - 적용형: "이 경우 어떤 방법을 쓰나요?"
  - 코딩형: "이 코드의 출력 결과는?"

#### C. 사용자 응답 처리

**맞은 경우:**
- 짧게 칭찬 + 핵심 포인트 보충 (1~2줄)
- "다음 섹션으로 넘어갈까요?"

**틀린 경우:**
- 틀린 이유를 친절하게 설명
- 정답과 함께 핵심 개념을 다시 설명
- "다시 한번 정리해볼까요, 아니면 넘어갈까요?"

**질문이 있는 경우:**
- 사용자의 질문에 충분히 답변
- 필요하면 비유, 예시, 코드로 보충 설명
- 추가 질문이 없을 때까지 대화 계속
- 질문 해결 후 "이 부분 이해됐으면 다음으로 넘어갈까요?"

#### D. 다음 단계 전환
- 사용자가 동의하면 다음 섹션으로
- "건너뛰기" 요청 시 해당 섹션 스킵
- "여기서 그만" 요청 시 세션 종료

## 4단계: 세션 종료

복습 세션이 끝나면:

1. **진행 요약** — 다룬 섹션 목록, 맞은/틀린 질문 수
2. **취약 포인트** — 틀리거나 추가 설명이 필요했던 부분 정리
3. **다음 단계 제안**:
   - `/quiz`로 해당 주차 퀴즈 풀기
   - `/flashcard`로 핵심 개념 플래시카드 생성
   - `/review`로 다른 주차 복습

## 톤 & 스타일

- 친근하고 격려하는 톤
- 틀려도 비난하지 않고, "좋은 시도예요" 스타일
- 너무 길게 설명하지 않기 — 사용자가 원하면 더 설명
- 이모지 사용하지 않음
- 존댓말 사용

## 전체 워크플로우

```
1. 과목·주차 파악 → 강의노트 로드
2. 노트를 섹션별로 분리
3. 섹션 목록 제시 → 시작점 선택
4. 각 섹션: 핵심 제시 → 질문 → 응답 처리 → 다음
5. 세션 종료: 요약 + 취약 포인트 + 다음 단계 제안
```
