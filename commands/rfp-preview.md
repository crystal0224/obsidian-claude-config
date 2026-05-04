---
command-type: diagnostic
description: RFP 풀덱 HTML 브라우저 preview + fswatch HTML save → auto PDF regen 시작 (오빠 RFP 워크플로우 핵심)
---

# /rfp-preview

RFP 풀덱 HTML을 브라우저로 미리보기 + 백그라운드에서 HTML 저장 시 PDF 자동 갱신.

## 동작

1. brother-sample/ 안 가장 최근 v6+ 풀덱 HTML 파일 찾기
2. 브라우저로 HTML 열기 (`open`)
3. fswatch로 HTML 변경 감지 → Chrome headless로 PDF 자동 재생성 (background)
4. PDF 페이지 수 검증 (pypdf, 11쪽 fit)

## 명령

```bash
# 1. 가장 최근 풀덱 찾기
HTML=$(ls -t /Users/crystal/Desktop/brother-sample/sample-rfp-*-fulldeck.html 2>/dev/null | head -1)
PDF="${HTML%.html}.pdf"

if [ -z "$HTML" ]; then
  echo "❌ brother-sample/ 에 sample-rfp-*-fulldeck.html 없음"
  exit 1
fi

echo "📄 HTML: $HTML"
echo "📄 PDF:  $PDF"

# 2. 브라우저 열기
open "$HTML"
open "$PDF"

# 3. fswatch background watch (있으면 사용, 없으면 안내)
if command -v fswatch >/dev/null 2>&1; then
  echo "👀 fswatch HTML 감시 시작 (Ctrl+C 종료)"
  fswatch -o "$HTML" | while read -r _; do
    echo "✏️  HTML 변경 감지 → PDF 재생성 중..."
    "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome" \
      --headless --disable-gpu --no-sandbox \
      --print-to-pdf="$PDF" \
      --no-pdf-header-footer \
      "file://$HTML" 2>&1 | tail -1
    PAGES=$(python3 -c "from pypdf import PdfReader; print(len(PdfReader('$PDF').pages))" 2>/dev/null)
    echo "✅ PDF 갱신 ($PAGES 쪽) — $(date +%H:%M:%S)"
  done
else
  echo "⚠️  fswatch 없음 — 'brew install fswatch' 후 재시도"
  echo "수동 갱신: Claude에 '/regen-pdf' 또는 'PDF 다시 만들어줘' 입력"
fi
```

## 사용 예

```
오빠: /rfp-preview
Claude: 📄 HTML: ~/Desktop/brother-sample/sample-rfp-bunyangga-v6-fulldeck.html
        📄 PDF:  ~/Desktop/brother-sample/sample-rfp-bunyangga-v6-fulldeck.pdf
        👀 fswatch HTML 감시 시작
        ✅ PDF 갱신 (11 쪽) — 14:23:05
```

오빠가 텍스트 에디터에서 HTML 수정 → 저장 → PDF 자동 갱신 → 브라우저 새로고침.

## 종료

`Ctrl+C` 또는 새 터미널 세션.

## 주의

- fswatch 미설치 시: `brew install fswatch`
- 동시 다중 RFP 세션 시 명시 path 권장 (이 명령은 가장 최근 1개만 watch)
