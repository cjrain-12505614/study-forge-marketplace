---
name: ta
description: >
  학습관리 조교 — 현재 학습 상태를 자동 진단하고 다음에 할 일을 안내하는 스킬.
  사용자가 "오늘 뭐 공부하지", "다음에 뭐 해야 돼", "학습 도와줘", "조교",
  "공부 시작", "뭐부터 하면 돼", "이번 주 할 일" 등을 요청할 때 사용한다.
  사용자가 어떤 커맨드를 써야 할지 몰라도 조교가 현황을 분석해서 구체적인 행동을 제안한다.
version: 0.1.0
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
            for ext in exts:
                if f.lower().endswith(ext):
                    # 주차 번호 추출 (01~19)
                    for w in range(1, 20):
                        if f'{w:02d}' in f or f'_{w}_' in f or f'-{w}-' in f:
                            if w not in weeks:
                                weeks[w] = {}
                            weeks[w][dir_name] = True
                            break
    return weeks
```

## 2단계: 주차별 상태 판정

각 주차를 아래 상태 중 하나로 분류한다:

| 상태 | 조건 | 다음 액션 |
|------|------|-----------|
| `완료` | 교안 + 스크립트 + 노트 모두 있음 | 복습/퀴즈 제안 |
| `노트_필요` | 교안 + 스크립트 있지만 노트 없음 | `/create-note` |
| `스크립트_필요` | 녹음/영상 있지만 스크립트 없음 | `/transcribe` 또는 `/extract-video` |
| `자료_대기` | 교안만 있거나 녹음 없음 | 예습(`/preview`) 가능, 노트 작성은 대기 |
| `미시작` | 아무 자료도 없음 | 자료 업로드 안내 |

```python
def classify_week(week_data):
    has_pdf = week_data.get('강의교안', False)
    has_audio = week_data.get('강의녹음', False) or week_data.get('강의영상', False)
    has_script = week_data.get('스크립트', False)
    has_note = week_data.get('강의노트', False)
    has_practice = week_data.get('실습', False)

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
2. **스크립트 변환이 필요한 것** (`스크립트_필요`) — 변환 후 노트 작성 가능
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
| 파이썬데이터분석 | 2/4주차 완료 | 3주차 스크립트 변환 |
| 빅데이터기초수학 | 5/5주차 완료 | 복습 추천 |
| ... | ... | ... |

## 🎯 지금 추천하는 작업

**1. 머신러닝 4주차 강의노트 작성** ⭐ 가장 급함
- 스크립트와 교안이 준비되어 있어서 바로 노트 작성 가능
- 실행: `/create-note 머신러닝 4주차`

**2. 파이썬데이터분석 3주차 스크립트 변환**
- MP3가 올라와 있는데 아직 변환 안 됨
- 실행: `/transcribe 파이썬데이터분석 3주차`

**3. 빅데이터기초수학 3주차 복습**
- 노트 작성한 지 3일 지남, 복습 타이밍
- 실행: `/review 빅데이터기초수학 3주차`

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
| 월·화 | 새 주차 자료 처리 (transcribe → prepare-script → create-note) |
| 수·목 | 밀린 노트 작성 + 이번 주 복습 |
| 금 | 퀴즈·플래시카드로 정리 |
| 토·일 | 다음 주 예습 + 전체 진도 점검 |

이 패턴은 참고용이며, 실제 자료 상태가 우선한다.

## 전체 워크플로우

```
1. 전체 과목 폴더 스캔 (progress 로직 활용)
2. 주차별 상태 판정 (완료/노트필요/스크립트필요/자료대기/미시작)
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
