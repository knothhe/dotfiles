# Global Coding Guidelines

Default coding guidelines for all projects.

## Bash Tool Usage

When using the `bash` tool to search or find files, prefer modern alternatives:

- **Use `rg` instead of `grep`** - ripgrep is faster and has better default output
  ```bash
  rg "pattern"              # Search content
  rg -l "pattern"           # List matching files
  rg -g "*.tsx" "pattern"   # Search in specific glob
  rg -t ts "pattern"        # Search by type
  ```

- **Use `fd` instead of `find`** - fd is faster with simpler syntax
  ```bash
  fd "*.tsx"                # Find files by pattern
  fd "file_name"            # Find by filename
  fd -e ts -e tsx           # Find by extension
  fd --type f               # Files only
  ```

## Tool Selection Priority

1. Content search → `rg`
2. File search → `fd`
3. General commands → standard bash

## Local Vision Helper

When a task needs a textual description of a local image and no native image
input is available, use `x_eyes <image>` from `~/.local/xbin`. It calls the
LM Studio OpenAI-compatible local server with a vision model and prints only
the scene description to stdout, making it suitable for command substitution
or agent tool pipelines.

Configuration:

- `LMSTUDIO_BASE_URL` defaults to `http://localhost:1234/v1`
- `LMSTUDIO_VISION_MODEL` can pin the model id
- `x_eyes --model <name> <image>` overrides the model per call
- `x_eyes --lang zh <image>` returns Chinese descriptions
