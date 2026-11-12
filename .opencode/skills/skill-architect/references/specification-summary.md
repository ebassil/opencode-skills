# Agent Skills specification — working reference

Canonical source: https://agentskills.io/specification

Always check the canonical source for current requirements when web access is available. This summary is a convenience for the Skill Architect workflow and may become stale.

## Minimum structure

A skill is a directory containing at least:

```text
skill-name/
└── SKILL.md
```

Optional supporting directories commonly include:

```text
scripts/      Executable helpers
references/   Documentation loaded on demand
assets/       Templates and static resources
```

The format permits additional files and directories.

## SKILL.md format

The file contains YAML frontmatter followed by Markdown instructions:

```yaml
---
name: skill-name
description: What the skill does and when to use it.
---

# Instructions

...
```

## Frontmatter fields

| Field | Required | Constraints / purpose |
|---|---:|---|
| `name` | Yes | 1–64 characters; lowercase letters, digits, and hyphens; no leading/trailing hyphen or consecutive hyphens; must match parent directory name |
| `description` | Yes | 1–1024 characters; describe what the skill does and when to use it; include useful activation keywords |
| `license` | No | License name or reference to a bundled license file |
| `compatibility` | No | 1–500 characters; environment requirements such as intended product, packages, or network access |
| `metadata` | No | Arbitrary key-value mapping; values should be strings |
| `allowed-tools` | No | Space-separated pre-approved tool list; experimental and support may vary by implementation |

Only include optional fields when they add value. In particular, do not assume `allowed-tools` is portable.

## Body guidance

The Markdown body has no rigid section schema. Recommended content includes:
- Step-by-step instructions
- Examples of inputs and outputs
- Common edge cases

The full `SKILL.md` is loaded when the skill activates. Keep it concise: the specification recommends fewer than 500 lines and fewer than 5,000 tokens. Move detailed material to supporting files.

## Progressive disclosure

1. Discovery: the agent sees the skill's `name` and `description`.
2. Activation: the agent loads the full `SKILL.md`.
3. On-demand resources: the agent reads supporting references or uses scripts/assets as required.

Design around these loading stages. The description must be useful for discovery; the main file must contain the operating procedure; supporting resources should hold details not needed on every activation.

## File references

- Use paths relative to the skill root.
- Link supporting files from `SKILL.md`.
- Prefer references directly one level below the skill root; avoid deep reference chains.

## Scripts

Scripts should be self-contained or document dependencies, provide helpful error messages, and handle edge cases gracefully. Supported languages depend on the agent implementation.

## Validation

The reference implementation is `skills-ref`. The documented validation command is:

```bash
skills-ref validate ./skill-name
```

A one-shot invocation can be run with `uvx`:

```bash
uvx --from git+https://github.com/agentskills/agentskills#subdirectory=skills-ref skills-ref validate ./skill-name
```

Validation checks format and naming conventions. It does not prove that the skill's workflow is useful, safe, factually correct, or compatible with every agent runtime. Perform a separate content and portability review.

