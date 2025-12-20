#!/bin/bash

# Export directory
EXPORT_DIR="$(dirname "$0")/export"
mkdir -p "$EXPORT_DIR"

# Base path
BASE="$(dirname "$0")/Sources"

# Function to concatenate files for a target
export_target() {
    local target_dir="$1"
    local output_name="$2"
    local output_file="$EXPORT_DIR/$output_name.swift"
    
    echo "// Concatenated export of: $target_dir" > "$output_file"
    echo "// Generated: $(date)" >> "$output_file"
    echo "" >> "$output_file"
    
    find "$BASE/$target_dir" -name "*.swift" -type f | sort | while read -r file; do
        echo "" >> "$output_file"
        echo "// ============================================================" >> "$output_file"
        echo "// MARK: - $(basename "$file")" >> "$output_file"
        echo "// ============================================================" >> "$output_file"
        echo "" >> "$output_file"
        cat "$file" >> "$output_file"
    done
    
    echo "Exported: $output_file ($(wc -l < "$output_file") lines)"
}

# Export each target
export_target "File System Primitives" "FileSystemPrimitives"
export_target "File System Async" "FileSystemAsync"
export_target "File System" "FileSystem"

echo ""
echo "Done! Files exported to: $EXPORT_DIR"
ls -la "$EXPORT_DIR"
