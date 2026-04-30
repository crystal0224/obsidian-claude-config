---
name: crystal-multi-agent-orchestration
description: Use when designing or executing multi-stage build pipelines (TTS/video/PDF/deploy), dispatching parallel agents requiring verification, or staging batch git commits. Covers Diff-aware Sync caching pattern, orchestrate-audit 2-tier verification (Worker→Auditor→Reviewer), Spec-Validator pre-pass, Council 3-perspective for integration work, Post-audit Amendments pattern, FIFO commit gate, omnibus Worker rule for same-file changes, Worker Bash failure → Main fallback, stale-artifact single-source-of-truth rule.
---

# Crystal Multi-Agent Orchestration Patterns

복잡한 멀티스텝 작업의 설계·실행에서 학습된 패턴 모음. 본문은 CLAUDE.md (366-line monolith) 에서 추출하여 description-trigger 스킬화.

## When this skill activates

다음 키워드/맥락에서 자동 활성:
- "병렬 에이전트", "Worker 디스패치"
- 멀티스테이지 빌드 (TTS · video · PDF · deploy)
- "audit", "council", "code-reviewer 외 추가 검증"
- "/fifo-commit" 또는 batch git 작업
- "옴니버스 Worker", 같은 파일 다중 수정

## 1. Diff-aware Sync 패턴 (2026-04-24+)

복잡한 멀티스텝 생성 파이프라인(TTS · 비디오 · PDF · 배포)에서 변경분만 재실행하는 패턴. 구현 레퍼런스: `claude-knowledge-graph/presentation/people-intelligence/scripts/sync.js`.

핵심:
1. `.sync-cache.json` — 노트/슬라이드의 SHA1 16자 해시 저장
2. 현재 상태 해시 → 이전 캐시와 비교 → 변경된 unit 추출
3. 변경분만 비싼 연산(TTS 생성 등) 재실행
4. 선택적 실행 플래그 (`--video`, `--youtube`, `--pdf`, `--all`, `--force`, `--no-deploy`)
5. 실행 후 PROJECT.md + `.harness/last-run.json` 메타 업데이트

효과: 28장 슬라이드 중 1장만 수정 → 1장 TTS만 재생성 (3초 vs 2분). Multi-artifact 파이프라인 선택적 실행 가능.

참고: presentation-harness 스킬 H/I 단계가 이 패턴을 위임 호출.

## 2. orchestrate-audit 2층 체크 (2026-04-19+)

