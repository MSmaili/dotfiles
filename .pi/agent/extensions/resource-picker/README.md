# Pi resource picker

A local Pi extension that keeps default skill metadata small and the root slash
menu focused on commands.

## Prompt templates

`/prompts` opens a fuzzy-search picker. Selecting a template inserts its slash
invocation into the editor so arguments can be added before submission. A query
can be supplied directly, for example `/prompts review`.

Prompt templates remain loaded but are hidden from the root `/` autocomplete
menu.

## Skills

`/skills` opens a fuzzy-search picker over every discovered skill. Use Up/Down
or Ctrl+P/Ctrl+N to move between skills. The right pane previews the complete
`SKILL.md` locally; use Page Up/Page Down (or Home/End) to navigate it.
Selecting a skill inserts `/skill:name` into the editor
instead of sending anything immediately, so the model sees neither the preview
nor the full instructions until that invocation is submitted.

A query can be supplied directly, for example `/skills review`. In this
configuration, the picker is also available through the leader sequence
`Ctrl+X`, then `s`.

Only the `mcp-scripting` skill description is shown to the model automatically.
Every other discovered skill remains available through the picker or through:

```text
/skill:name
```

Skills that must remain manual even without this extension can use Pi's native
frontmatter attribute:

```yaml
---
name: deploy
description: Deploy an application.
disable-model-invocation: true
---
```

Pi exposes this as `disableModelInvocation`, omits the skill from its system
prompt, and still registers `/skill:deploy`. The picker marks these entries as
`[manual]` and continues to preview and invoke them normally.

Type `/skill:` to autocomplete skill names. Full `SKILL.md` instructions load
only when the explicit invocation is submitted. Skill commands are hidden from
the root `/` menu and become visible after `/skill:` is typed explicitly.
