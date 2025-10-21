# Joblet Runtimes Documentation

Welcome to the Joblet Runtimes documentation! This directory contains everything you need to understand, create, and
release runtimes for Joblet.

## 📚 Documentation Index

### For Users

**[RUNTIME_OVERVIEW.md](RUNTIME_OVERVIEW.md)** - Start here!

- What are runtimes and why they matter
- How runtimes work under the hood
- The registry system explained
- Version management and the `@` notation
- Real-world examples

**Quick read time:** 20-30 minutes

---

### For Runtime Developers

**[CREATING_RUNTIMES.md](CREATING_RUNTIMES.md)** - Step-by-step guide

- Planning your runtime
- Creating manifest.yaml
- Writing setup scripts
- Testing locally
- Adding to the repository
- Advanced topics (GPU, multi-platform, large dependencies)

**Estimated completion time:** 1-5 hours (depending on complexity)

**[RELEASING.md](RELEASING.md)** - Release management

- Naming conventions (must read!)
- Individual runtime releases (recommended)
- Bulk releases (all runtimes at once)
- Registry format explained
- Troubleshooting common issues

**Quick reference time:** 10 minutes

---

## 🚀 Quick Start

### I want to... use runtimes

```bash
# List available runtimes
rnx runtime list

# Install a runtime
rnx runtime install python-3.11-ml

# Install specific version
rnx runtime install python-3.11-ml@1.3.2

# Run a job
rnx job run --runtime=python-3.11-ml python script.py
```

**Learn more:** [RUNTIME_OVERVIEW.md](RUNTIME_OVERVIEW.md)

---

### I want to... create a new runtime

1. **Plan what to include** (language, packages, tools)
   ```bash
   # Example: Node.js 18 with Express
   Language: Node.js 18
   Packages: express, axios, lodash
   ```

2. **Create runtime directory**
   ```bash
   mkdir -p runtimes/node-18
   cd runtimes/node-18
   ```

3. **Write manifest.yaml**
   ```yaml
   name: node-18
   version: 1.0.0
   description: Node.js 18 with common packages
   platforms:
     - ubuntu-amd64
   packages:
     - express@4.18.0
     - axios@1.6.0
   ```

4. **Create setup scripts**
    - `setup.sh` (dispatcher)
    - `setup-ubuntu-amd64.sh` (installer)

5. **Test locally**
   ```bash
   sudo RUNTIME_NAME=node-18 bash setup.sh
   ```

6. **Release**
   ```bash
   git add runtimes/node-18
   git commit -m "Add node-18 runtime"
   git push origin main
   ./scripts/release-runtime.sh node-18
   ```

**Full guide:** [CREATING_RUNTIMES.md](CREATING_RUNTIMES.md)

---

### I want to... release a runtime

**Individual runtime release (recommended):**

```bash
# 1. Update manifest version
vim runtimes/python-3.11-ml/manifest.yaml
# Change: version: 1.3.3

# 2. Commit changes
git add runtimes/python-3.11-ml
git commit -m "Update python-3.11-ml to 1.3.3"
git push origin main

# 3. Release using helper script
./scripts/release-runtime.sh python-3.11-ml

# That's it! GitHub Actions handles the rest.
```

**Bulk release (all runtimes):**

```bash
# Tag with version
git tag -a v1.4.0 -m "Release all runtimes at 1.4.0"
git push origin v1.4.0
```

**Full guide:** [RELEASING.md](RELEASING.md)

---

## 🎓 Learning Path

**Brand new to Joblet runtimes?**

1. Read [RUNTIME_OVERVIEW.md](RUNTIME_OVERVIEW.md) (30 min)
    - Understand what runtimes are
    - See how they work
    - Learn the registry system

2. Try using a runtime
   ```bash
   rnx runtime install python-3.11-ml
   rnx job run --runtime=python-3.11-ml python -c "import numpy; print(numpy.__version__)"
   ```

3. Examine existing runtimes
   ```bash
   cd runtimes/python-3.11-ml
   cat manifest.yaml
   cat setup-ubuntu-amd64.sh
   ```

