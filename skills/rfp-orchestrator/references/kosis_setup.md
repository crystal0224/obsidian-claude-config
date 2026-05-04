# KOSIS API key 셋업 가이드

> Worker F (Web Search & Narrative) 의 인구·가구 정량 fetch 를 자동화하기 위한 KOSIS API key 셋업.
> 미사용 시 Worker F 가 CSV 다운로드 fallback 으로 우회.

## 셋업 절차 (5분)

### 1. KOSIS 회원가입
- URL: https://kosis.kr
- 우상단 "회원가입" → 일반 회원 (개인)
- 이메일·휴대폰 인증 후 즉시 가입 완료

### 2. API key 신청
- URL: https://kosis.kr/openapi/index/index.jsp
- 좌측 메뉴 "OpenAPI 신청" → "이용신청"
- 이용목적: "분양대행 시장 분석 데이터 수집"
- 사용 통계표:
  - **DT_1B040A3** (행정구역별 인구·세대) — 필수
  - **DT_1B26001** (시군구별 이동자수) — 필수
  - **DT_1J17001** (사업체 종사자 수) — 선택
- 즉시 발급 (수동 심사 없음)

### 3. .env 추가
```bash
# /Users/crystal/Desktop/brother/.env
KOSIS_API_KEY=YOUR_API_KEY_HERE
```

### 4. 셋업 검증
```bash
cd /Users/crystal/Desktop/brother
python -c "
import os
from dotenv import load_dotenv
load_dotenv()
key = os.environ.get('KOSIS_API_KEY')
print('KOSIS_API_KEY:', '[OK]' if key else '[MISSING]')
"
```

## 사용 통계표 — Worker F 매핑

| 통계표 ID | 명칭 | Worker F 산출물 | 페이지 |
|-----------|------|----------------|--------|
| DT_1B040A3 | 행정구역(시군구)별·연령별 인구수 | `worker_a/kosis_population.csv` | p.5 (인구·가구 시각화) |
| DT_1B26001 | 시군구별 이동자수 (전입·전출) | `worker_a/kosis_migration.json` | p.5 (인구이동 TOP 6) |
| DT_1J17001 | 시군구별 사업체 수 (선택) | `worker_a/business_stats.json` | p.5 (타겟 분석) |

## 호출 spec (Worker A·F 가 사용)

### REST API
```
https://kosis.kr/openapi/Param/statisticsParameterData.do
  ?method=getList
  &apiKey=<KOSIS_API_KEY>
  &itmId=T1
  &objL1=11  (서울)
  &objL2=강서구 OR 11500
  &format=json
  &jsonVD=Y
  &prdSe=Y  (연도)
  &startPrdDe=2021
  &endPrdDe=2026
  &orgId=101
  &tblId=DT_1B040A3
```

### CSV fallback (API key 없을 때)
- KOSIS 통계표 페이지에서 수동 CSV 다운로드
- `/Users/crystal/Desktop/brother/data/kosis/<통계표ID>_<날짜>.csv` 저장
- Worker F 가 CSV 우선 read, 없으면 API 호출

## 미사용 케이스
- KOSIS API key 미설정 시 Worker F 가 인구·가구 통계 skip
- p.5 인구·가구 시각화는 [TBD] 마킹 (정직성 우선)
- 또는 WebFetch 으로 통계청 사이트 직접 fetch (느리고 quality 낮음)

## 참고
- KOSIS 공식 OpenAPI 가이드: https://kosis.kr/openapi/index/index.jsp
- 통계 메타데이터: https://kosis.kr/statisticsList/statisticsListIndex.do
- 6 PPTX 中 KOSIS 인용: 신안·청라 (인구·가구 풍부)
