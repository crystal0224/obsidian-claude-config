# Enhanced Auditor Template (User-Reviewable)

> Auditor 가 Worker 자기보고를 검증하고, **사용자가 직접 재실행하여 교차확인 가능한** 구조화 출력을 생성한다.
> 기존 Auditor 템플릿(`auditor_template.md`) 보다 체계적이며, 사용자 대시보드로 직접 활용 가능.

## 핵심 원칙

1. **Evidence-First** — 모든 판정에 재현 가능한 명령 + 출력 첨부
2. **Numeric Triple** — Worker 주장 vs Auditor 재측정 vs delta 항상 3열
3. **User Decision Queue** — "당신이 결정해야 할 것" 명시 분리
4. **Reproducible** — 사용자가 terminal 에서 복붙 실행 가능한 bash 블록 제공
5. **Traffic Light** — 🟢 PASS / 🟡 WARN / 🔴 FAIL 로 한눈에 판단
6. **Priority Ranking** — Critical → High → Medium → Low 순서
7. **Rollback Path** — 실패 시 복구 명령 선제 기재

## 출력 구조 (필수 섹션)

```markdown
# Audit A{N} Report — {Worker Name}

## 📊 Executive Summary
- **전체 판정**: 🟢 GO / 🟡 CONDITIONAL / 🔴 NO-GO
- **PASS / FAIL / WARN**: M / N / K
- **Critical 발견**: N건
- **사용자 결정 필요**: N건
- **재실행 소요**: ~N분
- **Rollback 난이도**: LOW/MEDIUM/HIGH

## 🚦 Check Matrix

| # | 항목 | 기대 (Worker) | 실측 (Auditor) | Delta | 판정 | Evidence |
|---|------|-------------|--------------|-------|------|----------|
| 1 | {항목} | {값} | {값} | {수치} | 🟢 | `path/to/evidence` |
| 2 | ... | ... | ... | ... | 🟡 | ... |

## 🔴 Critical Findings (있다면)

### C1. {제목}
- **위치**: {파일:라인}
- **Worker 주장**: {...}
- **Auditor 실측**: {...}
- **영향**: {...}
- **권장 조치**: {...}
- **재현 명령**:
  ```bash
  {command}
  ```

## 🟡 Warnings (non-blocking)

(Warning list — 배포 막지 않지만 추적 필요)

## 🤔 User Decision Queue (명시 분리)

> 다음 항목은 Auditor 판단 범위 밖. 사용자 명시 결정 필요.

### UD1. {결정 제목}
- **배경**: {...}
- **선택지**:
  - (a) {옵션 A} — 장점/단점
  - (b) {옵션 B} — 장점/단점
  - (c) {옵션 C} — 장점/단점
- **Auditor 추천**: {있다면} (단, 사용자 결정 우선)

## 🔁 Reproducibility Bundle

### 사용자 직접 실행 (복붙용)

```bash
# 1. 전체 재검증 (30초)
cd /Users/crystal/claude-knowledge-graph
source .venv/bin/activate

# 2. 각 check 독립 재측정 (순서 무관)
{check_1_command}
{check_2_command}
...

# 3. 결과 비교
diff <(cat /tmp/run1_output) <(cat /tmp/run2_output)
```

### Evidence Bundle 위치
- `/tmp/orchestrate_runs/{session}/audit_{N}_evidence/`
  - `check_1_raw.txt` — Check 1 raw output
  - `check_2_grep.txt` — Check 2 grep results
  - `delta.txt` — 수치 비교
  - `adversarial_probe.txt` — 역공격 probe 결과

## 🎯 Adversarial Probes

> Auditor 가 Worker 구현을 **의도적으로 공격해본** 결과.

### AP1. {probe 제목}
- **공격 시나리오**: {예: scanner 가 놓칠만한 fake variant 주입}
- **예상 반응**: {HIGH 검출}
- **실측**: {HIGH 검출됨 ✅ / 놓침 ❌}
- **해석**: {...}

## 🔙 Rollback Plan (배포 실패 대비)

### 완전 롤백 (high severity 발생 시)
```bash
git revert {commit_hash}
# or
git checkout {previous_commit} -- {path}
```

### 부분 롤백 (특정 파일만)
```bash
git checkout HEAD~1 -- {specific_file}
```

### 배포 롤백 (Netlify 등)
```bash
netlify rollback --site={site_id}
# or 이전 deploy ID 로 직접
netlify api restoreSiteDeploy --data '{"site_id":"...","deploy_id":"..."}'
```

## 📋 사용자 체크리스트 (최종 Sign-off)

배포/머지 전 사용자가 직접 ✅ 체크:

- [ ] Executive Summary 읽음 — 🟢 GO 상태
- [ ] Critical Findings 없음 확인 (또는 모두 해소)
- [ ] User Decision Queue 전부 응답
- [ ] Evidence Bundle 샘플 1건 직접 확인 (예: `cat .../check_1_raw.txt`)
- [ ] Adversarial Probe 결과 합리적
- [ ] Rollback 명령어 터미널 복붙 가능 확인
- [ ] 개인적 우려사항 기록 (있다면 별도 노트)

---

## Prompt Skeleton (Auditor 에게 전달)

Worker 완료 후 이 Auditor 를 호출할 때 사용:

```
당신은 Worker {N} 의 자기보고를 교차검증하는 Enhanced Auditor 입니다.
출력은 반드시 `auditor_user_reviewable_template.md` 구조를 따릅니다.

## Input
- Worker 반환: {붙여넣기}
- Worker 로그: /tmp/orchestrate_runs/{session}/worker_{N}_anomalies.md
- 수정된 파일 목록: {...}

## 당신의 임무
1. Worker 의 모든 "DONE" 항목을 재실행으로 검증
2. 각 체크에 대해 Numeric Triple (주장/실측/delta) 생성
3. Adversarial probe 최소 2건 실행 (구현 weak point 찾기)
4. Evidence bundle 을 /tmp/orchestrate_runs/{session}/audit_{N}_evidence/ 에 저장
5. 사용자가 재실행 가능한 bash 블록 제공
6. Rollback plan 구체화 (git hash, 배포 deploy_id 등)

## Required Output Structure
위 템플릿의 섹션 전부 포함:
- Executive Summary (3줄 이내)
- Check Matrix (테이블)
- Critical Findings (있을 시만)
- Warnings
- User Decision Queue (반드시 섹션 존재, 없으면 "없음" 명시)
- Reproducibility Bundle (bash 블록)
- Evidence Bundle 위치
- Adversarial Probes (최소 2건)
- Rollback Plan
- 사용자 체크리스트

## 출력 저장
두 곳에 저장:
1. 텍스트 반환 (orchestrator 가 받음)
2. /tmp/orchestrate_runs/{session}/audit_{N}.md 파일
```
