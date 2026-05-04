---
command-type: mutation
description: RFP 풀덱 단지명·평당가·세대수·일정 등 빠른 변경 + cross-link 자동 swap + PDF 재생성. 시행사 PT 직전 마지막 수정 모드.
---

# /rfp-pt

RFP 풀덱의 핵심 변수만 prompt → 자동 cross-link swap → PDF 재생성. **시행사 PT 직전 마지막 수정** 전용.

## 동작

1. 가장 최근 brother-sample/ 풀덱 찾기
2. 변경할 항목 5 카테고리 prompt:
   - 단지명 / 시행사 / 평당가 표준안 / 세대수 / 분양 시기
3. 입력된 항목만 cross-link 자동 swap (RFP_HTML_EDIT_GUIDE.md cross-link 표 적용)
4. PDF 재생성 + DGO 11 Gate 자동 검증
5. 변경 영향 범위 보고

## 사용 예

```
오빠: /rfp-pt
Claude:
  📄 가장 최근: sample-rfp-bunyangga-v6-fulldeck.html (강남 도시형)
  
  변경 항목 (skip 가능, 그대로 두려면 빈 줄 또는 'keep'):
  
  1. 단지명: ?
  2. 시행사: ?
  3. 평당가 표준안 (만/평): ?
  4. 세대수: ?
  5. 분양 시기: ?

오빠: 검단 OO자이 / 호반건설 / 11000 / 320 / 2026-12

Claude:
  변경 적용 중...
  ✓ 표지 제목 · 단지명 (5건 cross-link)
  ✓ p.7 표준안 9,000 → 11,000만/평 + 매출 5,405.4 → 7,041.6억 (자동 산출)
  ✓ p.5 세대수 286 → 320 (5건 cross-link)
  ✓ p.8 분양 시기 D-day 재계산
  ✓ DGO 11 Gate 모두 PASS
  ✓ PDF 재생성 (11쪽)
  
  📄 ~/Desktop/brother-sample/sample-rfp-검단자이-fulldeck.{html,pdf}
```

## 변경 영향 범위 (cross-link 자동)

| 입력 | 영향 페이지 |
|------|-----------|
| 단지명 | p.3·p.5·p.7·p.10·p.11 (5쪽) |
| 시행사 | p.3·p.5·p.11 (3쪽) |
| 평당가 표준안 | p.6·p.7·p.10·p.11 (4쪽 + 매출/수수료 자동 재계산) |
| 세대수 | p.5·p.7·p.10·p.11 (4쪽 + 매출 자동 재계산) |
| 분양 시기 | p.5·p.8·p.10 (3쪽 + Gantt 재계산) |

## 절대 자동 swap 안 하는 항목

다음은 직접 수정 또는 별도 dispatch 필요:
- 본부장 약력 / 분양 실적 6 row → Worker C 재dispatch
- 호재 5건 / 정책 brief → Worker F 재dispatch
- 카카오맵 [SAMPLE] image → 시행사 site URL 확정 후 swap
- CSS·Layout → "p.X 우측 잘려 — fix해줘" 한 줄

## 종료 후

```
오빠: /rfp-preview
```
브라우저로 시각 검토 + 부정사전 trigger 시 보고.
