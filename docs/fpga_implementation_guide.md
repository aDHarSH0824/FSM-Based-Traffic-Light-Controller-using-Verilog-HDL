# FPGA Implementation & ASIC Interview Preparation Guide

This guide extends the FSM Traffic Light Controller project from discrete-event simulation to real-world FPGA hardware synthesis and provides answers to key ASIC/FPGA digital design interview questions.

---

## Part 1: Physical FPGA Deployment

In pure simulation, the clock runs at 100 MHz (period = 10 ns), meaning 10 clock cycles take only 100 nanoseconds—invisible to the human eye. To deploy this design onto an actual physical FPGA development board with real LEDs:

1. Use the wrapper module [`rtl/traffic_controller_top.v`](../rtl/traffic_controller_top.v).
2. The wrapper integrates a clock frequency divider that scales the 100 MHz oscillator down to a **1 Hz clock** (1 pulse every second).
3. The 10 Green cycles correspond to **10 physical seconds**, and the 3 Yellow cycles correspond to **3 physical seconds**.

### Block Diagram for FPGA Deployment

```
 +-----------------------------------------------------------------------------------------+
 |                                  traffic_controller_top                                 |
 |                                                                                         |
 |   [100 MHz Oscillator] ---> sys_clk                                                     |
 |                                |                                                        |
 |                       +-----------------+                                               |
 |                       | Clock Divider   |                                               |
 |                       | (100M -> 1 Hz)  |                                               |
 |                       +-----------------+                                               |
 |                                | slow_clk (1 Hz)                                        |
 |                                v                                                        |
 |   [Center Pushbutton] ----> reset                                                       |
 |                                |                                                        |
 |                       +----------------------+       led_ns[2:0]                        |
 |                       |  traffic_controller  |------> {Red, Yellow, Green} --> NS LEDs  |
 |                       |        (Core)        |       led_ew[2:0]                        |
 |                       |                      |------> {Red, Yellow, Green} --> EW LEDs  |
 |                       +----------------------+                                          |
 +-----------------------------------------------------------------------------------------+
```

---

## Part 2: FPGA Pin Constraints

### 1. Digilent Basys 3 (Xilinx Artix-7 - `Basys3_Master.xdc`)

```tcl
## Clock Signal (100 MHz oscillator)
set_property PACKAGE_PIN W5 [get_ports sys_clk]
set_property IOSTANDARD LVCMOS33 [get_ports sys_clk]
create_clock -add -name sys_clk_pin -period 10.00 -waveform {0 5} [get_ports sys_clk]

## Reset Button (Center Pushbutton BTNC)
set_property PACKAGE_PIN U18 [get_ports sys_reset_btn]
set_property IOSTANDARD LVCMOS33 [get_ports sys_reset_btn]

## North-South LEDs: {Red=LD2, Yellow=LD1, Green=LD0}
set_property PACKAGE_PIN U19 [get_ports {led_ns[2]}] ;# Red (LED 2)
set_property IOSTANDARD LVCMOS33 [get_ports {led_ns[2]}]
set_property PACKAGE_PIN E19 [get_ports {led_ns[1]}] ;# Yellow (LED 1)
set_property IOSTANDARD LVCMOS33 [get_ports {led_ns[1]}]
set_property PACKAGE_PIN U16 [get_ports {led_ns[0]}] ;# Green (LED 0)
set_property IOSTANDARD LVCMOS33 [get_ports {led_ns[0]}]

## East-West LEDs: {Red=LD15, Yellow=LD14, Green=LD13}
set_property PACKAGE_PIN L1 [get_ports {led_ew[2]}]  ;# Red (LED 15)
set_property IOSTANDARD LVCMOS33 [get_ports {led_ew[2]}]
set_property PACKAGE_PIN P1 [get_ports {led_ew[1]}]  ;# Yellow (LED 14)
set_property IOSTANDARD LVCMOS33 [get_ports {led_ew[1]}]
set_property PACKAGE_PIN N3 [get_ports {led_ew[0]}]  ;# Green (LED 13)
set_property IOSTANDARD LVCMOS33 [get_ports {led_ew[0]}]
```

### 2. Terasic DE10-Lite (Intel MAX 10 - `DE10_Lite.qsf`)

```tcl
# Clock (50 MHz MAX 10 Oscillator)
set_location_assignment PIN_P11 -to sys_clk

# Reset Button (KEY0, active-high via invert)
set_location_assignment PIN_B8 -to sys_reset_btn

# North-South LEDs (LEDR[2:0])
set_location_assignment PIN_B10 -to led_ns[2]
set_location_assignment PIN_A10 -to led_ns[1]
set_location_assignment PIN_A8  -to led_ns[0]

# East-West LEDs (LEDR[9:7])
set_location_assignment PIN_B11 -to led_ew[2]
set_location_assignment PIN_A11 -to led_ew[1]
set_location_assignment PIN_D14 -to led_ew[0]
```

---

## Part 3: Top 10 ASIC & Digital Design Interview Questions

### Q1: Why did you choose a Moore machine instead of a Mealy machine for this traffic light controller?
**Answer:**
In a traffic light controller, the outputs drive real physical lamps or high-current LED drivers. In a **Mealy machine**, outputs depend on both current state and input combinations, making them prone to combinational glitches and rippling transients whenever inputs change mid-cycle. In contrast, a **Moore machine's** outputs depend exclusively on state registers (`current_state`). Outputs change only synchronously on the active clock edge, guaranteeing glitch-free, safe operation.

---

