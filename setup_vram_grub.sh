#!/bin/bash

# Script to configure GPU memory allocation for AMD APUs via GRUB
# Uses modern amdgpu.gttsize kernel parameter (replaces deprecated TTM)
# Supports: Debian, Ubuntu, Fedora, Arch, CachyOS, CentOS/RHEL

SYSTEM_RAM_RESERVE=16

get_physical_ram_gb() {
    if [ -f /proc/meminfo ]; then
        local kb
        kb=$(grep "MemTotal" /proc/meminfo | awk '{print $2}')
        echo $(awk "BEGIN {printf \"%.2f\", $kb / (1024 * 1024)}")
    else
        echo ""
    fi
}

detect_distribution() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        echo "$ID"
    else
        echo "unknown"
    fi
}

check_privileges() {
    if [ "$EUID" -ne 0 ] && [ "$(whoami)" != "root" ]; then
        echo "This script requires elevated privileges."
        echo "Please run with sudo."
        exit 1
    fi
}

get_grub_file() {
    echo "/etc/default/grub"
}

update_grub_debian() {
    if command -v update-grub &> /dev/null; then
        update-grub
    elif command -v grub-mkconfig &> /dev/null; then
        grub-mkconfig -o /boot/grub/grub.cfg
    else
        echo "GRUB tools not found. Please run 'update-grub' manually"
        exit 1
    fi
}

update_grub_fedora() {
    if command -v grub2-mkconfig &> /dev/null; then
        grub2-mkconfig -o /boot/grub2/grub.cfg
    else
        echo "GRUB2 tools not found. Please run 'grub2-mkconfig' manually"
        exit 1
    fi
}

update_grub_arch() {
    if command -v grub-mkconfig &> /dev/null; then
        grub-mkconfig -o /boot/grub/grub.cfg
    else
        echo "GRUB tools not found. Please run 'grub-mkconfig' manually"
        exit 1
    fi
}

update_grub_centos() {
    if command -v grub2-mkconfig &> /dev/null; then
        grub2-mkconfig -o /boot/grub2/grub.cfg
    else
        echo "GRUB2 tools not found. Please run 'grub2-mkconfig' manually"
        exit 1
    fi
}

calculate_gttsize_mib() {
    local gb=$1
    echo $(( gb * 1024 ))
}

main() {
    local distro
    local total_ram
    local recommended_vram
    local target_gb
    local input_val
    
    check_privileges
    
    distro=$(detect_distribution)
    total_ram=$(get_physical_ram_gb)
    
    echo "--- AMD APU GPU Memory Allocator (amdgpu.gttsize) ---"
    
    if [ -n "$total_ram" ]; then
        echo "Detected System RAM: ${total_ram} GB"
        recommended_vram=$(awk "BEGIN {printf \"%.2f\", $total_ram - $SYSTEM_RAM_RESERVE}")
        if [ "$(awk "BEGIN {print ($recommended_vram > 0)}")" -eq 1 ]; then
            echo "Recommended VRAM Ceiling: ${recommended_vram} GB (Leaving ${SYSTEM_RAM_RESERVE}GB for OS)"
        else
            recommended_vram=0
        fi
    else
        echo "Could not detect RAM. Defaulting to manual mode."
        recommended_vram=0
    fi
    
    if [ "$(awk "BEGIN {print ($recommended_vram > 0)}")" -eq 1 ]; then
        input_val="${1:-}"
        if [ -n "$input_val" ]; then
            target_gb=$input_val
        else
            read -p "Enter target VRAM in GB [Default ${recommended_vram%%.*}]: " target_gb
            if [ -z "$target_gb" ]; then
                target_gb=$recommended_vram
            fi
        fi
        
        if [ -n "$total_ram" ]; then
            max_allowed=$(awk "BEGIN {printf \"%.2f\", $total_ram * 0.9}")
            if [ "$(awk "BEGIN {print ($target_gb > $max_allowed)}")" -eq 1 ]; then
                echo ""
                echo "!!! WARNING: High Allocation detected."
                echo "Allocating >90% of RAM to GPU may cause System Instability / OOM Kills."
                read -p "Continue anyway? (y/N): " confirm
                if [ "$confirm" != "y" ] && [ "$confirm" != "Y" ]; then
                    echo "Aborted."
                    exit 0
                fi
            fi
        fi
        
        gttsize_mib=$(calculate_gttsize_mib ${target_gb%%.*})

        grub_file=$(get_grub_file $distro)

        echo ""
        echo "============================================"
        echo "  TARGET: ${target_gb} GB"
        echo "  GTT SIZE: ${gttsize_mib} MiB"
        echo "============================================"
        echo ""
        echo "Adding to $grub_file:"
        echo "  amdgpu.gttsize=$gttsize_mib"
        echo ""

        read -p "Apply these changes? (y/N): " confirm
        if [ "$confirm" != "y" ] && [ "$confirm" != "Y" ]; then
            echo "Aborted."
            exit 0
        fi

        sed -i 's/\(GRUB_CMDLINE_LINUX_DEFAULT="[^"]*\)"/\1 amdgpu.gttsize='"$gttsize_mib"'"' "$grub_file"
        
        echo "Updating GRUB for $distro..."
        case "$distro" in
            debian|ubuntu|cachyos)
                update_grub_debian
                ;;
            fedora)
                update_grub_fedora
                ;;
            arch|manjaro|cachyos)
                update_grub_arch
                ;;
            centos|rhel|rocky|almalinux)
                update_grub_centos
                ;;
            *)
                echo "Unsupported distribution. Please run grub-mkconfig manually."
                ;;
        esac
        
        echo "VRAM configuration applied successfully!"
    else
        echo "No RAM available for VRAM allocation after system reserve."
    fi
}

main "$@"
