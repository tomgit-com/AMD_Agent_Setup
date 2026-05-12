#!/bin/bash

set -euo pipefail

show_menu() {
    echo ""
    echo "=== AMD Tools Manager ==="
    echo "1. GPU Monitoring & Control (rocm-smi)"
    echo "2. CPU Frequency Scaling"
    echo "3. Memory Performance Tuning"
    echo "4. Thermal Management"
    echo "5. AMDGPU Driver Settings"
    echo "6. Exit"
    echo ""
}

get_user_choice() {
    local prompt="$1"
    read -p "$prompt" choice
    echo "$choice"
}

gpu_monitoring() {
    echo ""
    echo "=== GPU Monitoring & Control ==="
    
    if ! command -v rocm-smi &>/dev/null; then
        echo "Error: rocm-smi not found. Install ROCm drivers first."
        return
    fi
    
    echo ""
    echo "Current GPU Status:"
    echo "-------------------"
    rocm-smi --showmeminfo vram
    rocm-smi --showclocks
    rocm-smi --showpower
    rocm-smi --showtemp
    
    echo ""
    echo "GPU Utilization:"
    echo "----------------"
    rocm-smi --showutilization | grep -E "(GPU|MEM)"
}

cpu_frequency() {
    echo ""
    echo "=== CPU Frequency Scaling ==="
    
    local governor
    governor=$(cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor 2>/dev/null || echo "not found")
    
    echo "Current governor: $governor"
    echo ""
    
    echo "Available governors:"
    cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_available_governors 2>/dev/null || echo "not available"
    
    echo ""
    echo "Current frequencies:"
    for i in /sys/devices/system/cpu/cpu*/cpufreq/scaling_cur_freq; do
        if [[ -f "$i" ]]; then
            cpu=$(echo "$i" | grep -oP 'cpu\d+')
            freq=$(cat "$i")
            echo "  $cpu: $((freq / 1000)) MHz"
        fi
    done
    
    echo ""
    echo "Available options:"
    echo "1. Set performance governor (max performance)"
    echo "2. Set balanced governor (default)"
    echo "3. Set power-save governor (max efficiency)"
    read -p "Select option (1-3): " choice
    
    case "$choice" in
        1)
            echo "Setting performance governor..."
            for i in /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor; do
                echo "performance" > "$i" 2>/dev/null || true
            done
            echo "Done. Current governor: $(cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor)"
            ;;
        2)
            echo "Setting balanced governor..."
            for i in /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor; do
                echo "schedutil" > "$i" 2>/dev/null || true
            done
            echo "Done. Current governor: $(cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor)"
            ;;
        3)
            echo "Setting power-save governor..."
            for i in /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor; do
                echo "powersave" > "$i" 2>/dev/null || true
            done
            echo "Done. Current governor: $(cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor)"
            ;;
        *)
            echo "Invalid choice"
            ;;
    esac
}

memory_tuning() {
    echo ""
    echo "=== Memory Performance Tuning ==="
    
    echo ""
    echo "Current Memory Settings:"
    echo "------------------------"
    
    echo "NUMA balancing: $(cat /proc/sys/kernel/numa_balancing 2>/dev/null || echo 'N/A')"
    echo "Transparent huge pages: $(cat /sys/kernel/mm/transparent_hugepage/enabled 2>/dev/null || echo 'N/A')"
    echo "Swappiness: $(cat /proc/sys/vm/swappiness 2>/dev/null || echo 'N/A')"
    
    echo ""
    echo "Memory stats:"
    free -h
    
    echo ""
    echo "Available options:"
    echo "1. Enable transparent huge pages (for large workloads)"
    echo "2. Disable transparent huge pages (for low latency)"
    echo "3. Adjust swappiness (default: 60)"
    read -p "Select option (1-3): " choice
    
    case "$choice" in
        1)
            echo "always" | sudo tee /sys/kernel/mm/transparent_hugepage/enabled
            echo "Done. Transparent huge pages: $(cat /sys/kernel/mm/transparent_hugepage/enabled)"
            ;;
        2)
            echo "never" | sudo tee /sys/kernel/mm/transparent_hugepage/enabled
            echo "Done. Transparent huge pages: $(cat /sys/kernel/mm/transparent_hugepage/enabled)"
            ;;
        3)
            local swappiness
            read -p "Enter swappiness value (0-100, default 60): " swappiness
            if [[ -z "$swappiness" ]]; then
                swappiness=60
            fi
            echo "$swappiness" | sudo tee /proc/sys/vm/swappiness
            echo "Done. Swappiness set to: $swappiness"
            ;;
        *)
            echo "Invalid choice"
            ;;
    esac
}

