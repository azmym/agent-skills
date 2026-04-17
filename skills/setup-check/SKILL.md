---
name: setup-check
description: Use when auditing Claude Code configuration for issues, overlaps, unused components, update status, or misconfigurations. Triggers on "check my setup", "audit config", "what's broken", "cleanup skills", "find overlaps", "check for updates", or /setup-check.
argument-hint: [all|updates|skills|hooks|plugins|rules|settings|security|mcp|memory|overlaps] ["goal message"]
---

# Setup Check

Audit Claude Code configuration and report issues, overlaps, update status, and cleanup recommendations.

## Arguments

Parse from `$ARGUMENTS`. Default: `all`.

| Arg | Scope |
|-----|-------|
| `all` | Full audit (all categories below, including updates) |
| `updates` | Claude Code CLI + plugin version/update checks |
| `skills` | Skills: duplicates, broken symlinks, unused, placeholders |
| `hooks` | Hooks: conflicts, broken paths, event collisions |
| `plugins` | Plugins: disabled, stale cache, version tracking |
| `rules` | Rules: contradictions, overlap with plugin behavior |
| `settings` | Settings files: duplicates, conflicting keys (health only) |
| `security` | Security: broad permissions, skipped prompts, orphaned MCP perms |
| `mcp` | MCP servers: empty configs, duplicate servers |
| `memory` | Memory: empty dirs, stale entries, index mismatches |
| `overlaps` | Cross-category overlap detection only |

Multiple args supported: `/setup-check skills plugins` runs both.

### Goal Message

In addition to category args, the user can pass a quoted free-text string as a goal message:

`/setup-check "ready for production?"`
`/setup-check settings "security hardening"`

If an argument is not a recognized category keyword, treat it as a goal message. The goal triggers an additional Goal Assessment section in the output (see below).

## Scan Paths (MANDATORY)

You MUST read ALL of these paths for the relevant category. Do not skip any. Missing a path means missing findings.

**Updates:**
- Claude Code CLI binary (run `claude --version` to get current version)
- npm registry (run `npm view @anthropic-ai/claude-code version 2>/dev/null` for latest published version; requires network)
- `~/.claude/plugins/installed_plugins.json` (plugin versions, `gitCommitSha`, `lastUpdated`)
- `~/.claude/plugins/cache/` (all cached versions; detect stale ones not matching active `installPath`)
- `claude plugins update <name>@<marketplace>` output (authoritative source for update availability)

**Skills:**
- `~/.claude/skills/` (symlinks; check for broken links with `ls -la`)
- `~/.agents/skills/` (source directories; compare against symlinks for orphans)
- `~/.claude/plugins/cache/<marketplace>/<plugin>/<version>/skills/` and `.../agents/` (plugin-provided; the nesting is marketplace/plugin/version, so glob accordingly)

**Hooks:**
- `~/.claude/plugins/cache/*/hooks/hooks.json` (glob ALL versions, not just active)
- Cross-reference against `~/.claude/plugins/installed_plugins.json` to identify stale vs active

**Plugins:**
- `~/.claude/plugins/installed_plugins.json` (installed list with versions)
- `~/.claude/settings.json` > `enabledPlugins` (enabled/disabled state)
- `~/.claude/plugins/cache/` (all cached versions; detect stale ones)

**Rules:**
- `~/.claude/rules/*.md` (read every rule file)

**Settings:**
- `~/.claude/settings.json` (main; lower precedence)
- `~/.claude/settings.local.json` (local overrides; higher precedence, wins on conflicts)

**Security:**
- `~/.claude/settings.json` (check `skipDangerousModePermissionPrompt`, permissions)
- `~/.claude/settings.local.json` (check permissions for broad `Bash(<command>:*)` patterns)
- `~/.claude/.mcp.json` (cross-reference MCP permissions against configured servers)

**MCP:**
- `~/.claude/.mcp.json` (global)
- Project-level `.mcp.json` files in workspace directories

**Memory:**
- `~/.claude/projects/<current-project-path>/memory/` (project memory)
- `MEMORY.md` in that directory (index file)

## Checks Per Category

