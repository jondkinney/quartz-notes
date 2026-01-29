---
publish: true
created: 2026-01-27T16:54:53.999-06:00
modified: 2026-01-28T21:41:06.200-06:00
cssclasses: ""
---


# QMD - Local Semantic Search for Obsidian

QMD (Quick Markdown) is a local search engine that indexes your Obsidian vault and provides both keyword (BM25) and semantic (vector) search. No API keys needed — runs entirely on your Mac using small local models.

## Why QMD?

- **Keyword search** (`qmd search`) — fast BM25 matching, finds exact terms
- **Semantic search** (`qmd vsearch`) — understands meaning, finds related content even with different wording
- **Hybrid search** (`qmd query`) — combines both with query expansion and reranking for best results
- **100% local** — no data leaves your machine
- **Apple Silicon optimized** — uses Metal acceleration on M1/M2/M3/M4 Macs

## Installation

```bash
# Install via bun (if not already installed: brew install oven-sh/bun/bun)
bun install -g qmd
```

## Initial Setup

### 1. Add your Obsidian vault as a collection

```bash
qmd collection add ~/Documents/Obsidian --name obsidian --mask "**/*.md"
```

### 2. Index the collection

```bash
qmd update
```

### 3. Generate vector embeddings

This downloads the Qwen embedding model (~2.2GB) on first run:

```bash
qmd embed
```

## Usage

### Basic keyword search (fast)
```bash
qmd search "hockey drills"
```

### Semantic search (understands intent)
```bash
qmd vsearch "exercises for beginners learning to skate"
```

### Hybrid search with reranking (best quality)
```bash
qmd query "how to practice backward skating"
```

### List indexed files
```bash
qmd ls obsidian
```

### Get a specific document
```bash
qmd get "obsidian/path/to/file.md"
```

### Check status
```bash
qmd status
```

## Automatic Daily Reindexing

Set up a cron job to reindex your vault daily (runs at 3:30 AM):

```bash
echo "30 3 * * * /Users/jon/.bun/bin/qmd update && /Users/jon/.bun/bin/qmd embed" | crontab -
```

Verify it's set:
```bash
crontab -l
```

## Output Formats

QMD supports multiple output formats for integration with other tools:

```bash
qmd search "query" --json    # JSON output
qmd search "query" --csv     # CSV output
qmd search "query" --md      # Markdown output
qmd search "query" --files   # File paths only
```

## Models Used (auto-downloaded)

- **Embedding:** embeddinggemma-300M-Q8_0
- **Reranking:** qwen3-reranker-0.6b-q8_0
- **Generation:** Qwen3-0.6B-Q8_0

Models are stored in `~/.cache/qmd/` and downloaded automatically on first use.

## Index Location

```
~/.cache/qmd/index.sqlite
```

## Troubleshooting

### Reindex after adding many files
```bash
qmd update && qmd embed
```

### Clear cache and rebuild
```bash
qmd cleanup
qmd update
qmd embed
```

### Check what's indexed
```bash
qmd collection list
qmd status
```

## References

- Original tweet: https://x.com/andrarchy/status/2015783856087929254
- Source: https://github.com/nicobytes/qmd (assumed based on bun package)

---

*Set up January 2026 by Del*

---
*Part of [[index|Jonokasten]]*
