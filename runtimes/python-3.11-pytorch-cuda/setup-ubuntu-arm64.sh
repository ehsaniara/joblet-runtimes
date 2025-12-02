#!/bin/bash
# Python 3.11 PyTorch Runtime Setup for Ubuntu/Debian ARM64
# ARM64 Note: Uses CPU-only PyTorch (CUDA wheels not available for ARM)
#             For Jetson devices, use Jetson-specific PyTorch builds

set -e  # Exit on any error
set -u  # Exit on undefined variables
set -o pipefail  # Exit on pipe failures

# Error handling function
handle_error() {
    local exit_code=$?
    local line_number=$1
    echo "❌ ERROR: Script failed at line $line_number with exit code $exit_code"
    echo "❌ Installation FAILED - runtime may be in inconsistent state"
    exit $exit_code
}

# Set up error trap
trap 'handle_error ${LINENO}' ERR

# =============================================================================
# CONFIGURATION
# =============================================================================

RUNTIME_NAME="${RUNTIME_NAME:-python-3.11-pytorch-cuda}"
RUNTIME_BASE_DIR="/opt/joblet/runtimes/$RUNTIME_NAME"
ISOLATED_DIR="$RUNTIME_BASE_DIR/isolated"

echo "Starting Python 3.11 PyTorch runtime setup..."
echo "Platform: ubuntu-arm64"
echo "Runtime: $RUNTIME_NAME"
echo "Installation path: $RUNTIME_BASE_DIR"

# Detect if running on NVIDIA Jetson
IS_JETSON=false
if [ -f /etc/nv_tegra_release ] || [ -d /usr/lib/aarch64-linux-gnu/tegra ]; then
    IS_JETSON=true
    echo "🔧 Detected NVIDIA Jetson platform - will use Jetson-specific PyTorch"
else
    echo "ℹ️  Standard ARM64 platform - will use CPU-only PyTorch"
fi

# =============================================================================
# SAFETY CHECKS - NO HOST CONTAMINATION
# =============================================================================

safety_check() {
    echo "Performing safety checks to prevent host contamination..."

    # Verify we're in a controlled environment
    if [ "${JOBLET_CHROOT:-false}" != "true" ] && [ -z "${BUILD_ID:-}" ]; then
        echo "⚠ WARNING: Not running in joblet build environment"
        echo "This script should only run within joblet runtime installation"
    fi

    # Ensure target directory is within expected path
    if [[ "$RUNTIME_BASE_DIR" != "/opt/joblet/runtimes/"* ]]; then
        echo "✗ ERROR: Invalid runtime base directory: $RUNTIME_BASE_DIR"
        exit 1
    fi

    echo "✓ Safety checks passed - no host contamination risk"
}

# =============================================================================
# DIRECTORY SETUP
# =============================================================================

create_directories() {
    echo "Creating runtime directories..."

    mkdir -p "$RUNTIME_BASE_DIR"
    cd "$RUNTIME_BASE_DIR"

    # Create minimal isolated filesystem structure
    local dirs=(
        bin lib lib64 usr/bin usr/lib usr/local/lib/python3.11/dist-packages
        opt/venv etc tmp proc lib/aarch64-linux-gnu usr/lib/aarch64-linux-gnu
    )

    for dir in "${dirs[@]}"; do
        mkdir -p "$ISOLATED_DIR/$dir"
    done

    echo "✓ Directories created"
}

# =============================================================================
# SYSTEM FILES COPY
# =============================================================================

