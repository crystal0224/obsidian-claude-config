---
name: crystal-rfp-patterns
description: Crystal RFP 풀덱 세션 고유 함정 8개 + 자동 트리거 커맨드. 트리거 키워드 "RFP", "풀덱", "DGO", "거버닝 메시지", "overflow", "Worker rate limit", "audit trail", "Worker silent drift", "1Q26 약어", "1000x 단위", "meta-execution", "cross-link 추측"
---

# Crystal RFP Patterns (auto-load)

> rfp-orchestrator skill (1289 lines) 내 함정 8개를 추출 — 매 세션 재발견 비용 제거. brother/ 폴더 작업 시 rfp-orchestrator와 동시 로드.

## 함정 8 (매 세션 재발견 방지)

### 1. Worker rate limit → Main take-over (L18, P1)
**증상**: Worker가 31 tool uses 후 "server temporary" 에러로 멈춤
**처리**: Worker 부분 결과 (`/tmp/orchestrate_runs/<TS>/worker_*/`) 검증 후 Main이 직접 take-over → 추가 swap 진행. callback 대안.

### 2. DGO 자동 fix 우선 / 의미·뉘앙스만 사용자 보고 (L19, P2)
**증상**: DGO Gate FAIL 발견 (좌측선 / 표지 더미 / 메타영문 / nowrap 부족 등)
**처리**: anti-pattern 자동 grep + replace **즉시 fix** (사용자 보고 X). 의미·뉘앙스 영역만 사용자 시각 검토 trigger.

### 3. 거버닝 메시지 명사 종결 금지 + 직관성 > 자수 (L5, L13, L25)
**증상**: 거버닝 메시지가 명사로 끝남 (예: "...분양 실적") 또는 약어·단위·영어 혼용으로 도메인 외 사람 못 읽음
**처리**: 동사형 개조식 완결 (보유·확보·달성·약속). 5 규칙 통과해도 직관성 별개 — **충돌 시 직관성 우선**. 자수 (30-50자)는 정보량 위해 약간 초과 허용.

### 4. 좌측 강조선 6 elem = 조잡 (AP-1)
**증상**: `border-left:.*solid var(--accent|navy)` 6개 이상 = Crystal "조잡" trigger
**처리**: top border / 둘레 border / bg only 로 대체. DGO Gate 8 자동 검출.

### 5. overflow 즉시 감지 (L10, L23, L24)
**증상**: PDF 시각 검토에서 페이지 boundary clip 발견 (우측 잘림 / 표지 footer not bottom-pinned)
**root cause 후보**:
- CSS grid 3-row + children 2개 → row 3 빈 채로 child가 row 2 stuck
- `.profile-table td.value white-space: nowrap` + 긴 한국어 swap → 좌측 col 비율 초과 expand → 우측 col clip
**처리**: DGO Gate 1 페이지 fit 매 변경 자동. P13 Layout Compositor 안전망 CSS (`word-break: keep-all + overflow-wrap: anywhere`).

### 6. Worker cross-link 미참조 = silent drift (L9, P4)
**증상**: Worker C가 평당가 baseline·평형·% 항목을 추측으로 채움 (예: v5 마곡 5,820~6,420 → v6 강남에서 그대로 유지) → Worker A 실측 8,550~9,450과 50% gap
**처리**: RO Round 1B의 cross-link strict 검증 + DGO Gate 9 (`[Worker A 산출]` 마커 외부 추측값 0). 추측 placeholder 사전 차단.

### 7. 같은 세션 SKILL 미반영 / 슬래시는 즉시 (L14, 2-tier reload)
**증상**: 세션 중 SKILL.md 수정 → 같은 세션에서 description-trigger 자동 활성 X
**처리**: SKILL 변경은 **다음 세션부터** 자동 트리거 / 슬래시 명령은 같은 세션 reload ✓. 같은 세션 SKILL 검증 시도 X — `/exit` → `claude` 재시작 mandatory.