thermal_management() {
    echo ""
    echo "=== Thermal Management ==="
    
    if ! command -v rocm-smi &>/dev/null; then
        echo "Warning: rocm-smi not found. Some features disabled."
    fi
    
    echo ""
    echo "Current thermal status:"
    if command -v rocm-smi &>/dev/null; then
        rocm-smi --showtemp
    fi
    
    echo ""
    echo "Available options:"
    echo "1. Set GPU performance level (manual fan control)"
    echo "2. Reset to automatic fan control"
    echo "3. View detailed thermal info"
    read -p "Select option (1-3): " choice
    
    case "$choice" in
        1)
            if command -v rocm-smi &>/dev/null; then
                echo "Setting performance level to manual..."
                rocm-smi --setfanlevel 100 2>/dev/null || echo "Failed to set fan level"
                echo "Done."
            else
                echo "rocm-smi required for fan control"
            fi
            ;;
        2)
            if command -v rocm-smi &>/dev/null; then
                echo "Resetting to automatic fan control..."
                rocm-smi --resetfan 2>/dev/null || echo "Failed to reset fan"
                echo "Done."
            else
                echo "rocm-smi required for fan control"
            fi
            ;;
        3)
            if command -v rocm-smi &>/dev/null; then
                rocm-smi --showpower
                rocm-smi --showtemp
                rocm-smi --showclocks
            else
                echo "rocm-smi not found"
            fi
            ;;
        *)
            echo "Invalid choice"
            ;;
    esac
}

amdgpu_driver_settings() {
    echo ""
    echo "=== AMDGPU Driver Settings ==="
    
    echo ""
    echo "Current driver info:"
    echo "--------------------"
    cat /sys/module/amdgpu/parameters/power_dpm_force_performance_level 2>/dev/null || echo "N/A"
    
    echo ""
    echo "Available options:"
    echo "1. View power profile modes"
    echo "2. Set power profile mode"
    echo "3. View current GPU clocks"
    read -p "Select option (1-3): " choice
    
    case "$choice" in
        1)
            if command -v rocm-smi &>/dev/null; then
                echo "Power profile modes:"
                rocm-smi --showmeminfo vram
            else
                echo "rocm-smi not found"
            fi
            ;;
        2)
            if command -v rocm-smi &>/dev/null; then
                echo "Current power profile: $(rocm-smi --showpowerprofile 2>/dev/null || echo 'N/A')"
                echo "Available profiles: compute, balanced, performance"
                read -p "Enter profile name: " profile
                rocm-smi --setpowerprofile "$profile" 2>/dev/null || echo "Failed to set profile"
            else
                echo "rocm-smi not found"
            fi
            ;;
        3)
            if command -v rocm-smi &>/dev/null; then
                rocm-smi --showclocks
            else
                echo "rocm-smi not found"
            fi
            ;;
        *)
            echo "Invalid choice"
            ;;
    esac
}

while true; do
    show_menu
    choice=$(get_user_choice "Select an option (1-6): ")
    
    case "$choice" in
        1)
            gpu_monitoring
            ;;
        2)
            cpu_frequency
            ;;
        3)
            memory_tuning
            ;;
        4)
            thermal_management
            ;;
        5)
            amdgpu_driver_settings
            ;;
        6)
            echo "Goodbye!"
            exit 0
            ;;
        *)
            echo "Invalid choice. Please select 1-6."
            ;;
    esac
done
