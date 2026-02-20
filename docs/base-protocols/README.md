# Base Protocols

This folder contains the **universal development standards** that apply to every app built by Mrswami — regardless of stack, platform, or project size.

## Files

| File | Description |
|------|-------------|
| `BASE_PROTOCOLS.md` | Full standards document covering autofill, security, auth, Firebase, a11y, git, deployment, and more |

## How to Use

When starting a **new project**:
1. Copy this `docs/base-protocols/` folder into the new repo
2. Reference `BASE_PROTOCOLS.md` as the baseline
3. Add any project-specific deviations in the project's own `README.md`

When **reviewing code**:
- Use `BASE_PROTOCOLS.md` as the checklist before merging any PR

When **new standards are adopted**:
- Update `BASE_PROTOCOLS.md`
- Add an entry to the Changelog section
- Commit with message: `docs: update BASE_PROTOCOLS - <what changed>`
