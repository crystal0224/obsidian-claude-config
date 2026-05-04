---
name: rfp-orchestrator
description: 한국 부동산 분양 RFP·분양성 보고서·적정 분양가 산정 풀덱 작성을 위한 2-tier 오케스트레이터. Research Orchestrator (자료조사+검증+추가조사 iteration) → Presentation Orchestrator (HTML 통합+PDF+on-demand 자료 보완). 트리거 "RFP 풀덱", "분양 참여 제안서", "분양성 보고서", "적정 분양가 산정", "분양 제안서". brother/ 폴더 작업 시 자동 활성.
author: Crystal
version: 1.4.0
---

# RFP Orchestrator — 한국 부동산 분양 풀덱 2-tier 파이프라인

> v5 풀덱 작성 세션 (2026-05-04) 에서 단발 Worker 패러다임의 silent drift (Worker C 가 Worker A 결과 미참조 → cross-link 깨짐) + fact-check 누락 (양병천 11,100세대 hallucination → 실측 10,583) 을 발견하고, **자료조사 완결성·iteration 가능·on-demand 보완** 을 위한 구조로 압축.

## 언제 활성하는가

| 트리거 | 케이스 |
|--------|--------|
| 사용자가 "RFP 풀덱·분양 참여 제안서" 작성 요청 | brother/ 또는 brother-sample/ 작업 시 |
| 분양성 보고서·적정 분양가 산정·시장 분석 보고서 | Tone B 산출물 |
| 검토 보고서 (사업지·실적·구조) | 부동산 도메인 |
| RFP 의 한 쪽 콘텐츠 부족 (자료 보완 필요) | PO Phase 중 callback |

## 비활성 케이스
- 단순 슬라이드 작성 (`/new-presentation` 사용)
- 발표 준비 일반 (`/presentation-harness` 사용)
- 마케팅 안내문·잔금수금 (Tone A · brother CLAUDE.md 매핑 참조)
- 진짜 단발 작업 (단일 페이지 분석 sample) — orchestrator overkill

## 핵심 원칙

1. **Research-first** — 자료조사·fact-check 가 RFP 작성보다 먼저. 자료 미완결 상태에서 PPT 시작 금지.
2. **Cross-link 강제** — 한 Worker 의 출력 (예: MOLIT 평당가 4,370) 이 다른 Worker 의 입력으로 published 되면 후속 Worker 는 그 값을 reference. 추측·미확인 진행 silent drift = 1차 anti-pattern.
3. **Iteration** — 자료조사는 1회로 끝나지 않음. Auditor 가 gap 발견하면 추가 조사 task spec → Main 이 추가 Worker spawn.
4. **On-demand callback** — PPT 작업 중 Presentation Orchestrator 가 자료 부족 발견하면 Main 에 callback 요청. Main 이 RO 재호출 → 추가 자료 → PO 재개.
5. **완결성 게이트** — RO 가 GO/NO-GO 판정. NO-GO 면 PO 진행 차단.

## 2-tier 구조

```
Main (Crystal 대화 + 모든 Agent dispatch 통제)
  │
  ├── Phase 1: Research Orchestrator (RO)
  │   │   목적: 자료조사 완결성. cross-link 무결성. fact-check.
  │   │
  │   ├── Round 1 (병렬):
  │   │   ├── Worker A: 자동조사 (MOLIT API + Phase 1 MVP)
  │   │   ├── Worker B: reference-analyzer (★250414 등 PPTX 패턴)
  │   │   └── Worker C: Layer 2 도메인 sample (회사·인력·수수료)
  │   │   각 완료시 → Auditor A/B/C 즉시 dispatch
  │   │
  │   ├── Round 1 후 — RO sub-task:
  │   │   1. Auditor 결과 통합 + cross-link 무결성 점검
  │   │   2. fact-check 충돌 발견 시 (예: 11,100세대 vs 10,583)
  │   │   3. 자동 patch 가능 항목 spec (예: 25.7→21평, 4,000→4,370)
  │   │   4. 추가 조사 필요 항목 spec
  │   │   5. Crystal 결정 항목 카테고리화 (보통 4 그룹)
  │   │
  │   ├── Round 2 (필요 시): Main 이 추가 Worker spawn
  │   │   예: ★250414 5번째 단지 추출 / 정률 vs 정액 산식 확정 / 1-2인 가구 비율 추가 조사 등
  │   │   각 완료시 Auditor 재검증
  │   │
  │   └── 완결성 보고 → GO/NO-GO 판정
  │
  ├── Phase 2: Presentation Orchestrator (PO)
  │   │   목적: 11쪽 HTML 통합 + PDF + on-demand 자료 보완.
  │   │
  │   ├── 입력: RO 가 produce 한 cross-link patched 자료
  │   ├── HTML 통합 (v4 layout 기반 또는 신규 작성)
  │   ├── 작업 중 자료 부족 발견 시:
  │   │   → Main 에 callback 요청 (`/tmp/orchestrate_runs/<SESSION>/po_callback.md` 작성)
  │   │   → Main 이 RO 재호출 → 추가 자료 → PO 재개
  │   ├── PDF 변환 (Chrome headless --print-to-pdf, 11쪽 fit 검증)
  │   └── Final Auditor (8 항목 검증 — 아래 참조)
  │
  └── Main: RO/PO 가 작성한 spec 을 받아 실제 Agent dispatch
      (sub-agent 가 sub-agent dispatch 어려움 → spec 작성과 spawn 분리)
```

## Phase 1 — Research Orchestrator (RO) 상세

### Round 1 — 3 Worker 병렬

#### Worker A — 자동조사 (MOLIT API)

**Source**: `/Users/crystal/Desktop/brother/scripts/automation/` (Phase 1 MVP)

**프롬프트 skeleton**:
```
당신은 Worker A. brother-automation Phase 1 MVP 실행해서 [지역] 실거래가 fetch + 인근 단지 + 적정 분양가 산정.

## 요구사항
1. python -m scripts.automation --site "[가상 단지명]" --submarket-sigungu [구] --from-date YYYY-MM --to-date YYYY-MM
2. nearby_units 6 row (단지명/위치/세대수/분양가/분양시기/흡수율)
3. pricing_3 (보수 -5% / 표준 / 적극 +5%, 286세대 × N평 매출 추정)
4. hojae.md (역세권·단지·인허가 trend)

## 절대 금지
- 흡수율·세대수 등 MOLIT 결측 필드 추정값 채움 → "[TBD: 시장 자료]" 마킹
- footnote 누락 (아파트 비교 한계, n=2 표본 작음 등)

## 산출물 → /tmp/orchestrate_runs/<SESSION>/worker_a/
```

**Auditor A 검증 8 항목**:
1. MOLIT raw row count 독립 측정
2. 평당가 ±0.01% 재계산
3. 인근 6단지 csv 실재성 grep
4. 가중평균 독립 재계산
5. pricing_3 산식 (×0.95, ×1.05, 매출 × 환산)
6. [TBD] 결측 정직 마킹
7. caveats 적절성 (Worker D 가 v5 통합 시 누락 금지 권고)
8. 단위 일관성 (만원/㎡/평/억)

#### Worker B — reference-analyzer

**Source**: `★250414 호반써밋수성 RFP markitdown` 또는 매칭 도메인 PPTX

**프롬프트 skeleton**:
```
당신은 Worker B. ★250414 호반써밋 RFP 와 v[N] 풀덱을 매칭해 24-30 누락 + 21-25 drift + 6-10 본질 차이 + P0/P1/P2 권고 산출.

## 요구사항
1. 250414_extract.md (15 슬라이드 추출)
2. comparison_matrix.md (11 페이지 매칭, ✓/✗/△ mark)
3. vocabulary_patterns.md (9 카테고리 한국어 어휘)
4. v5_recommendations.md (P0 3 + P1 6 + P2 4)

## 핵심 점검
- "결론 1줄 (대형) + sub 1줄" 패턴이 ★250414 본문 9 페이지에 일관 있는가
- v[N] 에 그 패턴이 있는가 (없으면 헐빈 root cause)
- 본질 차이 (재분양 vs 신규 분양) 가 분양가 산식·수수료에 어떻게 영향
```

**Auditor B 검증 8 항목**:
1. ★250414 markitdown 실재성
2. 9 단지 단지명·세대수 grep 매칭
3. 수수료 정액 산식 검증
4. conclusion-strip 9 페이지 누락 grep 확정
5. 24/21/6 카운트 정확성
6. 양병천 약력 cross-link with Worker C
7. 사용자 결정 4건 본질 검증
8. P0/P1/P2 우선순위 정합성

#### Worker C — Layer 2 도메인 sample

