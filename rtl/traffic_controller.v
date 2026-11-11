// ============================================================================
// File:        traffic_controller.v
// Module:      traffic_controller
// Project:     FSM-Based Traffic Light Controller using Verilog HDL
// Description: Synthesizable Moore Finite State Machine (FSM) implementation
//              for a 4-way intersection (North-South & East-West directions).
//              Features configurable Green and Yellow durations, counter-based
//              timing, and synchronous active-high reset.
// ============================================================================

`timescale 1ns / 1ps

module traffic_controller #(
    parameter GREEN_CYCLES  = 10,   // Number of clock cycles for Green light
    parameter YELLOW_CYCLES = 3,    // Number of clock cycles for Yellow light
    parameter COUNTER_WIDTH = 6     // Bit-width of the cycle counter
)(
    input  wire clk,                // System clock
    input  wire reset,              // Synchronous active-high reset
    output reg  ns_red,             // North-South Red signal
    output reg  ns_yellow,          // North-South Yellow signal
    output reg  ns_green,           // North-South Green signal
    output reg  ew_red,             // East-West Red signal
    output reg  ew_yellow,          // East-West Yellow signal
    output reg  ew_green            // East-West Green signal
);

    // ========================================================================
    // State Encoding (Moore FSM - 4 States)
    // ========================================================================
    localparam [1:0] S0_NS_GREEN  = 2'b00; // NS: Green,  EW: Red
    localparam [1:0] S1_NS_YELLOW = 2'b01; // NS: Yellow, EW: Red
    localparam [1:0] S2_EW_GREEN  = 2'b10; // NS: Red,    EW: Green
    localparam [1:0] S3_EW_YELLOW = 2'b11; // NS: Red,    EW: Yellow

    // State registers & Counter
    reg [1:0] current_state;
    reg [1:0] next_state;
    reg [COUNTER_WIDTH-1:0] count;

    // ========================================================================
    // Block 1: Sequential State & Counter Update (Synchronous Reset)
    // ========================================================================
    always @(posedge clk) begin
        if (reset) begin
            current_state <= S0_NS_GREEN;
            count         <= {COUNTER_WIDTH{1'b0}};
        end else begin
            current_state <= next_state;
            if (current_state != next_state) begin
                // Reset counter on every state transition
                count <= {COUNTER_WIDTH{1'b0}};
            end else begin
                // Increment counter while remaining in the same state
                count <= count + 1'b1;
            end
        end
    end

    // ========================================================================
    // Block 2: Combinational Next-State Logic
    // Determines next state based on current state and elapsed counter cycles
    // ========================================================================
    always @(*) begin
        case (current_state)
            S0_NS_GREEN: begin
                if (count >= (GREEN_CYCLES - 1))
                    next_state = S1_NS_YELLOW;
                else
                    next_state = S0_NS_GREEN;
            end

            S1_NS_YELLOW: begin
                if (count >= (YELLOW_CYCLES - 1))
                    next_state = S2_EW_GREEN;
                else
                    next_state = S1_NS_YELLOW;
            end

            S2_EW_GREEN: begin
                if (count >= (GREEN_CYCLES - 1))
                    next_state = S3_EW_YELLOW;
                else
                    next_state = S2_EW_GREEN;
            end

            S3_EW_YELLOW: begin
                if (count >= (YELLOW_CYCLES - 1))
                    next_state = S0_NS_GREEN;
                else
                    next_state = S3_EW_YELLOW;
            end

            default: begin
                next_state = S0_NS_GREEN;
            end
        endcase
    end

    // ========================================================================
    // Block 3: Moore Output Logic
    // Outputs depend solely on the current state.
    // Conflicting green signals (ns_green & ew_green) are guaranteed mutually
    // exclusive by design.
    // ========================================================================
    always @(*) begin
        // Safe default assignments
        ns_red    = 1'b0;
        ns_yellow = 1'b0;
        ns_green  = 1'b0;
        ew_red    = 1'b0;
        ew_yellow = 1'b0;
        ew_green  = 1'b0;

        case (current_state)
            S0_NS_GREEN: begin
                ns_green = 1'b1;
                ew_red   = 1'b1;
            end

            S1_NS_YELLOW: begin
                ns_yellow = 1'b1;
                ew_red    = 1'b1;
            end

            S2_EW_GREEN: begin
                ns_red   = 1'b1;
                ew_green = 1'b1;
            end

            S3_EW_YELLOW: begin
                ns_red    = 1'b1;
                ew_yellow = 1'b1;
            end

            default: begin
                // Failsafe condition: Red in both directions
                ns_red = 1'b1;
                ew_red = 1'b1;
            end
        endcase
    end

endmodule

