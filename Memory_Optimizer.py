# Recommended RAM to reserve for system/CPU (GB)
SYSTEM_RAM_RESERVE = 16
# Page size in KB (standard x86 page size)
PAGE_SIZE_KB = 4

def get_physical_ram_gb():
    """Reads /proc/meminfo to find total system RAM in GB."""
    try:
        with open('/proc/meminfo', 'r') as f:
            for line in f:
                if "MemTotal" in line:
                    # Convert kB to GB
                    kb = int(line.split()[1])
                    return kb / (1024 * 1024)
    except FileNotFoundError:
        return None

def calculate_pages(gb):
    """Convert GB to page count using 4KB page size."""
    return int((gb * 1024 * 1024) // PAGE_SIZE_KB)

def main():
    total_ram = get_physical_ram_gb()
    
    print("--- AMD Ryzen AI Max+ Pro 395 Optimizer ---")
    recommended_vram = 0
    if total_ram:
        print(f"Detected System RAM: {total_ram:.2f} GB")
        recommended_vram = max(0, total_ram - SYSTEM_RAM_RESERVE)
        print(f"Recommended VRAM Ceiling: {recommended_vram:.2f} GB (Leaving {SYSTEM_RAM_RESERVE}GB for OS)")
    else:
        print("Could not detect RAM. Defaulting to manual mode.")

    if recommended_vram > 0:
        try:
            val = input(f"\nEnter target VRAM in GB [Default {recommended_vram:.0f}]: ")
            target_gb = float(val) if val.strip() else recommended_vram
            
            # Guardrail: Check if user is trying to allocate > 90% of RAM
            if total_ram and target_gb > (total_ram * 0.9):
                print("\n!!! WARNING: High Allocation detected.")
                print("Allocating >90% of RAM to GPU may cause System Instability / OOM Kills.")

            pages = calculate_pages(target_gb)
            
            print("\n" + "="*45)
            print(f"  TARGET: {target_gb} GB")
            print(f"  PAGES:  {pages}")
            print("="*45)
            mib = int(target_gb * 1024)
            print("\nAdd this to your GRUB_CMDLINE_LINUX_DEFAULT:")
            print(f'amdgpu.gttsize={mib}')
            print(f'\n(Deprecated TTM equivalent for reference only: ttm.pages_limit={pages} ttm.page_pool_size={pages})')
            
        except ValueError:
            print("Please enter a valid number.")
    else:
        print("\nNo RAM available for VRAM allocation after system reserve.")

if __name__ == "__main__":
    main()
