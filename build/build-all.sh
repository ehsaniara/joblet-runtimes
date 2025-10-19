#!/bin/bash
# Build all runtimes in the registry
# Usage: ./build-all.sh [runtime-name]

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"
RUNTIMES_DIR="$ROOT_DIR/runtimes"
OUTPUT_DIR="$ROOT_DIR/releases"

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log_info() {
    echo -e "${BLUE}ℹ${NC} $1"
}

log_success() {
    echo -e "${GREEN}✓${NC} $1"
}

log_error() {
    echo -e "${RED}✗${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}⚠${NC} $1"
}

# Create output directory
mkdir -p "$OUTPUT_DIR"

echo "╔══════════════════════════════════════════════════════════════════╗"
echo "║        Joblet Runtime Registry - Build All Runtimes             ║"
echo "║                    (LOCAL BUILD ONLY)                            ║"
echo "╚══════════════════════════════════════════════════════════════════╝"
echo ""
log_warning "This script is for LOCAL TESTING only"
log_info "For releases: Push a git tag (e.g., v1.0.0) to trigger CI/CD"
echo ""

# Find all runtimes
cd "$RUNTIMES_DIR"
RUNTIMES=()

if [ $# -gt 0 ]; then
    # Build specific runtime
    RUNTIMES=("$1")
else
    # Build all runtimes
    for dir in */; do
        runtime_name="${dir%/}"
        if [ -f "$runtime_name/setup.sh" ]; then
            RUNTIMES+=("$runtime_name")
        fi
    done
fi

log_info "Found ${#RUNTIMES[@]} runtime(s) to build"
echo ""

# Build each runtime
for runtime in "${RUNTIMES[@]}"; do
    echo "═══════════════════════════════════════════════════════════════════"
    log_info "Building: $runtime"
    echo "═══════════════════════════════════════════════════════════════════"

    if [ ! -d "$RUNTIMES_DIR/$runtime" ]; then
        log_error "Runtime directory not found: $runtime"
        continue
    fi

    cd "$RUNTIMES_DIR/$runtime"

    # Read version from manifest.yaml
    if [ -f "manifest.yaml" ]; then
        VERSION=$(grep "^version:" manifest.yaml | head -1 | awk '{print $2}' | tr -d '"')
        log_info "Version: $VERSION"
    else
        log_warning "No manifest.yaml found, using version 1.0.0"
        VERSION="1.0.0"
    fi

    # Create archive
    ARCHIVE_NAME="${runtime}-${VERSION}.tar.gz"
    ARCHIVE_PATH="$OUTPUT_DIR/$ARCHIVE_NAME"

    log_info "Creating archive: $ARCHIVE_NAME"
    tar --exclude=".git" \
        --exclude=".idea" \
        --exclude="__pycache__" \
        --exclude="*.pyc" \
        -czf "$ARCHIVE_PATH" -C "$RUNTIMES_DIR" "$runtime"

    if [ $? -eq 0 ]; then
        ARCHIVE_SIZE=$(ls -lh "$ARCHIVE_PATH" | awk '{print $5}')
        CHECKSUM=$(sha256sum "$ARCHIVE_PATH" | awk '{print $1}')

        log_success "Built: $ARCHIVE_NAME ($ARCHIVE_SIZE)"
        log_info "SHA256: $CHECKSUM"

        # Save checksum
        echo "$CHECKSUM  $ARCHIVE_NAME" > "$ARCHIVE_PATH.sha256"
    else
        log_error "Failed to build: $runtime"
    fi

    echo ""
done

# Generate summary
echo "╔══════════════════════════════════════════════════════════════════╗"
echo "║                       Build Summary                              ║"
echo "╚══════════════════════════════════════════════════════════════════╝"
echo ""

TOTAL_ARCHIVES=$(find "$OUTPUT_DIR" -name "*.tar.gz" | wc -l)
log_success "Built $TOTAL_ARCHIVES runtime archive(s)"

echo ""
log_info "Archives location: $OUTPUT_DIR"
echo ""

ls -lh "$OUTPUT_DIR"/*.tar.gz 2>/dev/null || log_warning "No archives found"

echo ""
log_info "To create a release:"
echo "  1. Commit your changes: git add -A && git commit -m '...'"
echo "  2. Push to GitHub: git push origin main"
echo "  3. Create and push a tag: git tag v1.0.0 && git push origin v1.0.0"
echo ""
log_info "GitHub Actions will automatically:"
echo "  • Build all runtimes"
echo "  • Generate checksums"
echo "  • Update registry.json"
echo "  • Create GitHub Release"
echo "  • Upload runtime packages"
echo ""
