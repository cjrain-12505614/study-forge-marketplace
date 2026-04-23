# Study Assistant Marketplace

`study-assistant` 플러그인 배포용 Claude Code 마켓플레이스.

## 포함 플러그인

| 플러그인 | 최신 버전 | 설명 |
|---|---|---|
| `study-assistant` | v0.8.1 | 대학 강의 학습 지원 — 강의노트 작성·복습·시험 대비 |

## 설치 방법

### 1. 마켓플레이스 등록

`~/.claude/settings.json` 의 `extraKnownMarketplaces` 에 추가:

```json
"study-assistant-marketplace": {
  "source": {
    "source": "github",
    "repo": "cjrain-12505614/study-assistant-marketplace"
  }
}
```

또는 CLI:

```bash
claude plugin marketplace add study-assistant-marketplace --github cjrain-12505614/study-assistant-marketplace
```

### 2. 플러그인 설치

```bash
claude plugin install study-assistant@study-assistant-marketplace
```

CoWork 데스크탑 앱을 재시작하면 자동 반영됩니다.

## 업데이트 방법

```bash
claude plugin marketplace update study-assistant-marketplace
claude plugin install study-assistant@study-assistant-marketplace
```

## 소스 레포

- 플러그인 소스: [study-assistant](https://github.com/cjrain-12505614/study-assistant) _(비공개, 배포본만 본 레포에서 공유)_