### Updates
1. **Claude Code CLI version:** Run `claude --version` to get current version. Then run `npm view @anthropic-ai/claude-code version 2>/dev/null` to get the latest published version. Compare the two. If npm is unavailable or network fails, report current version as `i` (INFO) only with message "Could not check for updates".
2. **Plugin version freshness:** For each plugin in `installed_plugins.json`:
   - If `version` is `"unknown"`, flag as `⚠` (WARN) with recommendation to reinstall for version tracking
   - Run `claude plugins update <name>@<marketplace>` for each plugin (the plugin key in `installed_plugins.json` is already in `name@marketplace` format). Parse the output:
     - If output contains "already at the latest version", mark as `✓` with current version
     - If output indicates an update was applied (version changed), mark as `⬆` with old and new versions
     - If the command fails, fall back to checking `lastUpdated`: flag plugins not updated in 30+ days as `i` (INFO, "not updated in N days, possibly stale")
   - **Important:** Do NOT compare `gitCommitSha` against the marketplace repo HEAD. Marketplace repos contain multiple plugins, so repo HEAD advances when any plugin changes, causing false positives for unrelated plugins.
   - Show one finding per plugin, using the full `name@marketplace` identifier so users can copy-paste directly into commands
3. **Stale plugin cache:** Detect version directories in `~/.claude/plugins/cache/<marketplace>/<plugin>/` where more than one version directory exists. The active version is the one matching `installPath` in `installed_plugins.json`. Other directories are stale cache. Flag as `⚠` (WARN) with recommendation to clean up.

### Skills
1. **Broken symlinks:** `ls -la ~/.claude/skills/` and verify each target exists
2. **Orphaned sources:** Directories in `~/.agents/skills/` with no symlink in `~/.claude/skills/`
3. **Semantic duplicates:** Skills with overlapping names OR overlapping descriptions (read frontmatter). Common pairs: `api-docs-generator`/`api-documentation-generator`, `android-design-guidelines`/`mobile-android-design`, `kubernetes-specialist`/`kubernetes-best-practices`
4. **Plugin collisions:** Standalone skill with same name as a plugin-provided skill (double-loaded). Also check partial overlaps: a standalone skill whose functionality is a subset of a plugin's sub-skills (e.g., standalone `slack-messaging` vs plugin providing `slack:slack-messaging`)
5. **Placeholder skills:** Skills with unfilled template content in either the description ("Replace with description") OR the body ("Insert instructions below", empty body)
6. **Tech stack mismatch:** Skills for technologies not found in any workspace project. Check `~/workspace/` for project indicators (go.mod, build.gradle, package.json, Cargo.toml, etc.). If `~/workspace/` does not exist, skip this check and note it as `i`

### Hooks
1. **Event collisions:** Multiple hooks on the same event (e.g., two `UserPromptSubmit` handlers)
2. **Broken commands:** Hook commands referencing non-existent scripts
3. **Stale hooks:** Hooks from old plugin versions still in cache (compare `installPath` in `installed_plugins.json`)

### Plugins
1. **Disabled plugins:** `enabledPlugins: false` entries (candidates for removal)
2. **Version unknown:** Plugins with `"version": "unknown"` (cannot track updates)
3. **Stale cache:** Old version directories in cache that are not the active `installPath`
4. **Enablement mismatch:** Plugin in `installed_plugins.json` but missing from `enabledPlugins` or vice versa

### Rules
1. **Contradictions:** Rules that give opposing instructions (read all rule files, compare)
2. **Plugin overlap:** Rules that duplicate behavior a plugin already provides (e.g., formatting rules when a formatting plugin is installed)
3. **Outdated references:** Rules mentioning tools, commands, or patterns that no longer exist

### Settings
1. **Duplicate keys:** Same key in both `settings.json` and `settings.local.json` with identical values (redundant)
2. **Conflicting keys:** Same key with different values (settings.local.json takes precedence over settings.json)

### Security
1. **Skipped prompts:** `skipDangerousModePermissionPrompt` set to `true` in settings
2. **Broad permissions:** `Bash(<command>:*)` patterns that allow arbitrary arguments (especially `python3:*`, `osascript:*`, `chmod:*`, `xargs:*`)
3. **Orphaned MCP permissions:** MCP tool permissions (`mcp__<server>__*`) for servers not in any `.mcp.json`
4. **Credential exposure:** Credential files with loose filesystem permissions

