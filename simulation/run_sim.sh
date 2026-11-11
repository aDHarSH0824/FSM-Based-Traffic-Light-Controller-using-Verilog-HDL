#!/bin/bash
# ==============================================================================
# Script:      run_sim.sh
# Project:     FSM-Based Traffic Light Controller using Verilog HDL
# Description: Automated script to compile RTL and Testbench using Icarus Verilog,
#              execute the simulation via VVP, generate VCD waveforms, and optionally
#              launch GTKWave for waveform inspection.
# ==============================================================================

set -e

# Project root directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

cd "${PROJECT_ROOT}"

echo "======================================================================"
echo "    FSM Traffic Light Controller - Simulation Build & Run Script"
echo "======================================================================"

# Ensure directories exist
mkdir -p simulation waveforms

# Step 1: Check dependencies
echo "[1/4] Checking toolchain dependencies..."
if ! command -v iverilog &> /dev/null; then
    echo "ERROR: 'iverilog' (Icarus Verilog) is not installed."
    echo "Install with: sudo apt-get install iverilog"
    exit 1
fi

if ! command -v vvp &> /dev/null; then
    echo "ERROR: 'vvp' runtime is not installed."
    echo "Install with: sudo apt-get install iverilog"
    exit 1
fi

echo "      iverilog version: $(iverilog -V | head -n 1)"

# Step 2: Compile RTL and Testbench
echo "[2/4] Compiling Verilog source files..."
iverilog -Wall -g2001 -o simulation/traffic_sim rtl/traffic_controller.v testbench/traffic_controller_tb.v
echo "      Compilation successful -> simulation/traffic_sim generated."

# Step 3: Run the simulation
echo "[3/4] Running simulation with vvp..."
vvp simulation/traffic_sim

# Step 4: Verify waveform generation
echo "[4/4] Verifying generated waveform file..."
if [ -f "waveforms/traffic_waveform.vcd" ]; then
    WAVE_SIZE=$(ls -lh waveforms/traffic_waveform.vcd | awk '{print $5}')
    echo "      Waveform generated: waveforms/traffic_waveform.vcd (${WAVE_SIZE})"
else
    echo "      WARNING: waveforms/traffic_waveform.vcd was not created."
fi

echo "======================================================================"
echo " Simulation Complete!"
echo " To view waveforms in GTKWave, run:"
echo "     gtkwave waveforms/traffic_waveform.vcd &"
echo "======================================================================"

# If --gui or -g is passed, launch GTKWave
if [[ "$1" == "--gui" || "$1" == "-g" ]]; then
    if command -v gtkwave &> /dev/null; then
        echo "Launching GTKWave..."
        gtkwave waveforms/traffic_waveform.vcd &
    else
        echo "GTKWave is not installed. Install with: sudo apt install gtkwave"
    fi
fi

