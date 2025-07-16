`timescale 1ns/1ns

// Device Control Register
// > Stores the thread count for kernel execution
// > Updated when write enable is asserted
// > Resets to zero on reset
module dcr (
    input logic clk,                          // Clock signal
    input logic reset,                        // Reset signal
    input logic device_control_write_enable,  // Write enable for thread count
    input logic [7:0] device_control_data,    // Input thread count data
    output logic [7:0] thread_count            // Stored thread count
);
  always_ff @(posedge clk or negedge reset) begin
      if (~reset) begin
            thread_count <= 8'd0; // Reset thread count to 0
        end else if (device_control_write_enable) begin
            thread_count <= device_control_data; // Update thread count
        end
    end
endmodule