### Q2: Why is the FSM coded using a 3-always-block structure rather than a single always block?
**Answer:**
The 3-always-block coding style separates:
1. **Sequential state & counter register logic** (`always @(posedge clk)`).
2. **Combinational next-state decoding** (`always @(*)`).
3. **Combinational output logic** (`always @(*)`).

Benefits include:
- Eliminates unintended latch inference because combinational paths explicitly define default assignments.
- Improves code readability and maintainability.
- Allows static timing analysis (STA) tools to clearly distinguish register-to-register setup/hold constraints from combinational input/output delays.

---

### Q3: What is the purpose of the default branch in the Moore output always block?
**Answer:**
The `default` branch implements a **failsafe emergency halt**:
```verilog
default: begin
    ns_red = 1'b1;
    ew_red = 1'b1;
end
```
If an illegal or unmapped state is entered (due to a Single Event Upset, cosmic ray flip, or voltage transient in an ASIC), the controller defaults to showing **Red in all directions**, preventing traffic collisions. Additionally, assigning defaults for all outputs prevents combinational latch synthesis.

---

### Q4: Explain the difference between synchronous reset and asynchronous reset. Which did you choose and why?
**Answer:**
- **Asynchronous reset** acts immediately without waiting for a clock edge (`always @(posedge clk or posedge reset)`). However, deassertion of an asynchronous reset near the clock edge can cause metastability (Reset Recovery / Removal timing violations).
- **Synchronous reset** is sampled only on the active clock edge (`always @(posedge clk)` with `if (reset)`).
- We chose **synchronous active-high reset** because it filters out spurious glitch pulses shorter than a clock period, makes the entire circuit 100% synchronous, and is preferred in high-reliability synchronous designs.

---

### Q5: How do you verify that both North-South and East-West Green lights never turn ON at the same time?
**Answer:**
We implement dual-layer safety:
1. **Design by Construction:** The Moore state encoding has only 4 orthogonal states: `S0` (NS Green, EW Red), `S1` (NS Yellow, EW Red), `S2` (NS Red, EW Green), and `S3` (NS Red, EW Yellow). There is no state that sets both Green outputs high.
2. **Dynamic Invariant Assertion in Testbench:** A concurrent monitor runs on every positive clock edge:
```verilog
always @(posedge clk) begin
    if (ns_green && ew_green) begin
        $display("[FATAL ERROR] Mutual exclusion violation! Both Greens ON!");
        fail_count = fail_count + 1;
    end
end
```
If both signals ever asserted simultaneously, the simulation would flag a fatal error and fail.

---

### Q6: What is the maximum operating frequency of this FSM on an FPGA?
**Answer:**
The critical path comprises:
1. Clock-to-Q delay of the state and counter registers ($T_{C2Q}$).
2. Combinational logic delay of the 6-bit comparator (`count >= GREEN_CYCLES - 1`) and 2-to-1 next-state multiplexer ($T_{logic}$).
3. Setup time of the destination register ($T_{setup}$).

$$T_{min} = T_{C2Q} + T_{logic} + T_{setup}$$

Because the counter is only 6 bits wide and state logic is 2 bits, the logic depth is very shallow (typically 1–2 LUT levels on a Xilinx 7-series FPGA). Consequently, $T_{min} \approx 2.5\text{ ns}$, allowing the design to easily close timing at **300+ MHz**.

---

### Q7: What state encoding scheme was used, and when would One-Hot encoding be preferred?
**Answer:**
We used **Binary Encoding** (`2'b00`, `2'b01`, `2'b10`, `2'b11`), which requires only $\lceil\log_2(4)\rceil = 2$ flip-flops.
In contrast, **One-Hot Encoding** uses 1 flip-flop per state (4 flip-flops total: `4'b0001`, `4'b0010`, `4'b0100`, `4'b1000`).
One-Hot is preferred in **FPGAs** with abundant flip-flops when state machines have many states (e.g., 8–32 states), because decoding next-state and output logic requires checking only a single bit, minimizing LUT levels and maximizing clock frequency. For a simple 4-state machine, binary encoding is compact and optimal.

---

### Q8: How did your testbench verify that the counter transitions at exactly the right clock cycle?
**Answer:**
The testbench uses a cycle-by-cycle sampling task `verify_state_duration`.
At entry (`cycle 0`), it confirms `count == 0` and the correct state. For each cycle up to `expected_cycles - 1`, it samples at `posedge clk` plus a delta `#1`, asserting that `uut.count == cycle_index`.
On the final cycle (`count == GREEN_CYCLES - 1`), it verifies that combinational `next_state` anticipates the upcoming state. On the very next clock edge, it verifies that `current_state` updates and `count` resets to `0`.

---

### Q9: How would you extend this controller to handle pedestrian crossing requests or emergency vehicle priority?
**Answer:**
1. Add an input `ped_request` or `emergency_sensor`.
2. Add a `ped_request` latch register. When pressed, store the request.
3. For emergency vehicles, introduce an emergency preempt state `S_EMERGENCY` that immediately forces Yellow on the active direction (for safe deceleration), followed by Red, and grants Green exclusively to the emergency direction until the vehicle clears.

---

### Q10: How do you prevent metastability when connecting physical push-button inputs (like reset) to the FPGA?
**Answer:**
Physical buttons are asynchronous and suffer from contact bounce. To safely interface them:
1. Pass the mechanical switch through a **debouncer filter** (a digital counter verifying the input remains stable for 10–20 ms).
2. Feed the debounced signal through a **2-flip-flop synchronizer** to eliminate metastability before driving the synchronous reset network.

