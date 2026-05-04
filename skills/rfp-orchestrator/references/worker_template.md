# Worker Prompt Template

Use this skeleton when dispatching a Worker via `Agent`. Fill every `{placeholder}` — do not leave any blank.

```
당신은 {ROLE}입니다.

## 배경 및 문제
{CONTEXT — 2~5 문단. Worker는 오케스트레이터 세션 컨텍스트를 볼 수 없으므로 다음을 모두 포함:
 - 프로젝트 배경
 - 해결할 문제의 증상/증거
 - 앞서 다른 Worker가 남긴 중요 결과 (있다면 경로 + 요약)
 - 이 Worker의 결과가 어디에 쓰이는지 (downstream 의존성)}

## 핵심 파일 (반드시 Read로 탐색)
- {경로 1} — {역할/주목할 지점}
- {경로 2} — ...
- {경로 3} — ...

## 구현 목표 (번호 매겨서, 모두 완수 명시)

### 1. {목표 제목}
{구체 요구. 스펙 수준: 어떤 함수/필드/테스트가 존재해야 하는지}

### 2. ...

### N. 검증
{실제 실행할 명령 + 기대 결과}

## 엄격한 제약

- **git checkout 금지**
- `_local/` 경로 production 미사용
- immutable 패턴 (새 객체 반환, 원본 변형 금지)
- 파일당 800줄 초과 금지
- 유료 API 호출: {구체 한도}
- 다른 Worker 파일 영역 침범 금지:
  - 당신이 다룰 영역: {명시 경로들}
  - 건드리면 안 되는 영역 (다른 Worker 진행 중): {명시 경로들}

## 절대 금지 — 간소화 방지 조항 (CRITICAL)

오케스트레이터가 가장 경계하는 실패 모드:

1. **"거의 다 했음" 반환**: 실제로 미구현/미검증 항목을 DONE으로 표시 금지.
   대신 DONE/PARTIAL/SKIPPED 중 명확히 구분하고 SKIPPED 이유 명시.

2. **정적 검증만으로 "작동 확인"**: `tsc --noEmit` 또는 import 성공만으로 "backward compat 확인" 금지.
   실제 런타임 실행이 필요한 검증은 반드시 실행하거나, 실행 못했으면 명시적으로 SKIPPED 보고.

3. **선재(pre-existing) 버그 은폐**: 작업 중 기존 코드의 의심 지점을 발견하면 로그에 기록.
   "내 스코프가 아님"으로 덮지 말고 Auditor가 따라갈 수 있게 경로+증거 제공.

4. **환경 가정 금지**: rdflib, Redis, Neo4j 등 의존성이 로컬에만 있고 프로덕션에 없을 수 있음.
   Worker의 환경 문서화 + try/except로 조용히 삼키는 곳 반드시 로그로 surfacing.

5. **배포 없이 "배포 효과 검증"**: 로컬 변경만으로 프로덕션 동작을 판단 금지.
   실제 배포가 필요한 변경은 "배포 필요 (오케스트레이터가 커밋/푸시/배포 담당)"로 명시.

## 로깅 (진행 중 필수)

모든 이상 현상을 `/tmp/orchestrate_runs/{SESSION}/worker_{ID}_anomalies.md`에 누적 기록:

- 예상과 다른 데이터/코드 구조
- 기존 가정이 깨진 지점
- 설계 변경 결정 + 왜 그 결정을 했는지
- 임시방편(TODO)로 남긴 항목 + 재개 방법
- 테스트 실패 또는 빌드 에러 (회피하지 말고 기록)
- 코드베이스 개선 제안 (스코프 밖이지만 주목할 것)

## 최종 반환 형식 (엄격히 준수)

```
## 구현 완료 항목
| # | 목표 | 상태 | 측정치 |
|:-:|------|:---:|--------|
| 1 | ... | DONE/PARTIAL/SKIPPED | ... |

## 변경 파일 목록
- {경로} ({+N/-M lines}) — {역할}

## 실제 실행된 검증
| 명령 | 출력 요약 | 통과 여부 |
|------|----------|:--------:|

## 의도적으로 실행 안 한 검증 (SKIPPED)
- {항목}: {이유 + 어떻게 재개할지}

## 발견된 선재 이슈 (out-of-scope)
- {경로:라인}: {증상} — Auditor 확인 권장

## 특이사항
- {로그의 주요 발견}

## 사용자 결정 필요 (있다면)
- {결정 포인트} — 옵션 A/B/C
```

종료 전 자가 점검: 위 5개 섹션 중 "빈 값 허용"은 마지막 2개뿐. 나머지는 반드시 채울 것.
```

## 작성 시 주의

### {ROLE} 명명
구체적으로. 예:
- ❌ "코드 수정 에이전트"
- ✅ "Anthropic response.usage 메트릭을 GraphRAG API debug 필드까지 전파하는 에이전트"

### {CONTEXT} 작성 원칙
Worker는 main 세션을 전혀 모른다. 다음은 반드시 포함:

1. **문제의 증거** — 로그 출력 일부, 실제 관측 값
2. **이전 Worker의 기여** — 경로 + 1~2줄 요약 (필요시 파일 Read 유도)
3. **downstream 의존성** — "당신 결과가 Worker E의 입력이 됨"

### 파일 영역 중복 체크
Workers를 병렬로 보낼 때, 각 Worker 프롬프트에서 **다른 Worker가 건드릴 파일 경로 명시적 금지**. 예:

```
## 다른 Worker 영역 (건드리지 말 것)
- Worker E가 cascade_router.py 수정 중 — 당신은 cascade_decision_sheet.py만
- Worker C가 tier_assignment.py 수정 중 — 당신은 ring_classifier.py만
```

### 유료 API 제한 명시
금지가 아니라 **상한**을 명시:
- ❌ "유료 API 금지"
- ✅ "유료 API 호출 1회 이내 (검증용). 대량 테스트 금지. 초과 시 /tmp/orchestrate_runs/{SESSION}/worker_{id}_approval_needed.md에 승인 요청 후 대기."

## 실제 사용 예

프로덕션 세션에서 사용된 포맷 (이게 잘 작동함):

```
당신은 tier_router 선재 버그를 수정하고 canonical tier 분포를 복구하는 에이전트입니다. **Critical 우선순위**.

## 긴급 배경
Agent E가 cascade canonical tier 통합을 완료했습니다... [상세 배경 4문단]

## 작업 1: tier_router._get_candidates_for_position 수정

### 탐색 단계
1. api/routers/tier_router.py 전체 Read (구조 파악)
2. lines 88-108 구체적 코드 확인
...

### 검증 단계 1: 개별 포지션 tier 분포
[구체 검증 스크립트]

## 엄격한 제약
- Agent H/F/G 작업 파일과 충돌 금지:
  - H는 cascade_decision_sheet.py + DecisionSheet.tsx 하위 분할 중
  - ...
- 당신은 tier_router.py + 헬퍼 모듈만 수정

...

## 최종 반환
[구조화된 포맷]
```

이 포맷으로 Worker I는 152×T3 붕괴 버그를 1회 실행에 복구했다 (insufficient_pool=True 57→0, T1 평균 0→8.81).
