# Understanding Joblet Runtimes: A Comprehensive Guide

This guide explains what runtimes are, how they work in Joblet, and how the runtime registry system operates.

## Table of Contents

1. [What Are Runtimes?](#what-are-runtimes)
2. [Why Runtimes Matter](#why-runtimes-matter)
3. [How Runtimes Work](#how-runtimes-work)
4. [Runtime Anatomy](#runtime-anatomy)
5. [The Registry System](#the-registry-system)
6. [Version Management](#version-management)
7. [Real-World Examples](#real-world-examples)

---

## 📦 What Are Runtimes?

A **runtime** in Joblet is a pre-built, isolated environment containing everything your job needs to run:

- **Programming language** (Python, Java, Node.js)
- **Libraries and packages** (NumPy, PyTorch, Spring Boot)
- **System tools** (bash, curl, grep)
- **Dependencies** (OpenSSL, CUDA drivers, native libraries)

Think of a runtime like a **sealed box** containing a complete, working environment. When you run a job, Joblet opens
this box and gives your code access to everything inside it, without touching your host system.

### Key Characteristics

✅ **Isolated** - Jobs can't modify the runtime or affect other jobs
✅ **Reproducible** - Same runtime = same environment every time
✅ **Versioned** - Multiple versions can coexist (like npm packages)
✅ **Portable** - Works the same way on any machine running Joblet
✅ **Zero-contamination** - No effect on host system packages

---

## 🎯 Why Runtimes Matter

### 😫 The Problem They Solve

Without runtimes, you'd face these challenges:

1. **Dependency Hell**
   ```bash
   # Job A needs PyTorch 2.1 with CUDA 11.8
   # Job B needs PyTorch 1.13 with CUDA 11.7
   # How do you install both on the same machine? 🤯
   ```

2. **Host Contamination**
   ```bash
   # Job installs packages globally
   sudo pip install numpy==1.26.0
   # Now ALL jobs must use this version!
   ```

3. **Reproducibility Issues**
   ```bash
   # Works on my machine...
   # Different library versions on production
   # Job fails mysteriously 😢
   ```

### ✨ How Runtimes Fix This

```bash
# Job A gets its own isolated PyTorch 2.1 environment
rnx job run --runtime=python-3.11-pytorch-cuda@2.1.0 python train.py

# Job B gets a different isolated environment
rnx job run --runtime=python-3.11-pytorch-cuda@1.13.0 python legacy_model.py

# Both work perfectly, zero conflicts! 🎉
```

Each job gets exactly what it needs, nothing more, nothing less.

---

## ⚙️ How Runtimes Work

### 🔍 The Big Picture

```
┌─────────────────────────────────────────────────────────────┐
│ User runs job with runtime specification                    │
│   $ rnx job run --runtime=python-3.11-ml python script.py  │
└─────────────────────────┬───────────────────────────────────┘
                          │
                          ▼
┌─────────────────────────────────────────────────────────────┐
│ Joblet creates isolated namespace for the job               │
│   - New PID namespace (job becomes PID 1)                   │
│   - New mount namespace (isolated filesystem)               │
│   - New network namespace (controlled networking)           │
└─────────────────────────┬───────────────────────────────────┘
                          │
                          ▼
┌─────────────────────────────────────────────────────────────┐
│ Runtime resolution: Find the runtime directory              │
│   /opt/joblet/runtimes/python-3.11-ml/                     │
│   /opt/joblet/runtimes/python-3.11-ml-1.3.2/  (versioned) │
└─────────────────────────┬───────────────────────────────────┘
                          │
                          ▼
┌─────────────────────────────────────────────────────────────┐
│ Load runtime configuration (runtime.yml)                    │
│   - Mount points: /bin, /lib, /usr, etc.                   │
│   - Environment variables: PATH, PYTHONPATH, etc.           │
└─────────────────────────┬───────────────────────────────────┘
                          │
                          ▼
┌─────────────────────────────────────────────────────────────┐
│ Mount runtime directories into isolated filesystem          │
│   - Bind mount (read-only)                                 │
│   - /opt/joblet/runtimes/.../isolated/bin → /bin           │
│   - /opt/joblet/runtimes/.../isolated/usr → /usr           │
└─────────────────────────┬───────────────────────────────────┘
                          │
                          ▼
┌─────────────────────────────────────────────────────────────┐
│ Set environment variables from runtime.yml                  │
│   export PATH=/usr/bin:/bin                                │
│   export PYTHONPATH=/usr/local/lib/python3.11/site-packages│
└─────────────────────────┬───────────────────────────────────┘
                          │
                          ▼
┌─────────────────────────────────────────────────────────────┐
│ Execute job in isolated environment                         │
│   python script.py                                          │
│   - Has access to all runtime packages                     │
│   - Cannot modify runtime (read-only)                      │
│   - Cannot affect host system                              │
└─────────────────────────────────────────────────────────────┘
```

### Step-by-Step Walkthrough

**1. You run a job:**

```bash
rnx job run --runtime=python-3.11-ml python analyze.py
```

**2. Joblet parses the runtime specification:**

- Runtime name: `python-3.11-ml`
- Version: `latest` (default, since you didn't specify `@version`)

**3. Joblet creates an isolated environment:**

- New Linux namespace (like a lightweight container)
- Isolated filesystem (chroot)
- Job process becomes PID 1 in this namespace

**4. Joblet finds the runtime:**

```bash
# Searches in /opt/joblet/runtimes/
# Finds: /opt/joblet/runtimes/python-3.11-ml-1.3.2/
```

**5. Joblet reads `runtime.yml` configuration:**

```yaml
name: python-3.11-ml
mounts:
  - source: "isolated/usr/bin"
    target: "/usr/bin"
    readonly: true
  - source: "isolated/usr/lib"
    target: "/usr/lib"
    readonly: true
environment:
  PYTHONPATH: "/usr/local/lib/python3.11/site-packages"
```

**6. Joblet mounts the runtime directories:**

```bash
# Read-only bind mounts:
mount --bind /opt/joblet/runtimes/python-3.11-ml-1.3.2/isolated/usr/bin /job/chroot/usr/bin
mount --bind /opt/joblet/runtimes/python-3.11-ml-1.3.2/isolated/usr/lib /job/chroot/usr/lib
# ... more mounts ...

# Remount as read-only:
mount -o remount,ro /job/chroot/usr/bin
```

**7. Your job runs:**

```python
# analyze.py
import numpy as np  # ✅ Works! NumPy is in the runtime
import pandas as pd  # ✅ Works! Pandas is in the runtime

data = np.array([1, 2, 3])
print(data.mean())
```

The job has access to all packages in the runtime, but:

- ❌ Cannot install new packages (read-only)
- ❌ Cannot modify existing packages
- ❌ Cannot affect the host system

---

## 🔬 Runtime Anatomy

### 📁 Directory Structure

A runtime on disk looks like this:

```
/opt/joblet/runtimes/python-3.11-ml-1.3.2/
├── runtime.yml           # Configuration file (tells Joblet what to mount)
└── isolated/            # Complete isolated filesystem
    ├── bin/             # System binaries (bash, sh, ls, cat)
    ├── lib/             # System libraries (libc, libssl, etc.)
    ├── lib64/           # 64-bit libraries (dynamic linker)
    ├── usr/
    │   ├── bin/         # User binaries (python3, pip)
    │   ├── lib/         # User libraries
    │   └── local/
    │       └── lib/
    │           └── python3.11/
    │               └── dist-packages/  # Python packages
    │                   ├── numpy/
    │                   ├── pandas/
    │                   ├── sklearn/
    │                   └── ... more packages
    ├── etc/             # Configuration files (passwd, group)
    └── tmp/             # Temporary directory (writable)
```

### The `runtime.yml` Configuration

This file tells Joblet how to set up the runtime environment:

```yaml
# Runtime identification
name: python-3.11-ml
version: 3.11
description: Python 3.11 with ML packages (NumPy, Pandas, Scikit-learn)

# Mount specifications - where to mount directories
mounts:
  # System directories
  - source: "isolated/bin"      # Relative to runtime directory
    target: "/bin"              # Where to mount in job's filesystem
    readonly: true              # Cannot be modified

  - source: "isolated/lib"
    target: "/lib"
    readonly: true

  - source: "isolated/lib64"
    target: "/lib64"
    readonly: true

  - source: "isolated/usr"
    target: "/usr"
    readonly: true

  # Writable temp directory
  - source: "isolated/tmp"
    target: "/tmp"
    readonly: false             # Jobs can write here

# Environment variables set for every job
environment:
  PATH: "/usr/bin:/bin"
  PYTHONPATH: "/usr/local/lib/python3.11/dist-packages"
  OPENBLAS_NUM_THREADS: "1"    # Control parallelism
  OMP_NUM_THREADS: "1"
```

### What's Inside the `isolated/` Directory?

**System Binaries (`bin/`, `usr/bin/`):**

```bash
bash, sh, ls, cat, cp, mv, rm, mkdir, chmod, grep, sed, awk,
python3, python3.11, pip, pip3, curl, wget, tar, gzip
```

**System Libraries (`lib/`, `lib64/`, `usr/lib/`):**

```bash
libc.so.6           # C standard library
libpthread.so.0     # Threading
libssl.so.3         # SSL/TLS
libcrypto.so.3      # Cryptography
libz.so.1           # Compression
libffi.so.8         # Foreign function interface
ld-linux-x86-64.so.2  # Dynamic linker
```

**Python Libraries (`usr/local/lib/python3.11/dist-packages/`):**

```bash
numpy/              # NumPy (arrays, linear algebra)
pandas/             # Pandas (data frames)
scikit_learn/       # Scikit-learn (ML algorithms)
matplotlib/         # Plotting
scipy/              # Scientific computing
... and all their dependencies
```

### Mount Mechanism: Read-Only Bind Mounts

Joblet uses **bind mounts** with the `MS_BIND` flag to make runtime directories visible inside the job's filesystem:

```go
// From joblet source code
syscall.Mount(sourcePath, targetPath, "", syscall.MS_BIND, "")

// Then remount as read-only
syscall.Mount("", targetPath, "",
syscall.MS_BIND|syscall.MS_REMOUNT|syscall.MS_RDONLY, "")
```

**Why read-only?**

- Prevents jobs from tampering with the runtime
- Ensures runtime stays pristine for the next job
- Protects against accidental corruption
- Multiple jobs can safely share the same runtime

---

## 🌐 The Registry System

### 📚 What Is the Registry?

The **registry** is a central catalog of available runtimes, similar to:

- **npm registry** - for JavaScript packages
- **PyPI** - for Python packages
- **Docker Hub** - for container images

The registry tells Joblet:

- What runtimes exist
- What versions are available
- Where to download them
- How to verify them (checksums)

### Registry Format

The registry is a JSON file (`registry.json`):

```json
{
  "version": "1",
  "updated_at": "2025-10-20T23:56:08Z",
  "runtimes": {
    "python-3.11-ml": {
      "1.3.1": {
        "version": "1.3.1",
        "description": "Python 3.11 with ML libraries",
        "download_url": "https://github.com/.../python-3.11-ml-1.3.1.tar.gz",
        "checksum": "sha256:f103aa0240d853250354b6501f7c83e31e...",
        "size": 12604,
        "platforms": [
          "ubuntu-amd64",
          "ubuntu-arm64"
        ]
      },
      "1.3.2": {
        "version": "1.3.2",
        "description": "Python 3.11 with ML libraries",
        "download_url": "https://github.com/.../python-3.11-ml-1.3.2.tar.gz",
        "checksum": "sha256:a2b4c6d8e9f0a1b2c3d4e5f6a7b8c9d0e1...",
        "size": 12705,
        "platforms": [
          "ubuntu-amd64",
          "ubuntu-arm64"
        ]
      }
    },
    "python-3.11-pytorch-cuda": {
      "1.3.1": {
        "version": "1.3.1",
        "description": "PyTorch 2.1.0 + CUDA 11.8",
        "download_url": "https://github.com/.../python-3.11-pytorch-cuda-1.3.1.tar.gz",
        "checksum": "sha256:14c071b935baf91764a8080c8c9a42f8b29...",
        "size": 8857,
        "platforms": [
          "ubuntu-amd64"
        ]
      }
    }
  }
}
```

### How the Registry Works

**1. Installation Request:**

```bash
rnx runtime install python-3.11-ml@1.3.2
```

**2. Fetch Registry:**

```bash
# Default registry: https://github.com/ehsaniara/joblet-runtimes
# Fetch: https://raw.githubusercontent.com/ehsaniara/joblet-runtimes/main/registry.json
```

**3. Version Resolution:**

```javascript
// Find the runtime
registry.runtimes["python-3.11-ml"]

// Get specific version (or latest if not specified)
const entry = registry.runtimes["python-3.11-ml"]["1.3.2"]
```

**4. Download Package:**

```bash
# Download from entry.download_url
curl -L https://github.com/.../python-3.11-ml-1.3.2.tar.gz -o /tmp/python-3.11-ml.tar.gz
```

**5. Verify Checksum:**

```bash
# Calculate SHA256
sha256sum /tmp/python-3.11-ml.tar.gz

# Compare with entry.checksum
# If mismatch → abort! (corrupted download or security issue)
```

**6. Extract to Runtime Directory:**

```bash
# Extract to /opt/joblet/runtimes/python-3.11-ml-1.3.2/
tar -xzf /tmp/python-3.11-ml.tar.gz -C /opt/joblet/runtimes/
```

**7. Verify Installation:**

```bash
# Check runtime.yml exists
ls /opt/joblet/runtimes/python-3.11-ml-1.3.2/runtime.yml

# Runtime is ready! ✅
```

### Registry Caching

The registry is cached for **1 hour** to avoid repeated downloads:

```go
const DefaultCacheTTL = 1 * time.Hour

// First request: fetch from GitHub
// Next requests (within 1 hour): use cached copy
```

### Custom Registries

You can use your own private runtime registry:

```bash
# Install from custom registry
rnx runtime install my-custom-runtime --registry=mycompany/joblet-runtimes

# Or set default registry in config
~/.rnx/config.yaml:
  runtimes:
    registries:
      - name: company
        url: https://github.com/mycompany/joblet-runtimes
        enabled: true
```

---

## 🔢 Version Management

### 📌 The `@` Notation (npm-style)

Joblet uses `@` to separate runtime name from version:

```bash
runtime-name@version

# Examples:
python-3.11-ml@1.3.2
openjdk-21@2.0.0
graalvmjdk-21@1.0.0
```

### Semantic Versioning

All runtime versions follow [Semantic Versioning 2.0.0](https://semver.org/):

**Format:** `MAJOR.MINOR.PATCH`

```
1.3.2
│ │ │
│ │ └─ PATCH: Bug fixes, minor improvements
│ └─── MINOR: New features, backwards compatible
└───── MAJOR: Breaking changes
```

**Version Comparison:**

```bash
# Joblet uses proper semantic version comparison
1.10.0 > 1.9.0   # Not string comparison (1.9.0 would be "greater" as string)
1.3.2 > 1.3.1    # Patch increment
1.4.0 > 1.3.9    # Minor increment
2.0.0 > 1.99.99  # Major increment
```

### Using `@latest`

When you don't specify a version, Joblet uses `@latest`:

```bash
# These are equivalent:
rnx runtime install python-3.11-ml
rnx runtime install python-3.11-ml@latest

# Joblet finds the highest version:
# Available: 1.3.1, 1.3.2, 1.4.0
# Installs: 1.4.0 (highest)
```

### Multiple Versions Can Coexist

```bash
# Install multiple versions
rnx runtime install python-3.11-ml@1.3.1
rnx runtime install python-3.11-ml@1.3.2

# Directory structure:
/opt/joblet/runtimes/
├── python-3.11-ml-1.3.1/
│   └── runtime.yml
└── python-3.11-ml-1.3.2/
    └── runtime.yml

# Use different versions for different jobs:
rnx job run --runtime=python-3.11-ml@1.3.1 python legacy.py
rnx job run --runtime=python-3.11-ml@1.3.2 python new_code.py
```

### Version Resolution at Runtime

When you run a job without specifying `@version`:

```bash
rnx job run --runtime=python-3.11-ml python script.py
```

Joblet uses the **latest installed version**:

1. Scans `/opt/joblet/runtimes/`
2. Finds all `python-3.11-ml-*` directories
3. Parses versions: 1.3.1, 1.3.2, 1.4.0
4. Picks highest: 1.4.0
5. Uses `/opt/joblet/runtimes/python-3.11-ml-1.4.0/`

---

## 💡 Real-World Examples

### 🤖 Example 1: ML Training Pipeline

**Scenario:** You need to train models with different PyTorch versions.

```bash
# Install runtimes
rnx runtime install python-3.11-pytorch-cuda@2.1.0
rnx runtime install python-3.11-pytorch-cuda@1.13.0

# Train with PyTorch 2.1 (latest model)
rnx job run \
  --runtime=python-3.11-pytorch-cuda@2.1.0 \
  --gpu=1 \
  --memory=8192 \
  python train_model_v2.py

# Evaluate with PyTorch 1.13 (legacy model)
rnx job run \
  --runtime=python-3.11-pytorch-cuda@1.13.0 \
  --gpu=1 \
  python evaluate_legacy_model.py
```

No conflicts! Each job gets exactly the PyTorch version it needs.

### 📊 Example 2: Data Processing Pipeline

**Scenario:** Different stages need different tools.

```bash
# Stage 1: Data extraction (Python + Pandas)
rnx job run \
  --runtime=python-3.11-ml \
  --upload=raw_data.csv \
  python extract.py > extracted.json

# Stage 2: Data transformation (Java processing)
rnx job run \
  --runtime=openjdk-21 \
  --upload=extracted.json \
  java -jar transformer.jar > transformed.json

# Stage 3: Analysis (Python + NumPy/SciPy)
rnx job run \
  --runtime=python-3.11-ml \
  --upload=transformed.json \
  python analyze.py > results.txt
```

Each stage uses the appropriate runtime, no dependency conflicts.

### 🔬 Example 3: Reproducible Research

**Scenario:** You published a paper 6 months ago and need to reproduce results.

```bash
# Original paper used python-3.11-ml@1.0.0
# You still have it installed, even though @latest is now 1.3.2

# Reproduce exact results
rnx job run \
  --runtime=python-3.11-ml@1.0.0 \
  python paper_analysis.py

# Output matches exactly! ✅
```

Perfect reproducibility because the runtime is **frozen** at the version you used.

### 🚀 Example 4: Development vs Production

**Scenario:** Test new libraries without affecting production.

```bash
# Production uses stable version
rnx job run \
  --runtime=python-3.11-ml@1.3.1 \
  python production_pipeline.py

# Development uses cutting-edge version
rnx job run \
  --runtime=python-3.11-ml@1.4.0-beta \
  python experimental_pipeline.py
```

Test safely without risking production workloads.

---

## 📝 Summary

### 🎓 Key Takeaways

1. **Runtimes are isolated environments** containing languages, libraries, and tools
2. **Zero contamination** - jobs can't affect host system or each other
3. **Versioned like npm packages** - use `@` notation for specific versions
4. **Registry-based** - central catalog with checksums for security
5. **Read-only mounts** - runtime stays pristine, multiple jobs can share
6. **Reproducible** - same runtime version = same results, always

### Quick Reference

```bash
# List available runtimes
rnx runtime list

# Install latest version
rnx runtime install python-3.11-ml

# Install specific version
rnx runtime install python-3.11-ml@1.3.2

# Run job with runtime
rnx job run --runtime=python-3.11-ml python script.py

# Run job with specific version
rnx job run --runtime=python-3.11-ml@1.3.1 python script.py
```

### 🚀 Next Steps

- **Creating Runtimes:** See [CREATING_RUNTIMES.md](CREATING_RUNTIMES.md)
- **Releasing Runtimes:** See [RELEASING.md](RELEASING.md)
- **Main Joblet Docs:** https://github.com/ehsaniara/joblet
