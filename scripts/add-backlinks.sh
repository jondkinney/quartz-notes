#!/bin/bash
# Adds backlink to index on all published markdown files that don't have one

CONTENT_DIR="content"
BACKLINK_PATTERN="\[\[index"
BACKLINK_TEXT=$'\n---\n*Part of [[index|Jonokasten]]*'

find "$CONTENT_DIR" -name "*.md" ! -name "index.md" -type f | while read -r file; do
  if ! grep -q "$BACKLINK_PATTERN" "$file"; then
    echo "$BACKLINK_TEXT" >> "$file"
    echo "Added backlink to: $file"
  fi
done
