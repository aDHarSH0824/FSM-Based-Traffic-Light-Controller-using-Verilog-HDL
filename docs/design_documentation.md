# Technical Design Documentation: FSM-Based Traffic Light Controller

## 1. Executive Summary

This document provides a comprehensive digital hardware design specification for an **FSM-Based Traffic Light Controller** implemented in synthesizable Verilog HDL. The controller regulates vehicular traffic flow at a four-way planar intersection consisting of two orthogonal lanes: **North-South (NS)** and **East-West (EW)**.

The architecture employs a 4-state **Moore Finite State Machine (FSM)** coupled with an integrated cycle counter to generate deterministic, cycle-accurate timing intervals for Green, Yellow, and Red signals. A synchronous active-high reset ensures deterministic power-up initialization and failsafe recovery.

---

## 2. System Architecture & Block Diagram

### 2.1 Intersection Topology
The intersection consists of two crossing 2-way roads. The controller outputs dedicated 1-bit driving lines for three distinct lamp colors (Red, Yellow, Green) for both directions:
- North-South direction lamps: `ns_red`, `ns_yellow`, `ns_green`
- East-West direction lamps: `ew_red`, `ew_yellow`, `ew_green`

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

### 2.2 RTL Module Interface Block Diagram

```
                       +---------------------------------------+
                       |       traffic_controller              |
                       |                                       |
    [clk]   ---------->| System Clock                          |
    [reset] ---------->| Synchronous Active-High Reset         |
                       |                                       |
                       |               North-South (NS) Lamps: |
                       |                  ns_red ------------->| [NS Red LED]
                       |               ns_yellow ------------->| [NS Yellow LED]
                       |                ns_green ------------->| [NS Green LED]
                       |                                       |
                       |                 East-West (EW) Lamps: |
                       |                  ew_red ------------->| [EW Red LED]
                       |               ew_yellow ------------->| [EW Yellow LED]
                       |                ew_green ------------->| [EW Green LED]
                       +---------------------------------------+
```

---

## 3. Finite State Machine (FSM) Design

### 3.1 State Definitions
The controller is designed as a classic **Moore FSM**, meaning that the output signals depend **exclusively** on the current state register, ensuring glitch-free outputs devoid of combinational input ripple.

| State Symbol | Binary Encoding | North-South Light | East-West Light | Default Duration |
|:------------:|:---------------:|:-----------------:|:---------------:|:----------------:|
| **S0**       | `2'b00`         | **Green**         | **Red**         | 10 clock cycles  |
| **S1**       | `2'b01`         | **Yellow**        | **Red**         | 3 clock cycles   |
| **S2**       | `2'b10`         | **Red**           | **Green**       | 10 clock cycles  |
| **S3**       | `2'b11`         | **Red**           | **Yellow**      | 3 clock cycles   |

### 3.2 State Transition Diagram

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

### 3.3 State Transition Table

| Current State | Current Counter Value (`count`) | Condition / Event | Next State | Next Counter Value |
|:---:|:---:|:---:|:---:|:---:|
| `S0` | `0 <= count < GREEN_CYCLES-1` | Active timing window | `S0` | `count + 1` |
| `S0` | `count == GREEN_CYCLES-1` | Green window expired | `S1` | `0` |
| `S1` | `0 <= count < YELLOW_CYCLES-1` | Active timing window | `S1` | `count + 1` |
| `S1` | `count == YELLOW_CYCLES-1` | Yellow window expired | `S2` | `0` |
| `S2` | `0 <= count < GREEN_CYCLES-1` | Active timing window | `S2` | `count + 1` |
| `S2` | `count == GREEN_CYCLES-1` | Green window expired | `S3` | `0` |
| `S3` | `0 <= count < YELLOW_CYCLES-1` | Active timing window | `S3` | `count + 1` |
| `S3` | `count == YELLOW_CYCLES-1` | Yellow window expired | `S0` | `0` |
| Any | Any | `reset == 1` (posedge clk) | `S0` | `0` |

---

## 4. Hardware Implementation Details

### 4.1 3-Always-Block Architecture
The RTL follows the recommended standard 3-block FSM partitioning for synthesizability and maintainability:

1. **Sequential State Register & Counter Block (`always @(posedge clk)`):**
   - Updates `current_state <= next_state` synchronously.
   - Clears `count <= 0` when `reset == 1` or when transitioning (`current_state != next_state`).
   - Increments `count <= count + 1` while remaining within the active state.
2. **Combinational Next-State Logic Block (`always @(*)`):**
   - Evaluates `current_state` and counter boundary conditions (`count >= DURATION - 1`).
   - Assigns `next_state` without inferring memory or latches.
3. **Moore Output Logic Block (`always @(*)`):**
   - Directly maps `current_state` to the 6 lamp driver bits.
   - Includes a default failsafe assignment (`ns_red = 1`, `ew_red = 1`) to guarantee safety under illegal or unmapped states.

### 4.2 Critical Safety Invariants
- **Mutual Green Exclusion:** Under no circumstances can `ns_green` and `ew_green` be asserted at the same instant ($ns\_green \land ew\_green = 0$).
- **One-Hot Signal Validity:** For each individual traffic direction, exactly one of the three lamps (Red, Yellow, Green) must be asserted during normal runtime ($ns\_red + ns\_yellow + ns\_green = 1$).

---

## 5. Timing Diagram & Cycle Analysis

Assuming `GREEN_CYCLES = 10` and `YELLOW_CYCLES = 3`:

```
Cycle:      0   1   2  ...  9  10  11  12  13  14  15 ... 23  24  25  26  27
clk:       _|~|_|~|_|~|   |~|_|~|_|~|_|~|_|~|_|~|_|~|   |~|_|~|_|~|_|~|_|~|
reset:     ~~~|____________________________________________________________
State:     |        S0 (NS Green)         | S1 (NS Ylw)|    S2 (EW Grn)   |S3
Count:     | 0 | 1 | 2 ... | 8 | 9 | 0 | 1 | 2 | 0 | 1 ... | 8 | 9 | 0 | 1
ns_green:  ~~~~~-----------------------------------------------------------
ns_yellow: -------------------------~~~~~~~~~~~~---------------------------
ns_red:    -----------------------------------------~~~~~~~~~~~~~~~~~~~~~~~
ew_red:    ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~---------------------------
ew_green:  -----------------------------------------~~~~~~~~~~~~~~~~~~~~---
ew_yellow: -------------------------------------------------------------~~~
```

Total Period of One Complete Loop:
$$T_{cycle} = T_{S0} + T_{S1} + T_{S2} + T_{S3} = 10 + 3 + 10 + 3 = 26 \text{ clock cycles}$$

---

## 6. Synthesis and FPGA Deployment Considerations

- **Clock Domain:** Single synchronous clock domain (`clk`).
- **Resource Utilization (Estimated for typical FPGA / ASIC):**
  - Flip-Flops: 2 for `current_state`, 6 for `count` (Total = 8 registers).
  - Combinational LUTs: ~15-20 LUT4/LUT6 for next-state logic, comparator, and output decoding.
- **Clock Frequency:** Because the logic depth is minimal (a 6-bit incrementer and 2-bit state comparator), this design easily achieves timing closure exceeding 200+ MHz on modern FPGA fabrics (Xilinx 7-Series / Intel Cyclone V).
- **Physical Road Interfacing:** For real-world intersections running at 100 MHz, a clock prescaler / frequency divider should divide the system clock down to 1 Hz (1 pulse per second), allowing parameterized cycle counts to directly represent physical seconds (e.g., 30s Green, 5s Yellow).

