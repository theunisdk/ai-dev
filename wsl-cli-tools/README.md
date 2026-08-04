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

### docx2md

Converts Word documents (`.docx`) to Markdown using pandoc. Accepts a single file or a directory (converts all `.docx` files in it). Output is GitHub-flavored Markdown. Embedded images are not extracted — output is text only.

```bash
# Single file
docx2md document.docx

# All Word documents in a directory
docx2md /path/to/docs/
```

**Requires:** `pandoc`

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
transcribe -m whisper-1 -l af recording.m4a output.txt
```

| Option | Default | Purpose |
|--------|---------|---------|
| `-l, --language <code>` | `en` (or `$TRANSCRIBE_LANGUAGE`) | ISO-639-1 language of the audio. `auto` restores API detection. |
| `-m, --model <name>` | `gpt-transcribe` (or `$TRANSCRIBE_MODEL`) | Also: `gpt-4o-transcribe`, `gpt-4o-transcribe-diarize`, `gpt-4o-mini-transcribe`, `whisper-1`. |
| `-b, --bitrate <rate>` | `24k` (or `$TRANSCRIBE_BITRATE`) | Opus bitrate of the working copy. Raise for noisy or multi-mic audio. |

### Encoding and chunking

Input is re-encoded to **24kbps mono Opus at 16kHz** before upload. The models downsample to 16kHz mono internally, so a higher-quality encode is discarded — it only inflates the file. A 100-minute recording comes out around 17MB instead of 141MB as 192kbps mp3. Measured against a 192kbps encode of the same audio, the only differences were words that are genuinely ambiguous in the source.

Two separate API limits force a file to be split, and **either** can bind:

| Limit | `whisper-1` | `gpt-transcribe`, `gpt-4o-*` |
|-------|-------------|------------------------------|
| Size | 25MB | 25MB |
| Duration | *none* | **1400s (23:20)** |

Low-bitrate audio makes the size limit easy to satisfy, which leaves duration as the real constraint — a 40-minute recording is only ~7MB but is still far too long for `gpt-transcribe`. The script therefore splits on whichever limit binds first. Splitting on size alone produces requests that are small but too long, which the API rejects with the misleading message `"Audio file might be corrupted or unsupported"`.

Every split lands mid-sentence and destroys the word straddling it, so the script uses the fewest chunks each model allows.

`gpt-transcribe` is OpenAI's current batch speech-to-text model — more accurate and cheaper than `gpt-4o-transcribe`. It is still rolling out, and entitlement is decided per request, so a project can be accepted on one call and rejected on the next. The script therefore probes once with a one-second silent clip before doing any work, and pins a single model for the whole run: if `gpt-transcribe` is unavailable it says so and uses `gpt-4o-transcribe` instead. This keeps every chunk of a file on the same model and avoids failing partway through a long transcription. A model given explicitly with `-m` is never substituted.

The language is pinned by default because the API detects language from only the first ~30 seconds of each request. Strongly accented or code-switched English is regularly misdetected, and the API then returns a *translation* into the wrong language instead of a transcript. Since large files are split into chunks that are each detected independently, one bad chunk is enough to corrupt part of the output.

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
sudo rm /usr/local/bin/{cleanZoneFiles,docx2md,initClaudeSettings,md2pdf,packme,pdf2md,transcribe}
```

## License

MIT
