# Topology Guide

Choose the right orchestration shape before dispatching. Wrong topology either wastes parallelism or creates undetected race conditions.

## Decision tree

```
사용자 요청 분해 시작
├─ 단일 원자 작업? → 스킬 쓰지 말고 직접 처리
├─ 2개 작업, 둘 다 trivial? → Agent × 2 병렬, Auditor 생략
└─ 3개 이상 작업?
   ├─ 상호 의존 없음 → Topology A (Star)
   ├─ A→B→C 체인 → Topology B (Chain with gates)
   ├─ N개 병렬 + 공통 downstream → Topology C (Swarm with gate)
   └─ 모든 작업 Audit가 비쌀 때 → Topology D (Escalating audit)
```

## Topology A — Star

1개 orchestrator → N개 독립 Worker → 각 Worker마다 1개 Auditor.

```
            orchestrator
           /     |     \
       Worker A Worker B Worker C
         |        |        |
       Audit A  Audit B  Audit C
           \     |     /
            synthesis
```

**언제 쓸 것**: Task들이 서로 결과를 참조하지 않고 파일 영역도 겹치지 않을 때. 세션 기본값.

**배치 방법**:
- Workers를 **모두 background mode로 동시 디스패치** (한 메시지에 N개 Agent 호출)
- 각 Worker 완료 통지 수신 시 즉시 Auditor 디스패치 (Auditor도 background)
- 모든 Auditor 완료 후 synthesis

**실패 모드**:
- Worker끼리 "숨은 의존성" 있는데 간과 (예: 공통 config 수정)
- **방어**: 각 Worker 프롬프트에 "다른 Worker 영역 금지" 리스트 명시

## Topology B — Chain with gates

A → Audit A → B → Audit B → C → Audit C

```
Worker A → Audit A → [gate pass?] → Worker B → Audit B → ...
                       ↓ fail
                    escalate to user
```

**언제 쓸 것**: B의 입력이 A의 출력. 예: ETL 파이프라인, migration → data load → validation.

**배치 방법**:
- 순차 디스패치 (foreground 또는 완료 대기)
- 각 gate에서 Auditor 결과가 FAIL이면 chain 중단 + 사용자 보고
- gate PASS여도 Auditor 측정치를 다음 Worker 프롬프트에 주입

**실패 모드**:
- Auditor가 "통과"로 보고했지만 실제로는 미검증 (Auditor 자체 skipping)
- **방어**: Chain B~C~D에서는 Auditor도 안 간략화 — gate마다 반드시 실행 결과 요구

## Topology C — Swarm with gate

N개 Worker 동시 → 1개 Gate Auditor → 단일 downstream

```
Worker A ─┐
Worker B ─┼→ Gate Auditor (consistency check) → Worker D
Worker C ─┘
```

**언제 쓸 것**: N개 Worker가 공통 downstream을 위해 기여 (e.g., 5개 팀이 config 섹션 각자 작성 → merge agent가 합침). Gate auditor는 cross-worker 일관성을 검증.

**배치 방법**:
- A, B, C 병렬 디스패치
- 모두 완료 후 Gate Auditor 디스패치 (단일)
- Gate 통과 후 Worker D 디스패치

**실패 모드**:
- 개별 Worker audit 생략 → Gate가 "이상 없음" 보고했지만 개별 Worker가 실제로 skipped 항목 많음
- **방어**: Topology A와 병행 — 개별 Audit + Gate Audit 둘 다

## Topology D — Escalating audit

Worker → Light Auditor → [anomaly?] → Deep Auditor

```
Worker → Light Audit (cheap check)
            ↓ anomaly found
         Deep Audit (thorough)
            ↓
         user synthesis
```

**언제 쓸 것**: 50+ 작업 스케일. 모든 작업에 Deep Audit은 과잉. Light Audit으로 1차 필터링.

**Light Auditor 체크포인트 (빠름, ≤1분)**:
- Git diff가 주장한 파일과 일치
- 핵심 숫자 1~2개 재측정
- 로그에 ERROR/CRITICAL 없음

**Deep Auditor 발동 트리거**:
- Light audit 불일치 1건 이상
- Worker 로그에 "SKIPPED" 3건 이상
- Worker의 핵심 주장이 환경 의존적 (외부 서비스 확인 필요)

**실패 모드**:
- Light Audit이 너무 간소해서 실제 문제 놓침
- **방어**: Light Audit은 최소 3개 critical 체크포인트 필수. 그 아래면 Light Audit 생략하고 바로 Deep.

## 병렬성 추정

| 에이전트 수 | 권장 동시성 | 이유 |
|:---:|:---:|------|
| 1~3 | foreground | 사용자가 완료 대기할 수 있음 |
| 4~6 | background 전부 | 기다리는 것보다 overlap 이익 큼 |
| 7~10 | background + phase별 배치 | 리소스/토큰 과다 방지 |
| 10+ | Topology D 필수 | Light/Deep 분리로 비용 관리 |

## 파일 충돌 체크

Workers를 병렬로 보내기 전 **반드시** 충돌 매트릭스 작성:

```
      | W_A | W_B | W_C | W_D |
------|-----|-----|-----|-----|
 W_A  |  -  |  ?  |  ?  |  ?  |
 W_B  |  ?  |  -  |  ?  |  ?  |
 W_C  |  ?  |  ?  |  -  |  ?  |
 W_D  |  ?  |  ?  |  ?  |  -  |
```

각 셀에 Y (충돌) / N (분리) / `file_path` (공유 파일) 표기.

공유 파일 있으면:
1. Worker 프롬프트에 "append only, 기존 코드 수정 금지" 제약 추가
2. 또는 sequential로 재배치 (Topology B)
3. 또는 한 Worker가 전담 수정 + 다른 Worker는 Read만

## 세션별 실제 사용 패턴

**Phase 1 (병렬 Stage, 세션 예시)**:
- Topology A — 3 트랙 오케스트레이터 (Track 1/2/3 독립)
- 각 트랙마다 1 Reporter (= Auditor)
- 파일 충돌: 0 (cascade / llm / career 디렉토리 분리)

**Phase 2 (복구 Stage)**:
- Topology D — tier_router 버그 발견 시 escalating
- Light: Worker E의 자기보고 읽기
- Deep: Worker I가 실제로 57개 포지션 재측정

**Phase 3 (후속 Stage)**:
- Topology A × 4 Worker (A/B/C/D) + Topology B로 E는 A+B 이후
- Auditor A-E 쌍
- 파일 충돌 매트릭스로 사전 검증 완료

이것이 복잡한 세션 1회를 감당할 수 있는 실제 구조.
