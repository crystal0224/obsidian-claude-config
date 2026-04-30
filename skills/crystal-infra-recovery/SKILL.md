---
name: crystal-infra-recovery
description: Use when investigating macOS APFS sparse files (logical N bytes but du shows 0B), Vite builds hanging at transform stage with no output, or Obsidian browser-based slide editor injecting fixed-px CSS that breaks cqw responsive layouts. Covers root causes, diagnostic gates, and recovery procedures including the natural-recovery wait pattern for APFS, vite-ignore CDN dynamic import for ML/WASM packages, and pre-deploy regex scan for inline px styles.
---

# Crystal Infra Recovery — macOS / Vite / Obsidian Editor

Mac (APFS) · Vite build · Obsidian 편집기 자동저장의 함정 3개 모음.

## When this skill activates

- "0B 파일", "스파스", "logical vs physical" mismatch
- "vite build 멈춤", "transform 단계 출력 0"
- "고정 px width", "cqw 깨짐", "Obsidian 편집기 자동저장"

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