### 8. fact-check = 원본 실측 cross-validate (hallucination 차단)
**증상**: Worker B/C가 ★250414 양병천 약력 fact를 그대로 인용했지만 산술 오류 (26년 vs 25년) 또는 fact 누락 (2016.07 DL 퇴사 / 2014 최우수상)
**처리**: Auditor가 250414_extract.md 직접 grep + ±0.01% 재계산. Worker 자가집계 신뢰 X.

## 자동 트리거 커맨드 (rfp-orchestrator 도메인)

| 명령 | 타입 | 용도 |
|------|------|------|
| `/regen-pdf` | mutation | HTML → Chrome headless PDF + pypdf 페이지 fit 검증 |
| `/rfp-preview` | diagnostic | HTML 브라우저 + fswatch HTML save → auto PDF regen |
| `/rfp-pt` | mutation | 단지명·평당가·세대수·일정 빠른 변경 + cross-link 자동 swap + PDF |
| `/rfp-status` | diagnostic | Phase 1A·1B·2·2.5·Final 진행 시각화 |
| `/rfp-handoff` | mutation | audit_summary + decisions → handoff.md + MEMORY auto-update |
| `/rfp-design-check` | diagnostic | DESIGN.md §12 Tone B vs HTML 실측 색 토큰 cross-validate |

## 추가 패턴

### 1000x 단위 silent error 패턴
**증상**: pricing_3.json `"총_분양수익_억원": 51351` (실값 5135.13억 1000x 오류)
**처리**: Auditor A의 ±0.01% 재계산 + 단위 일관성 grep (만원/㎡/평/억). DGO Gate 10 (Meta-execution 일치) 자동 검증.

### 2-tier reload 메커니즘
- **슬래시 명령**: 같은 세션 reload ✓
- **SKILL.md description-trigger**: process boot 시 1회 scan only
- 혼동 방지: 슬래시 즉시 검증 / SKILL 검증은 새 세션

### 7-file 오빠 워크플로우 scaffolding
- `brother/RFP_QUICKSTART.md` — 5 step + Phase 0 short-form 예시 5개
- `brother/RFP_HTML_EDIT_GUIDE.md` — 11쪽 페이지별 수정 영역 + cross-link 영향 표
- `brother/RFP_TROUBLESHOOT.md` — 자주 발생 issue 6건
- `~/.claude/commands/rfp-{preview,pt,status,handoff,design-check}.md`
- `~/.claude/scripts/rfp-watch.sh`

## Crystal 페르소나 trigger 점검 (RFP 도메인 특이)

| 어휘 | 의미 | 처리 |
|------|------|------|
| **딱딱** | 부동산 보고서 톤 답습 (카피 여운·현실감 부재) | 거버닝 메시지 동사형 + 직관성 |
| **조잡** | 좌측 강조선 6 elem 또는 컬러 카드 5개 그리드 | top/bg only 대체 |
| **헐빈** | 우측 col 콘텐츠 부족 / 정보 밀도 낮음 | KPI 보강 / mini timeline |
| **식상** | 클로징 클리셰 (월요일 체크리스트 류) | 동사형 commitment lead |
| **엉망진창** | 표지 더미 (의뢰·등급·disclaimer) 등 다중 오류 | 즉시 대규모 재작업 |

## 적용 시점

- brother/ 폴더 작업 시 자동 트리거 (rfp-orchestrator와 동시 로드)
- 이 skill은 **참조용** — 트리거 시 읽고 함정 사전 회피
- rfp-orchestrator skill의 1289 lines 전체 read 부담 ↓ (핵심 함정만)

## 관련 skill / agent

- **rfp-orchestrator** — 풀 워크플로우 오케스트레이터
- **crystal-multi-agent-orchestration** — 일반 Worker / Council / FIFO commit (RFP 도메인 X, 일반 멀티 에이전트)
- **crystal-infra-recovery** — APFS sparse / Vite / Docker 등 인프라 함정
- **crystal-plugin-dev** — 플러그인/스킬 함정
