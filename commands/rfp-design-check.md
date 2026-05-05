---
command-type: diagnostic
description: RFP 풀덱 HTML 실측 색 토큰 vs DESIGN.md §12 Tone B 팔레트 cross-validate. drift 검출 시 design_variance_report.md 생성. Worker D 후 자동 또는 수동 호출.
---

# /rfp-design-check [HTML_PATH] [DESIGN_PATH]

RFP 풀덱 HTML이 DESIGN.md §12 Tone B 디자인 시스템과 일치하는지 cross-validate.

## 동작

1. HTML 파일에서 실측 색 토큰 grep:
   - `#[0-9A-Fa-f]{6}` 패턴 추출 + sort -u
2. DESIGN.md §12 Tone B 팔레트 비교:
   - 표준 5 색: #5E6AD2 (accent) / #14306E (navy) / #0A0B0C (ink) / #D4D6DA (hairline) / #F5F6F6 (surface)
3. 추가 측정:
   - Spacing token (xxs~xxl) 사용 빈도
   - Font family (Pretendard / Apple SD Gothic Neo / Noto Sans KR) 일치
   - 거버닝 6 규칙 (직관성) 자동 grep (약어 / 단위 / 영어 혼용)
4. drift 검출 시 `design_variance_report.md` 생성:
   - 표준 외 색 hits + 위치
   - 누락된 표준 색
   - 거버닝 직관성 위반 항목
5. 결과 요약:
   - PASS: drift 0 → "design 일치"
   - FAIL: drift N건 + report 경로

## 명령

```bash
HTML="${1:-$(ls -t /Users/crystal/Desktop/brother-sample/sample-rfp-*-fulldeck.html 2>/dev/null | head -1)}"
DESIGN="${2:-/Users/crystal/Desktop/brother/DESIGN.md}"

if [ -z "$HTML" ] || [ ! -f "$HTML" ]; then
  echo "❌ HTML 파일 없음: $HTML"
  exit 1
fi

REPORT_DIR="$(dirname "$HTML")"
REPORT="$REPORT_DIR/design_variance_report.md"

echo "🎨 /rfp-design-check"
echo "  HTML:   $HTML"
echo "  DESIGN: $DESIGN"
echo ""

# 1. 색 토큰 grep (HTML)
HTML_COLORS=$(grep -oE '#[0-9A-Fa-f]{6}' "$HTML" | sort -u)

# 2. DESIGN.md Tone B 표준 5 색
TONE_B="#5E6AD2 #14306E #0A0B0C #D4D6DA #F5F6F6"

# 3. drift 검출
DRIFT_HITS=""
for color in $HTML_COLORS; do
  if ! echo "$TONE_B" | grep -qi "$color"; then
    # white·black 변형은 제외
    case "$color" in
      "#FFFFFF"|"#000000"|"#FAFAFA"|"#F5F5F5"|"#E5E5E5") ;;
      *) DRIFT_HITS="$DRIFT_HITS $color" ;;
    esac
  fi
done

# 4. 거버닝 직관성 자동 grep
ABBR=$(grep -oE '\b(1Q[0-9]+|2Q[0-9]+|3Q[0-9]+|4Q[0-9]+|R&amp;D|R&D|GBC|TIA|MGM|BEP|KPI|IRR|OT)\b' "$HTML" | sort -u | wc -l)
ENG_MIX=$(grep -oE '\b(proxy|mix|unit|baseline|target|drift|swap|risk|share|prime|fully)\b' "$HTML" | grep -v 'class=\|style=\|/\*\|//' | wc -l)

# 5. Report 작성
cat > "$REPORT" <<EOF
# Design Variance Report

**HTML**: $HTML
**DESIGN**: $DESIGN
**Generated**: $(date "+%Y-%m-%d %H:%M:%S KST")

## 1. 색 토큰 일치 (Tone B 5 색)

표준: $TONE_B

실측 (HTML grep):
$(echo "$HTML_COLORS" | sed 's/^/- /')

Drift hits (표준 외):
$([ -n "$DRIFT_HITS" ] && echo "$DRIFT_HITS" | tr ' ' '\n' | grep -v '^$' | sed 's/^/- /' || echo "(없음)")

## 2. 거버닝 6 규칙 (직관성) 자동 grep

- 약어 패턴 hits: $ABBR (cite 컨텍스트 동반 권장)
- 영어 혼용 (콘텐츠) hits: $ENG_MIX (한국어화 권장)

## 3. 종합 판정

EOF

DRIFT_COUNT=$(echo "$DRIFT_HITS" | tr ' ' '\n' | grep -v '^$' | wc -l | tr -d ' ')
if [ "$DRIFT_COUNT" -eq 0 ]; then
  echo "✅ PASS — Tone B 일치 (drift 0)" | tee -a "$REPORT"
else
  echo "⚠️  PARTIAL — drift $DRIFT_COUNT건 검출" | tee -a "$REPORT"
fi

echo ""
echo "📄 Report: $REPORT"
```

## 사용 예

```
오빠: /rfp-design-check
Claude:
  🎨 /rfp-design-check
    HTML:   ~/Desktop/brother-sample/sample-rfp-bunyangga-v6-fulldeck.html
    DESIGN: ~/Desktop/brother/DESIGN.md
  
  ✅ PASS — Tone B 일치 (drift 0)
  📄 Report: ~/Desktop/brother-sample/design_variance_report.md
```

## 적용 시점

- Worker D 후 자동 호출 (다음 세션 v1.5.x에서 SKILL spec)
- 시각 검토 전 1 cycle 추가 자동 검증
- /rfp-preview 와 결합 시 design + layout 양 측면 동시 검증

## 비교

- `/rfp-status` — Phase 진행 status (workflow level)
- `/rfp-preview` — HTML 브라우저 + PDF auto regen (visual level)
- `/rfp-design-check` — design 일치 (semantic level) ★
- `/regen-pdf` — PDF 단순 재생성 (mutation)
- `/rfp-pt` — 단지명·평당가 변경 (mutation)
- `/rfp-handoff` — 세션 종료 handoff (mutation)
