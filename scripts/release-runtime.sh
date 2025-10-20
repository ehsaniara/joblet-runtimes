#!/bin/bash
# Helper script to release an individual runtime
# Usage: ./scripts/release-runtime.sh <runtime-name>

set -e

RUNTIME_NAME="$1"

if [ -z "$RUNTIME_NAME" ]; then
    echo "Usage: $0 <runtime-name>"
    echo ""
    echo "Available runtimes:"
    ls -1 runtimes/ | grep -v "^\."
    exit 1
fi

RUNTIME_DIR="runtimes/$RUNTIME_NAME"

# Verify runtime exists
if [ ! -d "$RUNTIME_DIR" ]; then
    echo "Error: Runtime directory '$RUNTIME_DIR' not found"
    echo ""
    echo "Available runtimes:"
    ls -1 runtimes/ | grep -v "^\."
    exit 1
fi

# Verify manifest.yaml exists
if [ ! -f "$RUNTIME_DIR/manifest.yaml" ]; then
    echo "Error: manifest.yaml not found in '$RUNTIME_DIR'"
    exit 1
fi

# Extract version from manifest.yaml
VERSION=$(grep "^version:" "$RUNTIME_DIR/manifest.yaml" | awk '{print $2}' | tr -d '"' | tr -d "'")

if [ -z "$VERSION" ]; then
    echo "Error: Could not extract version from manifest.yaml"
    exit 1
fi

TAG="${RUNTIME_NAME}@${VERSION}"

# Validate naming conventions
echo "Validating naming conventions..."
VALIDATION_FAILED=0

# Validate runtime name: lowercase letters, numbers, dots, and hyphens only
if [[ ! "$RUNTIME_NAME" =~ ^[a-z0-9.-]+$ ]]; then
    echo ""
    echo "❌ Error: Invalid runtime name: '$RUNTIME_NAME'"
    echo ""
    echo "Runtime name must:"
    echo "  - Use only lowercase English letters (a-z)"
    echo "  - Can include numbers (0-9)"
    echo "  - Can include dots (.)"
    echo "  - Can include hyphens (-)"
    echo "  - No uppercase letters, underscores, or special characters"
    echo ""
    echo "Valid examples:"
    echo "  ✓ python-3.11-ml"
    echo "  ✓ openjdk-21"
    echo "  ✓ python-3.11-pytorch-cuda"
    echo "  ✓ graalvmjdk-21"
    echo ""
    echo "Invalid examples:"
    echo "  ✗ Python-3.11-ML (uppercase)"
    echo "  ✗ python_3.11_ml (underscores)"
    echo "  ✗ python@3.11-ml (@ symbol)"
    VALIDATION_FAILED=1
fi

# Validate version: semver format (MAJOR.MINOR.PATCH)
if [[ ! "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    echo ""
    echo "❌ Error: Invalid version format: '$VERSION'"
    echo ""
    echo "Version must follow semantic versioning:"
    echo "  - Format: MAJOR.MINOR.PATCH"
    echo "  - Only numbers and dots"
    echo "  - Three parts required"
    echo ""
    echo "Valid examples:"
    echo "  ✓ 1.0.0"
    echo "  ✓ 1.3.2"
    echo "  ✓ 2.0.0"
    echo ""
    echo "Invalid examples:"
    echo "  ✗ 1.0 (missing patch)"
    echo "  ✗ v1.0.0 (v prefix)"
    echo "  ✗ 1.0.0-beta (pre-release suffix)"
    VALIDATION_FAILED=1
fi

if [ $VALIDATION_FAILED -eq 1 ]; then
    echo ""
    echo "Please fix the naming convention issues in manifest.yaml and retry."
    exit 1
fi

echo "  ✓ Runtime name is valid: $RUNTIME_NAME"
echo "  ✓ Version format is valid: $VERSION"
echo ""

echo "=========================================="
echo "Runtime Release Helper"
echo "=========================================="
echo "Runtime: $RUNTIME_NAME"
echo "Version: $VERSION"
echo "Tag:     $TAG"
echo "=========================================="
echo ""

# Show what will be released
echo "Files to be packaged:"
find "$RUNTIME_DIR" -type f | sed 's|^|  - |'
echo ""

# Check if tag already exists
if git rev-parse "$TAG" >/dev/null 2>&1; then
    echo "⚠️  Warning: Tag '$TAG' already exists!"
    echo ""
    echo "Existing tag info:"
    git show "$TAG" --no-patch --format="%H%n  Author: %an <%ae>%n  Date: %ad%n  Message: %s" | sed 's/^/  /'
    echo ""
    read -p "Do you want to delete and recreate this tag? (yes/no): " CONFIRM
    if [ "$CONFIRM" = "yes" ]; then
        echo "Deleting local tag..."
        git tag -d "$TAG"
        echo "Deleting remote tag (if exists)..."
        git push origin ":refs/tags/$TAG" 2>/dev/null || echo "  (remote tag didn't exist)"
    else
        echo "Aborted."
        exit 1
    fi
fi

echo "This will:"
echo "  1. Create git tag: $TAG"
echo "  2. Push tag to GitHub"
echo "  3. Trigger GitHub Actions to:"
echo "     - Build $RUNTIME_NAME only"
echo "     - Update registry.json with this version"
echo "     - Create GitHub release with package"
echo ""

read -p "Proceed with release? (yes/no): " CONFIRM

if [ "$CONFIRM" != "yes" ]; then
    echo "Aborted."
    exit 0
fi

echo ""
echo "Creating tag..."
git tag -a "$TAG" -m "Release $RUNTIME_NAME version $VERSION

Runtime: $RUNTIME_NAME
Version: $VERSION

Changes: See commit history for details.

This tag will trigger a runtime-specific release that:
- Builds only $RUNTIME_NAME
- Updates registry.json with version $VERSION
- Preserves all other runtime versions"

echo "✓ Tag created: $TAG"
echo ""

echo "Pushing tag to GitHub..."
git push origin "$TAG"

echo ""
echo "=========================================="
echo "✅ Release initiated!"
echo "=========================================="
echo ""
echo "Tag pushed: $TAG"
echo "GitHub Actions: https://github.com/ehsaniara/joblet-runtimes/actions"
echo ""
echo "The workflow will:"
echo "  - Build: $RUNTIME_NAME-$VERSION.tar.gz"
echo "  - Update: registry.json (add $RUNTIME_NAME@$VERSION)"
echo "  - Release: https://github.com/ehsaniara/joblet-runtimes/releases/tag/$TAG"
echo ""
echo "Monitor the release at:"
echo "  https://github.com/ehsaniara/joblet-runtimes/actions/workflows/release-runtime.yml"
