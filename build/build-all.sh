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

    # Build the runtime by running the setup script
    log_info "Running setup script to build runtime..."

    # Set environment variables for the build
    export RUNTIME_NAME="$runtime"
    export BUILD_ID="local-build-$(date +%s)"
    export RUNTIME_SPEC="${runtime}@${VERSION}"

    # Setup scripts install to flat structure: /opt/joblet/runtimes/<name>/
    TEMP_BUILT_DIR="/opt/joblet/runtimes/$runtime"
    if [ -d "$TEMP_BUILT_DIR" ]; then
        log_info "Cleaning existing runtime: $TEMP_BUILT_DIR"
        sudo rm -rf "$TEMP_BUILT_DIR"
    fi

    # Run the setup script to build the runtime
    if [ -f "setup.sh" ]; then
        log_info "Executing: ./setup.sh"
        if sudo bash setup.sh; then
            log_success "Runtime built successfully"
        else
            log_error "Failed to run setup script for: $runtime"
            continue
        fi
    else
        log_error "No setup.sh found for: $runtime"
        continue
    fi

    # Verify the built runtime exists
    if [ ! -d "$TEMP_BUILT_DIR" ]; then
        log_error "Built runtime not found at: $TEMP_BUILT_DIR"
        continue
    fi

    # Verify runtime.yml exists
    if [ ! -f "$TEMP_BUILT_DIR/runtime.yml" ]; then
        log_error "runtime.yml not found in built runtime"
        continue
    fi

    log_success "Runtime validation passed"

    # Move to nested version structure: /opt/joblet/runtimes/<name>/<version>/
    # Use temporary location to avoid moving directory into itself
    NESTED_RUNTIME_DIR="/opt/joblet/runtimes/$runtime/$VERSION"
    TEMP_MOVE_DIR="/tmp/joblet-build-$runtime-$$"
    log_info "Moving to nested structure: $NESTED_RUNTIME_DIR"

    sudo mv "$TEMP_BUILT_DIR" "$TEMP_MOVE_DIR"
    sudo mkdir -p "/opt/joblet/runtimes/$runtime"
    sudo mv "$TEMP_MOVE_DIR" "$NESTED_RUNTIME_DIR"

    # Create archive from the nested BUILT runtime
    ARCHIVE_NAME="${runtime}-${VERSION}.tar.gz"
    ARCHIVE_PATH="$OUTPUT_DIR/$ARCHIVE_NAME"

    log_info "Creating archive from built runtime: $ARCHIVE_NAME"

    # Package the CONTENTS of the version directory (no wrapper directory)
    # Archive will contain: runtime.yml, isolated/, etc. (at root level)
    # When extracted to /opt/joblet/runtimes/<name>/<version>, creates correct structure
    sudo tar --exclude="__pycache__" \
        --exclude="*.pyc" \
        --exclude="*.pyo" \
        -czf "$ARCHIVE_PATH" -C "$NESTED_RUNTIME_DIR" .

    # Fix ownership of the archive
    sudo chown $(whoami):$(whoami) "$ARCHIVE_PATH"

    if [ $? -eq 0 ]; then
        ARCHIVE_SIZE=$(ls -lh "$ARCHIVE_PATH" | awk '{print $5}')
        CHECKSUM=$(sha256sum "$ARCHIVE_PATH" | awk '{print $1}')

        log_success "Built: $ARCHIVE_NAME ($ARCHIVE_SIZE)"
        log_info "SHA256: $CHECKSUM"

        # Save checksum
        echo "$CHECKSUM  $ARCHIVE_NAME" > "$ARCHIVE_PATH.sha256"

        # Clean up the built runtime to save space
        log_info "Cleaning up built runtime: $NESTED_RUNTIME_DIR"
        sudo rm -rf "/opt/joblet/runtimes/$runtime"
    else
        log_error "Failed to create archive for: $runtime"
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