**Source**: `RFP_TEMPLATE.md` p.3·p.4·p.9·p.11 + ★250414 패턴

**프롬프트 skeleton**:
```
당신은 Worker C. RFP v[N] 의 Layer 2 (회사·인력·수수료) 도메인 sample 작성. demo 성격 keep — 모든 sample 에 [SAMPLE: 항목] 마킹.

## 요구사항
1. company_profile.md (p.3 회사 개요·연혁·대표 약력)
2. track_record.md (p.4 분양 실적 N row + 본부장 약력)
3. organization.md (p.9 인력 36명 + 팀장 5 + 부동산 12)
4. fee_basis.md (p.11 수수료 산정 4 항목)
5. swap_markers.md (모든 [SAMPLE] 마킹 list)

## 절대 금지
- 진짜 실데이터 hallucination
- 사진 첨부 (placeholder 위치만)
- ★250414 콘텐츠 그대로 복사 (변형 + [SAMPLE] 마킹)
- Worker A 결과 미참조 (분양가 baseline 절대 금액은 [SAMPLE] 또는 [Worker A 산출] 으로 표기)
```

**Auditor C 검증 8 항목**:
1. [SAMPLE] 마킹 누락 점검 (구체값에 마크 없으면 critical)
2. 수수료 산식 무결성 (인건비 + 광고 + 모델하우스 + 부동산 = 합계)
3. Worker A cross-link 일관성 (분양가 baseline·평형 가정·% 산출)
4. 양병천 약력 ★250414 일치 (with Worker B)
5. 도메인 단가 현실성 (인건비·광고비·모델하우스 시장 시세 부합)
6. NDA 위반 risk (실시행사 명 노출)
7. 회사 설립년수 + 실적 페이스 정합성
8. swap_markers 카운트 (claim vs grep -c)

### Round 1 후 — RO 통합 sub-task

RO 가 spawn 되면 다음을 produce:

```markdown
# RO Round 1 통합 보고

## Cross-link 무결성 점검
- Worker A → Worker C: baseline·평형·% 일치 (or 불일치 발견)
- Worker B → Worker C: 양병천 약력 일치 (or hallucination)

## fact-check 충돌
- [11,100세대 vs 10,583세대 류 항목]

## 자동 patch 가능 (Crystal 확인 불필요)
- 25.7평 → 21평
- 4,000만/평 → 4,370만/평
- 11,100세대 → 10,583세대 (or 5번째 단지 명시)

## Crystal 결정 카테고리 (보통 4 그룹)
1. **Cross-link 무결성** (자동 처리, Crystal 승인만)
2. **수수료 산출 방식** (정률 vs 정액 vs hybrid)
3. **분양 실적 row 수** (Auditor B vs C 충돌 등)
4. **narrative 톤** (본사 주소·NDA·도시형 vs 오피스텔·별첨·layout)

## 추가 조사 필요 (Round 2 candidate)
- ★250414 5번째 단지 (10,583 → 11,100 정정에 필요한 수치)
- 1-2인 가구 비율 (Worker A 결측)
- 도시형생활주택 인허가 trend
- 흡수율 [TBD] 보강

## GO/NO-GO 판정
- 자료 완결성: PASS|PARTIAL|FAIL
- cross-link 무결성: PASS|PARTIAL|FAIL
- fact-check: PASS|PARTIAL|FAIL
```

### Round 2 (필요 시)

Main 이 RO 결과 받아서:
1. Crystal 에게 카테고리별 batch 결정 (4 그룹) 제시
2. Crystal 결정 + 추가 조사 spec → 추가 Worker spawn
3. 추가 Worker 완료 → Auditor 재검증
4. RO 재진입 → 완결성 재판정

## Phase 2 — Presentation Orchestrator (PO) 상세

### 입력
- RO 가 produce 한 cross-link patched 자료 (Worker A/B/C 산출물 + Auditor 결과 + Crystal 결정)
- DESIGN.md §12 Tone B 토큰 (linear.app 차용)
- v[N-1] HTML (있으면 layout reference)

### HTML 통합

**프롬프트 skeleton**:
```
당신은 Worker D. RO 가 produce 한 자료를 v[N] 11쪽 HTML 로 통합.

## 입력
- RO 통합 보고 + 모든 Worker 산출물 + Crystal 결정 batch
- DESIGN.md §12 Tone B (linear.app 토큰)
- v[N-1] HTML (layout reference)

## 요구사항
1. v[N].html 작성 (single :root, 11쪽 통일 anatomy)
2. RO patched 자료 swap ([TBD]·[SAMPLE] 모두 처리)
3. conclusion-strip 9 페이지 추가 (Worker B P0-1)
4. 수수료 footnote 3 항목 (Worker B P0-3)
5. PDF 변환 (Chrome headless, 11쪽 fit)

## 자료 부족 발견 시
- 작업 stop. /tmp/orchestrate_runs/<SESSION>/po_callback.md 작성:
  - 어떤 페이지·어떤 elem 에서
  - 어떤 자료가 부족한지
  - 추가 조사 spec (이러이러한 자료가 fetch 되어야 함)
- Main 에 callback 요청 → Main 이 RO 재호출 → 추가 자료 도착 → 작업 재개

## 절대 금지
- 자료 부족을 [TBD] 로 채우고 진행 (callback 의무)
- Cross-link patched 자료 무시 (예: 4,000 → 4,370 안 swap)
- DESIGN.md §12 Tone B 토큰 drift (#5E6AD2 등)
- 11쪽 fit 위반 (12쪽 또는 10쪽 X)
```

### On-demand RO Callback

PO 가 작업 중 자료 부족 발견 시:
```markdown
# PO Callback (po_callback.md)

## Trigger
- 페이지: p.5 입지 분석
- elem: 1-2인 가구 비율 막대 그래프
- 부족 자료: 마곡동·화곡동·등촌동 1-2인 가구 비율 (% 단위)

## 추가 조사 spec
- 통계청 KOSIS 인구주택총조사 2026년 → 강서구 동별 1-2인 가구 비율 추출
- 또는 KB부동산 동별 인구통계
- 결과를 /tmp/orchestrate_runs/<SESSION>/worker_a_round2/single_household_ratio.json 으로

## 차단 결정
- 이 자료 없이 p.5 진행 불가 (시각적 elem 핵심)
- Crystal 에게 callback 알림 + 결정 요청
```

Main 이 callback 받으면:
1. Crystal 에게 즉시 보고 (자료 부족 이유 + 옵션)
2. Crystal 승인 → 추가 Worker spawn → Auditor → RO 재검증
3. PO 작업 재개

### Final Auditor 8 항목

PO 완료 후 검증:
1. **남은 [TBD]·[SAMPLE] count** (Layer 3 image placeholder 만 허용)
2. **DESIGN.md Tone B 토큰 일치** (drift 0)
3. **Crystal 부정사전 5개** (엉망진창·조잡·식상·딱딱·헐빈, 0 hits)
4. **메타 영문 어휘 0** (콘텐츠 — CSS 주석·`align-items: baseline` 등 false positive 제외)
5. **A4 가로 11쪽 fit** (PDF mediabox 297mm × 210mm)
6. **한국 RFP 어휘** (★250414 patterns ≥ N hits)
7. **§12.8 nowrap 룰** (숫자+단위 white-space: nowrap)
8. **Cross-link 무결성** (Worker A baseline 4,370 → v[N] p.7·p.11 실제 swap 됐는지 grep)

## Crystal 결정 항목 카테고리화 룰

자료조사 + 검증 후 Crystal 결정 항목이 보통 12-20개. 카테고리 4 그룹으로 압축:

| 카테고리 | 처리 | 예시 |
|---------|------|------|
| **C1 — Cross-link 무결성** | RO 자동 patch + Crystal 승인만 | 25.7→21평, 4,000→4,370/평, 11,100→10,583 |
| **C2 — 산출 방식** | Crystal 선택 (옵션 명확) | 수수료 정률 vs 정액 vs hybrid |
| **C3 — Auditor 충돌** | Crystal 결정 (논리 + 권고) | B: 6 row keep / C: 4 row 축소 |
| **C4 — narrative 톤** | Crystal 선택 (도메인 직관) | 본사 주소, NDA 범위, 도시형 vs 오피스텔, 별첨 추가 |

batch 결정: 4 카테고리 = 4 질문, 한 번 응답으로 12-20 항목 처리.

## brother/ 폴더 종속성

이 스킬을 사용하기 전 다음 파일들이 brother/ 안에 존재해야:

