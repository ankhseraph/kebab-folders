#!/usr/bin/env bash

TARGET_DIR=""
DRY_RUN=true

while [[ $# -gt 0 ]]; do
    case $1 in
        --execute)
            DRY_RUN=false
            shift
            ;;
        --help|-h)
            echo "Usage: kebab-folders [OPTIONS] <directory>"
            echo ""
            echo "Convert folder names to kebab-case"
            echo ""
            echo "Options:"
            echo "  --execute    Actually rename folders (default is dry-run)"
            echo "  --help, -h   Show this help message"
            echo ""
            echo "Examples:"
            echo "  kebab-folders ~/Music              Preview changes"
            echo "  kebab-folders --execute ~/Music   Execute changes"
            exit 0
            ;;
        -*)
            echo "Unknown option: $1"
            echo "Use --help for usage"
            exit 1
            ;;
        *)
            TARGET_DIR="$1"
            shift
            ;;
    esac
done

if [[ -z "$TARGET_DIR" ]]; then
    echo "Error: No directory specified"
    echo "Use --help for usage"
    exit 1
fi

if [[ ! -d "$TARGET_DIR" ]]; then
    echo "Error: '$TARGET_DIR' is not a directory"
    exit 1
fi

TARGET_DIR=$(cd "$TARGET_DIR" && pwd)

to_kebab_case() {
    local input="$1"
    local result
    result=$(echo "$input" | iconv -f UTF-8 -t ASCII//TRANSLIT 2>/dev/null || echo "$input")
    result=$(echo "$result" | \
        tr '[:upper:]' '[:lower:]' | \
        sed "s/['''\`\"]//g" | \
        sed 's/[^a-z0-9]/-/g' | \
        sed 's/-\+/-/g' | \
        sed 's/^-//' | sed 's/-$//')
    [[ -z "$result" ]] && result="unnamed"
    echo "$result"
}

same_name_case_insensitive() {
    [[ "${1,,}" == "${2,,}" ]]
}

echo "=== kebab-folders ==="
echo "Target: $TARGET_DIR"
echo "Mode: $(if $DRY_RUN; then echo 'DRY RUN'; else echo 'EXECUTE'; fi)"
echo ""

changes=0
errors=0

while IFS= read -r dir; do
    [[ "$dir" == "$TARGET_DIR" ]] && continue

    parent=$(dirname "$dir")
    basename=$(basename "$dir")
    newname=$(to_kebab_case "$basename")

    [[ "$basename" == "$newname" ]] && continue

    newpath="$parent/$newname"

    if [[ -e "$newpath" ]]; then
        if ! same_name_case_insensitive "$basename" "$newname"; then
            echo "CONFLICT: $dir -> $newpath (target exists)"
            ((errors++))
            continue
        fi
    fi

    ((changes++))

    if $DRY_RUN; then
        echo "$basename -> $newname"
    else
        if mv "$dir" "$newpath" 2>/dev/null; then
            echo "RENAMED: $basename -> $newname"
        else
            echo "ERROR: $dir"
            ((errors++))
        fi
    fi
done < <(find "$TARGET_DIR" -type d | awk -F/ '{print NF, $0}' | sort -rn | cut -d' ' -f2-)

echo ""
echo "Changes: $changes | Errors: $errors"

if $DRY_RUN && [[ $changes -gt 0 ]]; then
    echo ""
    echo "Run with --execute to apply changes"
fi
