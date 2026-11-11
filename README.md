# FSM-Based Traffic Light Controller using Verilog HDL

A complete digital hardware design and RTL verification project of a **Finite State Machine (FSM) Traffic Light Controller** written in synthesizable Verilog HDL.

This project models and simulates a 4-way planar traffic intersection with dual orthogonal directions (**North-South** and **East-West**), featuring parameterized timing intervals, cycle-accurate counter management, synchronous reset recovery, and self-checking testbench verification.

---

## Table of Contents
1. [Project Overview & Objectives](#1-project-overview--objectives)
2. [Software Requirements & Installation Guide](#2-software-requirements--installation-guide)
3. [Project Directory Structure](#3-project-directory-structure)
4. [Intersection Model & Hardware Architecture](#4-intersection-model--hardware-architecture)
5. [FSM Architecture & State Transition Diagram](#5-fsm-architecture--state-transition-diagram)
6. [State Transition Table](#6-state-transition-table)
7. [Clock, Reset, and Counter Management](#7-clock-reset-and-counter-management)
8. [Verilog RTL Implementation Details](#8-verilog-rtl-implementation-details)
9. [Testbench Verification Methodology](#9-testbench-verification-methodology)
10. [How to Compile, Simulate, and View Waveforms](#10-how-to-compile-simulate-and-view-waveforms)
11. [Simulation Results & GTKWave Visualization](#11-simulation-results--gtkwave-visualization)
12. [Interview & Academic Discussion Points](#12-interview--academic-discussion-points)

---

## 1. Project Overview & Objectives

In modern digital systems, sequential controllers coordinate safety-critical operations using Finite State Machines (FSMs). This project implements an intersection traffic light controller that satisfies the following core objectives:

- **Sequential Circuit Design:** Implement a robust **Moore FSM** in synthesizable Verilog HDL.
- **Safety Guarantee:** Ensure that orthogonal traffic routes (North-South and East-West) are **never** granted a Green signal simultaneously ($ns\_green \land ew\_green = 0$).
- **Configurable Timing:** Use an internal digital counter with customizable parameters (`GREEN_CYCLES = 10`, `YELLOW_CYCLES = 3`) to govern signal durations.
- **Synchronous Reset:** Guarantee known power-up state (`S0_NS_GREEN`) and safe recovery upon reset assertion.
- **Comprehensive Verification:** Include a self-checking testbench that validates timing accuracy, state sequencing, safety invariants, and mid-operation reset behavior.

---

## 2. Software Requirements & Installation Guide

To compile, simulate, and inspect waveforms for this project, you need two open-source tools:
1. **Icarus Verilog (`iverilog` & `vvp`):** The IEEE-1364 Verilog simulation and synthesis compiler.
2. **GTKWave (`gtkwave`):** An interactive graphical waveform viewer for Value Change Dump (`.vcd`) files.

### A. Linux (Ubuntu / Debian / Linux Mint)
Open your terminal and run:
```bash
sudo apt-get update
sudo apt-get install -y iverilog gtkwave
```

### B. Linux (Fedora / Red Hat)
```bash
sudo dnf install -y iverilog gtkwave
```

### C. macOS (via Homebrew)
```bash
brew install icarus-verilog
brew install --cask gtkwave
```

### D. Windows
You have three convenient options for Windows:
1. **Windows Subsystem for Linux (WSL2 - Recommended):**
   Install WSL (`wsl --install` in PowerShell), then follow the Ubuntu instructions above.
2. **Native Windows Binaries:**
   - Download the Icarus Verilog Windows installer from [bleyer.org/icarus](https://bleyer.org/icarus/) (includes both `iverilog` and `gtkwave`).
   - During installation, check the box: *"Add executable path to system PATH"*.
3. **Zero-Install Cloud Option (EDA Playground):**
   - Open [edaplayground.com](https://www.edaplayground.com/).
   - Set Simulator to **Icarus Verilog 12.0** or **Aldec Riviera-PRO**.
   - Paste `rtl/traffic_controller.v` into the design window and `testbench/traffic_controller_tb.v` into the testbench window.
   - Check **Open EPWave after run** to view waveforms in your browser.

---

## 3. Project Directory Structure

Where to place each file in the workspace:

```text
EProject-2/
│
├── rtl/
│   └── traffic_controller.v         # Synthesizable RTL Moore FSM code
│
├── testbench/
│   └── traffic_controller_tb.v      # Self-checking automated testbench
│
├── simulation/
│   ├── run_sim.sh                   # Automated compile & simulation bash script
│   └── traffic_sim                  # Compiled simulation binary (generated)
│
├── waveforms/
│   ├── traffic_waveform.vcd         # VCD waveform dump (generated)
│   └── traffic_waveform.gtkw        # Pre-configured GTKWave signal layout
│
├── docs/
│   └── design_documentation.md      # Detailed hardware specification & calculations
│
└── README.md                        # Master project guide (this document)
```

---

## 4. Intersection Model & Hardware Architecture

The controller governs a standard 4-way crossroad:
- **North-South (NS)** corridor.
- **East-West (EW)** corridor.

```
                          |   | North |   |
                          |   |   |   |   |
                          |   |   v   |   |
                          |   | [NS]  |   |
     _____________________|   |       |   |_____________________
     West  ----->  [EW]                       [EW] <-----   East
     ---------------------                 ---------------------
     _____________________                 _____________________
                          |   |       |   |
                          |   |  [NS] |   |
                          |   |   ^   |   |
                          |   |   |   |   |
                          |   | South |   |
```

### Module Port List

| Signal Name | Direction | Width | Description |
|:---|:---:|:---:|:---|
| `clk` | Input | 1 bit | System clock (transitions occur on posedge) |
| `reset` | Input | 1 bit | Synchronous active-high reset |
| `ns_red` | Output | 1 bit | North-South Red lamp output (`1` = ON) |
| `ns_yellow` | Output | 1 bit | North-South Yellow lamp output (`1` = ON) |
| `ns_green` | Output | 1 bit | North-South Green lamp output (`1` = ON) |
| `ew_red` | Output | 1 bit | East-West Red lamp output (`1` = ON) |
| `ew_yellow` | Output | 1 bit | East-West Yellow lamp output (`1` = ON) |
| `ew_green` | Output | 1 bit | East-West Green lamp output (`1` = ON) |

---

## 5. FSM Architecture & State Transition Diagram

The controller implements a 4-state **Moore Finite State Machine**:

```
         +-------------------------------------------------------+
         |                                                       |
         v                                                       |
   +------------+   count == GREEN_CYCLES-1   +------------+     |
   |     S0     | --------------------------> |     S1     |     |
   |  NS: GREEN |                             | NS: YELLOW |     |
   |  EW: RED   | <-------------------------+ |  EW: RED   |     |
   +------------+         reset == 1        | +------------+     |
         |                                  |        |           |
         | reset == 1                       |        | count == YELLOW_CYCLES-1
         |                                  |        v           |
   +------------+   count == GREEN_CYCLES-1   +------------+     |
   |     S3     | <-------------------------- |     S2     |     |
   |  NS: RED   |                             |  NS: RED   |     |
   | EW: YELLOW | --------------------------+ | EW: GREEN  |     |
   +------------+         reset == 1        | +------------+     |
         |                                  |        |           |
         | count == YELLOW_CYCLES-1         +--------+           |
         +-------------------------------------------------------+
```

### State Descriptions
1. **State S0 (`2'b00` - NS Green, EW Red):**
   North-South traffic flows unimpeded. East-West traffic is stopped. Default duration: **10 clock cycles**.
2. **State S1 (`2'b01` - NS Yellow, EW Red):**
   North-South traffic prepares to stop. East-West traffic remains stopped. Default duration: **3 clock cycles**.
3. **State S2 (`2'b10` - NS Red, EW Green):**
   East-West traffic flows unimpeded. North-South traffic is stopped. Default duration: **10 clock cycles**.
4. **State S3 (`2'b11` - NS Red, EW Yellow):**
   East-West traffic prepares to stop. North-South traffic remains stopped. Default duration: **3 clock cycles**.

---

## 6. State Transition Table

| State Name | Current State (`current_state`) | Cycle Range (`count`) | Condition | Next State (`next_state`) | North-South Lamps {R, Y, G} | East-West Lamps {R, Y, G} |
|:---:|:---:|:---:|:---:|:---:|:---:|:---:|
| **S0** | `2'b00` | $0 \le \text{count} < 9$ | `count < 9` | `2'b00` (S0) | `{0, 0, 1}` | `{1, 0, 0}` |
| **S0** | `2'b00` | $9$ | `count == 9` | `2'b01` (S1) | `{0, 0, 1}` | `{1, 0, 0}` |
| **S1** | `2'b01` | $0 \le \text{count} < 2$ | `count < 2` | `2'b01` (S1) | `{0, 1, 0}` | `{1, 0, 0}` |
| **S1** | `2'b01` | $2$ | `count == 2` | `2'b10` (S2) | `{0, 1, 0}` | `{1, 0, 0}` |
| **S2** | `2'b10` | $0 \le \text{count} < 9$ | `count < 9` | `2'b10` (S2) | `{1, 0, 0}` | `{0, 0, 1}` |
| **S2** | `2'b10` | $9$ | `count == 9` | `2'b11` (S3) | `{1, 0, 0}` | `{0, 0, 1}` |
| **S3** | `2'b11` | $0 \le \text{count} < 2$ | `count < 2` | `2'b11` (S3) | `{1, 0, 0}` | `{0, 1, 0}` |
| **S3** | `2'b11` | $2$ | `count == 2` | `2'b00` (S0) | `{1, 0, 0}` | `{0, 1, 0}` |
| **Any** | `2'bXX` | Any | `reset == 1` | `2'b00` (S0) | `{0, 0, 1}` | `{1, 0, 0}` |

---

## 7. Clock, Reset, and Counter Management

- **Clock (`clk`):** Serves as the global synchronization heartbeat. All internal state and counter transitions happen strictly on the positive clock edge (`posedge clk`).
- **Synchronous Reset (`reset`):** Active-high. When sampled high at `posedge clk`, it synchronously sets `current_state <= S0_NS_GREEN` and clears `count <= 0`.
- **Cycle Counter (`count`):** An internal $N$-bit register (`[COUNTER_WIDTH-1:0] count`).
  - Begins at `0` upon state entry.
  - Increments on each clock cycle: `count <= count + 1'b1`.
  - Resets back to `0` whenever `current_state != next_state`.

---

## 8. Verilog RTL Implementation Details

The design in [`rtl/traffic_controller.v`](rtl/traffic_controller.v) follows the industry-standard **3-always-block pattern**:

1. **Sequential Always Block (`always @(posedge clk)`):** Updates `current_state` and handles synchronous counter increment/reset.
2. **Combinational Next-State Logic (`always @(*)`):** Computes `next_state` by evaluating `current_state` against `GREEN_CYCLES` and `YELLOW_CYCLES`.
3. **Moore Output Logic (`always @(*)`):** Pure combinational output decoder driven directly by `current_state`. Includes a failsafe default assignment.

### Verilog Source Summary
```verilog
module traffic_controller #(
    parameter GREEN_CYCLES  = 10,
    parameter YELLOW_CYCLES = 3,
    parameter COUNTER_WIDTH = 6
)(
    input  wire clk,
    input  wire reset,
    output reg  ns_red, ns_yellow, ns_green,
    output reg  ew_red, ew_yellow, ew_green
);
    // State Encoding
    localparam [1:0] S0_NS_GREEN  = 2'b00;
    localparam [1:0] S1_NS_YELLOW = 2'b01;
    localparam [1:0] S2_EW_GREEN  = 2'b10;
    localparam [1:0] S3_EW_YELLOW = 2'b11;

    reg [1:0] current_state, next_state;
    reg [COUNTER_WIDTH-1:0] count;

    // Block 1: Sequential Update
    always @(posedge clk) begin
        if (reset) begin
            current_state <= S0_NS_GREEN;
            count         <= {COUNTER_WIDTH{1'b0}};
        end else begin
            current_state <= next_state;
            if (current_state != next_state)
                count <= {COUNTER_WIDTH{1'b0}};
            else
                count <= count + 1'b1;
        end
    end

    // Block 2: Combinational Next-State
    always @(*) begin
        case (current_state)
            S0_NS_GREEN:  next_state = (count >= GREEN_CYCLES-1)  ? S1_NS_YELLOW : S0_NS_GREEN;
            S1_NS_YELLOW: next_state = (count >= YELLOW_CYCLES-1) ? S2_EW_GREEN  : S1_NS_YELLOW;
            S2_EW_GREEN:  next_state = (count >= GREEN_CYCLES-1)  ? S3_EW_YELLOW : S2_EW_GREEN;
            S3_EW_YELLOW: next_state = (count >= YELLOW_CYCLES-1) ? S0_NS_GREEN  : S3_EW_YELLOW;
            default:      next_state = S0_NS_GREEN;
        endcase
    end

    // Block 3: Moore Output Logic
    always @(*) begin
        ns_red = 0; ns_yellow = 0; ns_green = 0;
        ew_red = 0; ew_yellow = 0; ew_green = 0;
        case (current_state)
            S0_NS_GREEN:  begin ns_green  = 1; ew_red    = 1; end
            S1_NS_YELLOW: begin ns_yellow = 1; ew_red    = 1; end
            S2_EW_GREEN:  begin ns_red    = 1; ew_green  = 1; end
            S3_EW_YELLOW: begin ns_red    = 1; ew_yellow = 1; end
            default:      begin ns_red    = 1; ew_red    = 1; end
        endcase
    end
endmodule
```

---

## 9. Testbench Verification Methodology

The testbench [`testbench/traffic_controller_tb.v`](testbench/traffic_controller_tb.v) uses automated assertions and verification tasks:

- **Periodic Clock:** 100 MHz clock generated using `forever #5 clk = ~clk;` (Period = 10 ns).
- **Concurrent Invariant Assertions:**
  1. `!(ns_green && ew_green)` continuously checked at every `posedge clk`.
  2. `(ns_red + ns_yellow + ns_green == 1)` and `(ew_red + ew_yellow + ew_green == 1)` verified continuously.
- **Cycle-by-Cycle State & Timing Checker:** Loops through every individual cycle, sampling `count`, `current_state`, and `next_state`.
- **Mid-Operation Reset Recovery:** Asserts `reset` midway through State S2 (EW Green), verifying that the FSM immediately resets to S0 and properly resumes normal sequence when released.

---

## 10. How to Compile, Simulate, and View Waveforms

### Automated Method (Single Command)
Run the included bash script:
```bash
chmod +x simulation/run_sim.sh
./simulation/run_sim.sh
```
To run the simulation and immediately launch GTKWave:
```bash
./simulation/run_sim.sh --gui
```

### Manual Command-Line Method

#### Step 1: Compile with Icarus Verilog
```bash
iverilog -Wall -g2001 -o simulation/traffic_sim rtl/traffic_controller.v testbench/traffic_controller_tb.v
```

#### Step 2: Execute Simulation Runtime
```bash
vvp simulation/traffic_sim
```

#### Step 3: Open Waveforms in GTKWave
```bash
gtkwave waveforms/traffic_waveform.vcd waveforms/traffic_waveform.gtkw &
```

---

## 11. Simulation Results & GTKWave Visualization

### Terminal Output
Executing the testbench produces:

```text
============================================================================
   STARTING FSM TRAFFIC LIGHT CONTROLLER TESTBENCH SIMULATION
   Parameters: GREEN_CYCLES = 10, YELLOW_CYCLES = 3, CLK = 10 ns
============================================================================

[TEST 1] Applying Synchronous Reset...
  [PASS] Synchronous reset confirmed: State=S0 (NS_GREEN), Counter=0
  [PASS] Reset State Outputs (NS_G=1, EW_R=1) | Outputs: NS={R:0, Y:0, G:1} EW={R:1, Y:0, G:0}
  [INFO] Synchronous reset deasserted at time 30000 ns

[TEST 2] Verifying Full FSM Sequence & Signal Durations...

--- Verifying State S0: NS Green (Expected Duration: 10 cycles) ---
  [PASS] State S0: NS Green | Outputs: NS={R:0, Y:0, G:1} EW={R:1, Y:0, G:0}
  [PASS] State S0: NS Green final cycle: next_state correctly decoded as S1 (NS_YELLOW)
  [PASS] Successfully transitioned to S1 (NS_YELLOW) (count reset to 0)

--- Verifying State S1: NS Yellow (Expected Duration: 3 cycles) ---
  [PASS] State S1: NS Yellow | Outputs: NS={R:0, Y:1, G:0} EW={R:1, Y:0, G:0}
  [PASS] State S1: NS Yellow final cycle: next_state correctly decoded as S2 (EW_GREEN)
  [PASS] Successfully transitioned to S2 (EW_GREEN) (count reset to 0)

--- Verifying State S2: EW Green (Expected Duration: 10 cycles) ---
  [PASS] State S2: EW Green | Outputs: NS={R:1, Y:0, G:0} EW={R:0, Y:0, G:1}
  [PASS] State S2: EW Green final cycle: next_state correctly decoded as S3 (EW_YELLOW)
  [PASS] Successfully transitioned to S3 (EW_YELLOW) (count reset to 0)

--- Verifying State S3: EW Yellow (Expected Duration: 3 cycles) ---
  [PASS] State S3: EW Yellow | Outputs: NS={R:1, Y:0, G:0} EW={R:0, Y:1, G:0}
  [PASS] State S3: EW Yellow final cycle: next_state correctly decoded as S0 (NS_GREEN)
  [PASS] Successfully transitioned to S0 (NS_GREEN) (count reset to 0)

  [PASS] Full 4-state cycle completed seamlessly! Continuous looping verified.

[TEST 3] Testing Mid-Operation Synchronous Reset in State S2...
  [INFO] Arrived in State S2 (EW_GREEN) with count = 5 at time 466000 ns
  [PASS] Mid-operation reset successfully returned FSM to S0 (NS_GREEN) and count to 0
  [INFO] Released reset, verifying resumption of normal sequence...

--- Verifying Post-Reset State S0 (Expected Duration: 10 cycles) ---
  [PASS] Post-Reset State S0 | Outputs: NS={R:0, Y:0, G:1} EW={R:1, Y:0, G:0}
  [PASS] Post-Reset State S0 final cycle: next_state correctly decoded as S1 (NS_YELLOW)
  [PASS] Successfully transitioned to S1 (NS_YELLOW) (count reset to 0)

--- Verifying Post-Reset State S1 (Expected Duration: 3 cycles) ---
  [PASS] Post-Reset State S1 | Outputs: NS={R:0, Y:1, G:0} EW={R:1, Y:0, G:0}
  [PASS] Post-Reset State S1 final cycle: next_state correctly decoded as S2 (EW_GREEN)
  [PASS] Successfully transitioned to S2 (EW_GREEN) (count reset to 0)

[TEST 4] Verifying Second Complete FSM Loop...
...
============================================================================
                   SIMULATION VERIFICATION REPORT
============================================================================
  Total Verification Checks Passed : 80
  Total Verification Checks Failed : 0
----------------------------------------------------------------------------
  >>> FINAL RESULT: ALL TESTS PASSED SUCCESSFULLY! (PASS) <<<
============================================================================
```

### Waveform Layout in GTKWave
The pre-configured session file [`waveforms/traffic_waveform.gtkw`](waveforms/traffic_waveform.gtkw) organizes traces into four logical groups:
1. **Clock & Reset:** `clk`, `reset`.
2. **FSM State & Timing:** `current_state[1:0]`, `next_state[1:0]`, `count[5:0]`.
3. **North-South Signals:** `ns_green` (Green), `ns_yellow` (Yellow), `ns_red` (Red).
4. **East-West Signals:** `ew_green` (Green), `ew_yellow` (Yellow), `ew_red` (Red).

---