| 파일 | 역할 |
|------|------|
| `RFP_TEMPLATE.md` | 11쪽 RFP 표준 spec |
| `DESIGN.md` (§12 Tone B) | 디자인 토큰 + linear.app 차용 |
| `CLAUDE.md` | 부정사전·도메인 정체성 |
| `WORKFLOW.md` | RFP 워크플로우 §1~§6 |
| `AUTOMATION.md` | Phase 1 MVP spec |
| `scripts/automation/` | Phase 1 MVP 코드 + MOLIT API |
| `★250414 markitdown` (or PPTX) | reference-analyzer source |
| `.env` (`MOLIT_API_KEY`) | API 인증 |

## 파일 구조 — 매 RFP 세션

```
/tmp/orchestrate_runs/<TIMESTAMP>_rfp_<id>/
├── plan.md                  # topology 선언 + 카테고리 분류
├── SESSION_ID.txt
├── worker_a/                # MOLIT 자동조사
│   ├── molit_raw.csv
│   ├── nearby_units.json
│   ├── pricing_3.json
│   ├── hojae.md
│   └── worker_a_anomalies.md
├── worker_b/                # reference-analyzer
│   ├── 250414_extract.md
│   ├── comparison_matrix.md
│   ├── vocabulary_patterns.md
│   ├── v[N]_recommendations.md
│   └── worker_b_anomalies.md
├── worker_c/                # Layer 2 sample
│   ├── company_profile.md
│   ├── track_record.md
│   ├── organization.md
│   ├── fee_basis.md
│   ├── swap_markers.md
│   └── worker_c_anomalies.md
├── worker_d/                # PO output
│   ├── v[N].html
│   ├── v[N].pdf
│   └── po_callback.md (있으면)
├── audit_a.md
├── audit_b.md
├── audit_c.md
├── audit_d.md (final)
├── audit_summary.md         # 누적 보완사항
├── ro_round1_report.md      # RO Round 1 통합
├── ro_round2_report.md      # 있으면
└── decisions.md             # Crystal 결정 batch 결과
```

## Anti-patterns (절대 하지 말 것)

1. **단발 Worker 후 즉시 PPT** — RO 검증 + cross-link 무결성 게이트 통과해야 PPT 진행
2. **추측으로 [SAMPLE] 채움** — Worker A 결과 미참조 silent drift = 1차 anti-pattern
3. **Auditor 충돌 무시** — B vs C 충돌 시 Crystal 결정 기다림. 어느 한 쪽으로 자동 진행 X
4. **callback 무시** — PO 가 자료 부족 발견하면 [TBD] 채우지 말고 callback. Main 이 RO 재호출
5. **fact-check 누락** — 양병천 11,100세대 같은 ★250414 직접 출처 표기 항목은 grep 으로 정합 확인 필수
6. **카테고리화 없이 16 결정 항목 raw 제시** — Crystal 인지 부하. 4 카테고리로 압축 후 batch 결정

## 사용 예시

### 새 RFP 시작
```
사용자: "강서구 발산역 신규 RFP 풀덱 작성"

Main:
1. SESSION dir 생성
2. RO Round 1 dispatch (Worker A·B·C 병렬 + Auditor 각각)
3. 모든 완료시 RO 통합 sub-task spawn
4. RO 보고 받음 → Crystal 에게 4 카테고리 batch 결정 제시
5. Crystal 결정 + 추가 조사 (필요시 Round 2) → PO dispatch
6. PO 진행 중 callback 가능
7. PO 완료 → Final Auditor → Crystal 보고
```

### v5 풀덱 (현재 진행 중 사례)
- Round 1 결과: Worker A/B/C 모두 완료, Auditor A 8/8 / B 8/8 / C 4 PARTIAL
- Critical: Worker C cross-link 깨짐 (25.7→21평, 4,000→4,370, 1.21→1.36%) + 11,100→10,583 hallucination + 1.5년 6단지 페이스 비현실
- Round 2 필요: RO 가 cross-link patch + Crystal 결정 4 카테고리 압축
- 그 다음 PO Worker D dispatch → v5 HTML + PDF + Final Audit

## 향후 확장 (현재 미구현, 남은 ad-hoc 항목)

- `scripts/automation/orchestrate_research.py` (RO Python implementation)
- `scripts/automation/orchestrate_presentation.py` (PO Python implementation)
- 자동화된 callback loop (Python state machine)
- 매 세션 RO 보고를 시계열로 누적 (`docs/rfp-history/`)
- ~~멀티 도메인 (분양성 보고서·적정 분양가·시장 분석 별 spec 분기)~~ → **v1.1.0 Phase 0 분기에서 구현**
- ~~★250414 외 다른 reference RFP 추가 (260416 신안군·청라의료복합·동탄 B1)~~ → **v1.1.0 Worker B 도메인 분기에서 구현**

---

# v1.1.0 (2026-05-04) — Phase 0 + 풍성 자료조사 + Worker F

> v5 세션의 단발 MOLIT only + ★250414 단일 reference 한계 발견 → 6 PPTX (★250414·★250901·신안·청라·마곡 잔금수금·지우 마곡 제안서) 자료조사 패턴 분석 결과 통합. Worker E (`/tmp/orchestrate_runs/20260504_213502_rfp_v5/worker_e/`).

## Phase 0 — Onboarding (대화형 question)

RFP 트리거 직후 Main 이 Crystal 에게 묻는 표준 6 질문. 기본값 있는 질문은 단답으로 패스 가능.

### 필수 질문 (4개)
1. **단지명** — `[가상] OO 단지` 또는 실제 명. 예: "마곡 르웨스트"
2. **시행사** — 실제 또는 `[가상] OO 개발(주)`. 예: "롯데건설"
3. **사업 위치** — 시·구·동 (구 단위 필수, MOLIT API 호출에 사용). 예: "서울 강서구 마곡동"
4. **부동산 종류** — 다음 中 1:
   - 아파트 (일반·공공임대·민간임대)
   - 도시형생활주택
   - 오피스텔
   - 생활형숙박시설
   - 의료복합 (노인복지주택 등)
   - 연립주택·테라스형

### 선택 질문 (2개, default 있음)
5. **문서 종류** — 다음 中 1 (default: RFP 응답):
   - **RFP 응답** (분양 참여 제안서) — 인력·일정·수수료 위주 / ★250414 패턴 / 11~15쪽
   - **적정 분양가 산정** — 시세 분석·3안 산정 / ★250901 동탄 패턴 / 8~12쪽
   - **마케팅 전략 제안서** — 인구·호재·정책 풍부 / 신안 패턴 / 30~40쪽
   - **분양성 보고서** — 시장조사·비교요인법 / 청라 패턴 / 25~30쪽
6. **청중** — 다음 中 1 (default: 시행사):
   - 시행사 (사업주)
   - 분양조직 (본부장·팀장·직원)
   - 외부 대행사 (협력)

### 자동 검증 체크리스트
- [ ] MOLIT API key 셋업 (`.env` 의 `MOLIT_API_KEY`) 확인
- [ ] KOSIS API key (선택, `.env` 의 `KOSIS_API_KEY`) — 미사용 시 CSV fallback
- [ ] 기존 자료 유무 (`/Users/crystal/Desktop/brother/<지역>/`)
- [ ] 별첨 포함 여부 (default: 1쪽 별첨)
- [ ] 페이지 수 (default: 11쪽)

### Crystal 응답 short-form 지원
- "마곡 르웨스트, 롯데건설, 강서구 마곡동, 아파트, RFP 응답, 시행사" 한 줄 OK
- 단답 패스: "동탄 적정가" → 적정 분양가 + 연립 + ★250901 동탄 자동 매칭

## Round 1A — 풍성한 자료조사 (병렬 4 Workers)

기존 3 Worker (A·B·C) 에서 **Worker F 추가**.

### Worker A — 정량 자동 fetch (확장)

**기존**: MOLIT 단발 API only

**확장 spec** (v1.1.0):
1. **MOLIT 실거래가** — RTMSDataSvcAptTrade / RHTrade (연립) / OFTrade (오피스텔). 부동산 종류 따라 endpoint 분기.
2. **KOSIS 인구·세대 통계** (DT_1B040A3) — 5년 timeline, 도메인별 인구 trend
3. **KOSIS 인구이동** (DT_1B26001) — 전입·전출 TOP 6
4. **청약Home 청약경쟁률** — 인근 분양 단지 5건
5. **사업체 통계** (KOSIS, 선택) — 종사자·평균소득

**5 산출물**:
- `worker_a/molit_raw.csv`
- `worker_a/kosis_population.csv`
- `worker_a/kosis_migration.json`
- `worker_a/cheongyak_results.json`
- `worker_a/business_stats.json` (선택)

