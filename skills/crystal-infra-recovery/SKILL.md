---
name: crystal-infra-recovery
description: Use when investigating macOS APFS sparse files (logical N bytes but du shows 0B), Vite builds hanging at transform stage with no output, Obsidian browser-based slide editor injecting fixed-px CSS that breaks cqw responsive layouts, file:// SPA blank screen due to ES module CORS (vite-plugin-singlefile pattern), Korean filename mojibake when unzipping macOS-zipped files on Windows (ASCII filename workaround), or Playwright headless visual audit setup for file:// SPAs. Covers root causes, diagnostic gates, and recovery procedures including the natural-recovery wait pattern for APFS, vite-ignore CDN dynamic import for ML/WASM packages, pre-deploy regex scan for inline px styles, single-HTML inline build pattern for VDI offline, and ASCII rename pre-zip.
---

# Crystal Infra Recovery — macOS / Vite / Obsidian Editor

Mac (APFS) · Vite build · Obsidian 편집기 자동저장의 함정 3개 모음.

## When this skill activates

- "0B 파일", "스파스", "logical vs physical" mismatch
- "vite build 멈춤", "transform 단계 출력 0"
- "고정 px width", "cqw 깨짐", "Obsidian 편집기 자동저장"
- "file:// 빈 화면", "type=module CORS", "vite-plugin-singlefile", "VDI offline SPA"
- "한글 zip 깨짐", "unzip mojibake", "ZIP UTF-8 flag", "ASCII filename"
- "Playwright visual audit", "헤드리스 캡처", "스크린샷 점수화"
- "PIPESTATUS", "pipestatus", "exit= 빈 값", "rm -rf $VAR 차단", "삭제 가드 건너뜀"

## 1. 편집기 자동저장의 인라인 CSS 삽입 주의

HTML 슬라이드 편집기(브라우저 내 WYSIWYG) 자동저장이 `width: 1376px` 같은 고정 픽셀값을 인라인 style로 삽입해 cqw 기반 반응형 레이아웃이 깨지는 사례 여러 차례. Claude가 재편집할 때 고정 px 속성이 보이면 의도 확인 후 제거. pre-deploy 시 `grep 'width: [0-9]*px'` 로 스캔 권장.

## 2. APFS 스파스 파일 복구 패턴 (2026-04-26+)

macOS APFS에서 `ls`는 정상 N바이트, `du -h`는 0B를 보고하는 sparse 파일 현상이 발생할 수 있다. 원인 후보: APFS clone glitch / iCloud Optimize Storage / 디스크 I/O 이벤트. **Time Machine destination 미설정과 무관하게 발생 가능** (이전 세션에서 잘못 진단함 — `tmutil destinationinfo`가 1순위 체크여야 함; `tmutil latestbackup`은 destination이 없을 때도 "Failed to mount" 출력함).

**진단**: `/sparse-check <path>` 슬래시 명령 또는 수동:
```bash
stat -f '%z' file   # logical 크기
du -h file          # physical 블록
# logical >> physical 이면 sparse
```

**중요 인사이트 — APFS sparse는 자연 복구되기도 함**: 0B 사파일을 즉시 재생성하지 말고 일단 백업 폴더로 옮긴 후 잠시 대기 → 재측정. 8.3MB pack file이 시간 지나 자연 복구되어 git tree object 회복한 사례 있음 (2026-04-26 portfolio-website). "du -h 0B"가 영구 손실 의미 아님.

**복구 순서**:
1. git: 깨진 pack 백업 → `git fetch origin` 으로 재수신 (단 backup 보존, 자연 복구 가능)
2. data files: 원본 스크립트로 재생성
3. node_modules: `rm -rf node_modules && npm install`

## 3. Vite 번들 제외 — CDN dynamic import 패턴 (2026-04-26+)

`@xenova/transformers` 같은 100MB+ ML 패키지나 ONNX/WASM 런타임을 Vite 빌드에 포함하면 build 행(2118+ modules transform 단계에서 실질 hang) 또는 배포 용량 폭증 발생. 해결: `/* @vite-ignore */` 주석으로 Vite 정적 분석에서 제외하고 CDN URL 직접 import.