복잡한 UI/통합 작업에서는 `/orchestrate-audit` 스킬로 2층 방어:
- **1층 (즉시)**: Worker 완료 직후 Auditor 매칭 — 같은 작업 독립 재측정 (수치·파일·API). **Auditor 원칙 (2026-04-25+)**: Worker 자기보고 ("X 수정 완료", 자기점검 체크리스트) 를 그대로 신뢰 금지. 모든 기술적 클레임은 반드시 Read 도구로 실제 파일 확인. Worker 의 점검 리스트는 의도의 선언일 뿐 — 실제 코드 반영은 Auditor 가 독립 검증. (Cycle 1 의 useLiveRoom Worker C 가 "endSession 후 timer 취소 점검" 명시했으나 코드 미반영 → Auditor C 가 코드 직접 읽고 leak 적발)
- **2층 (스프린트 종료)**: Visual/Usability/Integration 3-Reviewer 병렬 — 다른 관점의 blind spot 포착
- **효과**: 단일 Auditor PASS → Visual Reviewer Critical 발견 사례 (2026-04-19 React Hooks 규칙 위반 재발 포착)
- **Worker 간 파일 충돌 방지**: plan.md에 "scope files (exclusive)" + "수정 금지 파일" 양쪽 명시
- **Spec-Validator 선행 패스 (2026-04-24+)**: Worker 투입 전 Spec-Validator 를 독립 실행 — 스펙 내 blocker·contradiction·hidden pre-req 를 먼저 식별하고 "사용자 결정 필요" 로 에스컬레이션. 구현 중간에 발견하면 Worker 출력 전체를 재작업해야 하므로 반드시 선행. 2026-04-24 LiveKit 마이그레이션 세션에서 5 blockers / 4 contradictions / 6 hidden pre-reqs 사전 차단 (DiagnosticSession persona_id 부재, token endpoint 시그니처 불일치, WS voice= 파라미터 미지원 등). 2026-04-25 Phase B 에서는 17 amendments 사전 차단 → 5+ 시간 rework 절감 (실측).
- **Council 3-perspective 패턴 (2026-04-25+)**: Auditor 1명 PASS 만으로 부족한 통합 버그를 잡기 위해 Architect / QA / Deploy 3 perspective Council 추가. Phase B 에서 session_manager double-instantiation + missing phase_controller injection 을 단일 Auditor 가 놓친 것을 Council 이 교차 발견. orchestrate-audit Phase 3 Reviewer pass 의 변형 — 통합/배포 작업에 특화.
- **Post-audit Amendment 패턴 (2026-04-24+)**: Auditor 결과를 Worker 원본 출력에 인라인 수정하지 말고 master plan 의 `§ Post-audit Amendments` 섹션에 번호 (A-01, B-01 등) 로 기록. Worker 원본 (수천 줄) 보존 + 구현자가 실행 전 amendment 먼저 적용. 2026-04-24 세션에서 14 개 Amendments 통합, Worker 5189 줄 출력 손실 0.
- **Docs ↔ Code 라인 번호 cross-reference race (2026-04-25+)**: Worker A(docs) 와 Worker B(code) 가 disjoint 파일을 다루더라도 docs 가 code 의 특정 라인 번호 (`livekit_worker.py:147` 등) 를 인용할 때 race 발생. A 가 본 시점의 라인 번호가 B 의 +N 라인 추가로 stale 화. **예방**: docs 트랙은 code 트랙 완료 후 직렬 실행 (Topology B chain) 또는 docs 에 라인 번호 대신 함수/anchor 이름 사용. 동일 배치 docs+code 혼합 시 Auditor 가 라인 번호 정합성 검사 필수. 사후 수정은 orchestrator 가 모든 Worker 완료 후 단독 재동기화. 2026-04-25 Cycle 1 에서 Worker A docs 4건 인용 중 3건 stale → Auditor A 가 grep 재측정으로 적발 → orchestrator 직접 정정.
- **Worker Bash 권한 거부 → Main fallback (2026-04-26+)**: 일부 세션에서 Worker 가 Bash 도구 권한을 거부당해 (5회 시도 모두 `dangerouslyDisableSandbox: true` 무시) 스크립트 실행 단계에서 막힘. 이 경우 Worker 재시도 금지 — 즉시 Main 세션에서 take-over. **사전 차단**: dispatch 전 "Bash 필수 작업인가?" 자가 검사. 필수면 Worker 는 Write 만 (코드 작성), Main 이 실행 + Auditor 디스패치. **첫 실패 신호**: Worker 가 "권한 부여 필요" 보고 시 즉시 escalate, 재투입 X. git option C (Orchestrator 직접 commit) 와 같은 layer 의 fallback 패턴. 2026-04-26 SP v20 xlsx 빌드에서 Worker 5회 실패 → Main 직접 처리 30분 내 완료, Auditor 정상 동작.
- **Audit 시점 < Build 시점 = Transitive PASS 검토 (2026-04-26+)**: Auditor 가 v1 build 검증하는 동안 Main 이 사용자 피드백으로 v2 재빌드하면 Audit 보고는 stale. 보고 해석 시 "이 Audit 의 대상 빌드 버전 vs 현재 최신 빌드 버전" 시점 대조 필수. v2 가 v1 의 동일 빌더 + 동일 입력으로 재실행 (구조만 변경) 이면 transitive PASS. 그 외에는 v2 별도 audit 재투입. SP v20 1251 audit 진행 중 1258 재빌드 사례.
- **Stale 산출물 복사 함정 — Single source 동적 재생성 원칙 (2026-04-26+)**: 멀티스테이지 파이프라인 빌더가 단일 소스 (handoffs JSON 등 최종 업스트림) 가 아닌 이전 stage 산출물 (xlsx, csv) 을 복사하면 silent staleness. handoffs 가 패치로 업데이트돼도 xlsx 는 0423 stale 그대로. **검증**: 빌더 코드 리뷰 시 "이 데이터 어디서 왔는가? 이전 xlsx 인가 원본 JSON 인가?" 질문 강제. **회피**: 빌더는 항상 단일 소스에서 직접 재생성. 이전 산출물 복사 = 안티패턴. 2026-04-26 SP v20 build_unified_v19_xlsx.py → build_unified_v20_xlsx.py 마이그레이션 사례 (verbose opener 169건 silent 잔존 → 0건 해소).

