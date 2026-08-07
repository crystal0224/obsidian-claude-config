---
command-type: diagnostic
description: 고아 .git/index.lock(및 refs/HEAD lock) 진단·제거. git이 exit 128로 튕기거나 커밋이 조용히 안 될 때. 활성 git 프로세스가 있으면 제거하지 않고 보고만. /git-sync-recover(원격 ref 손상·diverged)와 안 겹침 — 이건 로컬 lock 파일 전용.
---

# /git-lock-clear [repo_path]

`repo_path` 생략 시 현재 작업 디렉토리 기준.

## 이 명령이 다루는 증상

- `fatal: Unable to create '.../.git/index.lock': File exists.`
- `git add` / `git commit` 이 **exit 128**로 즉시 튕김
- 커밋이 되는 것 같은데 실제로는 안 되고 미커밋 파일만 쌓임

> ⚠️ **hang과 혼동 금지.** 이건 멈춘 게 아니라 **즉시 거부**된다.
> 진짜 hang(대용량 작업트리 스캔 등)이면 lock은 없고 프로세스가 살아 있다 — 그건 이 명령 대상이 아니다.

## 실행 절차

### 1. lock 파일 탐색

```bash
find <repo>/.git -maxdepth 2 -name "*.lock" -print
```

`index.lock` 외에 `HEAD.lock`, `refs/heads/*.lock`, `config.lock`도 잡힌다.

**아무것도 없으면** → "lock 없음. 다른 원인" 보고하고 **종료**.
이때 실제 에러 원문을 다시 확인하도록 안내한다 (권한 · 디스크 풀 · 손상된 objects 등).

### 2. 활성 git 프로세스 확인 (필수 — 건너뛰지 말 것)

```bash
ps aux | grep "[g]it " | grep -v grep
```

해당 repo 경로를 인자로 물고 있는 프로세스가 있는지 본다.

**살아 있으면** → **제거하지 않는다.** PID와 명령줄을 보고하고 사용자에게 판단을 넘긴다:

```
활성 git 프로세스가 있습니다 — lock은 정상입니다.
  PID 48211  git add lectures/  (실행 3분째)

a) 기다린다 (대용량 add면 정상)
b) 강제 종료 후 lock 제거 (작업 손실 가능)
```

살아 있는 프로세스를 임의로 죽이지 않는다.

### 3. lock 파일 정보 확인 후 제거

제거 **전에** 나이와 크기를 보고한다 — 방치 기간이 사고 규모를 알려준다:

```bash
find <repo>/.git -maxdepth 2 -name "*.lock" -exec ls -la {} \;
```

0바이트 + 오래된 타임스탬프 = 죽은 프로세스가 남긴 고아 lock (전형).

활성 프로세스가 없음을 확인했으면 제거:

```bash
rm -f <발견된 lock 파일들>
```

### 4. 복구 확인 + 누적 피해 보고

```bash
git -C <repo> status --porcelain | wc -l
git -C <repo> log --oneline -1
```

lock이 오래됐다면 **그동안 커밋이 안 된 채 쌓인 분량**을 함께 보고한다.
마지막 커밋 날짜와 lock 타임스탬프를 비교하면 얼마나 잃을 뻔했는지 나온다.

## 보고 형식

```
✓ 고아 lock 제거

발견: .git/index.lock (0바이트, 2026-07-22 — 16일 방치)
활성 프로세스: 없음
마지막 커밋: 2026-07-21
미커밋 누적: 96개 파일

→ 3주간 커밋이 실패하고 있었습니다. 지금 커밋 가능합니다.
```

## 알아둘 것

- **오케스트레이션 중에는 반복 발생한다.** 중단된 병렬 워커의 `git add`가 매번 lock을 남긴다.
  이럴 땐 커밋 시퀀스 앞에 `rm -f .git/index.lock`을 선행시키는 게 실전에서 유효했다.
- `git status`는 lock 없이도 동작하므로 **평소 확인으로는 안 잡힌다.** 정기 점검 대상이 못 된다.
- 한글 커밋 메시지는 따옴표가 셸을 깨니 `-m` 대신 **`git commit -F <파일>`**.
- 배경·사고 사례: `~/.claude/projects/-Users-crystal-Desktop-linkedin/memory/git-index-lock-stale-diagnosis.md`