4. Create your first runtime following [CREATING_RUNTIMES.md](CREATING_RUNTIMES.md) (2-3 hours)

5. Release it following [RELEASING.md](RELEASING.md) (15 min)

---

## 📖 Concepts Explained

### What is a Runtime?

A runtime is a **complete, isolated environment** containing:

- Programming language (Python, Java, Node.js)
- Libraries and packages (NumPy, Spring Boot, Express)
- System tools (bash, curl, grep)
- Dependencies (OpenSSL, CUDA)

**Key characteristics:**

- ✅ Isolated (no host contamination)
- ✅ Versioned (like npm packages: `name@version`)
- ✅ Reproducible (same runtime = same results)
- ✅ Read-only (multiple jobs can share safely)

### How Do Runtimes Work?

```
1. User runs job with runtime
   ↓
2. Joblet creates isolated namespace
   ↓
3. Finds runtime directory (/opt/joblet/runtimes/)
   ↓
4. Loads runtime.yml configuration
   ↓
5. Mounts runtime directories (read-only bind mounts)
   ↓
6. Sets environment variables
   ↓
7. Job executes with access to runtime packages
```

### What is the Registry?

The **registry** is a central catalog (JSON file) that tells Joblet:

- What runtimes exist
- What versions are available
- Where to download them
- How to verify them (SHA256 checksums)

Similar to:

- npm registry (for JavaScript)
- PyPI (for Python)
- Docker Hub (for containers)

### Version Management (`@` notation)

Joblet uses npm-style versioning:

```bash
# Format: runtime-name@version
python-3.11-ml@1.3.2
openjdk-21@2.0.0

# Without version = @latest
python-3.11-ml          # Same as python-3.11-ml@latest

# Semantic versioning: MAJOR.MINOR.PATCH
1.3.2
│ │ │
│ │ └─ Patch: bug fixes
│ └─── Minor: new features
└───── Major: breaking changes
```

---

## 🗂️ Repository Structure

```
joblet-runtimes/
├── docs/                          # 📚 You are here
│   ├── README.md                  # This file
│   ├── RUNTIME_OVERVIEW.md        # How runtimes work
│   ├── CREATING_RUNTIMES.md       # How to create runtimes
│   └── RELEASING.md               # How to release runtimes
│
├── runtimes/                      # 🎯 Runtime definitions
│   ├── python-3.11/               # Basic Python
│   ├── python-3.11-ml/            # Python + ML packages
│   ├── python-3.11-pytorch-cuda/  # Python + PyTorch + CUDA
│   ├── openjdk-21/                # OpenJDK 21
│   └── graalvmjdk-21/             # GraalVM
│
├── scripts/                       # 🛠️ Helper scripts
│   ├── release-runtime.sh         # Release individual runtime
│   └── validate-runtimes.sh       # Validate naming conventions
│
├── .github/workflows/             # ⚙️ CI/CD automation
│   ├── release-runtime.yml        # Individual runtime release
│   └── release.yml                # Bulk release (all runtimes)
│
├── registry.json                  # 📦 Auto-generated registry catalog
├── README.md                      # Project overview
└── LICENSE                        # MIT license
```

---

## 🎯 Common Tasks

### Check if runtime naming is valid

```bash
./scripts/validate-runtimes.sh python-3.11-ml

# Output:
# Checking: python-3.11-ml
#   ✓ Runtime name valid: python-3.11-ml
#   ✓ Version format valid: 1.3.2
#   ✓ Found 6 setup script(s)
```

### See what's in a runtime

```bash
# Read manifest
cat runtimes/python-3.11-ml/manifest.yaml

# Check setup script
cat runtimes/python-3.11-ml/setup-ubuntu-amd64.sh

# See actual installed files (if installed locally)
ls -la /opt/joblet/runtimes/python-3.11-ml/isolated/
```

### Test runtime without releasing

```bash
# Build locally
cd runtimes/python-3.11-ml
sudo RUNTIME_NAME=python-3.11-ml bash setup.sh

# Verify installation
ls /opt/joblet/runtimes/python-3.11-ml/

# Test with job
rnx job run --runtime=python-3.11-ml python -c "import numpy; print('OK')"
```

