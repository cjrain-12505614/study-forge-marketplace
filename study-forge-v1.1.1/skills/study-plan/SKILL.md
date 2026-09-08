---
name: study-plan
description: >
  시험 일정을 기준으로 주별 복습 계획을 자동 생성하고 Google Calendar에 등록하는 스킬.
  사용자가 "복습 계획 세워줘", "study-plan", "시험 대비 스케줄",
  "중간고사까지 계획 짜줘", "공부 계획" 등을 요청할 때 사용한다.
  시험 범위와 취약 단원을 고려하여 효율적인 복습 스케줄을 생성한다.
version: 0.1.0
---

# 복습 계획 생성 스킬

시험 일정을 역산하여 주별/일별 복습 계획을 생성하고, Google Calendar에 등록한다.

## 1단계: 정보 수집

사용자에게 확인할 정보:
- 과목명
- 시험 일자
- 시험 범위 (주차)
- 하루 가용 학습 시간 (선택, 기본 2시간)
- 취약 단원 (있으면, mock-exam 결과 참조 가능)

## 2단계: 학습량 산정

```python
def estimate_study_load(course_path, start_week, end_week):
    """범위 내 주차별 학습량 추정"""
    note_dir = os.path.join(course_path, '강의노트')
    loads = {}
    for w in range(start_week, end_week + 1):
        for f in os.listdir(note_dir):
            if f'{w:02d}' in f and f.endswith('.md'):
                filepath = os.path.join(note_dir, f)
                size = os.path.getsize(filepath)
                loads[w] = size  # 파일 크기로 대략적 분량 추정
    return loads
```

- 강의노트 파일 크기로 각 주차의 상대적 분량 추정
- 취약 단원에는 가중치 부여 (1.5배)

## 3단계: 복습 스케줄 생성

### 스케줄 원칙

- **간격 반복 학습** (Spaced Repetition): 한 주제를 여러 날에 걸쳐 반복
- **취약 단원 우선**: 취약 단원을 먼저, 더 자주 배치
- **마지막 날은 전체 훑기**: 시험 전날은 요약 정리 + 모의시험
- **하루 2~3주차 분량** 기본 (가용 시간에 따라 조절)

### 일별 학습 항목

각 날의 학습 항목에 구체적 커맨드를 매핑:

```markdown
## D-7 (월) — 1~2주차

- [ ] `/review` 1주차 (40분)
- [ ] `/quiz` 1주차 (20분)
- [ ] `/review` 2주차 (40분)
- [ ] `/quiz` 2주차 (20분)

## D-6 (화) — 3~4주차

- [ ] `/review` 3주차 (40분)
- [ ] `/quiz` 3주차 (20분)
- [ ] `/review` 4주차 (40분) ⚠️ 취약
- [ ] `/flashcard` 4주차 → 반복 학습

## D-1 (일) — 최종 정리

- [ ] `/exam-summary` 1-7주차 훑어보기 (30분)
- [ ] `/mock-exam` 1-7주차 (60분)
- [ ] 오답 복습 (30분)
```

## 4단계: Google Calendar 등록 (선택)

사용자가 원하면 Google Calendar에 학습 일정을 등록한다.

```
gcal_create_event:
  summary: "[과목명] 복습 — 1~2주차"
  description: "/review 1주차, /quiz 1주차, /review 2주차, /quiz 2주차"
  start: "2026-04-15T18:00:00"
  end: "2026-04-15T20:00:00"
```

- 각 날의 학습 블록을 이벤트로 생성
- 설명에 실행할 커맨드 목록 포함

## 5단계: 계획 파일 저장

마크다운 파일로 저장:
- 파일명: `복습계획-{시험명}.md` (예: `복습계획-중간고사.md`)
- 저장 위치: 과목 폴더 루트

## 전체 워크플로우

```
1. 시험 일정·범위·가용 시간 파악
2. 학습량 산정 + 취약 단원 가중치
3. 일별 복습 스케줄 생성 (간격 반복 + 취약 우선)
4. (선택) Google Calendar 등록
5. 마크다운 파일 저장 + 링크 제공
```