### MCP
1. **Empty configs:** `.mcp.json` with no servers defined
2. **Duplicate servers:** Same server configured at multiple scopes

### Memory
1. **Empty directory:** Memory dir exists but has no files
2. **Missing index:** Memory files exist but no `MEMORY.md`
3. **Index mismatch:** `MEMORY.md` references files that do not exist, or files exist but are not in the index
4. **Stale entries:** Memories referencing deleted files or very old dates

### Overlaps (Cross-Category)

When running `overlaps`, you need data from ALL categories. Read all scan paths from every category, then run ONLY the cross-category checks below (not per-category checks like broken symlinks).

1. **Skill vs plugin:** Standalone skill duplicates plugin-provided skill or behavior (exact name match or functional subset)
2. **Rule vs plugin/hook:** Rule enforces what a plugin or hook already does
3. **Permission vs actual tools:** Permissions granted for tools/servers not actually configured
4. **Multi-concern overlap:** Multiple components (skill + plugin + rule) all addressing the same concern (e.g., Slack formatting)

**Scoring note:** Overlap findings are cross-category views of issues already counted in their source categories. Do NOT count overlap findings toward either score. They appear in the report for visibility but have zero weight.

### Goal Assessment

This section only appears when the user provides a quoted goal message in the arguments. It is NOT a standard check category; it is generated after all other checks complete.

**How it works:**
1. All standard checks run first (whichever categories are selected)
2. Review all findings through the lens of the user's stated goal
3. Produce a filtered view: only findings relevant to the goal, plus any concerns that were not flagged by standard checks but matter for the stated goal
4. End with a one-line "Verdict" summarizing readiness

**Output structure:**

```
┌─ GOAL ASSESSMENT ───────────────────────────────────
│
│  Goal: "<user's quoted message>"
│
│  ✓  <relevant positive finding>
│  ⚠  <relevant warning> -> <recommendation>
│  ✗  <relevant error> -> <how to fix>
│
│  Verdict: <one-line readiness assessment>
│
└─────────────────────────────────────────────────────
```

**Examples of how to interpret goal messages:**
- `"ready for production?"` - focus on errors, security settings, broken configs, stale versions
- `"security hardening"` - focus on broad permissions, MCP orphaned permissions, security flags, unknown versions
- `"clean up unused stuff"` - focus on disabled plugins, stale cache, placeholder skills, duplicates, orphans
- `"starting a new React project"` - focus on relevant skills available, missing skills for React ecosystem, MCP servers for dev tooling

**Verdict tone:** Be direct and honest. Examples:
- "Ready. No blockers found for your goal."
- "Almost ready. Address the 2 warnings above first."
- "Not ready. 3 errors must be fixed before proceeding."

## Output Format

Use this exact structure. Do not wrap the report in markdown code blocks. Render all box-drawing characters directly as plain text output.

### Header

```
╭─────────────────────────────────────────────────────
│  Claude Code Setup Check
│  YYYY-MM-DD  |  Scope: <scope>
│  Claude Code v<version>
╰─────────────────────────────────────────────────────
```

Replace `YYYY-MM-DD` with today's date, `<scope>` with the selected scope (e.g., "all", "skills, plugins"), and `<version>` with the output of `claude --version`.

### Scores

Displayed immediately after the header, stacked on two lines:

```
  Health:   N.N / 10  ████████░░░░  <Label>
  Security: N.N / 10  ████████░░░░  <Label>
```

**Health Score Calculation:**

Health measures functional correctness. Only health-classified findings contribute.

| Severity | Tier | Weight |
|----------|------|--------|
| ERROR (✗) | Major | -2.0 |
| ERROR (✗) | Minor | -1.0 |
| WARN (⚠) | Major | -0.7 |
| WARN (⚠) | Minor | -0.3 |
| INFO (i) | -- | -0.1 |
| OK (✓) | -- | 0.0 |
| UPDATE (⬆) | -- | 0.0 |