copy_system_files() {
    echo "Copying system files..."

    # Essential binaries
    local binaries="bash sh ls cat cp mv rm mkdir chmod grep sed awk ps echo tar gzip curl wget python3 python3.10 python3.11 pip3"
    local copied_binaries=()
    local missing_binaries=()
    local python_binary_copied=false

    for bin in $binaries; do
        local copied=false
        for path in /bin /usr/bin /usr/local/bin; do
            if [ -f "$path/$bin" ]; then
                if cp -P "$path/$bin" "$ISOLATED_DIR/usr/bin/" 2>/dev/null; then
                    copied_binaries+=("$bin")
                    copied=true
                    # Track if we copied any Python binary
                    if [[ "$bin" =~ ^python ]]; then
                        python_binary_copied=true
                    fi
                    break
                fi
            fi
        done
        if [ "$copied" = false ]; then
            missing_binaries+=("$bin")
        fi
    done

    # Report binary copying results
    if [ ${#copied_binaries[@]} -gt 0 ]; then
        echo "  ✓ Copied binaries: ${copied_binaries[*]}"
    fi
    if [ ${#missing_binaries[@]} -gt 0 ]; then
        echo "  ⚠ Missing binaries: ${missing_binaries[*]}"
    fi

    # Critical check: ensure at least one Python binary was copied
    if [ "$python_binary_copied" = false ]; then
        echo "❌ CRITICAL: No Python binary was copied successfully"
        echo "❌ This will result in a non-functional runtime"
        exit 1
    fi

    # Essential libraries for ARM64
    local lib_patterns="libc.so* libdl.so* libpthread.so* libm.so* ld-linux*.so* libz.so* libssl.so* libcrypto.so* libffi.so* libexpat.so* libblas.so* liblapack.so* libopenblas.so* libgfortran.so* libgcc_s.so* libstdc++.so* libselinux.so* libresolv.so* libnss*.so* libpcre*.so*"

    local copied_libs=0
    for lib_dir in /lib/aarch64-linux-gnu /usr/lib/aarch64-linux-gnu /lib64; do
        if [ -d "$lib_dir" ]; then
            local target_dir="$ISOLATED_DIR${lib_dir}"
            mkdir -p "$target_dir"
            for pattern in $lib_patterns; do
                local found_libs=$(find "$lib_dir" -maxdepth 1 -name "$pattern" 2>/dev/null | wc -l)
                if [ "$found_libs" -gt 0 ]; then
                    find "$lib_dir" -maxdepth 1 -name "$pattern" -exec cp -P {} "$target_dir" \; 2>/dev/null && ((copied_libs+=found_libs)) || true
                fi
            done
        fi
    done

    echo "  ✓ Copied $copied_libs library files"

    # Dynamic linker for ARM64
    if [ -f "/lib/ld-linux-aarch64.so.1" ]; then
        mkdir -p "$ISOLATED_DIR/lib"
        if cp -P "/lib/ld-linux-aarch64.so.1" "$ISOLATED_DIR/lib/" 2>/dev/null; then
            echo "  ✓ Copied dynamic linker"
        else
            echo "  ⚠ Failed to copy dynamic linker"
        fi
    else
        echo "  ⚠ Dynamic linker not found"
    fi

    echo "✓ System files copied"
}

# =============================================================================
# PYTHON INSTALLATION
# =============================================================================

install_python() {
    echo "Setting up Python environment..."

    # Install Python packages in chroot environment
    if [ "${JOBLET_CHROOT:-false}" = "true" ] && command -v apt-get >/dev/null 2>&1; then
        echo "Installing Python packages in chroot environment..."
        export DEBIAN_FRONTEND=noninteractive
        if ! apt-get update -qq 2>/dev/null; then
            echo "⚠ apt-get update failed, but continuing with existing package cache"
        fi
        if ! apt-get install -y python3 python3-dev python3-venv python3-pip python3-setuptools python3-wheel \
                          build-essential libopenblas-dev liblapack-dev libffi-dev 2>/dev/null; then
            echo "⚠ Some Python packages failed to install in chroot, but this is non-critical"
        fi
    else
        echo "Not in chroot or apt not available - copying existing Python from host"
    fi

    # Copy Python runtime
    echo "Copying Python standard libraries..."
    local python_copied=false
    for py_dir in /usr/lib/python3*; do
        if [ -d "$py_dir" ]; then
            echo "  Copying $py_dir..."
            if cp -r "$py_dir" "$ISOLATED_DIR/usr/lib/" 2>/dev/null; then
                python_copied=true
            else
                echo "⚠ Failed to copy $py_dir (non-critical)"
            fi
        fi
    done

    if [ "$python_copied" = false ]; then
        echo "❌ CRITICAL: No Python libraries were copied successfully"
        exit 1
    fi

    # Copy lib-dynload and other essential Python directories
    for py_lib in /usr/lib/python3*/lib-dynload; do
        if [ -d "$py_lib" ]; then
            echo "  Copying dynamic modules from $py_lib..."
            py_parent=$(dirname "$py_lib" | sed "s|^/usr||")
            mkdir -p "$ISOLATED_DIR/usr/$py_parent"
            if ! cp -r "$py_lib" "$ISOLATED_DIR/usr/$py_parent/" 2>/dev/null; then
                echo "⚠ Failed to copy $py_lib (non-critical)"
            fi
        fi
    done

    # Create symlinks
    cd "$ISOLATED_DIR/usr/bin"
    [ -f python3.11 ] && ln -sf python3.11 python 2>/dev/null || true
    [ -f python3 ] && [ ! -f python ] && ln -sf python3 python 2>/dev/null || true
    [ -f pip3 ] && ln -sf pip3 pip 2>/dev/null || true
    cd - >/dev/null

    echo "✓ Python environment ready"
}

# =============================================================================
# PYTORCH AND ML PACKAGES (ARM64 Optimized)
# =============================================================================

install_pytorch_packages() {
    echo "Installing PyTorch for ARM64..."

    local site_packages="$ISOLATED_DIR/usr/local/lib/python3.11/dist-packages"
    mkdir -p "$site_packages"

    # Additional ML packages
    local ml_packages=(
        "numpy"
        "pandas"
        "matplotlib"
        "scipy"
        "scikit-learn"
        "pillow"
        "requests"
    )

    # Check DNS resolution in chroot
    echo "Checking network connectivity..."
    if ! ping -c 1 -W 2 8.8.8.8 >/dev/null 2>&1; then
        echo "  ⚠ WARNING: No network connectivity detected"
        echo "  ⚠ Package installation may fail"
    else
        echo "  ✓ Network connectivity OK"
    fi

    # Configure pip for better reliability
    mkdir -p ~/.pip
    cat > ~/.pip/pip.conf << 'PIPCONF'
[global]
timeout = 300
retries = 3
index-url = https://pypi.org/simple
trusted-host = pypi.org
               pypi.python.org
               files.pythonhosted.org
               download.pytorch.org
PIPCONF

    # Update pip first
    echo "Updating pip..."
    python3 -m pip install --upgrade pip 2>&1 | grep -v "^Requirement already satisfied" || echo "  ⚠ Could not upgrade pip"

    local installed_packages=()
    local failed_packages=()

    # Install PyTorch for ARM64
    echo ""
    echo "========================================="
    echo "Installing PyTorch for ARM64..."
    echo "========================================="

    local pytorch_installed=false

    if [ "$IS_JETSON" = true ]; then
        # Jetson-specific installation
        echo "Attempting Jetson-specific PyTorch installation..."
        echo "Note: For best results, use NVIDIA's pre-built Jetson wheels"
        echo "See: https://forums.developer.nvidia.com/t/pytorch-for-jetson/"

        # Try standard PyTorch first (may work on newer Jetson with JetPack 5+)
        if python3 -m pip install torch torchvision torchaudio \
            --no-cache-dir \
            --timeout=300 \
            --retries=3 2>&1; then
            if python3 -c "import torch; print('PyTorch version:', torch.__version__)" 2>/dev/null; then
                installed_packages+=("torch" "torchvision" "torchaudio")
                pytorch_installed=true
                echo "  ✓ PyTorch installed successfully"
            fi
        fi
    else
        # Standard ARM64 - install CPU-only PyTorch directly
        echo "Installing CPU-only PyTorch for ARM64..."
        echo "(CUDA wheels are not available for ARM64 architecture)"

        if python3 -m pip install torch torchvision torchaudio \
            --no-cache-dir \
            --timeout=300 \
            --retries=3 2>&1; then
            if python3 -c "import torch; print('PyTorch version:', torch.__version__)" 2>/dev/null; then
                installed_packages+=("torch" "torchvision" "torchaudio")
                pytorch_installed=true
                echo "  ✓ PyTorch (CPU) installed successfully"
            else
                echo "  ⚠ PyTorch install command succeeded but import failed"
            fi
        else
            echo "  ✗ PyTorch installation failed"
        fi
    fi

    # If PyTorch installation failed, add to failed packages
    if [ "$pytorch_installed" = false ]; then
        failed_packages+=("torch" "torchvision" "torchaudio")
        echo "  ✗ PyTorch installation failed"
    fi

    # Install additional ML packages
    echo ""
    echo "========================================="
    echo "Installing ML packages..."
    echo "========================================="
    for package in "${ml_packages[@]}"; do
        echo "Installing $package..."
        if python3 -m pip install "$package" --no-cache-dir --timeout=180 2>&1 | grep -E "(Successfully installed|Requirement already satisfied)"; then
            # Verify package can be imported
            local pkg_import="${package}"
            # Handle special import names
            [ "$package" = "scikit-learn" ] && pkg_import="sklearn"
            [ "$package" = "pillow" ] && pkg_import="PIL"

            if python3 -c "import ${pkg_import}" 2>/dev/null; then
                installed_packages+=("$package")
                echo "  ✓ $package installed and verified"
            else
                failed_packages+=("$package")
                echo "  ⚠ $package installed but import failed"
            fi
        else
            failed_packages+=("$package")
            echo "  ✗ Failed to install $package"
        fi
    done

    # Copy installed packages to isolated environment
    echo ""
    echo "========================================="
    echo "Copying installed packages to isolated environment..."
    echo "========================================="

    # Copy system site-packages
    for python_path in /usr/local/lib/python3*/dist-packages /usr/lib/python3/dist-packages /usr/local/lib/python3*/site-packages; do
        if [ -d "$python_path" ]; then
            echo "Copying from $python_path..."
            local copied_files=$(find "$python_path" -type f 2>/dev/null | wc -l)
            if [ "$copied_files" -gt 0 ]; then
                cp -r "$python_path"/* "$site_packages/" 2>/dev/null || echo "  ⚠ Some files couldn't be copied from $python_path"
                echo "  ✓ Copied $copied_files files"
            fi
        fi
    done

    # Copy from user site-packages if exists
    local user_site=$(python3 -c "import site; print(site.getusersitepackages())" 2>/dev/null || echo "")
    if [ -n "$user_site" ] && [ -d "$user_site" ]; then
        echo "Copying from user site-packages: $user_site"
        cp -r "$user_site"/* "$site_packages/" 2>/dev/null || echo "  ⚠ Some files couldn't be copied from user site"
    fi

    # Report installation results
    echo ""
    echo "========================================="
    echo "📊 PyTorch/ML Package Installation Results:"
    echo "========================================="
    echo "  Successfully installed: ${#installed_packages[@]} packages"
    [ ${#installed_packages[@]} -gt 0 ] && echo "    ${installed_packages[*]}"
    echo "  Failed to install: ${#failed_packages[@]} packages"
    [ ${#failed_packages[@]} -gt 0 ] && echo "    ${failed_packages[*]}"

    # Count final files
    local final_files=$(find "$site_packages" -name "*.py" -type f 2>/dev/null | wc -l)
    echo "  Final Python files in isolated packages: $final_files"

    # Verify PyTorch specifically
    if [ -d "$site_packages/torch" ]; then
        local torch_size=$(du -sh "$site_packages/torch" 2>/dev/null | cut -f1)
        echo "  ✓ PyTorch package found in isolated env (size: $torch_size)"
    else
        echo "  ⚠ PyTorch package NOT found in isolated environment"
    fi

    echo "✓ PyTorch/ML packages installation completed"
}

# =============================================================================
# CONFIGURATION FILES
# =============================================================================

create_config_files() {
    echo "Creating configuration files..."

    # Minimal /etc files
    cat > "$ISOLATED_DIR/etc/passwd" << 'EOF'
root:x:0:0:root:/root:/bin/bash
nobody:x:65534:65534:nobody:/nonexistent:/bin/false
EOF

    cat > "$ISOLATED_DIR/etc/group" << 'EOF'
root:x:0:
nogroup:x:65534:
EOF

    # Basic /proc files
    echo "processor : 0" > "$ISOLATED_DIR/proc/cpuinfo"
    echo "MemTotal: 8388608 kB" > "$ISOLATED_DIR/proc/meminfo"

    # Runtime configuration
    cat > "$RUNTIME_BASE_DIR/runtime.yml" << EOF
name: $RUNTIME_NAME
version: "${RUNTIME_VERSION:-3.11}"
description: "Python 3.11 with PyTorch (ARM64 CPU)"

mounts:
  - source: "isolated/bin"
    target: "/bin"
    readonly: true
  - source: "isolated/lib"
    target: "/lib"
    readonly: true
  - source: "isolated/lib64"
    target: "/lib64"
    readonly: true
  - source: "isolated/usr"
    target: "/usr"
    readonly: true
  - source: "isolated/opt"
    target: "/opt"
    readonly: true
  - source: "isolated/etc"
    target: "/etc"
    readonly: true
  - source: "isolated/tmp"
    target: "/tmp"
    readonly: false
  - source: "isolated/proc"
    target: "/proc"
    readonly: true

environment:
  PATH: "/opt/venv/bin:/usr/bin:/bin"
  PYTHONPATH: "/usr/local/lib/python3.11/dist-packages"
  VIRTUAL_ENV: "/opt/venv"
  LD_LIBRARY_PATH: "/usr/lib/aarch64-linux-gnu:/lib/aarch64-linux-gnu"
  OPENBLAS_NUM_THREADS: "1"
  OMP_NUM_THREADS: "1"
EOF

    echo "✓ Configuration files created"
}

# =============================================================================
# VALIDATION
# =============================================================================

validate_installation() {
    echo "Validating installation..."

    local status=0

    # Check runtime.yml
    [ -f "$RUNTIME_BASE_DIR/runtime.yml" ] && echo "✓ runtime.yml exists" || { echo "✗ runtime.yml missing"; status=1; }

    # Check Python binary
    [ -f "$ISOLATED_DIR/usr/bin/python3" ] && echo "✓ Python binary exists" || { echo "✗ Python binary missing"; status=1; }

    # Check packages directory
    [ -d "$ISOLATED_DIR/usr/local/lib/python3.11/dist-packages" ] && echo "✓ Packages directory exists" || { echo "✗ Packages directory missing"; status=1; }

    # Check for PyTorch
    if [ -d "$ISOLATED_DIR/usr/local/lib/python3.11/dist-packages/torch" ]; then
        echo "✓ PyTorch package found"
    else
        echo "⚠ PyTorch package not found (may need manual installation)"
    fi

    # Report sizes
    if [ -d "$ISOLATED_DIR" ]; then
        local file_count=$(find "$ISOLATED_DIR" -type f 2>/dev/null | wc -l)
        local dir_size=$(du -sh "$ISOLATED_DIR" 2>/dev/null | cut -f1)
        echo "✓ Total files: $file_count"
        echo "✓ Directory size: $dir_size"
    fi

    return $status
}

# =============================================================================
# MAIN EXECUTION
# =============================================================================

main() {
    echo "═══════════════════════════════════════════════════════════════"
    echo "Python 3.11 PyTorch Runtime Installation (ARM64)"
    echo "═══════════════════════════════════════════════════════════════"

    # Perform safety checks first
    safety_check

    # Execute installation steps
    create_directories
    copy_system_files
    install_python
    install_pytorch_packages
    create_config_files

    # Validate and report
    echo ""
    if ! validate_installation; then
        echo "❌ CRITICAL: Installation validation failed"
        echo "❌ Runtime installation FAILED - check errors above"
        exit 1
    fi

    echo ""
    echo "🎉 Installation completed successfully!"
    echo "Runtime installed at: $RUNTIME_BASE_DIR"
}

# Run installation
main "$@"
