`timescale 1ns/1ns

// Scheduler module: Determines active threads in the block based on thread count
module scheduler #(
    parameter THREADS_PER_BLOCK = 4
) (
    input logic [$clog2(THREADS_PER_BLOCK):0] thread_count, // Number of active threads
    output logic [THREADS_PER_BLOCK-1:0] active_threads // Mask of active threads
);

    // Combinational logic to set active threads
    always_comb begin
        for (int t = 0; t < THREADS_PER_BLOCK; t++) begin
            active_threads[t] = (t < thread_count); // Thread is active if index < thread_count
        end
    end
endmodule