**필수 메타데이터** (각 파일 header):
- `source_url`: 실제 호출 URL
- `fetched_at`: ISO timestamp
- `data_period`: "2026-04 ~ 2026-04" 형태
- `item_count`: row 수
- `key_match`: 사업지·기간 일치 여부

### Worker B — reference-analyzer (도메인 분기)

**기존**: ★250414 호반써밋 단일 매칭 (1-1)

**확장 spec** (v1.1.0): Phase 0 응답에 따라 6 PPTX 中 1-2개 자동 매칭. **부동산 종류 × 문서 종류 매핑** 표 (아래) 참조.

**Worker B 산출물 6 파일** (기존 4 + 신규 2):
- `<reference>_extract.md`
- `comparison_matrix.md`
- `vocabulary_patterns.md`
- `recommendations.md`
- **(신규)** `data_source_pattern.md` — 매칭 PPTX 의 출처·자료조사 패턴 추출
- **(신규)** `framework_diagram.md` — 매칭 PPTX 의 5장/3안/평점법 등 표준 구조 차용

### Worker C — 회사 sample (변경 없음)

기존 그대로: `company_profile.md`, `track_record.md`, `organization.md`, `fee_basis.md`, `swap_markers.md`

### Worker F — Web Search & Narrative (신규)

**책임**: 정량 fetch 로 못 잡는 정성 narrative + 호재 timeline + 정책 brief.

**4 산출물**:

1. `worker_f/hojae_timeline.md` — 호재 timeline (3-5건)
   - WebSearch: `"<지역> 호재 OR 개발사업 OR 교통" "2025 OR 2026"`
   - Source: 시·군 보도자료, 매경/한경/한겨레 부동산
   - 형식: 연도 + 사업명 + 위치 + 사업비 + 기대효과 (참고: 신안 PPTX slide 8)

2. `worker_f/market_narrative.md` — 시장 분위기 (300-500자)
   - WebSearch: `"<지역> 분양시장 OR 미분양 OR 시세" 최근 6개월`
   - 형식: 분양가 trend + 미분양 동향 + 청약 분위기

3. `worker_f/policy_brief.md` — 정책 brief (단지·상품 영향)
   - WebSearch: `"<상품종류> 규제 OR 정책 OR 대책"`
   - Source: 국토부 보도자료, 법제처 (`law.go.kr`)
   - 형식: 발표일 + 정책명 + 주요 내용 + 당 PJT 영향 (참고: 청라 PPTX slide 12)

4. `worker_f/nearby_recent.md` — 인근 분양 단지 reference (3-5건)
   - WebSearch: `"<지역> 분양 OR 청약" 최근 12개월`
   - Source: 입주자 모집공고, 청약Home, 한국부동산원
   - 형식: 단지명 + 분양/입주 + 분양가 + 청약경쟁률 + 분양조건 (참고: 청라 PPTX slide 16-18)

**Worker F 절대 금지**:
- 출처 hallucination (WebSearch 결과만 cite)
- "최근" 같은 모호한 시점 — 명확한 일자 명시
- 단순 의견 (한경/매경 같은 매체 cite 필수)

**Worker F prompt template**: `~/.claude/skills/rfp-orchestrator/references/worker_f_prompt.md`

### Round 1B — 정리·압축 (페이지 fit)

Round 1A 양적 풍부 → Worker D (PO) 또는 별도 Compactor 가 11쪽 fit 으로 다듬기.

## 자료조사 source 카탈로그 (12 source × 우선순위 1-3차)

| 자료 | source | 호출 방식 | 우선순위 | 적용 케이스 |
|------|--------|-----------|---------|-----------|
| **실거래가** | MOLIT RTMS API | 공공데이터포털 API key | **1차** | 모든 케이스 |
| **인구·가구** | KOSIS DT_1B040A3 | KOSIS API or CSV | **1차** | 마케팅 전략·분양성 보고서 |
| **인구이동** | KOSIS DT_1B26001 | KOSIS API | **1차** | 마케팅 전략·분양성 보고서 |
| **인허가/분양** | 시·군·구청·SH·LH | WebSearch | 2차 | 모든 케이스 |
| **시세 (KB)** | KB Liiv ON `liivon.kbstar.com` | 웹 스크래핑 | 2차 | 적정 분양가 산정 |
| **청약경쟁률** | 청약Home `applyhome.co.kr` | 웹 스크래핑 | 2차 | 분양성 보고서·RFP 응답 |
| **호재** | 매경·한경·한겨레 / 시·군 보도자료 | WebSearch | 3차 (narrative) | 마케팅 전략 풍부 |
| **정책 brief** | 국토부·국토교통위원회·법제처 | WebFetch | 3차 | 분양성 보고서·RFP 응답 |
| **교통** | 국토부 교통DB·서울교통공사·KORAIL | WebFetch | 3차 | 마케팅 전략·분양성 보고서 |
| **시장 trend** | 한국부동산원 R-ONE·부동산114 | WebFetch | 3차 | 분양성 보고서 |
| **사업체 조사** | 통계지리서비스 국가데이터처 | WebFetch | 3차 (선택) | 마케팅 전략 (타겟 분석) |
| **시·군 통계연보** | 시·군청 자료실 PDF | WebFetch + PDF parse | 3차 (선택) | 마케팅 전략 |

- **1차** = Worker A (정량 자동 fetch, API)
- **2차** = Worker A (정량 web fetch) 또는 Worker F (정량 web search)
- **3차** = Worker F (정성 narrative + 호재 + 정책 + trend)

### 출처 footnote 표준 형식

각 슬라이드 footnote 에 다음 형식 표준화 (6 PPTX 공통 패턴):
- `[ 출처 : KOSIS 행정구역별 인구수 / 기준 : 2026.03 / 단위 : 명 ]` (신안 PPTX 패턴)
- `[ 출처 : 국토교통부 아파트 실거래가 ‘26.04 ~ ‘26.04 / 단위 : 천원 ]` (청라 PPTX 패턴)
- `(자료 : 네이버부동산 KB부동산 매매시세)` (동탄 PPTX 패턴)

표준 = `[출처: <source> / 기준: <기간> / 단위: <unit>]` 3-필드.

## 부동산 종류 × 문서 종류 매핑 (Phase 0 분기)

Phase 0 응답에 따라 자동 매칭되는 reference PPTX + 핵심 자료조사:

| 부동산 종류 | 문서 종류 | 매칭 PPTX (Worker B) | 핵심 자료조사 (Worker A·F) | 분량 |
|------------|----------|---------------------|------------------------|------|
| 아파트 | RFP 응답 | ★250414 호반써밋 | MOLIT + 청약Home + KB시세 | 11~15쪽 |
| 아파트 | 적정 분양가 | ★250901 동탄 | MOLIT + KB시세 + 비교평점 | 8~12쪽 |
| 아파트 (민간임대) | 마케팅 전략 | 260416 신안 | KOSIS + MOLIT + 호재·정책 | 30~40쪽 |
| 연립주택 | 적정 분양가 | ★250901 동탄 | MOLIT (RHTrade) + KB | 8~12쪽 |
| 오피스텔 | 분양성 보고서 | 청라 (비교요인법) | MOLIT (OFTrade) + R-ONE + 정책 | 25~30쪽 |
| 노인복지주택 | 분양성 보고서 | 청라 | KOSIS 연령별 + R-ONE | 25~30쪽 |
| 생활형숙박시설 | RFP 응답 / 제안서 | 지우 마곡 (2021) | 자체 시세 + 정책 timeline | 20~30쪽 |
| 생활형숙박시설 | 잔금수금 | 마곡 잔금수금 | 정책 timeline + 사례 12개 | 8~10쪽 |
| 도시형생활주택 | 적정 분양가 | (없음 — generic 적용) | MOLIT + 정책 brief | 8~12쪽 |

**잔금수금 / 분양조직 청중 케이스**: 일반 RFP framework 비활성. Tone A 변형 (마곡 잔금수금 패턴) 매칭.

## v1.1.0 변경사항 요약

- ✅ **Phase 0** (Onboarding 대화형 6 질문) — 신규
- ✅ **Round 1A / 1B 분리** — 4 Worker 병렬 + Compactor
- ✅ **Worker A 확장** — MOLIT + KOSIS + 청약Home + R-ONE
- ✅ **Worker B 도메인 분기** — 6 PPTX 매핑 표
- ✅ **Worker F 신규** — Web Search & Narrative
- ✅ **자료조사 source 카탈로그** — 12개 source × 우선순위 1-3차
- ✅ **부동산 종류 × 문서 종류 매핑 표**
- ✅ **출처 footnote 표준 형식**

