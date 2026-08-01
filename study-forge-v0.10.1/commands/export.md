---
description: 강의노트를 PDF/DOCX/PPTX로 변환
argument-hint: "<과목명> <주차> <형식: pdf|docx|pptx>"
---

# /export 커맨드

마크다운 강의노트를 PDF, DOCX, PPTX로 변환한다.

## 인자

- `$1` = 과목명 (선택)
- `$2` = 주차 또는 범위 (선택)
- `$3` = 출력 형식 (pdf, docx, pptx) (선택, 기본 pdf)

## 실행

1. `export` 스킬의 워크플로우를 실행
2. 강의노트 로드
3. Cowork의 해당 형식 스킬(pdf/docx/pptx)로 변환
4. 과목 폴더에 저장 + 링크 제공