Formula: `health_score = max(0.0, min(10.0, 10.0 - sum_of_health_penalties))`

**Health Labels:**
- 9.0 to 10.0: "Excellent"
- 7.0 to 8.9: "Healthy"
- 5.0 to 6.9: "Needs Attention"
- 0.0 to 4.9: "Critical"

**Security Score Calculation:**

Security measures how locked-down the permission model is. These are intentional preferences, not defects, so no `✗` ERROR is used; all findings are `⚠` WARN with recalibrated weights.

| Finding | Indicator | Weight |
|---------|-----------|--------|
| `skipDangerousModePermissionPrompt` enabled | ⚠ | -1.0 |
| Broad permission (each `Bash(<command>:*)` pattern) | ⚠ | -0.5 |
| Orphaned MCP permissions (server not configured) | ⚠ | -0.5 |
| Credential files with loose permissions | ⚠ | -0.5 |

Formula: `security_score = max(0.0, min(10.0, 10.0 - sum_of_security_penalties))`

**Security Labels:**
- 9.0 to 10.0: "Locked Down"
- 7.0 to 8.9: "Guarded"
- 5.0 to 6.9: "Relaxed"
- 0.0 to 4.9: "Permissive"

**Progress bar (both scores):** 12 characters wide. Calculate filled blocks as `round(score / 10 * 12)`. Use `█` for filled and `░` for empty.

### Category Sections

Each category renders as a left-bordered section with its name and finding count in the header:

```
┌─ CATEGORY NAME (N findings) ────────────────────────
│
│  ✓  Finding with no issues
│  i  Informational note (details inline)
│  ⚠  Problem description (specifics) -> Recommendation
│  ✗  Broken config (specifics) -> How to fix
│
└─────────────────────────────────────────────────────
```

**Indicators (use these exact symbols, not text tags):**
- `✓` = OK (check passed, no issues)
- `⚠` = WARN (actionable recommendation)
- `✗` = ERROR (broken configuration, must fix)
- `i` = INFO (informational, no action needed)
- `⬆` = Update available (used only in the Updates section)

**Formatting rules:**
- **One finding per line.** Each finding MUST fit on a single line: `indicator + description + (details) + -> recommendation`. Do not wrap findings across multiple lines. Use concise language to keep lines compact.
- Examples of single-line findings:
  - `✓  88 symlinks intact, no broken links`
  - `⚠  3 plugins "unknown" version (frontend-design, playwright, skill-creator) -> Reinstall for version tracking`
  - `✗  Broken symlink: my-skill -> missing target -> Remove or recreate symlink`
  - `⬆  prompt-improver@severity1-marketplace updated (0.5.1 -> 0.6.0) -> Was auto-updated by check`
- Use parentheses for inline details rather than separate indented lines
- Use `->` to attach the recommendation directly on the same line
- If ALL sub-checks in a category pass, show a single `✓  No issues found`
- Missing scan paths: show `i  <path> not found, skipping` and continue. Do not error out.
- **Long findings may extend past the bottom rule width.** This is expected behavior; there is no right border to align with. Do not truncate or wrap findings to match the rule length.

**Severity rules (applies to health categories):**
- `✗` (ERROR): Broken symlinks, missing scripts, corrupted configs, CLI not found
- `⚠` (WARN): Duplicates, overlaps, disabled plugins, stale cache, available updates, unknown versions
- `i` (INFO): Version not checked (network unavailable), tech stack mismatch, empty memory, component not updated in 30+ days
- `✓` (OK): Category or sub-check passed with no issues

**Severity rules (Security category):**
- `⚠` (WARN): All security findings (broad permissions, skipped prompts, orphaned MCP perms, credential exposure)
- `✓` (OK): All security checks passed
- No `✗` ERROR in Security; these are intentional preferences, not broken configuration

**Tier classification (determines weight, see Scores section above):**
- **Major** = impacts runtime correctness. Ask: "Does this cause wrong behavior?"
- **Minor** = housekeeping, cosmetic, or redundant. Ask: "Is this messy but harmless?"
- When unsure, default to **minor**. Promote to major only if the finding can cause incorrect behavior.
- Security findings have their own fixed weights (see Security Score Calculation) and do not use tier classification.