```ts
// BAD: vite가 import 그래프에 포함 → 빌드 매우 느림 / 실패
import { pipeline } from '@xenova/transformers';

// GOOD: vite는 무시, 브라우저가 첫 호출 시 CDN에서 fetch
const tf = await import(
  /* @vite-ignore */
  "https://cdn.jsdelivr.net/npm/@xenova/transformers@2.17.2/+esm"
);
```

번들 크기 0 추가, 첫 호출 시만 ~30MB 다운로드 (브라우저 캐시). 적용 사례: `LinkedinSearch.tsx` 의 의미 검색 모드 (Xenova/paraphrase-multilingual-MiniLM-L12-v2). 빌드 시간 10분+ → 26초로 단축.

**부수 학습**: vite build의 stdout buffering 때문에 `transform` 단계에서 여러 분 동안 출력 0줄 상태 가능. "출력 없음 ≠ hung". `ps aux | grep vite` CPU 사용량 확인 후 kill 결정. (성급히 kill 하면 dist 삭제됨)

## 4. file:// + ES module CORS — VDI offline SPA 단일 HTML (2026-05-03+)

Vite default 출력 (`<script type="module" src="./assets/...">`) 은 `file://` origin="null" 에서 Chrome/Safari 가 CORS 차단 → blank screen. `base: './'` + 상대 경로만으로는 해결 안 됨 — ES module spec 자체가 CORS 요구.

**진단**: 빈 화면 + Chrome 콘솔에 `Access to script ... blocked by CORS policy: Cross origin requests are only supported for protocol schemes: chrome, ..., http, https`.

**정답**: `vite-plugin-singlefile` — 모든 JS/CSS/asset 을 단일 HTML 에 base64 inline. external asset 0개 → CORS 발생 자체 불가.

```bash
npm install -D vite-plugin-singlefile
```

```ts
// vite.config.ts — 4개 동시 설정 필수
import { viteSingleFile } from 'vite-plugin-singlefile'

export default defineConfig({
  plugins: [react(), viteSingleFile()],
  base: './',
  build: {
    assetsInlineLimit: 100000000,    // 모든 asset inline (~100MB)
    cssCodeSplit: false,              // CSS 도 단일
    rollupOptions: {
      output: { inlineDynamicImports: true }  // dynamic import 도 inline
    }
  }
})
```

결과: `dist/index.html` 단일 파일 (~1MB+). file:// 더블클릭 즉시 동작. zip 인계 단순.

**적용 사례**: 2026-05-03 observation React 마이그레이션 (commit 4d72ae1). VDI 폐쇄망 임원 도구.

**Trade-off**: 1개 큰 HTML (~1MB) 라 첫 로드 100ms+ 지연. code splitting / lazy import 사용 불가. VDI 단일 더블클릭 모델에는 적합 — 다회 페이지 로드 SPA 에는 부적합.

## 5. macOS zip + 한글 파일명 cross-platform 함정 (2026-05-03+)

macOS `zip` 명령은 한글 파일명을 raw UTF-8 bytes 로 저장하지만 ZIP general-purpose bit 11 (UTF-8 flag) 를 안 켬. Windows 의 일부 unzip 도구 (특히 회사 보안 zip 도구) 가 IBM437/CP949 로 해석 시도 → mojibake 또는 silent skip (파일 누락처럼 보임).

**증상**: VDI 또는 Windows 동료가 zip 풀었는데 "파일이 안 나온다" 보고.

**해결**: 배포 zip 의 파일명은 ASCII 영문만. **파일 내용 (CSV cell value, 텍스트 본문) 은 한글 OK** — zip 압축/해제와 무관.

```bash
# BAD: 한글 파일명
zip out.zip "관찰로그_clean_60건.xlsx"  # Windows mojibake risk

# GOOD: ASCII rename + zip
mv "관찰로그_clean_60건.xlsx" observations_clean_60.xlsx
zip out.zip observations_clean_60.xlsx
```

**적용 사례**: 2026-05-03 observation React 마이그레이션 (commit 68771c7). 처음에 한글 zip 만들었더니 사용자가 "test 파일 안 나온다" 보고 → ASCII rename 후 정상.

