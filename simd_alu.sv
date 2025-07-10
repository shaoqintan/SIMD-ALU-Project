typedef struct packed {
  logic valid;
  logic ready;
  logic [2:0] opcode;
  logic [7:0] A;
  logic [7:0] B;
} RS_Entry;


module simd_lane #(parameter int lanes = 4, parameter RS_SIZE = 4) (input clk, input reset, input logic[7:0] A, input logic[7:0] B, input logic[2:0] opcode, output logic[8:0] result);
    RS_Entry rs[RS_SIZE];
    logic[1:0] rs_head;
    logic[1:0] rs_tail;
    always_ff @(posedge clk) begin
        rs[rs_tail].opcode <= opcode;
        rs[rs_tail].A <= A;
        rs[rs_tail].B <= B;
        rs[rs_tail].valid <= 1;
        rs <= (rs_tail + 1) % RS_SIZE;
    end
    always_ff @(posedge clk or posedge reset) begin
        if (reset) begin
            result <= 0;   
        end else begin
            if (rs[rs_head].ready and rs[rs_head].valid) begin
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

module simd_unit #(parameter int lanes = 4) (input clk, input reset, input logic[7:0] A, input logic[7:0] B, input logic[2:0] opcode, output logic[8:0] result[lanes]);
    genvar i;
    generate
        for (i = 0; i < lanes; i++) begin
            simd_lane lane_i (
                .clk(clk),
                .A(A),
                .B(B),
                .opcode(opcode),
                .result(result[i])
            )
        end
    endgenerate
endmodule
