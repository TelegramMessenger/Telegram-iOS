#!/bin/bash

# Usage: ./macos-copy-and-cleanup.sh /source/folder /target/folder

SOURCE_DIR="$1"
TARGET_DIR="$2"

if [ -z "$SOURCE_DIR" ] || [ -z "$TARGET_DIR" ]; then
  echo "Usage: $0 /source/folder /target/folder"
  exit 1
fi

# Ensure source exists
if [ ! -d "$SOURCE_DIR" ]; then
  echo "Source directory not found: $SOURCE_DIR"
  exit 1
fi

# Clean up the entire target folder first
if [ -d "$TARGET_DIR" ]; then
  echo "Cleaning target directory: $TARGET_DIR"
  rm -rf "$TARGET_DIR"
fi

# Recreate the target directory
mkdir -p "$TARGET_DIR"

# Get the base folder name from the source (e.g., "td")
SOURCE_BASENAME=$(basename "$SOURCE_DIR")

# Copy the entire source folder into the target
cp -R "$SOURCE_DIR" "$TARGET_DIR/"

# Path to the copied folder
COPIED_DIR="$TARGET_DIR/$SOURCE_BASENAME"

# Delete everything inside the copied folder except .h files
find "$COPIED_DIR" \( ! -name "*.h" -a ! -type d \) -delete

# Remove all empty directories inside, except the root
find "$COPIED_DIR" -type d -empty -not -path "$COPIED_DIR" -delete

echo "✅ Copied $SOURCE_BASENAME into $TARGET_DIR and kept only .h files."
