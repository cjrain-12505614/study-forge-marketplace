---
name: progress
description: >
  전체 과목의 주차별 학습 진행 현황을 파악하여 대시보드로 보여주는 스킬.
  사용자가 "진행 현황 보여줘", "progress", "어디까지 했지", "노트 작성 현황",
  "이번 주 뭐 해야 돼" 등을 요청할 때 사용한다.
  각 과목 폴더를 스캔하여 스크립트/교안/노트 존재 여부를 확인하고 현황표를 생성한다.
version: 0.1.0
---

# 학습 진행 현황 대시보드 스킬

마운트된 전체 과목 폴더를 스캔하여 주차별 학습 자료 현황을 파악하고 대시보드를 제공한다.

## 1단계: 전체 과목 스캔

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

def scan_course(course_path):
    """과목 폴더의 주차별 자료 현황 스캔"""
    status = {}
    dirs = {
        '강의교안': '.pdf',
        '강의녹음': '.mp3',
        '강의영상': '.mp4',
        '스크립트': '.txt',
        '실습': '.pdf',
        '강의노트': '.md',
    }

    for dir_name, ext in dirs.items():
        dir_path = os.path.join(course_path, dir_name)
        if not os.path.isdir(dir_path):
            continue
        for f in os.listdir(dir_path):
            if f.lower().endswith(ext):
                # 주차 번호 추출
                for w in range(1, 20):
                    if f'{w:02d}' in f or f'_{w}_' in f:
                        if w not in status:
                            status[w] = {}
                        status[w][dir_name] = True
                        break
    return status
```

## 2단계: 현황표 생성

### 과목별 현황

```markdown
## 파이썬데이터분석

| 주차 | 교안 | 녹음 | 영상 | 스크립트 | 실습 | 노트 | 상태 |
|------|------|------|------|----------|------|------|------|
| 01 | ✓ | ✓ | - | ✓ | ✓ | ✓ | 완료 |
| 02 | ✓ | ✓ | - | ✓ | - | ✓ | 완료 |
| 03 | ✓ | ✓ | - | - | - | - | 스크립트 변환 필요 |
| 04 | ✓ | - | - | - | - | - | MP3 대기 |
```

### 상태 판별 로직

- **완료**: 교안 + 스크립트 + 노트 모두 있음
- **노트 작성 필요**: 교안 + 스크립트 있지만 노트 없음
- **스크립트 변환 필요**: 교안 + 녹음/영상 있지만 스크립트 없음
- **자료 대기**: 교안만 있거나 아무것도 없음

## 3단계: 전체 요약

```markdown
## 전체 요약

| 과목 | 총 주차 | 노트 완료 | 진행률 | 다음 할 일 |
|------|---------|-----------|--------|-----------|
| 파이썬데이터분석 | 4 | 2 | 50% | 03주차 /transcribe |
| 머신러닝 | 3 | 1 | 33% | 02주차 /create-note |
| 빅데이터기초수학 | 4 | 4 | 100% | - |
| ... | ... | ... | ... | ... |
```

## 4단계: 다음 액션 제안

현황을 기반으로 가장 급한 작업을 제안:
1. 스크립트 변환이 밀린 과목
2. 노트 작성이 밀린 과목
3. 복습이 필요한 과목 (노트 완료 후 일정 시간 경과)

## 전체 워크플로우

```
1. 전체 과목 폴더 스캔
2. 주차별 자료 존재 여부 확인
3. 과목별 현황표 생성
4. 전체 요약 + 진행률
5. 다음 액션 제안
```
