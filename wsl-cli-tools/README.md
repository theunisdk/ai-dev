# CLI Utils

A collection of command-line utilities for development workflows in WSL (Windows Subsystem for Linux). These tools handle common tasks like file conversion, project setup, and audio transcription.

## Tools

### cleanZoneFiles

Removes `Zone.Identifier` metadata files that Windows creates when copying files into WSL.

```bash
cd /path/to/project
cleanZoneFiles
```

### initClaudeSettings

Bootstraps a project with [Claude Code](https://docs.anthropic.com/en/docs/claude-code) configuration. Creates a `.claude/settings.local.json` with standard permissions and a default `CLAUDE.md` guidelines file. If a settings file already exists, it merges permissions without overwriting your existing ones.

```bash
cd /path/to/project
initClaudeSettings
```

**Requires:** `jq`

### md2pdf

Converts Markdown files to PDF using pandoc. Accepts a single file or a directory (converts all `.md` files in it). Automatically tries multiple PDF engines (`pdflatex`, `xelatex`) for compatibility.

```bash
# Single file
md2pdf document.md

# All markdown files in a directory
md2pdf /path/to/docs/
```

**Requires:** `pandoc` and a LaTeX distribution (e.g., `texlive`)

### packme

Interactive script runner for Node.js projects. Reads `package.json`, detects your package manager (pnpm/npm/yarn), and presents an arrow-key navigable menu of available scripts.

```bash
cd /path/to/node-project
packme
```

Use arrow keys to select a script, then press Enter to run it.

**Requires:** `jq` and a Node.js package manager

### pdf2md

Converts PDF files to Markdown (plain text) using `pdftotext`. Accepts a single file or a directory.

```bash
# Single file
pdf2md document.pdf

# All PDFs in a directory
pdf2md /path/to/pdfs/
```

**Requires:** `poppler-utils` (`sudo apt install poppler-utils`)

### transcribe

Transcribes audio files to text using the OpenAI Whisper API. Handles format conversion and automatically splits large files into chunks to stay within API size limits.

```bash
transcribe recording.m4a output.txt
```

Supported audio formats: any format `ffmpeg` can read (mp3, m4a, wav, ogg, etc.).

**Requires:** `ffmpeg`, `jq`, and an `OPENAI_API_KEY` environment variable:
```bash
export OPENAI_API_KEY='your-api-key'
```

## Installation

Clone the repository and run the installer. It copies all tools to `/usr/local/bin` so they're available globally.

```bash
git clone <repo-url>
cd cli-utils
sudo bash install-utils.sh
```

To install a single tool manually:

```bash
sudo cp <tool-name> /usr/local/bin/
sudo chmod +x /usr/local/bin/<tool-name>
```

## Dependencies

Install all dependencies at once on Debian/Ubuntu:

```bash
sudo apt install jq pandoc poppler-utils ffmpeg texlive
```

Not all dependencies are required — each tool only needs its specific ones (listed above).

## Uninstallation

Remove any tool by deleting it from `/usr/local/bin`:

```bash
sudo rm /usr/local/bin/{cleanZoneFiles,initClaudeSettings,md2pdf,packme,pdf2md,transcribe}
```

## License

MIT
