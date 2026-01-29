---
publish: true
created: 2026-01-28T23:28:04.238-06:00
modified: 2026-01-28T23:36:29.504-06:00
cssclasses: ""
---

# Memory Embeddings

How Moltbot remembers things across sessions.

## Overview

Moltbot uses **semantic search** to recall information from memory files (`MEMORY.md` and `memory/*.md`). This is powered by text embeddings — numerical representations of text that capture meaning.

## Architecture

Two separate models work together:

| Role               | Model                  | Provider  |
| ------------------ | ---------------------- | --------- |
| **Chat/Reasoning** | Claude Opus 4.5        | Anthropic |
| **Embeddings**     | text-embedding-3-small | OpenAI    |

These are independent — changing your chat model doesn't affect embeddings, and vice versa.

## How It Works

1. **Indexing**: When memory files change, their content is chunked and converted to embedding vectors via OpenAI's API
2. **Search**: When `memory_search` runs, your query is embedded and compared against stored vectors
3. **Retrieval**: The most semantically similar chunks are returned with file path and line numbers
4. **Reading**: `memory_get` fetches the actual text for context

## Why OpenAI for Embeddings?

Anthropic doesn't offer an embedding API — Claude is a generative model only. Common embedding providers:

- **OpenAI** (current default): `text-embedding-3-small`, `text-embedding-3-large`
- **Cohere**: `embed-english-v3.0`
- **Voyage AI**: Specialized for retrieval
- **Google**: `text-embedding-004`

OpenAI's small model is fast, cheap, and effective for most use cases.

## Configuration

Embedding settings live in Moltbot's config. The default uses OpenAI with the API key from your auth profile.

## Cost

`text-embedding-3-small` is very cheap:
- ~$0.02 per 1M tokens
- A typical memory search costs a fraction of a cent

---

*Last updated: 2026-01-26*

---
*Part of [[index|Jonokasten]]*