근거: 6 PPTX 자료조사 패턴 분석 (`/tmp/orchestrate_runs/20260504_213502_rfp_v5/worker_e/`)

---

# v1.2.0 (2026-05-04) — 디테일 검수 오케스트레이터 + 거버닝 메시지 규칙 + Anti-pattern 검출

> v5 세션 후반 (PO 산출물 → Crystal 시각 검토 → 9 라운드 반복 정제) 에서 발견된 실측 레슨 통합. **PO 가 자료를 받아서 HTML 한 번 만들고 끝나는 게 아니라, 매 변경마다 디테일을 검수·다잡는 게이트키퍼 역할이 핵심**.

## Detail Gatekeeper Orchestrator (DGO) — 신규 핵심 역할

기존 RO/PO 외에 **DGO** 가 매 변경마다 자동 점검. PO 가 HTML 변경할 때마다 다음 8 항목 즉시 검증:

### 8 Detail Gates (매 변경 후 자동 실행)

```bash
# Gate 1: 페이지 fit (PDF 페이지 수)
python3 -c "from pypdf import PdfReader; print(len(PdfReader('FILE.pdf').pages))"
# 기대값: 정확히 11쪽 (또는 Phase 0 결정값). 12쪽 → overflow → 즉시 fix

# Gate 2: A4 가로 mediabox (297×210mm)
python3 -c "from pypdf import PdfReader; p = PdfReader('FILE.pdf').pages[0]; print(p.mediabox.width, p.mediabox.height)"
# 기대값: 841.92 x 594.96 pt (= 297×210mm)

# Gate 3: Crystal 부정사전 (5개 0 hits)
grep -cE '엉망진창|조잡|식상|딱딱|헐빈' FILE.html
# 기대값: 0

# Gate 4: 메타 영문 어휘 (콘텐츠 0)
grep -oE '\b(trace|conclusion|IRR|BEP|SWOT|persona|sub-market|Bear|Base|Bull|scenarios|eyebrow|baseline|KPI)\b' FILE.html | grep -v 'align-items: baseline\|/\* KPI'
# 기대값: 0 (false positive 제외)

# Gate 5: §12.8 nowrap 룰 (≥ 15 권장)
grep -c 'white-space: nowrap' FILE.html
# 기대값: ≥ 15

# Gate 6: Tone B 토큰 일치 (drift 0)
grep -E '#5E6AD2|#14306E|#0A0B0C|#D4D6DA|#F5F6F6' FILE.html | wc -l
# 기대값: 5 핵심 토큰 모두 존재

# Gate 7: Cross-link 무결성 (Worker A baseline → swap 됐는지)
grep -c '4,370' FILE.html  # Worker A 측정값
# 기대값: ≥ 1 (p.7 적정 분양가에 swap)

# Gate 8: Anti-pattern 검출 (좌측 강조 선)
grep -cE 'border-left:.*solid\s+var\(--(accent|navy)\)' FILE.html
# 기대값: 0 (Crystal "조잡" trigger anti-pattern)
```

### DGO 실패 시 처리

| Gate 실패 | 처리 |
|----------|------|
| Gate 1 — overflow | grid-row 재할당 / padding 축소 / col 재배치 / 콘텐츠 압축 (KPI 박스화) |
| Gate 2 — A4 mismatch | @page A4 landscape / .page width·height mm 단위 확인 |
| Gate 3 — 부정사전 | 즉시 사용자 보고 (대규모 재작업 신호) |
| Gate 4 — 메타 영문 | 한글화 (sub-market → 인근 시장, baseline → 기준) |
| Gate 5 — nowrap 부족 | mono 숫자·KPI value·footer source 등 selector 추가 |
| Gate 6 — Tone B drift | DESIGN.md §12.1 spec 으로 정정 |
| Gate 7 — cross-link 깨짐 | RO Round 2 재호출 / Worker D 가 Worker A 출력 read 강제 |
| Gate 8 — 좌측 강조 선 | top border / 둘레 border / bg only 로 대체 |

## 거버닝 메시지 규칙 (Conclusion-Strip Pattern)

v5 세션에서 사용자 명시 요청: **동사형 개조식 완결**. 명사 종결 금지. 모든 conclusion-strip lead 에 적용.

### 규칙

| # | 항목 | 예시 (X) | 예시 (O) |
|---|------|---------|---------|
| 1 | 동사 종결 | "발산역 280m·마곡 R&D 5분 직주근접 입지" | "발산역 280m·마곡 R&D 5분 직주근접 입지로 1-2인 가구 직접 흡수" |
| 2 | 한 줄 (30~50자) | (긴 문장 X) | "표준안 4,370만원/평 × 286세대 × 21평 적용 시 매출 2,624.6억 달성 가능" |
| 3 | 수치 + 의미 + 결과 동시 | "본부장 양병천 약력" | "본부장 양병천 e편한세상 4단지 누적 10,583세대 분양 실적 확보" |
| 4 | 명사 종결 금지 | "분양가 5~7% 정률 + footnote 3" | "분양가 5~7% 정률 + 지급조건·MGM·특판 3 footnote 명시로 시행사 명확 약속" |
| 5 | white-space: nowrap | (줄바꿈 X) | (한 줄로 fit) |

### 동사 종결 어휘

- 보유 / 확보 / 흡수 / 적용 / 달성 / 가동 / 운영 / 기대 / 가능 / 명시 / 제공 / 창출
- 분양 / 운영 / 입증 / 검증

### conclusion-strip CSS (DGO 검증 spec)
```css
.conclusion-strip { grid-row: 2; padding: 1mm 0 3mm; }
.conclusion-strip .lead {
  font-size: 13pt; font-weight: 600; color: var(--navy);
  letter-spacing: -0.3px; line-height: 1.35;
  white-space: nowrap;  /* §12.8 룰 */
}
```

## Anti-pattern 라이브러리 (즉시 검출 + 자동 fix)

v5 세션에서 발견된 anti-pattern 9 개. 매 변경마다 DGO 가 grep 으로 검출.

| # | Anti-pattern | 검출 grep | 자동 fix |
|---|-------------|----------|---------|
| AP-1 | 좌측 강조 선 (Crystal "조잡") | `border-left:.*solid var\(--(accent\|navy)\)` | top border / 둘레 border / bg only |
| AP-2 | 헤더 sub 노이즈 | `<div class="page-sub">` | 통째 제거 |
| AP-3 | 거버닝 메시지 회색 sub | `<div class="sub">` (conclusion-strip 안) | 통째 제거 (lead만 keep) |
| AP-4 | 표지 더미 (의뢰·등급·disclaimer·PAGE) | `cover-meta-cell\|cover-footer-line` | 표지에서 제거 (조직명 + 날짜만 keep) |
| AP-5 | 목차 sub 부연 설명 | `<span class="sub">` (toc-list 안) | 통째 제거 |
| AP-6 | 의미 없는 footer source | `<div class="source">출처 \|<div class="source">본 보고서` | 빈 div 또는 제거 |
| AP-7 | float 사진 layout 깨짐 | `float:\s*left.*img-placeholder` | grid 또는 flex 명시 배치 |
| AP-8 | 명사 종결 거버닝 메시지 | conclusion-strip lead 끝 어휘 검사 | 동사형 종결 (보유·확보 등) |
| AP-9 | 헤더-거버닝 메시지 spacing 4mm+ | `.conclusion-strip { padding: [4-9]mm` | padding: 1mm 0 3mm |

## 페이지 레이아웃 5-row 표준 (모든 페이지 일관)

```css
.page {
  grid-template-rows: 26mm auto 1px 1fr 9mm;  /* header / strip / divider / body / footer */
  /* 5-row grid + grid-row 명시 할당으로 strip 없는 페이지도 안 깨짐 */
}
.page-header  { grid-row: 1; padding-bottom: 0; }
.conclusion-strip { grid-row: 2; padding: 1mm 0 3mm; }
.divider      { grid-row: 3; background: var(--navy); height: 1px; }
.page-body    { grid-row: 4; padding-top: 6mm; }  /* divider 아래 lg spacing */
.page-footer  { grid-row: 5; }
```

## DESIGN.md Tone B Spacing Token 매핑 (실측 검증 적용)

| 토큰 | 값 | 적용 |
|------|-----|------|
| xxs | 1mm | strip padding-top, KPI cell padding |
| xs | 2mm | profile-table padding |
| sm | 3mm | strip padding-bottom, basis-block gap |
| md | 4mm | basis-block padding, leader-card padding |
| lg | 6mm | divider→body padding-top, header gap |
| xl | 8mm | section break, cover-sub margin-top |
| xxl | 12mm | cover padding-top |

