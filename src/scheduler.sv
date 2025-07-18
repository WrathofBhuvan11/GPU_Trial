`timescale 1ns/1ns

// Scheduler module: Determines active threads in the block based on thread count
// and handles branch logic for next_pc and load_pc
module scheduler #(
    parameter THREADS_PER_BLOCK = 4,
    parameter PROGRAM_MEM_ADDR_BITS = 8
) (
    input clk,                   // Clock signal
    input reset,                 // Reset signal
    input logic [$clog2(THREADS_PER_BLOCK):0] thread_count, // Number of active threads
    input logic is_branch,
    input logic [2:0] condition, // Reduced to 3 bits assuming NZP mapping
    input logic [7:0] IMM8,
    input logic [PROGRAM_MEM_ADDR_BITS-1:0] PC,
    input logic [THREADS_PER_BLOCK-1:0][2:0] NZP,
    input core_state_t core_state, // From compute_core state
    output logic [THREADS_PER_BLOCK-1:0] active_threads, // Mask of active threads
    output logic [PROGRAM_MEM_ADDR_BITS-1:0] next_pc,
    output logic load_pc
);

    // Combinational logic to set active threads
    always_comb begin
        for (int t = 0; t < THREADS_PER_BLOCK; t++) begin
            active_threads[t] = (t < thread_count); // Thread is active if index < thread_count
        end
    end

    // Combinational calculation for branch logic
    logic [PROGRAM_MEM_ADDR_BITS-1:0] temp_next_pc;
    logic temp_load_pc;

    always_comb begin
        logic [THREADS_PER_BLOCK-1:0] branch_taken;
        logic all_taken;
        logic all_not_taken;
        logic signed [PROGRAM_MEM_ADDR_BITS-1:0] offset;

        all_taken = 1'b1;
        all_not_taken = 1'b1;
        offset = {{(PROGRAM_MEM_ADDR_BITS-8){IMM8[7]}}, IMM8};  // Sign-extend IMM8 for offset

        // Default: no branch
        temp_next_pc = PC + 1;
        temp_load_pc = 1'b0;

        // Compute per-thread branch taken (assuming condition[2:0] maps to nzp bits)
        for (int t = 0; t < THREADS_PER_BLOCK; t++) begin
            if (active_threads[t]) begin
                branch_taken[t] = (NZP[t] & condition) != 3'b000;
                all_taken &= branch_taken[t];
                all_not_taken &= ~branch_taken[t];
            end else begin
                branch_taken[t] = 1'b0;  // Inactive threads don't affect decision
            end
        end

        if (is_branch && (core_state == EXECUTE)) begin
            // Check for divergence
            if (~(all_taken | all_not_taken)) begin
                // Divergence detected; in full design, handle with scheduler stack/masking
                // For now, proceed with 'all'
            end

            //'all': branch only if all active threads take it
            if (all_taken) begin
                temp_next_pc = PC + offset;
                temp_load_pc = 1'b1;
            end
        end
    end

    // Sequential registration of combinational results
    always_ff @(posedge clk or negedge reset) begin
        if (~reset) begin
            next_pc <= {PROGRAM_MEM_ADDR_BITS{1'b0}};
            load_pc <= 1'b0;
        end else begin
            next_pc <= temp_next_pc;
            load_pc <= temp_load_pc;
        end
    end

endmodule
