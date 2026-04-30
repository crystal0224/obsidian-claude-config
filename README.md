# obsidian-claude-config

> Crystal's personal Claude Code customization for working with multiple Obsidian vaults.
> Adapted from [johnfkoo951/cmds-system-files](https://github.com/johnfkoo951/cmds-system-files) (CMDS v4.2).

## What this is

A plugin that customizes Claude Code (`~/.claude/`) to work fluently across Crystal's 4 Obsidian vaults (`sk_old`, `work`, `new`, `leadership/기타`). It absorbs 4 patterns from the public CMDS system and adapts them to a multi-vault, code-development-heavy environment.

## Patterns adopted

1. **Split monolithic CLAUDE.md into auto-loading skills** — 366-line global CLAUDE.md → ~80 lines + 3 description-triggered skills. Reduces always-loaded context cost ~62%.
2. **English `description` standard** for AI-searchable Obsidian notes — 5 required frontmatter properties; type-based scope (Permanent / Project / Output / Reference notes only); new notes only.
3. **Command-type classification** — every slash command tagged `diagnostic` / `mutation` / `meta`; CLAUDE.md rule auto-aligns Claude's "ask vs execute" behavior to side-effect risk.
4. **Frontmatter audit trail** (folded into pattern 2) — optional `createdByCommand`, `sourceRefs`, `sessionPurpose` fields for traceability of AI-generated notes.

## Patterns NOT adopted

10+ CMDS patterns deliberately excluded — see [the design spec](specs/2026-04-30-cmds-inspired-claude-config-design.md#out-of-scope-deliberately-not-adopted) for the full list with reasons. Highlights:

- The 9-category PKM taxonomy (100 Themes ~ 900 Divisions) — too prescriptive for a multi-vault setup
- AGENTS.md split (other-AI tech doc) — Crystal is Claude-only
- Symlink-based `.claude/` ↔ vault sync — no single source-of-truth vault
- Frontmatter changelog — git history suffices

## Status

🟡 **Design phase complete, implementation pending.**

- [x] Spec written and committed
- [ ] §3 — `command-type` field added to 24 commands + CLAUDE.md rule paragraph
- [ ] §1 — 3 skills extracted; CLAUDE.md slimmed to ~80 lines
- [ ] §2 + §4 — `crystal-note-frontmatter` skill + `/desc-check` command

## Install (post-implementation)

Once skills are populated:

```bash
# Plugin installation (when skills land)
cd ~/.claude/plugins
git clone https://github.com/crystal0224/obsidian-claude-config.git
# Or via Claude Code:
/plugin install crystal0224/obsidian-claude-config
```

## Provenance

This is a **personal** customization. The patterns are taken from the public CMDS system but the implementation, scope, and naming are all Crystal-specific. The original CMDS targets a single 10K-note vault with a 9-category taxonomy; this targets 4 vaults with no enforced taxonomy.

Public because the patterns themselves may be useful as a reference for others adapting CMDS-style ideas to their own setup.

## License

MIT — see [LICENSE](LICENSE).
