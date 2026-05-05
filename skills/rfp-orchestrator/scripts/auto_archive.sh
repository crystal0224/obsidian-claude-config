#!/bin/bash
# rfp-orchestrator auto-archive helper
# Post-Phase-2 trigger: /tmp/orchestrate_runs/<TS>_rfp_*/ → ~/Desktop/brother-sample/archive/<TS>/
# Plus INDEX.md 항목 추가
# Usage: auto_archive.sh [SESSION_DIR]
#   SESSION_DIR 생략 시 /tmp/orchestrate_runs/ 최신 *_rfp_* dir 자동 감지

SESSION_DIR="${1:-$(ls -td /tmp/orchestrate_runs/*_rfp_* 2>/dev/null | head -1)}"
ARCHIVE_ROOT="/Users/crystal/Desktop/brother-sample/archive"
INDEX="$ARCHIVE_ROOT/INDEX.md"

if [ -z "$SESSION_DIR" ] || [ ! -d "$SESSION_DIR" ]; then
  echo "❌ SESSION_DIR 없음: $SESSION_DIR"
  exit 1
fi

TS=$(basename "$SESSION_DIR")
DEST="$ARCHIVE_ROOT/$TS"

mkdir -p "$ARCHIVE_ROOT"
if [ -d "$DEST" ]; then
  echo "⚠️  archive/$TS 이미 존재 — overwrite 차단. SESSION_DIR 다시 확인."
  exit 1
fi

# rsync archive (preserve perms, atomic)
rsync -a "$SESSION_DIR/" "$DEST/"
echo "✅ $TS → archive/$TS/ ($(du -sh "$DEST" | cut -f1))"

# INDEX.md 헤더 (없으면 생성)
if [ ! -f "$INDEX" ]; then
  cat > "$INDEX" <<'EOF'
# RFP Audit Trail Index

| TIMESTAMP | 단지명 | 버전 | 출력 HTML | 페이지 수 | DGO PASS |
|-----------|-------|------|-----------|----------|----------|
EOF
fi

# 산출물 추출 (plan.md 또는 audit_summary.md 에서)
SITE_NAME=$(grep -E '^- 단지명:' "$DEST/plan.md" 2>/dev/null | head -1 | sed 's/^- 단지명: //' || echo "(unknown)")
VERSION=$(echo "$TS" | grep -oE 'v[0-9]+' || echo "v?")
HTML_PATH=$(ls /Users/crystal/Desktop/brother-sample/sample-rfp-*-fulldeck.html 2>/dev/null | head -1)
HTML_BASE=$(basename "$HTML_PATH" 2>/dev/null || echo "(no html)")
PAGES=$(python3 -c "from pypdf import PdfReader; print(len(PdfReader('${HTML_PATH%.html}.pdf').pages))" 2>/dev/null || echo "?")
DGO_PASS=$(grep -cE 'PASS|✓' "$DEST/audit_d.md" 2>/dev/null || echo "?")

# INDEX.md 행 추가
echo "| $TS | $SITE_NAME | $VERSION | $HTML_BASE | $PAGES | $DGO_PASS |" >> "$INDEX"
echo "✅ INDEX.md updated ($INDEX)"

# Final 산출물 (HTML/PDF) 도 archive에 복사 (있으면)
LATEST_HTML=$(ls -t /Users/crystal/Desktop/brother-sample/sample-rfp-*-fulldeck.html 2>/dev/null | head -1)
LATEST_PDF=$(ls -t /Users/crystal/Desktop/brother-sample/sample-rfp-*-fulldeck.pdf 2>/dev/null | head -1)
if [ -n "$LATEST_HTML" ]; then
  cp "$LATEST_HTML" "$DEST/" 2>/dev/null
  cp "$LATEST_PDF" "$DEST/" 2>/dev/null
  echo "✅ 최종 HTML/PDF → archive/$TS/"
fi

echo ""
echo "Archive 완료. 다음 세션 reference:"
echo "  $DEST"
echo "  $INDEX"
