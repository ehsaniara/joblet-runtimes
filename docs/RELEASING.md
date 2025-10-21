# 🚀 Runtime Release Guide

This guide explains how to release individual runtimes or bulk releases.

## 📑 Table of Contents

- [Naming Conventions](#naming-conventions)
- [Individual Runtime Release (Recommended)](#individual-runtime-release-recommended)
- [Bulk Release (All Runtimes)](#bulk-release-all-runtimes)
- [Registry Format](#registry-format)
- [Troubleshooting](#troubleshooting)

---

## 🏷️ Naming Conventions

All runtimes must follow strict naming conventions for consistency and compatibility.

### 📝 Runtime Name Rules

Runtime names must contain **only**:
- ✅ Lowercase English letters (`a-z`)
- ✅ Numbers (`0-9`)
- ✅ Dots (`.`)
- ✅ Hyphens (`-`)

**Invalid characters:**
- ❌ Uppercase letters (`A-Z`)
- ❌ Underscores (`_`)
- ❌ Special characters (`@`, `#`, `$`, etc.)
- ❌ Spaces

**Valid examples:**
```
✓ python-3.11-ml
✓ openjdk-21
✓ python-3.11-pytorch-cuda
✓ graalvmjdk-21
✓ node-18.20
```

**Invalid examples:**
```
✗ Python-3.11-ML          (uppercase letters)
✗ python_3.11_ml          (underscores)
✗ python@3.11-ml          (@ symbol in name)
✗ Python ML 3.11          (spaces and uppercase)
```

### 🔢 Version Number Rules

Version numbers must follow **Semantic Versioning 2.0.0** format:

**Format:** `MAJOR.MINOR.PATCH`

- Must have exactly **three parts**
- Each part must be a **number**
- Parts separated by **dots only**

**Valid examples:**
```
✓ 1.0.0
✓ 1.3.2
✓ 2.0.0
✓ 10.15.3
```

**Invalid examples:**
```
✗ 1.0              (missing PATCH)
✗ v1.0.0           (v prefix)
✗ 1.0.0-beta       (pre-release suffix)
✗ 1.0.0.0          (four parts)
```

### ✅ Validation

Use the validation script to check compliance:

```bash
# Validate all runtimes
./scripts/validate-runtimes.sh

# Validate specific runtime
./scripts/validate-runtimes.sh python-3.11-ml

# Example output:
# Checking: python-3.11-ml
#   ✓ Runtime name valid: python-3.11-ml
#   ✓ Version format valid: 1.3.2
#   ✓ Found 6 setup script(s)
```

The validation runs automatically during:
- Manual releases via `release-runtime.sh`
- GitHub Actions workflow
- CI/CD pipelines

### 📁 Directory Structure

The runtime directory name should match the `name` field in `manifest.yaml`:

```
runtimes/
├── python-3.11-ml/           # Directory name
│   └── manifest.yaml         # name: python-3.11-ml (must match)
```

If they don't match, you'll get a warning (but it won't block releases).

---

## 🎯 Individual Runtime Release (Recommended)

Use this approach to release a single runtime without rebuilding all others.

### ✅ Prerequisites

1. Update the runtime's `manifest.yaml` with the new version
2. Make and commit your changes
3. Ensure you're on the `main` branch and up to date

### 📋 Step-by-Step Process

#### ⚡ Option 1: Using the Helper Script (Easiest)

```bash
# Update manifest version first
cd runtimes/python-3.11-pytorch-cuda
# Edit manifest.yaml: version: 1.3.2

# Commit your changes
git add manifest.yaml setup-*.sh
git commit -m "Update python-3.11-pytorch-cuda to 1.3.2"
git push origin main

# Use the helper script
cd ~/joblet/joblet-runtimes
./scripts/release-runtime.sh python-3.11-pytorch-cuda
```

The script will:
- Extract version from `manifest.yaml`
- Create tag in format `<runtime-name>@<version>`
- Push tag to GitHub
- Trigger GitHub Actions workflow

#### 🔧 Option 2: Manual Tagging

```bash
# 1. Update manifest.yaml
cd runtimes/python-3.11-pytorch-cuda
vim manifest.yaml  # Set version: 1.3.2

# 2. Commit changes
git add manifest.yaml setup-*.sh
git commit -m "Update python-3.11-pytorch-cuda to 1.3.2"
git push origin main

# 3. Create and push tag
git tag -a python-3.11-pytorch-cuda@1.3.2 -m "Release python-3.11-pytorch-cuda 1.3.2"
git push origin python-3.11-pytorch-cuda@1.3.2
```

### 🔄 What Happens Next

GitHub Actions (`.github/workflows/release-runtime.yml`) will:

1. **Parse the tag** to extract runtime name and version
2. **Verify** the runtime exists and manifest version matches
3. **Build** only that specific runtime package
4. **Update registry.json** with the new version entry
5. **Create GitHub release** with the runtime package
6. **Commit** updated registry.json back to main

### 💡 Example Workflow

```bash
# Update python-3.11-ml from 1.3.1 to 1.3.2
cd runtimes/python-3.11-ml
sed -i 's/version: 1.3.1/version: 1.3.2/' manifest.yaml

# Make your code changes
vim setup-ubuntu-amd64.sh  # ... improvements ...

# Commit
git add .
git commit -m "Improve PyTorch installation in python-3.11-ml v1.3.2"
git push origin main

# Release
cd ../..
./scripts/release-runtime.sh python-3.11-ml

# Output:
# Runtime: python-3.11-ml
# Version: 1.3.2
# Tag:     python-3.11-ml@1.3.2
# Proceed with release? (yes/no): yes
# ✓ Tag created: python-3.11-ml@1.3.2
# ✅ Release initiated!
```

### ⭐ Benefits of Individual Releases

✅ **Faster** - Only builds one runtime (~2-3 min vs 10-15 min for all)
✅ **Independent** - Each runtime has its own version lifecycle
✅ **Safer** - No risk of accidentally updating unrelated runtimes
✅ **Cleaner** - Registry shows clear version history per runtime

### 📊 Registry After Individual Release

```json
{
  "runtimes": {
    "python-3.11-ml": {
      "1.3.1": { "...": "old version" },
      "1.3.2": { "...": "new version" }
    },
    "python-3.11-pytorch-cuda": {
      "1.3.1": { "...": "stays unchanged" }
    },
    "openjdk-21": {
      "1.3.1": { "...": "stays unchanged" }
    }
  }
}
```

---

## 📦 Bulk Release (All Runtimes)

Use this approach when you want to release all runtimes with the same version.

### 🤔 When to Use

- Initial registry setup
- Major coordinated updates across all runtimes
- Synchronized version bumps

### 🔄 Process

```bash
# 1. Update ALL manifest.yaml files manually (or workflow will do it)
# 2. Make your changes to multiple runtimes
git add .
git commit -m "Update all runtimes to 1.4.0"
git push origin main

# 3. Create version tag (NOT runtime-specific)
git tag -a v1.4.0 -m "Release all runtimes at version 1.4.0"
git push origin v1.4.0
```

### ⚙️ What Happens

GitHub Actions (`.github/workflows/release.yml`) will:

1. **Update** all `manifest.yaml` files to version 1.4.0
2. **Build** all runtimes
3. **Update registry.json** with all runtimes at version 1.4.0
4. **Create** single GitHub release with all packages

### ⚠️ Downside

- Rebuilds ALL runtimes even if only one changed
- Creates large releases (5+ packages)
- Slower build times
- All runtimes forced to same version

---

## 📋 Registry Format

The registry uses a **multi-version nested format**:

```json
{
  "version": "1",
  "updated_at": "2025-10-20T20:00:00Z",
  "runtimes": {
    "<runtime-name>": {
      "<version>": {
        "version": "1.3.2",
        "description": "...",
        "download_url": "https://github.com/.../releases/download/<tag>/<file>.tar.gz",
        "checksum": "sha256:...",
        "size": 12345,
        "platforms": ["ubuntu-amd64", "ubuntu-arm64"]
      }
    }
  }
}
```

### 🔍 Version Resolution

When users install a runtime:

```bash
# Installs latest version
rnx runtime install python-3.11-ml

# Installs specific version
rnx runtime install python-3.11-ml@1.3.2
```

The client:
1. Fetches `registry.json`
2. Finds `runtimes["python-3.11-ml"]`
3. Gets all versions: `["1.3.1", "1.3.2"]`
4. Uses `@latest` → picks highest semver (1.3.2)
5. Downloads from `download_url`
6. Verifies `checksum`

---

## 🔧 Troubleshooting

### 🏷️ Tag Already Exists

```bash
# Delete local tag
git tag -d python-3.11-ml@1.3.2

# Delete remote tag
git push origin :refs/tags/python-3.11-ml@1.3.2

# Recreate and push
git tag -a python-3.11-ml@1.3.2 -m "..."
git push origin python-3.11-ml@1.3.2
```

### ⚠️ Version Mismatch Error

```
Error: Version mismatch!
  Tag specifies version: 1.3.2
  manifest.yaml has version: 1.3.1
```

**Solution:** Update `manifest.yaml` to match the tag version before creating the tag.

```bash
# Fix manifest
vim runtimes/python-3.11-ml/manifest.yaml
# Change: version: 1.3.2

# Commit
git add runtimes/python-3.11-ml/manifest.yaml
git commit -m "Update version to 1.3.2"
git push origin main

# Retry release
./scripts/release-runtime.sh python-3.11-ml
```

### ❌ Workflow Not Triggering

Check that your tag matches the pattern:

- ✅ `python-3.11-ml@1.3.2` - Correct
- ✅ `openjdk-21@2.0.0` - Correct
- ❌ `v1.3.2` - Wrong (triggers bulk release)
- ❌ `python-3.11-ml-1.3.2` - Wrong (use @ not -)
- ❌ `python@1.3.2` - Wrong (no runtime named "python")

### 👀 Check Workflow Status

```bash
# View recent tags
git tag -l '*@*' | tail -5

# View workflow runs
# Go to: https://github.com/ehsaniara/joblet-runtimes/actions/workflows/release-runtime.yml
```

---

## 💎 Best Practices

### 1️⃣ Version Bumping

Follow semantic versioning:
- **Patch** (1.3.1 → 1.3.2): Bug fixes, minor improvements
- **Minor** (1.3.2 → 1.4.0): New features, backwards compatible
- **Major** (1.4.0 → 2.0.0): Breaking changes

### 2️⃣ Testing Before Release

```bash
# Test runtime locally before releasing
cd runtimes/python-3.11-ml
sudo bash setup-ubuntu-amd64.sh

# Verify installation
ls -la /opt/joblet/runtimes/python-3.11-ml/
```

### 3️⃣ Changelog

Keep a changelog in your commit messages:

```bash
git commit -m "Update python-3.11-ml to 1.3.2

Improvements:
- Fixed PyTorch installation with better error handling
- Added network connectivity check
- Improved pip timeout configuration

This fixes issue #123"
```

### 4️⃣ Multiple Runtime Updates

If updating multiple runtimes, release them separately:

```bash
# Update and release first runtime
vim runtimes/python-3.11-ml/manifest.yaml
git commit -m "Update python-3.11-ml to 1.3.2"
git push origin main
./scripts/release-runtime.sh python-3.11-ml

# Wait for first release to complete

# Update and release second runtime
vim runtimes/python-3.11-pytorch-cuda/manifest.yaml
git commit -m "Update python-3.11-pytorch-cuda to 1.3.2"
git push origin main
./scripts/release-runtime.sh python-3.11-pytorch-cuda
```

---

## 📝 Summary

**For most releases, use individual runtime releases:**
```bash
./scripts/release-runtime.sh <runtime-name>
```

**Only use bulk releases when coordinating all runtimes:**
```bash
git tag -a v1.4.0 -m "..."
git push origin v1.4.0
```

The individual release system is **faster, safer, and more flexible**!
