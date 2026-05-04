# Session Init Checklist

Worker/Auditor 세션 시작 시 복붙으로 1분 세팅.

## 1. 디렉토리 생성

```bash
SESSION=$(date +%Y%m%d_%H%M%S)
mkdir -p /tmp/orchestrate_runs/${SESSION}
echo "SESSION=${SESSION}"
```

## 2. plan.md 템플릿 (복붙 후 채우기)

```markdown
# Orchestrate Plan — {SESSION}

## Source
- 사용자 요청 원문 또는 NEXT_SESSION_PROMPT 참조

## Topology
- [A Star / B Chain / C Swarm / D Escalating] — 선택 이유: {1줄}

## Workers

### W1 — {역할}
- **Scope files (exclusive)**:
  - {절대 경로}
  - {절대 경로}
- **수정 금지 파일 (다른 Worker 소유)**:
  - W2: {경로}
  - W4: {경로}
- **Tasks**:
  - {task 1}
  - {task 2}

### W2 — {역할}
...

## 파일 충돌 매트릭스

|    | W1 | W2 | W4 | W5 |
|----|:--:|:--:|:--:|:--:|
| W1 | -  | N  | N  | N  |
| W2 |    | -  | N  | N  |
| W4 |    |    | -  | N  |
| W5 |    |    |    | -  |

(N = no conflict, Y = 의존성 존재 → sequential)

## Auditors
각 Worker 완료 시 paired Auditor 즉시 디스패치 (A1/A2/A4/A5).

## Post-synthesis Reviewer Pass (선택)
Worker+Auditor 완료 후, 변경 유형별:
- TSX/CSS 수정 → ui-visual-reviewer
- FE↔BE 계약 변경 → ui-integration-reviewer
- 의사결정 UI → ui-usability-reviewer

## Log files
- `/tmp/orchestrate_runs/{SESSION}/worker_{id}_anomalies.md`
- `/tmp/orchestrate_runs/{SESSION}/audit_{id}.md`
- `/tmp/orchestrate_runs/{SESSION}/review_{visual|usability|integration}.md` (Phase 3)
```

## 3. 세션 종료 전 로그 보존

`/tmp/orchestrate_runs/` 는 시스템 재부팅 시 소실. 민감 정보 없으면 git 추적, 있으면 `_local/reviews/{YYYYMMDD}/`로 복사:

```bash
cp -r /tmp/orchestrate_runs/${SESSION}/ _local/reviews/$(date +%Y%m%d)/
```