## 3. 병렬 배치 커밋 게이트 — FIFO 전담 커밋 패턴 (2026-04-24+)

병렬 Worker 여러 개가 같은 git index 에 동시에 `git add / commit` 하면 staging race 가 발생한다.
증상: 한 Worker 의 커밋에 다른 Worker 의 변경분이 끼어들거나, `git status` 가 의도치 않은 파일을 포함.

**복구**: `git reset --mixed HEAD~1` 로 스테이지 되돌리기 (작업 파일 손실 없음, reflog 에 흔적 보존).

**예방 — 옵션 C (권장)**: Worker 는 파일 수정만, Orchestrator 가 배치 종료 후 단일 순차 커밋.
- 배치 내 Worker 프롬프트에 "**git 명령 일절 금지**" (add/commit/reset/status/diff/log) 조항 삽입
- Worker 는 "제안 커밋 메시지 + 스테이징 파일 목록" 만 반환
- Orchestrator 가 순서대로 `git add <specific files> && git commit -m "..."` 수행
- `/fifo-commit` command 로 표준화 가능

**효과**: 배치 4+ 에서 race 0건 (professor 프로젝트 2026-04-24 검증, 총 6 배치 중 옵션 C 적용 후 4 배치 전부 race 0)

**옴니버스 Worker 패턴 (2026-04-25+)**: 같은 파일에 여러 변경이 필요할 때 복수 Worker 에 분산하지 말고 1 Worker 에 통합. 이유: (1) 파일 단위 lock 이 없으면 두 Worker 가 같은 파일의 서로 다른 hunks 를 쓰면 나중 Write 가 앞 Write 를 덮어씀. (2) 같은 파일 내 변경들은 문맥 의존성이 높아 분산 시 불일치 발생 가능. (3) docs 가 인용하는 라인 번호 race 도 같은 파일이면 1 Worker 시작-종료 사이 안정. 적용 예: livekit_worker.py 에 B5.4 error publish + redundant import 정리 + `_pending_tasks` task tracking 3건을 Worker α 1개로 통합 (2026-04-25 Cycle 2). **판정 기준**: 동일 파일 내 변경이면 무조건 1 Worker 옴니버스. 다른 파일이면 병렬 가능.

## 위험 신호 (이 패턴들을 어겼을 때)

- "한 Worker 커밋에 다른 Worker 변경분 끼어듦" → FIFO commit 위반
- "Auditor PASS 인데 통합 시점에 버그 발견" → Council 3-perspective 누락
- "Worker 자기보고는 OK인데 코드 미반영" → Auditor 가 자기보고 신뢰함 (코드 직접 Read 안 함)
- "8.3MB pack 0B 됐는데 영구 손실로 판단" → APFS sparse 자연 복구 가능 (별도 skill `crystal-infra-recovery`)