### Check registry for a runtime

```bash
# Pretty print registry entry
cat registry.json | jq '.runtimes["python-3.11-ml"]'

# See all versions
cat registry.json | jq '.runtimes["python-3.11-ml"] | keys'
```

### Delete a tag (if release failed)

```bash
# Delete local tag
git tag -d python-3.11-ml@1.3.2

# Delete remote tag
git push origin :refs/tags/python-3.11-ml@1.3.2

# Recreate
./scripts/release-runtime.sh python-3.11-ml
```

---

## ❓ FAQ

### Q: Can I have multiple versions of the same runtime installed?

**A:** Yes! That's the whole point.

```bash
rnx runtime install python-3.11-ml@1.3.1
rnx runtime install python-3.11-ml@1.3.2

# Both coexist:
/opt/joblet/runtimes/python-3.11-ml-1.3.1/
/opt/joblet/runtimes/python-3.11-ml-1.3.2/

# Use different versions:
rnx job run --runtime=python-3.11-ml@1.3.1 python script.py
rnx job run --runtime=python-3.11-ml@1.3.2 python script.py
```

### Q: Can jobs modify the runtime?

**A:** No. Runtimes are mounted **read-only** to ensure:

- Jobs can't contaminate the runtime
- Multiple jobs can share the same runtime safely
- Runtime stays pristine for reproducibility

### Q: What if I need to install packages at runtime?

**A:** Create a writable work directory:

```bash
# Jobs can write to /tmp (mapped from runtime)
rnx job run --runtime=python-3.11 python -c "
import os
os.mkdir('/tmp/packages')
# Use --target to install to /tmp
"
```

Or create a new runtime with those packages pre-installed.

### Q: How big are runtimes typically?

- **Basic Python**: ~50-100 MB
- **Python ML**: ~100-200 MB
- **Python PyTorch + CUDA**: ~1-2 GB
- **Java/OpenJDK**: ~100-300 MB
- **Node.js**: ~50-150 MB

### Q: Can I use private registries?

**A:** Yes!

```bash
# Install from custom registry
rnx runtime install my-runtime --registry=mycompany/joblet-runtimes

# Or configure in ~/.rnx/config.yaml
runtimes:
  registries:
    - name: company
      url: https://github.com/mycompany/joblet-runtimes
      enabled: true
```

### Q: What happens if I don't specify a version?

**A:** Joblet uses `@latest` (highest version).

```bash
# These are equivalent:
rnx runtime install python-3.11-ml
rnx runtime install python-3.11-ml@latest

# Installs highest version from registry
```

### Q: Can I create a runtime for <my favorite language>?

**A:** Absolutely! Follow [CREATING_RUNTIMES.md](CREATING_RUNTIMES.md).

Runtimes have been created for:

- Python (multiple versions)
- Java (OpenJDK, GraalVM)
- Node.js
- Go
- Rust
- R
- ... and you can add more!

---

## 🤝 Contributing

We welcome runtime contributions!

1. **Fork this repository**
2. **Create a new runtime** following [CREATING_RUNTIMES.md](CREATING_RUNTIMES.md)
3. **Test thoroughly** using the testing section
4. **Submit a pull request** with your runtime

We especially need:

- Runtimes for more languages (Go, Rust, R, Julia, etc.)
- Platform support (ARM, RHEL, Amazon Linux)
- Specialized runtimes (bioinformatics, financial modeling, etc.)

---

## 📞 Getting Help

- **Documentation Issues**: Open an issue in this repo
- **Runtime Bugs**: Open an issue with runtime name and version
- **Joblet Issues**: https://github.com/ehsaniara/joblet/issues
- **Discussions**: https://github.com/ehsaniara/joblet-runtimes/discussions

---

## 📜 License

MIT License - see [LICENSE](../LICENSE) for details

---

## 🔗 Related Projects

- **Joblet**: https://github.com/ehsaniara/joblet - The main job execution system
- **Joblet Proto**: https://github.com/ehsaniara/joblet-proto - gRPC protocol definitions

---

**Happy runtime building! 🚀**
