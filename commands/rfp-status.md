---
command-type: diagnostic
description: 현재 RFP 풀덱 작업 진행 phase 시각화. /tmp/orchestrate_runs/ 최신 run dir 검사 후 Phase 1A~Final Auditor 어디까지 왔는지 표시.
---

# /rfp-status

현재 RFP 작업의 진행 phase 시각화 (오빠가 "어디까지 왔지?" 확인용).

## 동작

1. `/tmp/orchestrate_runs/` 의 가장 최근 `*_rfp_*` 디렉토리 찾기
2. 다음 산출물 존재 여부로 phase 판정:
   - Phase 1A Worker: `worker_a/`, `worker_b/`, `worker_c/`, `worker_f/` (각 anomalies.md)
   - Phase 1A Auditor: `audit_a.md`, `audit_b.md`, `audit_c.md`, `audit_f.md`
   - Phase 1B RO: `ro_round1_report.md`
   - Phase 2 Worker D: `worker_d/`
   - Phase 2.5: `worker_h/`, `worker_i/`, `worker_layout/`
   - Final Auditor: `audit_d.md`
   - 최종 산출물: `~/Desktop/brother-sample/sample-rfp-*-fulldeck.{html,pdf}`
3. 진행 status 표 + 다음 단계 안내

## 출력 예시

```
📊 RFP 풀덱 진행 status (run: 20260505_064823_rfp_v6)

Phase 0  Onboarding                    ✅ 완료
Phase 1A Worker A (MOLIT 4-source)     ✅ 완료
Phase 1A Worker B (★250414 reference)  ✅ 완료
Phase 1A Worker C (회사 sample)        ✅ 완료
Phase 1A Worker F (WebSearch)          ✅ 완료
Phase 1A Auditor A·B·C·F               ✅ 완료
Phase 1B RO Round 1B                   ✅ 완료
Phase 2  Worker D (HTML+PDF+DGO)       ✅ 완료
Phase 2.5 Worker H (Copy Editor)       ✅ 완료
Phase 2.5 Worker I (Per-Page)          ✅ 완료
Phase 2.5 Layout Compositor            ⏸  미실행
Final    Final Auditor (11 항목)       ✅ 완료
사용자 시각 검토                       ⏳ 진행 중

📄 산출물:
   HTML: ~/Desktop/brother-sample/sample-rfp-bunyangga-v6-fulldeck.html
   PDF:  ~/Desktop/brother-sample/sample-rfp-bunyangga-v6-fulldeck.pdf (11쪽)

다음 단계 (오빠 결정):
- 시각 검토 OK → /rfp-preview 로 마지막 수정 모드
- 부정사전 trigger → "OOO 다시 해줘" 한 줄
- 추가 변경 → /rfp-pt 로 빠른 단지명/평당가/세대수 swap
```

## 명령

```bash
SESSION_DIR=$(ls -td /tmp/orchestrate_runs/*_rfp_* 2>/dev/null | head -1)
if [ -z "$SESSION_DIR" ]; then
  echo "❌ /tmp/orchestrate_runs/ 에 *_rfp_* run dir 없음"
  echo "RFP 풀덱 작업 시작 안 됨 — 'RFP 풀덱 작성' 한 줄로 시작"
  exit 0
fi

echo "📊 RFP 풀덱 진행 status (run: $(basename "$SESSION_DIR"))"
echo ""

check() {
  local label="$1" file="$2"
  if [ -e "$SESSION_DIR/$file" ]; then echo "$label  ✅ 완료"
  else echo "$label  ⏸  미실행"; fi
}

check "Phase 0  Onboarding                   " "plan.md"
check "Phase 1A Worker A                     " "worker_a/worker_a_anomalies.md"
check "Phase 1A Worker B                     " "worker_b/worker_b_anomalies.md"
check "Phase 1A Worker C                     " "worker_c/worker_c_anomalies.md"
check "Phase 1A Worker F                     " "worker_f/worker_f_anomalies.md"
check "Phase 1A Auditor A                    " "audit_a.md"
check "Phase 1A Auditor B                    " "audit_b.md"
check "Phase 1A Auditor C                    " "audit_c.md"
check "Phase 1A Auditor F                    " "audit_f.md"
check "Phase 1B RO Round 1B                  " "ro_round1_report.md"
check "Phase 2  Worker D                     " "worker_d"
check "Phase 2.5 Worker H (Copy Editor)      " "worker_h"
check "Phase 2.5 Worker I (Per-Page)         " "worker_i"
check "Phase 2.5 Layout Compositor           " "worker_layout"
check "Final    Final Auditor                " "audit_d.md"
echo ""

# 최종 산출물 확인
LATEST_HTML=$(ls -t /Users/crystal/Desktop/brother-sample/sample-rfp-*-fulldeck.html 2>/dev/null | head -1)
LATEST_PDF=$(ls -t /Users/crystal/Desktop/brother-sample/sample-rfp-*-fulldeck.pdf 2>/dev/null | head -1)
if [ -n "$LATEST_HTML" ]; then
  echo "📄 산출물:"
  echo "   HTML: $LATEST_HTML"
  echo "   PDF:  $LATEST_PDF"
  if [ -n "$LATEST_PDF" ]; then
    PAGES=$(python3 -c "from pypdf import PdfReader; print(len(PdfReader('$LATEST_PDF').pages))" 2>/dev/null)
    echo "   ($PAGES 쪽)"
  fi
fi
```
