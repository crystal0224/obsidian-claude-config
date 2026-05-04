---
description: HTML → Chrome headless PDF 변환 + pypdf N쪽 fit 검증. 실패 시 페이지 수 불일치 진단.
command-type: mutation
---

# /regen-pdf <html_path> [expected_pages=11]

A4 가로 HTML 을 Chrome headless 로 PDF 변환하고 pypdf 로 페이지 수 검증.

## 사용법

```bash
/regen-pdf /Users/crystal/Desktop/brother-sample/sample-rfp-bunyangga-v6-fulldeck.html
/regen-pdf <html_path> 8   # expected_pages=8 (기본 11)
```

## 동작

1. **PDF 생성** (Chrome headless):
   ```bash
   /Applications/Google\ Chrome.app/Contents/MacOS/Google\ Chrome \
     --headless --disable-gpu \
     --print-to-pdf=<html_path:.html=>.pdf \
     --no-pdf-header-footer \
     file://<html_path>
   ```

2. **페이지 수 검증** (pypdf):
   ```python
   from pypdf import PdfReader
   r = PdfReader(pdf_path)
   actual = len(r.pages)
   ```

3. **A4 가로 mediabox 검증**:
   - mediabox 841.92 x 594.96 pt (= 297×210mm)

4. **결과 보고**:
   - PASS: `✅ <N>쪽 · A4 가로 297×210mm · <size>MB`
   - FAIL (페이지 수 불일치): overflow 의심 페이지 + 권고 (margin 축소 / KPI 박스화 / col 재배치)

## 실패 시 권고 (Recovery Pattern)

| 상황 | 권고 |
|------|------|
| **N+1쪽** (1쪽 overflow) | grid-row 명시 할당 누락 의심 / 마지막 페이지 콘텐츠 축소 / KPI 박스화 |
| **N+2쪽 이상** | 별첨 분리 또는 본문 압축 (인근 단지 표 row 수 축소 등) |
| **A4 mismatch** | `@page { size: A4 landscape }` + `.page { width: 297mm; height: 210mm }` 강제 |

## 도메인

`rfp-orchestrator` 스킬의 DGO Gate 1 (페이지 fit) + Gate 2 (A4 mediabox) 자동 검증.

## 참고

- Chrome headless 명령어 표준: `--no-pdf-header-footer` 필수 (페이지 번호 자동 추가 차단)
- webfont (Pretendard CDN) 사용 시 절대 제거 금지 (Chrome headless 한글 fallback 실패)
- `command-type: mutation` — PDF 파일 새로 생성 (덮어쓰기), Crystal 4공리 #2 (Explicit Action) 적용
