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

Only the `mcp-scripting` skill description is shown to the model automatically.
Every other discovered skill remains manually available through:

```text
/skill:name
```

Type `/skill:` to autocomplete skill names. Full `SKILL.md` instructions load
only when a skill is selected or invoked. Skill commands are hidden from the
root `/` menu and become visible after `/skill:` is typed explicitly.
