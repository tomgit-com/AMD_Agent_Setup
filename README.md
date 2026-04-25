# Agent Setup

Collection of utilities for system optimization and AI model management.

## 📋 Tools

### 1. Memory Optimizer

Optimizes memory allocation for AMD Ryzen AI Max+ Pro 395 (or similar APUs) by configuring TTM page pool settings.

**Main Script:** [`setup_vram_grub.sh`](setup_vram_grub.sh)

- Detects system RAM automatically from `/proc/meminfo`
- Calculates recommended VRAM ceiling (leaves 16GB for system/CPU)
- Warns if allocation exceeds 90% of total RAM
- Automatically updates GRUB configuration
- Supports multiple distributions (Debian, Ubuntu, Fedora, Arch, CachyOS, CentOS/RHEL)

**Usage:**
```bash
sudo ./setup_vram_grub.sh [target_ram_gb]
```

**Prerequisites:**
- Linux operating system
- Root access (required for GRUB modification)
- AMD GPU driver with TTM support

**Notes:**
- Always backup your GRUB config before making changes
- After modifying GRUB, the script automatically runs `update-grub` or `grub2-mkconfig`
- Allocating >90% of RAM to GPU may cause system instability or OOM kills

---

### 2. Ollama Model Manager

Interactive shell script for managing Ollama models with a menu-driven interface.

**Script:** [`manage_ollama_model.sh`](manage_ollama_model.sh)

**Features:**
- List all installed Ollama models
- Pull new models from Ollama library
- Modify existing models with custom context window and temperature
- Create new models from base models with custom parameters

**Usage:**
```bash
./manage_ollama_model.sh
```

**Menu Options:**
1. **List all models** - Shows all locally available Ollama models
2. **Pull a model** - Download a model from the Ollama library
3. **Modify existing model** - Change context window and temperature, creating a new model
4. **Create new model** - Create a completely new model from a base model
5. **Exit** - Close the application

**Context Window:**
- Default: 4096 tokens
- Common values: 2048, 4096, 8192, 16384, 32768
- Higher values allow longer context but require more VRAM

**Temperature:**
- Low (0.1-0.5): More focused and deterministic
- Medium (0.6-0.9): Balanced creativity and coherence
- High (1.0-2.0): More creative and random
- Default: 0.7

**Prerequisites:**
- Ollama installed and running
- At least one base model already pulled

**How It Works:**
Script generates a temporary Modelfile with custom parameters and runs `ollama create`:
```
FROM <base-model>
PARAMETER context_window <size>
PARAMETER temperature <value>
```

---

### 3. AMD System Tools

Comprehensive AMD Linux system management with interactive menu-driven interface for performance optimization and monitoring.

**Script:** [`amd_system_tools.sh`](amd_system_tools.sh)

**Features:**
- GPU monitoring & control (rocm-smi wrapper)
- CPU frequency scaling configuration
- Memory performance tuning (NUMA, huge pages, swappiness)
- Thermal management (fan control, temperature monitoring)
- AMDGPU driver settings

**Usage:**
```bash
./amd_system_tools.sh
```

**Menu Options:**
1. **GPU Monitoring** - VRAM usage, clocks, power, temperature, utilization
2. **CPU Frequency Scaling** - Governor management (performance/balanced/power-save)
3. **Memory Performance Tuning** - NUMA, transparent huge pages, swappiness
4. **Thermal Management** - Fan control, thermal monitoring
5. **AMDGPU Driver Settings** - Power profiles, clocks, performance levels
6. **Exit** - Close the application

**Prerequisites:**
- ROCm drivers installed (for GPU features via rocm-smi)
- Root access (for system modifications)

**Detailed Features:**

**1. GPU Monitoring:**
- VRAM memory usage breakdown (total, used, free)
- GPU and memory clock speeds
- Power draw in watts
- Temperature readings (hotspot, membrane)
- GPU utilization percentage
- Requires ROCm drivers with `rocm-smi` installed

**2. CPU Frequency Scaling:**
- View current governor and clock frequencies
- Change scaling governor:
  - **Performance**: Maximum frequency, lowest latency (best for AI workloads)
  - **Balanced (schedutil)**: Dynamic scaling, good compromise
  - **Powersave**: Minimum frequency, longest battery life
- Automatically applies to all CPU cores

**3. Memory Performance Tuning:**
- View NUMA balancing status
- Transparent huge pages (THP) management:
  - **Always**: Reduces TLB misses, better for large workloads
  - **Never**: Lower latency, better for small/random access
  - **Defer/Explicit**: Conditional huge page allocation
