---
description: Read-only diagnostic for note description quality across Crystal's Obsidian vaults. Reports missing description, Korean description, and low-information descriptions.
command-type: diagnostic
---

# /desc-check [folder]

Crystal의 Obsidian 노트 frontmatter `description` 필드를 진단. Read-only — 자동 수정 X.

## 사용법

```
/desc-check                          # 현재 디렉토리 .md 스캔
/desc-check ~/Desktop/work           # 지정 폴더
/desc-check ~/Desktop/new --type=output   # 타입별 필터
```

## 검사 항목

1. **MISSING**: frontmatter 또는 description 필드 자체 없음
2. **KOREAN**: description 절반 이상이 한글 (LLM 검색 hint 약화)
3. **LOWINFO**: 5단어 이하 / "이 노트", "this is", "회의록" 같은 무정보 패턴

## 실행 단계

1. 입력 path resolve (없으면 cwd)
2. 재귀적으로 `*.md` 스캔
3. 각 파일에 대해:
   - YAML frontmatter 추출 (`awk '/^---$/{f=!f; next} f{print}'`)
   - `description:` 필드 추출
   - 3가지 검사 적용
4. 결과 분류 출력:
   ```
   [MISSING]
     - path/to/note1.md
     - path/to/note2.md
   [KOREAN]
     - path/to/note3.md → "회의록 정리"
   [LOWINFO]
     - path/to/note4.md → "this is a test"

   Total: 42 .md scanned, 3 MISSING, 1 KOREAN, 1 LOWINFO
   ```
5. 면제 타입 (`daily`, `clipping`, `scratch`) 자동 스킵 — 카운트에서 제외하고 별도 표시
6. 자동 수정 X — 사용자가 결과 보고 결정

## 휴리스틱 디테일

- KOREAN 판정: description 문자 중 한글(가-힣) 비율 > 50%
- LOWINFO 판정: 단어 수 ≤ 5 OR 정규식 매칭 `^(이\s*노트|this\s+is|회의록|note|memo)$`

## 면제 타입

스킬 `crystal-note-frontmatter`의 Type→Scope 매트릭스 참조:
- daily / clipping / scratch → 검사 면제

## 출력 예시 빈 vault

```
✓ All 42 notes have valid English description
   (2 daily, 5 clippings, 1 scratch — exempt)
```
