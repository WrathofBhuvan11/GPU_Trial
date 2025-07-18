`timescale 1ns/1ns

module dispatch #(
    parameter NUM_CORES = 2,                 // Number of compute cores in the GPU
    parameter THREADS_PER_BLOCK = 4          // Number of threads per block
) (
    input clk,                               // Clock signal for synchronous operation
    input reset,                             // Active-low reset signal to initialize module state
    input start,                             // Start signal to initiate kernel execution
    input logic [7:0] thread_count,          // Total number of threads for the kernel
    input logic [NUM_CORES-1:0] core_done,   // Done signals from each core indicating block completion
    output logic [NUM_CORES-1:0] core_start, // Start signals to initiate execution on each core
    output logic [NUM_CORES-1:0] core_reset, // Reset signals to reset each core
    output logic [NUM_CORES-1:0][7:0] core_block_id, // Block IDs assigned to each core
    output logic [NUM_CORES-1:0][$clog2(THREADS_PER_BLOCK):0] core_thread_count, // Thread counts for each core's block
    output logic done                        // Done signal indicating all blocks are processed
);
    logic [7:0] num_blocks;                  // Total number of blocks needed for the kernel
    logic [7:0] next_block;                  // Index of the next block to assign
    logic [NUM_CORES-1:0] core_busy;         // Busy status for each core (1 = busy, 0 = free)

    // Calculate the number of blocks using ceiling division
    // Divides thread_count by THREADS_PER_BLOCK, rounding up to ensure all threads are covered
    always_comb begin
        num_blocks = (thread_count + THREADS_PER_BLOCK - 1) / THREADS_PER_BLOCK;
    end

    // Main dispatching logic
    // > Handles reset, block assignment, and completion monitoring
    always_ff @(posedge clk or negedge reset) begin
        if (~reset) begin
            // Reset condition: initialize all signals
            next_block <= 0;                 // Start from block 0
            core_busy <= '0;                 // Mark all cores as free
            done <= 0;                       // Clear done signal
            core_start <= '0;                // Do not start any core
            core_reset <= '1;                // Assert reset for all cores
            for (int i = 0; i < NUM_CORES; i++) begin
                core_block_id[i] <= 0;       // Clear block IDs
                core_thread_count[i] <= 0;   // Clear thread counts
            end
        end else begin
            // Normal operation: deassert reset for all cores
            core_reset <= '0;
            if (start && !done) begin
                // Assign blocks to available cores when kernel is active
                for (int i = 0; i < NUM_CORES; i++) begin
                    if (!core_busy[i] && next_block < num_blocks) begin
                        core_start[i] <= 1;  // Activate the core to start processing
                        core_block_id[i] <= next_block; // Assign the current block ID
                        // Calculate thread count for the block
                        // Full block if enough threads remain, otherwise partial block
                        core_thread_count[i] <= (next_block + 1) * THREADS_PER_BLOCK <= thread_count ? THREADS_PER_BLOCK : thread_count - next_block * THREADS_PER_BLOCK;
                        core_busy[i] <= 1;   // Mark core as busy
                        next_block <= next_block + 1; // Move to the next block
                    end else begin
                        core_start[i] <= 0;  // Do not start if core is busy or no blocks remain
                    end
                end
                // Check if all blocks are assigned and all cores are free
                if (next_block >= num_blocks && core_busy == '0) begin
                    done <= 1;               // Signal that kernel execution is complete
                end
            end else if (!start) begin
                // Clear done signal when start is deasserted
                done <= 0;
            end
            // Monitor core completion
            // Clear busy status when a core signals completion
            for (int i = 0; i < NUM_CORES; i++) begin
                if (core_done[i]) begin
                    core_busy[i] <= 0;       // Mark core as free
                end
            end
        end
    end
endmodule
