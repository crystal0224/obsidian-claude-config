#!/bin/bash
# RFP 풀덱 HTML save → auto PDF regen (fswatch)
# Usage: rfp-watch.sh [HTML_PATH]
#   HTML_PATH 생략 시 brother-sample/ 가장 최근 fulldeck.html

HTML="${1:-$(ls -t /Users/crystal/Desktop/brother-sample/sample-rfp-*-fulldeck.html 2>/dev/null | head -1)}"
PDF="${HTML%.html}.pdf"

if [ -z "$HTML" ] || [ ! -f "$HTML" ]; then
  echo "❌ HTML 파일 없음: $HTML"
  echo "사용법: $0 [HTML_PATH]"
  exit 1
fi

if ! command -v fswatch >/dev/null 2>&1; then
  echo "❌ fswatch 미설치 — 'brew install fswatch' 후 재시도"
  exit 1
fi

echo "👀 RFP 풀덱 watch 시작"
echo "   HTML: $HTML"
echo "   PDF:  $PDF"
echo "   Ctrl+C 종료"
echo ""

regen() {
  echo "✏️  HTML 변경 감지 — $(date +%H:%M:%S)"
  "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome" \
    --headless --disable-gpu --no-sandbox \
    --print-to-pdf="$PDF" \
    --no-pdf-header-footer \
    "file://$HTML" 2>&1 | grep -E 'bytes written|error' | tail -1
  PAGES=$(python3 -c "from pypdf import PdfReader; print(len(PdfReader('$PDF').pages))" 2>/dev/null)
  if [ "$PAGES" = "11" ]; then
    echo "✅ PDF 갱신 ($PAGES 쪽 — 11쪽 fit OK)"
  elif [ -n "$PAGES" ]; then
    echo "⚠️  PDF 갱신 ($PAGES 쪽 — 11쪽 fit 위반!)"
  else
    echo "❌ PDF 페이지 수 측정 실패"
  fi
  echo ""
}

# 시작 시 1회 regen + 무한 watch
regen
fswatch -o "$HTML" | while read -r _; do
  regen
done