- Swap behavior via swappiness (0-100):
  - Lower values (10-20): Prefer RAM, reduce disk I/O
  - Higher values (60-80): More aggressive swapping

**4. Thermal Management:**
- Real-time temperature monitoring (GPU hotspot/membrane)
- Fan speed control:
  - **Manual mode**: Set fixed fan speed (e.g., 100% for max cooling)
  - **Automatic mode**: Let ROCm manage fan curve
- Power profiling with thermal data

**5. AMDGPU Driver Settings:**
- Power profile modes:
  - **Compute**: High performance for compute workloads
  - **Balanced**: Mixed usage optimizations
  - **Power saving**: Reduced power consumption
- Clock monitoring (GPU, memory, SOC)
- Performance level control

**How It Works:**
Each menu option provides:
- Current system status display
- Available options with interactive prompts
- Root permission prompts when needed
- Success/failure confirmation

**Use Cases:**
- **AI/ML training**: Set performance governor, disabled THP, max GPU clocks
- **Gaming**: Balanced governor, automatic fan control
- **Workstation**: Performance GPU, balanced CPU, manual fan if needed
- **Battery life**: Powersave governor, aggressive THP

---

### 4. ROCm + Ollama Initializer (CachyOS)

One-shot setup script that installs and configures ROCm and Ollama for running LLMs on an AMD GPU under CachyOS (and other Arch-based distributions).

**Script:** [`setup_rocm_ollama_cachyos.sh`](setup_rocm_ollama_cachyos.sh)

**Features:**
- Detects AMD GPU and warns if none is found
- Installs ROCm packages via `pacman` (`rocm-opencl-runtime`, `rocm-hip-runtime`, `rocm-smi-lib`, `rocm-device-libs`, `hip-runtime-amd`, `rocminfo`)
- Adds the current user to the `render` and `video` groups required for GPU access
- Writes a `/etc/profile.d/rocm.sh` environment file (`ROCM_PATH`, `HIP_PATH`, `LD_LIBRARY_PATH`)
- Auto-detects GPU GFX version (e.g. `gfx1030`, `gfx1100`) and sets `HSA_OVERRIDE_GFX_VERSION` for unsupported cards, with a manual fallback prompt
- Installs Ollama (via `pacman`, AUR helper `yay`/`paru`, or the official installer as a fallback)
- Creates a systemd drop-in (`/etc/systemd/system/ollama.service.d/rocm.conf`) so the service inherits ROCm environment variables
- Enables and starts (or restarts) the `ollama` systemd service
- Runs a post-install verification with `rocminfo` and `rocm-smi`

**Usage:**
```bash
sudo ./setup_rocm_ollama_cachyos.sh
```

**Prerequisites:**
- CachyOS or another Arch-based distribution
- AMD GPU (ROCm-supported or with a known GFX override)
- Root / sudo access
- Internet connection (for package downloads)

**Post-setup steps:**
1. Log out and back in (or reboot) so group membership changes (`render`/`video`) take effect.
2. Source the ROCm environment in the current shell:
   ```bash
   source /etc/profile.d/rocm.sh
   ```
3. Pull and run an LLM:
   ```bash
   ollama pull llama3
   ollama run llama3
   ```
4. Verify GPU utilization:
   ```bash
   rocm-smi --showutilization
   ```

**GFX Version Reference:**

| GPU Series | HSA_OVERRIDE_GFX_VERSION |
|------------|--------------------------|
| RX 6000 (RDNA 2) | `1030` |
| RX 7900 (RDNA 3) | `1100` |
| RX 7800 / 7700 (RDNA 3) | `1101` |

**How It Works:**
The script installs all required ROCm userspace libraries, configures the runtime environment persistently via `/etc/profile.d/rocm.sh`, and injects those same variables into the Ollama systemd service unit via a drop-in override file so that GPU acceleration is available both interactively and as a background service.

---

## Supported Hardware

- **Memory Optimizer:** AMD Ryzen AI Max+ Pro 395 (and other APUs with shared memory)
- **Ollama Model Manager:** Any system running Ollama (Linux, macOS, Windows with WSL2)
- **AMD System Tools:** AMD CPU + AMD GPU systems with ROCm installed
- **ROCm + Ollama Initializer:** CachyOS and Arch-based distributions with an AMD GPU (RDNA 2 / RDNA 3 recommended)
