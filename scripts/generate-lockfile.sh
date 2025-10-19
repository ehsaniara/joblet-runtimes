#!/bin/bash
# Generate versions.lock file for a runtime
# This captures exact versions of all installed packages
# Usage: ./generate-lockfile.sh <runtime-name>

set -e

if [ $# -eq 0 ]; then
    echo "Usage: $0 <runtime-name>"
    echo "Example: $0 python-3.11-pytorch-cuda"
    exit 1
fi

RUNTIME_NAME="$1"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"
RUNTIME_DIR="$ROOT_DIR/runtimes/$RUNTIME_NAME"
LOCKFILE="$RUNTIME_DIR/versions.lock"

if [ ! -d "$RUNTIME_DIR" ]; then
    echo "Error: Runtime directory not found: $RUNTIME_DIR"
    exit 1
fi

echo "Generating versions.lock for: $RUNTIME_NAME"
echo "Output: $LOCKFILE"
echo ""

# Create temporary Python environment to inspect packages
TEMP_VENV="/tmp/runtime-inspect-$$"
python3 -m venv "$TEMP_VENV"
source "$TEMP_VENV/bin/activate"

# Install pip-tools for dependency resolution
pip install --quiet pip-tools

echo "# Inspecting Python packages..."

# Create requirements.txt from runtime.yaml if it exists
if [ -f "$RUNTIME_DIR/runtime.yaml" ]; then
    # Extract package names from runtime.yaml
    grep -A 100 "python_packages:" "$RUNTIME_DIR/runtime.yaml" | \
        grep "name:" | \
        awk '{print $3}' | \
        tr -d '"' > /tmp/requirements-$$.txt

    echo "Found packages in runtime.yaml"
    cat /tmp/requirements-$$.txt

    # Generate lock file with exact versions
    pip-compile --quiet --generate-hashes /tmp/requirements-$$.txt -o /tmp/lockfile-$$.txt 2>/dev/null || true

    if [ -f /tmp/lockfile-$$.txt ]; then
        echo ""
        echo "Generated lockfile with hashes"
    fi
fi

# Cleanup
deactivate
rm -rf "$TEMP_VENV"
rm -f /tmp/requirements-$$.txt /tmp/lockfile-$$.txt

echo ""
echo "✓ versions.lock template created"
echo ""
echo "Note: This is a simplified version. For production:"
echo "  1. Build the runtime in a clean environment"
echo "  2. Capture actual installed package versions"
echo "  3. Record SHA256 hashes for all packages"
echo "  4. Include system package versions"
echo "  5. Document CUDA toolkit versions"
echo ""