## Worker D (PO) 책임 확장 — DGO 통합

기존 PO 책임 + DGO 8 Gate 매 변경 후 자동 실행. 한 번 만들고 끝이 아니라 **반복 검증·수정 사이클**:

```
PO HTML 변경 →
  DGO 8 Gate 실행 →
    PASS → PDF 생성 + 시각 검증 →
    FAIL → Anti-pattern 자동 fix or 사용자 보고 →
  반복 (사용자 결정 OR overflow 해결까지)
```

## v1.2.0 변경사항 요약

- ✅ **Detail Gatekeeper Orchestrator (DGO)** — 신규 핵심 역할
- ✅ **8 Detail Gates** — 매 변경 자동 검증 (페이지 fit / A4 / 부정사전 / 메타영문 / nowrap / Tone B drift / cross-link / anti-pattern)
- ✅ **거버닝 메시지 규칙 (5)** — 동사형 개조식 완결 / 한 줄 / 수치+의미+결과 / 명사 종결 금지 / nowrap
- ✅ **Anti-pattern 9 라이브러리** — 좌측 강조 선·헤더 sub·표지 더미·footer source·float 사진 등 자동 검출
- ✅ **페이지 layout 5-row 표준** — grid-row 명시 할당으로 strip 없는 페이지도 안 깨짐
- ✅ **DESIGN.md spacing token 매핑** — xxs~xxl 7-tier 실측 적용
- ✅ **PO 책임 확장** — 한 번 생성이 아니라 반복 검증·수정 사이클

근거: v5 세션 9 라운드 정제 (`/Users/crystal/Desktop/brother-sample/sample-rfp-bunyangga-v5-fulldeck.html` v1.0 → v5.2)

## v5 세션 레슨런 (실측)

| # | 발견 | 처리 | 일반화 |
|---|------|------|--------|
| L1 | Worker D [SAMPLE]=30 보고 vs 실측 36 (undercount) | DGO Gate 추가 | 모든 grep count 보고 → Auditor 재실측 |
| L2 | 좌측 강조 선 6 elem 사용 → "조잡" 트리거 | top/둘레 border 또는 bg only 로 대체 | AP-1 자동 검출 |
| L3 | 표지 의뢰/등급/disclaimer 더미 → "엉망진창" | 미니멀 표지 = 단지명 + 부제 + 조직 + 날짜 | AP-4 자동 검출 |
| L4 | 목차·헤더 sub 노이즈 | 통째 제거 | AP-2, AP-5 자동 검출 |
| L5 | conclusion-strip 명사 종결 → 설득력 부족 | 동사형 개조식 완결 | 거버닝 메시지 규칙 (5) |
| L6 | conclusion-strip body 안 → divider 위로 이동 시 grid 깨짐 | 5-row + grid-row 명시 할당 | 페이지 layout 표준 |
| L7 | 본부장 사진 카드 분양 실적 페이지 → 분리 안 됨 | 회사 소개 페이지로 이동 | Worker B 도메인 분기 (회사·실적 분리) |
| L8 | 인력 5 row 표 → 시각 부담 | KPI 박스 + footer 한 줄 압축 | 박스화 디자인 패턴 |
| L9 | Worker C 가 Worker A 결과 미참조 silent drift (25.7→21평) | RO cross-link patch + Crystal 4 카테고리 batch | DGO Gate 7 |
| L10 | 12쪽 overflow → 시각 검토 후 발견 | DGO Gate 1 매 변경 자동 | 즉시 감지 |
| L11 | "분양가 [SAMPLE]:..." 같은 [SAMPLE] 마킹이 단순 grep 보다 많음 | 47 (논리적 unique) vs 132 (raw count) 분리 | DGO 보고 시 둘 다 |
| L12 | 자료조사 부족 → "자료조사가 충분히 됐냐" 사용자 자각 | Worker F WebSearch 도입 | v1.1.0 도입 (Phase 1A) |

---

**Crystal 페르소나 룰**: 부정사전 5개 (엉망진창·조잡·식상·딱딱·헐빈), 4공리 (최소 마찰·Explicit Action·범위 준수·Escape Hatch), 메타 영문 어휘 0, 한국 RFP 어휘 (★250414 patterns), DESIGN.md Tone B 토큰 일치, 거버닝 메시지 동사형 개조식 (v1.2.0).

---

# v1.3.0 (2026-05-04) — 분기 결정 트리 + User Visual Review Loop + Failure Recovery + Auditor F + Main 책임

> v1.2.0 점검 결과 누락 7 영역 (U1~U7) + v5 세션 추가 레슨 5 (L13~L17). 에이전트 vs 룰 분기 명시 + 반복 사이클 표준.

## U1 — Phase 분기 결정 트리

```
사용자 RFP 요청
  ↓
Phase 0: Onboarding (대화형 6 질문)
  ├─ 단지명 / 시행사 / 위치 / 부동산종류 (필수)
  └─ 문서종류 / 청중 (선택, default: RFP응답+시행사)
  ↓
Phase 1A: Round 1 (병렬 4 Workers + 즉시 Auditor)
  ├─ Worker A (정량) → Auditor A
  ├─ Worker B (reference, 부동산×문서종류 매핑) → Auditor B
  ├─ Worker C (회사 sample) → Auditor C
  └─ Worker F (WebSearch, v1.1.0+) → Auditor F (v1.3.0 신규)
  ↓
Phase 1B: RO 통합 + Cross-link 검증
  ├─ Worker 간 silent drift 검출
  ├─ fact-check 충돌 cross-validation
  ├─ 16 결정 → 4 카테고리 (C1/C2/C3/C4) 압축
  └─ GO/NO-GO 판정
  ├─ NO-GO → Round 2 (추가 Worker spawn) → 재진입
  └─ GO ↓
Crystal 4 카테고리 batch 결정 (Escape Hatch: go / go all / 변경 ID / ?)
  ↓
Phase 2: Worker D (PO) + DGO 매 변경 자동 검증
  ├─ DGO 8 Gates (페이지 fit / A4 / 부정사전 / 메타영문 / nowrap / Tone B / cross-link / anti-pattern)
  ├─ 8 Gates FAIL → Recovery Pattern (U3) → 자동 fix or 사용자 보고
  └─ Worker D callback (자료 부족) → Main → RO 재호출 → 추가 자료 → Worker D 재개
  ↓
Final Auditor (8 Gate 종결 검증)
  ↓
User Visual Review Loop (U2)
  ├─ 사용자 시각 검토
  ├─ 부정사전 trigger → 즉시 대규모 재작업 (Round N+1)
  ├─ 의미·뉘앙스 catch → Main 직접 Edit
  ├─ 콘텐츠 cross-page 이동 → Worker D 재dispatch
  └─ OK → 종결 (audit trail commit + handoff)
```

## U2 — User Visual Review Loop (v5 세션 9 라운드 정제 일반화)

DGO 통과해도 사용자 시각 검토에서 catch 되는 패턴.

### Catch 대상 (DGO 가 못 잡음)
- Crystal 부정사전 5 (엉망진창·조잡·식상·딱딱·헐빈) — 의미 영역
- 거버닝 메시지 명사 종결 — 톤 영역
- 콘텐츠 cross-page 이동 요청 — 구조 영역
- 페이지 layout 시각 균형 — 디테일 영역
- 더미 elem (의뢰·등급·disclaimer 등) — 노이즈 영역

### 처리 표준
| 사용자 trigger | 처리 |
|---------------|------|
| **부정사전** ("엉망진창" 등) | 즉시 대규모 재작업 (전체 페이지 또는 elem 부) |
| **콘텐츠 재배치** ("앞페이지로 들어가야") | Worker D 가 양쪽 페이지 동시 수정 |
| **의미·뉘앙스** ("거버닝 메시지를 동사형 개조식으로") | Main 직접 Edit + 새 룰 SKILL 추가 (L13) |
| **노이즈 제거** ("이런 더미 다 없애고") | 일괄 grep 제거 (Bash sed/Python) |
| **spacing 미세 조정** | Tone B token 매핑 (xxs~xxl) |

매 정제 후: PDF 재생성 + 11쪽 fit 검증 + audit_summary.md 누적.

## U3 — Failure Mode + Recovery Pattern (8 표준)

