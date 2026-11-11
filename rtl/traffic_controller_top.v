// ============================================================================
// File:        traffic_controller_top.v
// Module:      traffic_controller_top
// Project:     FSM-Based Traffic Light Controller using Verilog HDL
// Description: Physical FPGA top-level wrapper for traffic_controller.
//              Integrates a clock frequency divider that converts high-frequency
//              on-board oscillators (e.g. 100 MHz on Digilent Basys 3 / Nexys A7)
//              down to a human-observable 1 Hz clock rate (10 seconds Green,
//              3 seconds Yellow) to directly drive physical board LEDs.
// ============================================================================

`timescale 1ns / 1ps

module traffic_controller_top #(
    parameter CLK_FREQ_HZ  = 100_000_000, // 100 MHz board oscillator
    parameter TICK_FREQ_HZ = 1,           // 1 Hz target clock (1 cycle per second)
    parameter GREEN_SECS   = 10,          // 10 seconds Green light duration
    parameter YELLOW_SECS  = 3            // 3 seconds Yellow light duration
)(
    input  wire sys_clk,                  // On-board 100 MHz clock input
    input  wire sys_reset_btn,            // Physical reset push-button (active-high)
    output wire [2:0] led_ns,             // {Red, Yellow, Green} for North-South
    output wire [2:0] led_ew              // {Red, Yellow, Green} for East-West
);

    // ========================================================================
    // 1. Clock Divider: 100 MHz -> 1 Hz
    // Toggles slow_clk every 50,000,000 cycles (500 ms) to create 1 Hz (50% duty)
    // ========================================================================
    localparam TOGGLE_LIMIT = (CLK_FREQ_HZ / (2 * TICK_FREQ_HZ)) - 1;
    reg [$clog2(TOGGLE_LIMIT):0] clk_div_count = 0;
    reg slow_clk = 1'b0;

    always @(posedge sys_clk) begin
        if (sys_reset_btn) begin
            clk_div_count <= 0;
            slow_clk      <= 1'b0;
        end else if (clk_div_count >= TOGGLE_LIMIT) begin
            clk_div_count <= 0;
            slow_clk      <= ~slow_clk;
        end else begin
            clk_div_count <= clk_div_count + 1'b1;
        end
    end

    // ========================================================================
    // 2. Instantiate Core Traffic Light Controller
    // ========================================================================
    wire ns_r, ns_y, ns_g;
    wire ew_r, ew_y, ew_g;

    traffic_controller #(
        .GREEN_CYCLES(GREEN_SECS),
        .YELLOW_CYCLES(YELLOW_SECS),
        .COUNTER_WIDTH(6)
    ) u_traffic_core (
        .clk(slow_clk),
        .reset(sys_reset_btn),
        .ns_red(ns_r),
        .ns_yellow(ns_y),
        .ns_green(ns_g),
        .ew_red(ew_r),
        .ew_yellow(ew_y),
        .ew_green(ew_g)
    );

    // Output assignments for board LEDs: {Red, Yellow, Green}
    assign led_ns = {ns_r, ns_y, ns_g};
    assign led_ew = {ew_r, ew_y, ew_g};

endmodule
