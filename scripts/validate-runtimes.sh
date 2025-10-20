#!/bin/bash
# Validate all runtimes for naming convention compliance
# Usage: ./scripts/validate-runtimes.sh [runtime-name]
#
# If runtime-name is provided, validates only that runtime.
# Otherwise, validates all runtimes.

set -e

SPECIFIC_RUNTIME="$1"
VALIDATION_ERRORS=0
VALIDATION_WARNINGS=0

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo "=========================================="
echo "Runtime Naming Convention Validator"
echo "=========================================="
echo ""

# Function to validate a single runtime
validate_runtime() {
    local runtime_dir="$1"
    local runtime_name=$(basename "$runtime_dir")
    local has_errors=0

    echo "Checking: $runtime_name"

    # Check if manifest.yaml exists
    if [ ! -f "$runtime_dir/manifest.yaml" ]; then
        echo -e "  ${RED}✗${NC} manifest.yaml not found"
        ((VALIDATION_ERRORS++))
        return 1
    fi

    # Extract name and version from manifest.yaml
    local manifest_name=$(grep "^name:" "$runtime_dir/manifest.yaml" | awk '{print $2}' | tr -d '"' | tr -d "'")
    local manifest_version=$(grep "^version:" "$runtime_dir/manifest.yaml" | awk '{print $2}' | tr -d '"' | tr -d "'")

    # Check if name was extracted
    if [ -z "$manifest_name" ]; then
        echo -e "  ${RED}✗${NC} Could not extract 'name' from manifest.yaml"
        ((VALIDATION_ERRORS++))
        has_errors=1
    fi

    # Check if version was extracted
    if [ -z "$manifest_version" ]; then
        echo -e "  ${RED}✗${NC} Could not extract 'version' from manifest.yaml"
        ((VALIDATION_ERRORS++))
        has_errors=1
    fi

    # If we couldn't extract name or version, skip further validation
    if [ $has_errors -eq 1 ]; then
        echo ""
        return 1
    fi

    # Validate directory name matches manifest name
    if [ "$runtime_name" != "$manifest_name" ]; then
        echo -e "  ${YELLOW}⚠${NC}  Directory name '$runtime_name' does not match manifest name '$manifest_name'"
        ((VALIDATION_WARNINGS++))
    fi

    # Validate runtime name format
    if [[ ! "$manifest_name" =~ ^[a-z0-9.-]+$ ]]; then
        echo -e "  ${RED}✗${NC} Invalid runtime name: '$manifest_name'"
        echo "     Runtime name must:"
        echo "       - Use only lowercase English letters (a-z)"
        echo "       - Can include numbers (0-9)"
        echo "       - Can include dots (.)"
        echo "       - Can include hyphens (-)"
        echo "       - No uppercase letters, underscores, or special characters"
        ((VALIDATION_ERRORS++))
        has_errors=1
    else
        echo -e "  ${GREEN}✓${NC} Runtime name valid: $manifest_name"
    fi

    # Validate version format
    if [[ ! "$manifest_version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        echo -e "  ${RED}✗${NC} Invalid version format: '$manifest_version'"
        echo "     Version must follow semantic versioning:"
        echo "       - Format: MAJOR.MINOR.PATCH"
        echo "       - Only numbers and dots"
        echo "       - Three parts required"
        echo "     Examples: 1.0.0, 1.3.2, 2.0.0"
        ((VALIDATION_ERRORS++))
        has_errors=1
    else
        echo -e "  ${GREEN}✓${NC} Version format valid: $manifest_version"
    fi

    # Check for setup scripts
    local setup_scripts=$(find "$runtime_dir" -maxdepth 1 -name "setup-*.sh" 2>/dev/null | wc -l)
    if [ "$setup_scripts" -eq 0 ]; then
        echo -e "  ${YELLOW}⚠${NC}  No setup scripts found (setup-*.sh)"
        ((VALIDATION_WARNINGS++))
    else
        echo -e "  ${GREEN}✓${NC} Found $setup_scripts setup script(s)"
    fi

    echo ""
    return 0
}

# Determine which runtimes to validate
if [ -n "$SPECIFIC_RUNTIME" ]; then
    # Validate specific runtime
    RUNTIME_DIR="runtimes/$SPECIFIC_RUNTIME"

    if [ ! -d "$RUNTIME_DIR" ]; then
        echo -e "${RED}Error: Runtime directory '$RUNTIME_DIR' not found${NC}"
        echo ""
        echo "Available runtimes:"
        ls -1 runtimes/ | grep -v "^\." | sed 's/^/  - /'
        exit 1
    fi

    validate_runtime "$RUNTIME_DIR"
else
    # Validate all runtimes
    echo "Validating all runtimes..."
    echo ""

    for runtime_dir in runtimes/*/; do
        # Skip if not a directory or is hidden
        if [ ! -d "$runtime_dir" ] || [[ $(basename "$runtime_dir") == .* ]]; then
            continue
        fi

        validate_runtime "$runtime_dir"
    done
fi

# Summary
echo "=========================================="
echo "Validation Summary"
echo "=========================================="

if [ $VALIDATION_ERRORS -eq 0 ] && [ $VALIDATION_WARNINGS -eq 0 ]; then
    echo -e "${GREEN}✓ All validations passed!${NC}"
    echo ""
    exit 0
elif [ $VALIDATION_ERRORS -eq 0 ]; then
    echo -e "${YELLOW}⚠ Validation completed with warnings${NC}"
    echo "  Warnings: $VALIDATION_WARNINGS"
    echo ""
    echo "Warnings do not prevent releases but should be addressed."
    exit 0
else
    echo -e "${RED}✗ Validation failed${NC}"
    echo "  Errors: $VALIDATION_ERRORS"
    echo "  Warnings: $VALIDATION_WARNINGS"
    echo ""
    echo "Please fix the errors before creating a release."
    exit 1
fi