**부수 가이드**: zip 안에 README.txt (영문 또는 한글 둘 다 OK) 같이 넣어 unzip 후 사용법 즉시 보이게. 본문 한글이지만 파일명은 README.txt.

## 6. iOS 26 빈 데이터 디자인 — Hero null 반환 금지 (2026-05-03+)

React 컴포넌트에서 `obs.length === 0 ? null` 패턴으로 빈 데이터 hero 를 숨기면, 사용자가 "있어빌리티" 못 봄. iOS 26 디자인의 좋은 SPA 는 **빈 상태에서도 placeholder + CTA 보여야** — "첫 관찰을 기록해보세요" 같은 행동 유도.

**증상**: Playwright headless 캡처에서 dashboard 화면이 흰 공백만 — sparse/empty 부정사전 트리거.

**정답 패턴**:
```tsx
// BAD
if (obs.length === 0) return null

// GOOD
if (obs.length === 0) {
  return (
    <section className="hero hero-empty">
      <p className="hero-label">시작하기</p>
      <h2>첫 관찰을 기록해보세요</h2>
      <p>사이드바의 "빠른 입력" 으로 데이터를 추가하면 분석이 시작됩니다.</p>
    </section>
  )
}
```

**적용 사례**: 2026-05-03 observation DashboardHero (commit 6ac24f5). W-E-Audit Playwright 캡처 후 발견.

**관련 부정사전**: 헐빈 (여백 과다 / 정보 밀도 부족).

---

## § 7. Vercel Hobby Authentication + Supabase key 함정 (2026-05-05+)

**증상 패턴**: production deployment 의 static (`/`) 은 200 정상인데 `/api/*` 만 timeout/hang. 또는 fetch 가 영원히 pending. browser DevTools Network 에서 `/api/admin/auth` 요청이 끝없이 회전.

**원인**: Vercel Hobby plan 의 "Vercel Authentication" 기능이 production deployment 의 API routes 전체에 SSO 인증 레이어를 강제. static asset 은 Vercel CDN 에서 직접 응답 → 통과. API function 만 인증 redirect 로 막힘. Hobby 에서 toggle 자체가 회색일 수 있음 (또는 "Disabled" 옵션이 Pro 전용).

**진단 명령**:
```bash
curl -i -s -o /dev/null -w "code=%{http_code} time=%{time_total}\n" --max-time 10 https://<deploy>.vercel.app/
curl -i -s -o /dev/null -w "code=%{http_code} time=%{time_total}\n" --max-time 10 https://<deploy>.vercel.app/api/<route>
```
- `/` = 200, `/api/*` = 000 (timeout) → Vercel Hobby Auth 차단 확정
- 둘 다 401 → Supabase / 다른 API key 문제
- 직접 deploy URL (`assapp-xxx-crystals-projects.vercel.app/api/*`) → 401 + JSON `{"error":{"code":"401","message":"Protected deployment"},"protection":{"vercel_auth_enabled":true}}` 반환되면 확정

**대응 전략**:
1. **Pro upgrade** — 가장 단순. Vercel Authentication toggle 활성.
2. **다른 host 로 admin 분리** — Netlify Functions 등. main app 은 Vercel 유지.
3. **Apps Script + Google Sheets 우회** ★ — admin 이 read-only dashboard 라면 가장 실용적. Supabase REST API 를 Apps Script `UrlFetchApp` 으로 호출 → Sheet sync. browser 도메인 무관 (google.com).

### Supabase key 시스템 (2025+ 변경)

**3 key 레이어 구분 — 혼동 빈번**:

| 위치 | 형식 | 용도 | Apps Script / browser |
|------|------|------|---------------------|
| Settings → API Keys → **Publishable / secret** (신규) | `sb_publishable_*` / `sb_secret_*` | client / server | ❌ `sb_secret_*` 는 browser User-Agent fingerprint 로 차단됨 |
| Settings → API Keys → **Legacy** | JWT (`eyJhbGc...`) `anon` / `service_role` | client / server | ✅ `service_role` JWT 가 PostgREST API key |
| Settings → **JWT Keys** | Standard signing key | 서버가 토큰 발급할 때 sign 용 | ❌ API key 아님 (사용 시 401 invalid) |