| Failure | 진단 grep | Recovery |
|---------|---------|----------|
| **Worker silent drift** (cross-link 깨짐) | RO Round 1 cross-link 충돌 검증 | RO patch spec → Worker D swap 강제 |
| **PDF 12쪽 overflow** | DGO Gate 1 (pypdf > 11) | grid-row 재할당 / padding 축소 / 콘텐츠 KPI 박스화 |
| **PPTX 변환 실패** | markitdown/python-pptx 에러 | zip 압축 해제 + ppt/slides/*.xml 직접 파싱 / 페이지 범위 제한 |
| **WebSearch 결과 부족** | Worker F 결과 < 3 건 | 영문 키워드 / 시기 변경 / 매체 변경 / 범위 확대 |
| **Crystal 부정사전 trigger** | 사용자 메시지 grep | 즉시 대규모 재작업 + audit_summary 누적 + SKILL 레슨 추가 |
| **API key 미셋업** | .env 파싱 실패 | 셋업 가이드 + CSV/WebFetch fallback |
| **fact-check 충돌** (Auditor 간 다른 결과) | RO cross-validate | Auditor B+C cross-check + Crystal C4 결정 |
| **A4 mediabox mismatch** | DGO Gate 2 | @page A4 landscape 강제 + .page width·height mm 단위 |

## U4 — Auditor F (Worker F WebSearch 검증, v1.3.0 신규 정식 정의)

Worker F 가 v1.1.0 도입됐지만 Auditor F 정의 누락 → v1.3.0 정식.

### Critical 5 항목
1. **Cite hallucination** — 모든 source URL/매체명/일자 실재성 (WebSearch 결과 안에서 노출됐던 source 만)
2. **일자 명시 정확성** — "2026-04-29 세대수 완화" 같은 일자가 실제 보도일 일치
3. **Source 다양성** — 1차 source (정부·국토부·서울시·구청) ≥ 50%, 단순 매체 의존 ≤ 50%
4. **출처 footnote 표준** — `[출처: / 기준: / 단위:]` 3-필드 일관
5. **결과 부족 정직 마킹** — [TBD] + 다른 키워드 재시도 흔적

### 출력
`/tmp/orchestrate_runs/<SESSION>/audit_f.md`

## U5 — Main 책임 11 명시

Main = Crystal 대화 + 모든 Agent dispatch 통제 + DGO 실행 + callback 처리.

1. Phase 0 onboarding 대화 진행 (6 질문 short-form 지원)
2. 모든 Worker / Auditor / RO / PO dispatch (sub-agent → sub-agent 한계 우회)
3. PO 의 callback 받아 RO 재호출 (`po_callback.md` 모니터링)
4. 16 결정 → 4 카테고리 (C1/C2/C3/C4) 압축
5. Crystal 부정사전 trigger 모니터링 (즉시 대규모 재작업 발동)
6. DGO 8 Gate 결과 처리 (PASS/FAIL + Recovery)
7. 매 라운드 audit_summary.md 누적
8. Anti-pattern 검출 시 자동 fix (또는 사용자 보고)
9. 사용자 시각 검토 후 정제 요청 처리 (User Visual Review Loop)
10. SKILL.md 업데이트 (사용자 명시 룰화 요청 시 — L13)
11. 세션 종결 시 audit trail commit + 다음 세션 handoff

## U6 — 사용자 응답 인터페이스 표준 (Crystal 4공리 #4 Escape Hatch)

| 응답 | 의미 |
|------|------|
| `go` | 모두 default OK (단일 카테고리) |
| `go all` | 모두 default OK (다중 카테고리) |
| `(번호) (옵션)` | 변경 항목 (예: `C3-1 (a)`, `F2 (b)`) |
| `(번호) ?` | 자세한 trade-off 보고 싶음 |
| `Round 2` | 추가 조사 라운드 |
| `(번호) skip` | 항목 무시 |
| **부정사전 어휘** | 즉시 대규모 재작업 trigger |
| `커밋하고 진행` | git commit + 다음 작업 (commit 대상 명시 권장) |

## U7 — 반복 사이클 트리거

| 조건 | 처리 |
|------|------|
| 사용자 "RFP 풀덱 작성" | 새 세션 → Phase 0 onboarding |
| Round 1 GO + Crystal 결정 완료 | Phase 2 (PO) |
| DGO Gate FAIL | 자동 Recovery → 또는 Worker D 재dispatch |
| 사용자 시각 검토 정제 요청 | User Visual Review Loop (Round N+1) |
| PO callback (자료 부족) | RO 재호출 → Round 2 추가 Worker |
| Crystal 부정사전 | 즉시 대규모 재작업 |
| Final Auditor PASS + 사용자 OK | 세션 종결 |
| 사용자 명시 룰화 요청 (L13) | SKILL 즉시 업데이트 (다음 세션부터 자동 트리거) |

## v5 세션 추가 레슨런 (L13~L17)

| # | 발견 | 일반화 |
|---|------|--------|
| **L13** | "이게 규칙이 될 수 있도록 해줘" 사용자 명시 (거버닝 메시지) | 사용자 명시 룰화 요청 = 즉시 SKILL 반영 표준 |
| **L14** | 같은 세션 SKILL 누적 업데이트 (v1.0→1.1→1.2→1.3) | 같은 세션 미반영 (CLAUDE.md 함정), 다음 세션부터 자동 트리거 |
| **L15** | 9 라운드 사용자 시각 검토 후 정제 | 시각 검토 = DGO 가 catch 못하는 의미·뉘앙스 영역 (U2) |
| **L16** | "본부장 사진 같은것도 앞페이지로 들어가야" cross-page 이동 | Worker D 가 양쪽 페이지 동시 수정 / 콘텐츠 cross-page 이동 룰 |
| **L17** | "[참고] 별도 페이지" 페이지 라벨 분리 | 메인 (00./01.) / 참고 ([참고]) / 별첨 ([별첨]) 라벨 표준 |

## 에이전트 vs 룰 분기 명세

### 🤖 에이전트 (실제 Agent dispatch)
| 에이전트 | 트리거 | 산출물 | 검증자 |
|---------|--------|--------|--------|
| Worker A | Phase 0 응답 (모든 케이스) | 5 정량 파일 | Auditor A |
| Worker B | 부동산종류 × 문서종류 매핑 | 6 reference 파일 | Auditor B |
| Worker C | 모든 케이스 | 5 회사 sample md | Auditor C |
| Worker F | v1.1.0+ (모든 케이스) | 4 narrative md | **Auditor F (v1.3.0 신규)** |
| RO sub-task | Round 1 모든 Auditor 완료시 | ro_round1_report.md | — |
| Worker D / PO | RO GO 판정 + Crystal 결정 후 | v[N].html + v[N].pdf | Final Auditor |

### 📋 룰 (Agent 아님, 자동 grep/CSS/검증)
| 룰 | 적용 시점 | 실행 주체 |
|----|---------|---------|
| DGO 8 Detail Gates | 매 HTML 변경 후 | PO (Worker D) 안의 grep |
| Anti-pattern 9 라이브러리 | 매 HTML 변경 후 | PO 안의 grep |
| 거버닝 메시지 규칙 5 | strip lead 작성 시 | Worker D |
| 페이지 layout 5-row | CSS 작성 시 | Worker D |
| Spacing token 7-tier | spacing 정할 때 | Worker D |
| 결정 카테고리 4 | Crystal 결정 받을 때 | Main |
| Source 카탈로그 12 | Phase 1A 자료조사 시 | Worker A·F |

## v1.3.0 변경사항 요약

- ✅ **U1 Phase 분기 결정 트리** — 사용자 요청부터 종결까지 명시
- ✅ **U2 User Visual Review Loop** — DGO 후 사용자 시각 catch 사이클
- ✅ **U3 Failure Mode + Recovery Pattern** — 8 표준 처리
- ✅ **U4 Auditor F 정식 정의** — Worker F WebSearch 검증
- ✅ **U5 Main 책임 11 명시**
- ✅ **U6 사용자 응답 인터페이스 표준**
- ✅ **U7 반복 사이클 트리거 8**
- ✅ **L13~L17 추가 레슨 5**
- ✅ **에이전트 vs 룰 분기 명세 표**

근거: v5 세션 9 라운드 사용자 시각 검토 + Worker F 도입 + SKILL 점검 결과

---

# v1.4.0 (2026-05-04) — 자료 수집·분석 정리 강화 + 파이프라인 개선

> 사용자 강조: **"자료 수집과 분석 정리가 1차적으로 매우 중요"**.
> v5 세션 후반 Worker G rate limit + Worker F WebSearch 결과 분석 정리 → Phase 1A·1B 강화.

## 자료 수집 Mandatory 확장 (Phase 1A 강화)

### 정량 mandatory 4 source (Worker A)
기존 default = MOLIT only → 풍성한 default = **4 source 의무**.

| Source | API/방법 | mandatory? | fallback |
|--------|---------|------------|---------|
| **MOLIT 실거래가** | RTMS API (Apt/RH/OF Trade) | YES | — |
| **KOSIS 인구·세대·이동** | KOSIS OpenAPI (DT_1B040A3, DT_1B26001) | YES | CSV 다운로드 |
| **청약Home 청약경쟁률** | 웹 스크래핑 | YES | 매체 기사 cite |
| **KB부동산/한국부동산원 시세** | KB Liiv ON / R-ONE | YES | 매체 기사 cite |
| 사업체 통계 (선택) | KOSIS DT_1J17001 | OPT | — |
| 강서구청 인허가 (선택) | WebFetch | OPT | — |

### 정성 mandatory 4 산출물 (Worker F)
기존 v1.1.0 정의 그대로 + **출처 다양성 ≥ 50% 1차 source**.

### 자료 충분성 기준 (Auditor A·F 검증)

| 영역 | 기준 |
|------|------|
| 정량 row 수 | ≥ 100 row (MOLIT 4개월) |
| 정량 source | ≥ 4 source (mandatory 4 충족) |
| 정량 시계열 | ≥ 3 시점 (4·6·12개월) |
| 정성 cite | ≥ 5 cite |
| 1차 source | ≥ 50% (정부·국토부·서울시·구청) |
| 일자 명시 | 100% (cite 모든 항목) |

미달 시 → Round 2 자동 dispatch (수동 결정 의존 X).

## Round 1B 분석 정리 단계 강화 (RO sub-task 확장)

기존 v1.0 RO sub-task = cross-link 검증 + 결정 압축. v1.4.0 확장:

### 1. Cross-reference Mandatory
모든 Worker 산출물 간 cross-link 자동 검증:
- Worker A baseline → Worker C 분양가 % 산정 (필수 참조)
- Worker B 양병천 약력 (★250414) → Worker C 약력 일치
- Worker F 호재 → Worker A 시세 narrative 일치
- Worker A 인근 단지 → Worker F 청약 reference 중복 검증

### 2. 충돌 Cross-validate
- 11,100 vs 10,583 같은 fact 충돌 → Auditor B+C 동시 검증
- 시기·일자 충돌 → Worker B vs F 비교

### 3. 결정 카테고리 압축 (16 → 4)
- C1 Cross-link (자동 patch, Crystal 승인만)
- C2 산출 방식 (Crystal 선택)
- C3 Auditor 충돌 (Crystal 결정)
- C4 narrative 톤 (Crystal 도메인 직관)

### 4. 자료 부족 영역 식별
- 정량 미달 → Round 2 추가 fetch spec
- 정성 cite 부족 → Worker F Round 2
- 충돌 미해결 → Crystal 결정 trigger

### 5. 재현 가능성 보고
- 모든 fetch 명령어·검색 키워드 audit_summary.md 누적
- 다음 세션 동일 자료 재현 가능

## 반복 사이클 Mandatory (자동화)

기존 v1.3.0 = Crystal 결정 의존 → v1.4.0 = 일부 자동:

| 트리거 | 자동/수동 | 처리 |
|-------|---------|------|
| 자료 mandatory 미달 | **자동** | Round 2 dispatch (수동 결정 X) |
| Worker silent drift | 자동 | RO patch spec |
| DGO Gate FAIL | 자동 | Recovery Pattern (U3) |
| PO callback | 자동 | Main → RO 재호출 |
| Auditor 충돌 (B vs C) | 수동 | Crystal C3 결정 |
| User Visual Review 정제 요청 | 수동 | User Visual Review Loop |
| 부정사전 trigger | **자동** | 즉시 대규모 재작업 |

## 파이프라인 개선사항 (v5 세션 발견 5)

### P1 — Worker Rate Limit Graceful Resume
- **발견**: Worker G가 31 tool uses 후 rate limit (server temporary)
- **처리**: Main이 take-over → DGO 검증 → swap 부분 완료 확인 → 추가 swap
- **일반화**: Worker 실패 시 Main take-over + partial state 검증 + graceful resume
- **SKILL 추가**: Failure Mode Recovery 표에 "Worker rate limit" 항목 추가 (U3 보강)

### P2 — DGO 8 Gate 즉시 자동 fix
- **발견**: DGO Gate 8 (좌측선) FAIL 2 hits → 즉시 자동 fix 가능 (border-left → border-top)
- **처리**: Anti-pattern grep + replace 자동
- **일반화**: anti-pattern 검출 → 자동 fix 우선 (사용자 보고 X), 사용자 보고는 의미·뉘앙스만

### P3 — 같은 세션 SKILL 누적 미반영 명시
- **발견**: v1.0 → v1.1 → v1.2 → v1.3 → v1.4 같은 세션 누적
- **처리**: 모든 변경 다음 세션부터 자동 트리거 (Crystal CLAUDE.md L14 함정)
- **일반화**: 사용자에게 매 SKILL 업데이트 시 명시 — "다음 세션부터"

### P4 — 페이지 라벨 표준화 (00./01./[참고]/[별첨])
- **발견**: p.3 "#." 어색 / p.4 "[참고]" / p.5~p.11 "01.~07."
- **처리**: 라벨 패턴 표준
- **일반화**:
  - **숫자**: 본문 메인 항목 (`01.`, `02.` ...)
  - **`#.`**: 회사 소개 등 메인 진입 (또는 `00.` 으로)
  - **`[참고]`**: 본문 보조 페이지 (실적·데이터 등)
  - **`[별첨]`**: 본문 외 추가 자료 (정책 brief·인근 단지 reference 등)
  - **`CONTENTS`**: 목차 페이지

### P5 — 사용자 응답 패턴 확장
- **발견**: "go all 커밋하고 진행" 같은 복합 응답 (결정 + git commit + 다음 단계)
- **처리**: Main이 분리 처리 (Crystal 결정 OK → commit → 다음 작업)
- **일반화**: 사용자 응답 인터페이스 (U6) 보강
  - `(결정) 커밋하고 진행` = 결정 + git commit + 진행
  - `푸시도 해주고` = git push 명시
  - `(결정) skip` = 결정 무시

## 추가 레슨런 L18~L20

| # | 발견 | 일반화 |
|---|------|--------|
| **L18** | Worker rate limit (server temporary) → Main take-over | Worker 실패 시 partial state 검증 + Main 직접 진행 (callback 대안) |
| **L19** | DGO Gate FAIL 즉시 자동 fix | Anti-pattern 검출 → 자동 fix 우선 (의미·뉘앙스만 사용자 보고) |
| **L20** | Push 별도 명시 응답 처리 | git commit 과 push 분리 (Crystal CLAUDE.md "DO NOT push without explicit ask") |

## 자료 수집·분석 정리 단계 (사용자 강조 영역)

```
Phase 1A — 자료 수집 (mandatory 4 source 정량 + 4 산출물 정성)
  ↓
Phase 1A-Audit — 자료 충분성 검증
  ├─ 정량 ≥ 100 row / ≥ 4 source / ≥ 3 시점
  └─ 정성 ≥ 5 cite / ≥ 50% 1차 source / 100% 일자
  ├─ 충족 → Round 1B
  └─ 미달 → 자동 Round 2 dispatch (수동 결정 X)
  ↓
Round 1B — 분석 정리 (RO sub-task)
  ├─ Cross-reference 자동 (Worker 간 silent drift 방지)
  ├─ 충돌 Cross-validate (fact-check)
  ├─ 결정 압축 (16 → 4 카테고리)
  ├─ 자료 부족 영역 식별 (Round 2 spec)
  └─ 재현 가능성 보고 (모든 fetch 명령어·검색 키워드)
  ↓
Crystal 4 카테고리 batch 결정
  ↓
Phase 2 — Worker D + DGO 매 변경 자동
```

## v1.4.0 변경사항 요약

- ✅ **Phase 1A mandatory 4 source 정량 + 4 산출물 정성** (자료 수집 강화)
- ✅ **자료 충분성 기준 6** (Auditor 검증)
- ✅ **Round 1B 분석 정리 5 단계** (cross-ref / 충돌 cross-validate / 결정 압축 / 부족 식별 / 재현 가능성)
- ✅ **반복 사이클 자동화** (mandatory 미달 / Recovery / PO callback / 부정사전 자동, Auditor 충돌 / Visual Review 수동)
- ✅ **파이프라인 개선 P1~P5** (Worker rate limit graceful / DGO 자동 fix / SKILL 누적 미반영 명시 / 페이지 라벨 표준 / 사용자 응답 확장)
- ✅ **L18~L20 추가 레슨**

근거: v5 세션 Worker G rate limit + DGO 8 Gate 매 변경 검증 + 사용자 자료 수집·분석 강조

