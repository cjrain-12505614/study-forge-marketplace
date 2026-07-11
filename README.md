# Study Forge Marketplace

`study-forge` 플러그인 배포용 Claude Code 마켓플레이스.

> ℹ️ 구 **study-assistant**는 2026-07-11 **study-forge**로 개명되었습니다 (레포·플러그인·마켓플레이스 일괄). 기존 study-assistant 설치는 study-forge로 재설치가 필요합니다.

## 포함 플러그인

| 플러그인 | 최신 버전 | 설명 |
|---|---|---|
| `study-forge` | v0.9.0 | 대학 강의 학습 지원 — 강의노트 작성·복습·시험 대비 |

## 설치 방법

### 1. 마켓플레이스 등록

`~/.claude/settings.json` 의 `extraKnownMarketplaces` 에 추가:

```json
"study-forge-marketplace": {
  "source": {
    "source": "github",
    "repo": "cjrain-12505614/study-forge-marketplace"
  }
}
```

또는 CLI:

```bash
claude plugin marketplace add study-forge-marketplace --github cjrain-12505614/study-forge-marketplace
```

### 2. 플러그인 설치

```bash
claude plugin install study-forge@study-forge-marketplace
```

CoWork 데스크탑 앱을 재시작하면 자동 반영됩니다.

## 업데이트 방법

```bash
claude plugin marketplace update study-forge-marketplace
claude plugin install study-forge@study-forge-marketplace
```

## 소스 레포

- 플러그인 소스: [study-forge](https://github.com/cjrain-12505614/study-forge) _(비공개, 배포본만 본 레포에서 공유)_