**해결**: Apps Script / browser 환경에서 Supabase 호출 시 **Legacy `service_role` JWT** 만 사용. `/settings/api-keys/legacy` 페이지의 secret 라벨이 붙은 행.

### supabase CLI 일괄 패턴

```bash
npx supabase link --project-ref <ref>
npx supabase db push --include-all
npx supabase migration list  # remote 적용 확인
```

`db push` 는 자동으로 `[Y/n]` prompt 진행. migration 파일은 `supabase/migrations/<timestamp>_<name>.sql`. INSERT 도 migration 으로 push 가능 (`on conflict do nothing` 으로 idempotent).

**관련 부정사전**: 헐빈 (admin 화면 차단으로 Sheet 우회 시 "Sheet 만으론 부족하다" 인상 회피 — KPI / heatmap / cross-tab 까지 채워 정보 밀도 확보).

**적용 사례**: 2026-05-05 assapp `/admin` 페이지 — Phase 1+2 React UI 구현 완료 했으나 Vercel Hobby Auth 로 외부 접근 차단 → Apps Script + Sheets 우회로 운영. 코드는 그대로 남김 (Pro upgrade 시 즉시 활성).

## black PostToolUse 훅 × 줄수 지시 충돌 (2026-07-18)

전역 `~/.claude/hooks/post-tool-use.py`가 모든 세션(서브에이전트 포함)의 `.py` Write/Edit 직후 자동 포매팅을 실행 — ruff 미설치 머신에서는 black 폴백. black은 `--line-length`와 무관하게 압축 1줄 복합문(`if x: return y`)을 무조건 2줄로 쪼개서 물리 줄수가 크게 팽창한다 (실측: 302줄 원본 → 536줄, 1.77배).

**함정**: 서브에이전트에 "전체 N줄 이내" 같은 줄수 하드룰을 지시하면, 에이전트가 예산 내로 작성해도 훅이 팽창시켜 규칙 위반처럼 보임. 팽창분은 추가 코드가 아니라 포매팅 아티팩트.
**처방**: 줄수 게이트를 걸기 전에 자동 포매터 개입 여부 확인. 걸어야 하면 "포매터 적용 전 기준" 명시 또는 논리 복잡도(함수 수·기능 수) 기준으로 대체. 우회(Bash heredoc 직접 쓰기)는 다음 편집에서 재포맷돼 diff가 흔들리니 비추천 — 포맷된 상태를 기준으로 수용.

## zsh 종료 코드 가드 × `rm -rf "$VAR"` 차단 (2026-10-01)

Claude Code 의 Bash 도구는 사용자 셸(zsh)로 돈다. bash 문법으로 쓴 "검증 통과 시에만 삭제" 가드가 두 군데서 걸린다.

**함정 1 — `${PIPESTATUS[0]}` 는 zsh 에서 비어 있다** (zsh 는 소문자 `$pipestatus[1]`). `cmd | tail; rc=${PIPESTATUS[0]}; [ "$rc" = "0" ] && rm …` 는 항상 거짓이라, 검증은 통과했는데 삭제가 조용히 건너뛰어진다. 출력에 `exit=` 처럼 값이 비어 보이면 이것이다.
**처방**: 파이프를 끊고 종료 코드를 직접 본다.
```bash
if rclone check "<로컬>" "<원격>" --one-way > check.log 2>&1; then …삭제…; else tail -3 check.log; fi
```
스크립트 파일로 뺄 때는 `#!/bin/bash` 를 달아 bash 로 돌린다.

**함정 2 — 내장 안전 검사가 `rm -rf "$VAR/…"` 를 막는다**. 변수가 비면 `/` 로 펼쳐질 수 있는 대상은 사람 승인 없이는 실행되지 않고, 한 명령 안의 다른 줄까지 통째로 실행되지 않는다.
**처방**: 리터럴 절대 경로를 쓰거나 `"${VAR:?}/…"` 로 쓴다(비면 셸이 멈춤). 쪼개거나 다른 도구로 우회하지 않는다.

**적용 사례**: 2026-10-01 Drive 업로드 뒤 로컬 삭제 — 가드를 세 번 다시 썼다. 고정본: `~/.claude/scripts/gdrive_verified_sync.sh`.
