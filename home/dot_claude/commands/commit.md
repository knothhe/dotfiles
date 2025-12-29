---
description: Generates and executes a git commit with an appropriate message based on staged changes.
argument-hint: [optional context...]
allowed-tools: Bash(git add:*), Bash(git commit:*), Bash(git diff:*), Bash(git status:*), Bash(git log:*)
---

# Task: Generate and Execute Git Commit

Based on the following code changes, generate a concise and descriptive commit message that follows the Conventional Commits specification, then execute the git commit command.

## Instructions:

1. **Analyze the changes**: Review the staged and unstaged changes to understand what has been modified
2. **Generate commit message**: Create a conventional commit message (type: description)
3. **Stage files if needed**: If there are unstaged changes that should be included, stage them first
4. **Execute commit**: Use `git commit` with the generated message
5. **Verify success**: Check that the commit was successful

## Conventional Commit Types:
- `feat`: A new feature
- `fix`: A bug fix
- `docs`: Documentation only changes
- `style`: Changes that do not affect the meaning of the code
- `refactor`: A code change that neither fixes a bug nor adds a feature
- `test`: Adding missing tests or correcting existing tests
- `chore`: Changes to the build process or auxiliary tools

## Current Changes:

### Staged Changes:
!git diff --cached

### Unstaged Changes:
!git diff

### Git Status:
!git status

### Recent Commit History (for style reference):
!git log --oneline -5

## Optional User Context:
$ARGUMENTS

## Execute these steps:

1. First, check if there are any staged changes. If not, stage relevant unstaged changes
2. Generate a conventional commit message based on the changes
3. Execute: `git commit -m "your commit message"`
4. Verify the commit was successful with `git status`
