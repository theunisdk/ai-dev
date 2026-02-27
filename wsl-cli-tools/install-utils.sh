#!/bin/bash
# Install all utility scripts to /usr/local/bin

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "Installing utilities from $SCRIPT_DIR..."
echo ""

# Counter for installed scripts
count=0

# Find all files in the current directory (not subdirectories)
# Exclude this install script itself
for file in "$SCRIPT_DIR"/*; do
    # Skip if it's a directory
    if [ -d "$file" ]; then
        continue
    fi

    # Get just the filename
    filename=$(basename "$file")

    # Skip this install script itself
    if [ "$filename" = "install-utils.sh" ]; then
        continue
    fi

    # Skip common non-executable files
    if [[ "$filename" == *.md ]] || [[ "$filename" == *.txt ]] || [[ "$filename" == *.json ]]; then
        continue
    fi

    # Make sure the file is executable
    chmod +x "$file"

    # Copy to /usr/local/bin
    echo "Installing: $filename"
    cp "$file" /usr/local/bin/

    ((count++))
done

echo ""
echo "Installation complete! Installed $count utility script(s)."
echo "You can now run these commands from anywhere."