### Health Tier Assignment Table

Use this table to classify each health finding as major or minor for health score calculation. Security findings are NOT in this table; they use the Security Score weights above.

#### ERROR Tier Assignments

| Check | Tier |
|-------|------|
| Corrupted/unparseable config files | Major |
| CLI not found / `claude --version` fails | Major |
| Broken hook commands (script doesn't exist) | Major |
| Broken skill symlinks | Minor |
| Missing scan paths for critical configs | Minor |

#### WARN Tier Assignments

| Check | Tier |
|-------|------|
| Contradicting rules | Major |
| Conflicting settings keys (different values) | Major |
| Stale plugin cache (old versions in cache/) | Minor |
| Disabled plugins still installed | Minor |
| Unknown plugin versions | Minor |
| Semantic duplicate skills | Minor |
| Plugin collisions (standalone + plugin-provided) | Minor |
| Duplicate settings keys (identical values) | Minor |
| Orphaned skill sources (no symlink) | Minor |
| Placeholder skills | Minor |
| Stale hooks from old plugin versions | Minor |
| Event collisions (multiple hooks on same event) | Minor |
| Rule overlaps with plugin behavior | Minor |
| Empty MCP configs | Minor |
| Duplicate MCP servers across scopes | Minor |
| Memory index mismatches | Minor |

#### INFO (all single-tier, -0.1)

No tier distinction. All INFO findings use the flat -0.1 weight.

### Section Ordering

When `all` is selected, render sections in this order:
1. Updates
2. Skills
3. Hooks
4. Plugins
5. Rules
6. Settings
7. Security
8. MCP
9. Memory
10. Overlaps
11. Goal Assessment (only if a goal message was provided)

When a single category is selected, show only that category section plus the summary.

### Summary

```
╭─────────────────────────────────────────────────────
│  Summary
├─────────────────────────────────────────────────────
│
│  Health:   ✓ OK: N   ✗ ERROR: N major, N minor   ⚠ WARN: N major, N minor   i INFO: N
│  Security: ✓ OK: N   ⚠ WARN: N
│
│  Top Recommendations:
│
│  1. Most impactful recommendation
│  2. Second most impactful
│  3. Third
│  4. Fourth
│  5. Fifth
│
╰─────────────────────────────────────────────────────
```

**Summary counts formatting:**
- Health line: show tier breakdown for ERROR and WARN: `✗ ERROR: 1 major, 2 minor`
- Health line: when a severity has zero findings for a tier, omit that tier: `⚠ WARN: 3 minor`
- Health line: when a severity has zero findings entirely, show 0: `✗ ERROR: 0`
- Security line: show total WARN count only (no tier breakdown): `⚠ WARN: 3`
- Security line: when no warnings, show: `✓ OK: all clear`

Rank recommendations across both dimensions by severity (health ERROR first, then health WARN, then security WARN), and within the same severity by impact. Show up to 5 recommendations.

## Execution Order

1. Parse arguments to determine scope. Separate category keywords from a quoted goal message (if any).
2. Read ALL mandatory scan paths for selected categories (use parallel tool calls where possible).
3. Run update checks first (if `all` or `updates` is selected): `claude --version`, `npm view`, `claude plugins update <name>@<marketplace>` for each plugin, read `installed_plugins.json`.
4. Run checks for each remaining selected category (including the Security category).
5. Run overlap checks (if `all` or `overlaps` is selected).
6. Calculate dual scores:
   - **Health score:** start at 10.0, classify each health finding by tier (see Health Tier Assignment Table), subtract the corresponding weight. Floor at 0.0, cap at 10.0.
   - **Security score:** start at 10.0, subtract each security finding's fixed weight (see Security Score Calculation). Floor at 0.0, cap at 10.0.
7. Generate goal assessment (if a goal message was provided): review all findings against the stated goal, filter to relevant findings, write verdict.
8. Render the full report: header, dual score lines, category boxes (including Security), goal assessment (if any), summary.
9. End with the summary box containing per-dimension counts and top 3-5 recommendations sorted by impact across both dimensions.
