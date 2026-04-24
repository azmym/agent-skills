---
name: used
description: Reports which skills, hooks, rules, plugins, and MCP tools were activated during a Claude Code prompt or session. Use when the user asks "what was used", "which skills ran", "show me what fired", or invokes /used. Also triggers when the user wants transparency into Claude's behavior for a given prompt.
argument-hint: [session]
---

# Usage Tracker

Show which skills, hooks, rules, plugins, and MCP tools were activated in the current conversation.

## Arguments

- No arguments (default): report usage for the **last user prompt and Claude response only**
- `session` or `--session`: report usage for the **entire session** (since last `/clear` or session start)

Parse the arguments from: $ARGUMENTS (accept both `session` and `--session` as the session flag)

## Instructions

When this skill is invoked, scan the current conversation context and report what was used. Follow these detection rules exactly.

### 1. Detect Skills

Scan the conversation for:
- `<command-name>` tags: extract the value (e.g., `superpowers:brainstorming` from `<command-name>/superpowers:brainstorming</command-name>` or `<command-name>superpowers:brainstorming</command-name>`)
- Skill tool invocations in the conversation flow (where Claude called the Skill tool with a skill name)

Collect all unique skill names found.

### 2. Detect Hooks

Scan `<system-reminder>` tags for these patterns:
- Text containing "hook additional context" (e.g., "SessionStart hook additional context", "UserPromptSubmit hook additional context")
- Extract the hook name from the text before "hook additional context"

Collect all unique hook names found. Normalize to lowercase-kebab-case (e.g., "SessionStart" becomes "session-start", "UserPromptSubmit" becomes "user-prompt-submit").

### 3. Detect Rules

Scan the conversation for `<system-reminder>` blocks that contain `# claudeMd` sections. Within those sections, look for lines matching:
- `Contents of .../.claude/rules/<name>.md` - extract `<name>` as the rule name
- References to project-level `CLAUDE.md` files - report as "CLAUDE.md (project)" or similar

Collect all unique rule names found.

### 4. Detect Plugins

Scan the conversation for:
- `<system-reminder>` blocks containing "# MCP Server Instructions" followed by `## <plugin-name>` headings - extract the plugin name
- `<available-deferred-tools>` blocks containing tool names prefixed with `mcp__<plugin>__` - extract unique plugin names from the prefix
- Skill names that contain a colon prefix (e.g., `superpowers:brainstorming`) - the part before the colon is the plugin name
- Plugin-sourced skills listed in `<system-reminder>` skill availability blocks (e.g., "- superpowers:writing-plans: ...")

Collect all unique plugin names found.

**Classify each plugin into two groups:**
- **Active plugins**: plugins that had at least one skill invoked (detected in step 1). Track which skills were invoked per plugin.
- **Tools-only plugins**: plugins that only loaded tools (appeared in `<available-deferred-tools>` or MCP instructions) but had no skills invoked.

### 5. Detect MCP Tool Calls

Scan Claude's tool call blocks in the conversation for tool names matching the `mcp__<server>__<tool>` pattern. These are tools that were actually **invoked**, not merely available.

For each match:
- Extract the `<server>` portion as the server name
- Extract the `<tool>` portion as the tool name (strip the `mcp__<server>__` prefix)

Collect unique `(server, tool)` pairs. Group by server name, with tools sorted alphabetically within each server. Servers sorted alphabetically.

This is distinct from step 4 (Detect Plugins), which checks tool *availability*. This step checks for actual *invocation*.

### 6. Scope Filtering

- **Default (no `--session` flag):** Only report items detected in the **last user message and its corresponding Claude response** (the most recent exchange before `/used` was invoked). For skills, hooks, plugins, and MCP tools, only include those that appeared in that last exchange. For rules, always include all loaded rules (they are session-scoped and always active).
- **With `--session` flag:** Report items detected across the **entire conversation**

### 7. Output Format

Output a structured summary with counts and plugin grouping. Follow this template exactly:

```
[Header]  [N skills | N hooks | N rules | N plugins | N mcp tools]
--------------------------------------------------------------
Skills:     skill1, skill2, skill3
Hooks:      hook1, hook2
Rules:      rule1, rule2, rule3,
            rule4, rule5, rule6
Plugins:    active-plugin (skill1, skill2)
            tools-only-plugin1*, tools-only-plugin2*
MCP Tools:  server1 (tool1, tool2)
            server2 (tool3)

* tools only (no skills invoked)
```

**Header:**
- Default mode: `Last Prompt Usage`
- Session mode: `Session Usage`

**Summary counts:**
- Shown in square brackets on the same line as the header
- Format: `[N skills | N hooks | N rules | N plugins | N mcp tools]` using actual detected counts
- Use singular form when count is 1 (e.g., `1 skill`, `1 mcp tool`)

**Category rows:**
- If a category has no detected items, show `(none)` as the value
- Sort items alphabetically within each category
- When a list is long, wrap to the next line with indentation aligned to the first item

**Plugins row:**
- List active plugins first, each on its own line, with their invoked skill names in parentheses
- List tools-only plugins after, on their own line, comma-separated, each suffixed with `*`
- If there are any tools-only plugins, add a blank line then the legend: `* tools only (no skills invoked)`
- If all plugins are tools-only, list them all with `*` suffix
- If all plugins are active, skip the legend

**MCP Tools row:**
- Group tools by server name, one server per line
- Tool names are the part after `mcp__<server>__`, sorted alphabetically within each server
- Servers sorted alphabetically
- If no MCP tools were invoked, show `(none)` as the value
- Indentation of continuation lines aligns with the first server name

**General rules:**
- Do not wrap the output in a code block
- Do not add any extra text beyond the format above
