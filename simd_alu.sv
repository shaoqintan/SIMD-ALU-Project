typedef struct packed {
  logic valid;
  logic ready;
  logic [2:0] opcode;
  logic [7:0] A;
  logic [7:0] B;
} RS_Entry;


module simd_lane #(
    parameter int lanes = 4, parameter RS_SIZE = 4
    ) (
        input clk, 
        input reset, 
        input logic mark_ready_valid, 
        input logic[RS_SIZE-1:0] mark_ready_idx, 
        input instr_valid, 
        input logic[7:0] A, 
        input logic[7:0] B, 
        input logic[2:0] opcode, 
        output logic[8:0] result,
        output logic [RS_SIZE-1:0] tail_ptr_out
    );

    RS_Entry rs[RS_SIZE];
    logic[1:0] rs_head;
    logic[1:0] rs_tail;
    always_ff @(posedge clk) begin
        if (instr_valid) begin
            rs[rs_tail].opcode <= opcode;
            rs[rs_tail].A <= A;
            rs[rs_tail].B <= B;
            rs[rs_tail].valid <= 1;
            rs[rs_tail].ready <= 0;
            tail_ptr_out <= rs_tail;
            rs_tail <= (rs_tail + 1) % RS_SIZE;
        end else if (mark_ready_valid) begin
            rs[mark_ready_idx].ready <= 1;
        end
    end
    always_ff @(posedge clk or posedge reset) begin
        if (reset) begin
            result <= 0;   
        end else begin
            if (rs[rs_head].ready && rs[rs_head].valid) begin
                logic [2:0] opcode_exec;
                logic [7:0] A_exec, B_exec;
                opcode_exec = rs[rs_head].opcode;
                A_exec = rs[rs_head].A;
                B_exec = rs[rs_head].B;
                case(opcode_exec)
                    3'b000: begin
                        result <= A_exec + B_exec;
                    end
                    3'b001: begin
                        result <= A_exec - B_exec;
                    end
                    3'b010: begin
                        result <= A_exec | B_exec;
                    end
                    3'b011: begin
                        result <= A_exec & B_exec;
                    end
                    3'b100: begin
                        result <= A_exec ^ B_exec;
                    end
                    default: result <= 0;
                endcase
                rs[rs_head].valid <= 0;
                rs_head <= (rs_head + 1) % RS_SIZE;
            end
        end
    end
endmodule

module simd_unit #(
    parameter int lanes = 4, 
    parameter int RS_SIZE = 4
    ) (
        input logic clk, 
        input logic reset, 
        input logic mark_ready_valid[lanes], 
        input logic[RS_SIZE-1:0] mark_ready_idx [lanes], 
        input logic instr_valid, 
        input logic[7:0] A, 
        input logic[7:0] B, 
        input logic[2:0] opcode, 
        output logic[8:0] result[lanes], 
        output logic [lanes-1:0] issued_lane,
        output logic [RS_SIZE-1:0] issued_rs_index
    );
    genvar i;
    logic[1:0] rr_sequence;
    logic [lanes-1:0] lane_instr_valid;
    always_ff @(posedge clk or posedge reset) begin
        if (reset) begin
            rr_sequence <= 0;
        end else if (instr_valid) begin
            rr_sequence <= (rr_sequence + 1) % lanes;
        end
    end
    always_comb begin
        lane_instr_valid = '0;
        if (instr_valid) begin
            lane_instr_valid[rr_sequence] = 1;
        end
    end
    logic [RS_SIZE-1:0] tail_ptr_out[lanes];
    assign issued_lane = rr_sequence;
    assign issued_rs_index = tail_ptr_out[rr_sequence];
    generate
        for (i = 0; i < lanes; i++) begin
            simd_lane lane_i (
                .clk(clk),
                .reset(reset),
                .A(A),
                .B(B),
                .opcode(opcode),
                .instr_valid(lane_instr_valid[i]),
                .mark_ready_valid(mark_ready_valid[i]),
                .mark_ready_idx(mark_ready_idx[i]),
                .result(result[i]),
                .tail_ptr_out(tail_ptr_out[i])
            );
        end
    endgenerate
endmodule
