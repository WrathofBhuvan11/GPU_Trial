`default_nettype none
`timescale 1ns/1ns

// Compute Core module: Executes instructions for a block of threads in SIMD fashion
module compute_core #(
    parameter DATA_MEM_ADDR_BITS = 8,
    parameter DATA_MEM_DATA_BITS = 8,
    parameter PROGRAM_MEM_ADDR_BITS = 8,
    parameter PROGRAM_MEM_DATA_BITS = 16,
    parameter THREADS_PER_BLOCK = 4
) (
    input wire clk,
    input wire reset,
    input wire start,
    output reg done,
    input wire [7:0] block_id,
    input wire [$clog2(THREADS_PER_BLOCK):0] thread_count,
    output reg program_mem_read_valid,
    output reg [PROGRAM_MEM_ADDR_BITS-1:0] program_mem_read_address,
    input wire program_mem_read_ready,
    input wire [PROGRAM_MEM_DATA_BITS-1:0] program_mem_read_data,
    output reg [THREADS_PER_BLOCK-1:0] data_mem_read_valid,
    output reg [DATA_MEM_ADDR_BITS-1:0] data_mem_read_address [THREADS_PER_BLOCK-1:0],
    input wire [THREADS_PER_BLOCK-1:0] data_mem_read_ready,
    input wire [DATA_MEM_DATA_BITS-1:0] data_mem_read_data [THREADS_PER_BLOCK-1:0],
    output reg [THREADS_PER_BLOCK-1:0] data_mem_write_valid,
    output reg [DATA_MEM_ADDR_BITS-1:0] data_mem_write_address [THREADS_PER_BLOCK-1:0],
    output reg [DATA_MEM_DATA_BITS-1:0] data_mem_write_data [THREADS_PER_BLOCK-1:0],
    input wire [THREADS_PER_BLOCK-1:0] data_mem_write_ready
);

    // Internal signals
    reg [PROGRAM_MEM_ADDR_BITS-1:0] PC;
    reg [15:0] instruction;
    reg [3:0] opcode, Rd, Rs, Rt;
    reg [7:0] IMM8;
    reg [3:0] condition;
    reg is_nop, is_branch, is_cmp, is_add, is_sub, is_mul, is_div, is_ldr, is_str, is_const, is_halt;
    reg [7:0] reg_data1 [0:THREADS_PER_BLOCK-1];
    reg [7:0] reg_data2 [0:THREADS_PER_BLOCK-1];
    reg [7:0] write_data [0:THREADS_PER_BLOCK-1];
    reg write_enable [0:THREADS_PER_BLOCK-1];
    reg [3:0] write_addr;
    reg [7:0] alu_result [0:THREADS_PER_BLOCK-1];
    reg [2:0] NZP [0:THREADS_PER_BLOCK-1];
    reg [2:0] thread_NZP [0:THREADS_PER_BLOCK-1];
    reg active [0:THREADS_PER_BLOCK-1];
    reg fetch_enable, fetch_done;
    reg load_pc;
    reg [PROGRAM_MEM_ADDR_BITS-1:0] next_pc;

    // Submodule instances
    fetch #(.PROGRAM_MEM_ADDR_BITS(PROGRAM_MEM_ADDR_BITS), .PROGRAM_MEM_DATA_BITS(PROGRAM_MEM_DATA_BITS)) fetch_inst (
        .clk(clk),
        .reset(reset),
        .enable(fetch_enable),
        .PC(PC),
        .program_mem_read_valid(program_mem_read_valid),
        .program_mem_read_address(program_mem_read_address),
        .program_mem_read_ready(program_mem_read_ready),
        .program_mem_read_data(program_mem_read_data),
        .instruction(instruction),
        .fetch_done(fetch_done)
    );

    decoder decoder_inst (
        .instruction(instruction),
        .opcode(opcode),
        .Rd(Rd),
        .Rs(Rs),
        .Rt(Rt),
        .IMM8(IMM8),
        .condition(condition),
        .is_nop(is_nop),
        .is_branch(is_branch),
        .is_cmp(is_cmp),
        .is_add(is_add),
        .is_sub(is_sub),
        .is_mul(is_mul),
        .is_div(is_div),
        .is_ldr(is_ldr),
        .is_str(is_str),
        .is_const(is_const),
        .is_halt(is_halt)
    );

    program_counter #(.PROGRAM_MEM_ADDR_BITS(PROGRAM_MEM_ADDR_BITS)) pc_inst (
        .clk(clk),
        .reset(reset),
        .load(load_pc),
        .next_pc(next_pc),
        .PC(PC)
    );

    // Per-thread instances
    generate
        for (genvar t = 0; t < THREADS_PER_BLOCK; t++) begin : threads
            registers registers_inst (
                .clk(clk),
                .reset(reset),
                .read_addr1(Rs),
                .read_addr2(Rt),
                .read_data1(reg_data1[t]),
                .read_data2(reg_data2[t]),
                .write_addr(write_addr),
                .write_data(write_data[t]),
                .write_enable(write_enable[t]),
                .block_id(block_id),
                .thread_id(t[7:0]),
                .threads_per_block(THREADS_PER_BLOCK[7:0])
            );

            simple_alu alu_inst (
                .A(reg_data1[t]),
                .B(reg_data2[t]),
                .operation(opcode),
                .result(alu_result[t]),
                .NZP(NZP[t])
            );

            load_store_unit #(.DATA_MEM_ADDR_BITS(DATA_MEM_ADDR_BITS), .DATA_MEM_DATA_BITS(DATA_MEM_DATA_BITS)) lsu_inst (
                .clk(clk),
                .reset(reset),
                .load_enable(is_ldr && active[t]),
                .store_enable(is_str && active[t]),
                .address(reg_data1[t]),
                .store_data(reg_data2[t]),
                .load_data(write_data[t]),
                .data_mem_read_valid(data_mem_read_valid[t]),
                .data_mem_read_address(data_mem_read_address[t]),
                .data_mem_read_ready(data_mem_read_ready[t]),
                .data_mem_read_data(data_mem_read_data[t]),
                .data_mem_write_valid(data_mem_write_valid[t]),
                .data_mem_write_address(data_mem_write_address[t]),
                .data_mem_write_data(data_mem_write_data[t]),
                .data_mem_write_ready(data_mem_write_ready[t]),
                .lsu_done()
            );
        end
    endgenerate

    // Determine active threads
    always_comb begin
        for (int t = 0; t < THREADS_PER_BLOCK; t++) begin
            active[t] = (t < thread_count);
        end
    end

    // State machine for instruction execution
    enum logic [2:0] {IDLE, FETCH, DECODE_EXECUTE} state;

    always_ff @(posedge clk or posedge reset) begin
        if (reset) begin
            state <= IDLE;
            done <= 0;
            fetch_enable <= 0;
            load_pc <= 0;
            next_pc <= 0;
            for (int t = 0; t < THREADS_PER_BLOCK; t++) begin
                thread_NZP[t] <= 0;
                write_enable[t] <= 0;
                data_mem_read_valid[t] <= 0;
                data_mem_write_valid[t] <= 0;
            end
        end else begin
            case (state)
                IDLE: if (start) begin
                    state <= FETCH;
                    fetch_enable <= 1;
                    done <= 0;
                end
                FETCH: if (fetch_done) begin
                    state <= DECODE_EXECUTE;
                    fetch_enable <= 0;
                end
                DECODE_EXECUTE: begin
                    case (opcode)
                        4'b0000: begin // NOP
                            load_pc <= 0;
                            state <= FETCH;
                            fetch_enable <= 1;
                        end
                        4'b0001: begin // BRNzp
                            logic take_branch = 0;
                            for (int t = 0; t < THREADS_PER_BLOCK; t++) begin
                                if (active[t] && ((thread_NZP[t] & condition[2:0]) != 0)) take_branch = 1;
                            end
                            load_pc <= take_branch;
                            next_pc <= take_branch ? IMM8 : PC + 1;
                            state <= FETCH;
                            fetch_enable <= 1;
                        end
                        4'b0010: begin // CMP
                            for (int t = 0; t < THREADS_PER_BLOCK; t++) begin
                                if (active[t]) thread_NZP[t] <= NZP[t];
                            end
                            load_pc <= 0;
                            state <= FETCH;
                            fetch_enable <= 1;
                        end
                        4'b0011, 4'b0100, 4'b0101, 4'b0110: begin // ADD, SUB, MUL, DIV
                            for (int t = 0; t < THREADS_PER_BLOCK; t++) begin
                                write_enable[t] <= active[t] && Rd < 13;
                                write_data[t] <= alu_result[t];
                            end
                            write_addr <= Rd;
                            load_pc <= 0;
                            state <= FETCH;
                            fetch_enable <= 1;
                        end
                        4'b0111: begin // LDR
                            for (int t = 0; t < THREADS_PER_BLOCK; t++) begin
                                if (active[t] && Rd < 13) begin
                                    data_mem_read_valid[t] <= 1;
                                    data_mem_read_address[t] <= reg_data1[t];
                                    if (data_mem_read_ready[t]) begin
                                        write_data[t] <= data_mem_read_data[t];
                                        write_enable[t] <= 1;
                                    end else begin
                                        write_enable[t] <= 0;
                                    end
                                end else begin
                                    data_mem_read_valid[t] <= 0;
                                    write_enable[t] <= 0;
                                end
                            end
                            write_addr <= Rd;
                            load_pc <= 0;
                            state <= FETCH;
                            fetch_enable <= 1;
                        end
                        4'b1000
