# Using mise and pnpm on Omarchy Stable

date: 2026-05-28

## Current Setup

This machine runs Omarchy stable, whose Arch package mirror is intentionally
delayed for stability. The installed `mise` package is currently:

```text
mise 2026.3.17
```

This version cannot install current pnpm releases through mise's default
`aqua:pnpm/pnpm` backend. For example:

```bash
mise use -g pnpm@latest
```

fails when it tries to install pnpm `11.4.0`, because the old aqua definition
does not match pnpm's current release asset filenames.

## Install or Upgrade Global pnpm

Use mise's npm backend explicitly:

```bash
mise use -g npm:pnpm@latest
```

The global mise configuration should contain:

```toml
[tools]
"npm:pnpm" = "latest"
```

Do not use the shorthand command below while `mise` is older than the version
that contains the pnpm/aqua fix:

```bash
mise use -g pnpm@latest
```

## Verify the Global pnpm Version

A project's `packageManager` setting may make pnpm run a project-specific
version. Check the globally configured version outside any project directory:

```bash
cd /tmp
mise exec -- pnpm --version
```

At the time this note was written, the global version is:

```text
11.4.0
```

## Use pnpm Inside a Project

Projects should pin the pnpm version they expect in `package.json`:

```json
{
  "packageManager": "pnpm@10.12.1"
}
```

This repository does so. As a result, running:

```bash
pnpm --version
```

inside this repository reports `10.12.1`, even though mise has installed pnpm
`11.4.0` globally. This is expected: project commands use the pinned project
version for reproducible dependency management.

Use pnpm normally in the project:

```bash
pnpm install
pnpm dev
pnpm build
pnpm add <package>
```

## After mise Is Updated

`mise` versions from `2026.5.2` onward contain the required support for newer
pnpm releases through the default aqua backend.

Keeping `npm:pnpm` is valid after upgrading mise. To switch back to mise's
default pnpm backend after the system package has been updated, run:

```bash
mise unuse -g npm:pnpm
mise use -g pnpm@latest
```

## Rule of Thumb

```text
Global pnpm installation: mise use -g npm:pnpm@latest
Project pnpm version:      follow package.json packageManager
Daily project commands:    run pnpm normally inside the project
Before mise is updated:    do not switch back to mise use -g pnpm@latest
```
