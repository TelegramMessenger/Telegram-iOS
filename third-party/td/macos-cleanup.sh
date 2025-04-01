#!/bin/bash

# Usage: ./keep_headers.sh /path/to/your/folder

TARGET_DIR="$1"

if [ -z "$TARGET_DIR" ]; then
  echo "Usage: $0 /path/to/your/folder"
  exit 1
fi

# Ensure the path exists
if [ ! -d "$TARGET_DIR" ]; then
  echo "Directory not found: $TARGET_DIR"
  exit 1
fi

# Find and delete everything except .h files
find "$TARGET_DIR" \( ! -name "*.h" -a ! -type d \) -delete

# Remove empty directories (excluding root)
find "$TARGET_DIR" -type d -empty -not -path "$TARGET_DIR" -delete

echo "Cleanup completed. Only .h files remain."
