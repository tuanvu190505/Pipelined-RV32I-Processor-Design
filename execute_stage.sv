module execute_stage (
    input  logic [31:0] i_pc,
    input  logic [31:0] i_inst,
    input  logic [31:0] i_rs1,
    input  logic [31:0] i_rs2,
    input  logic [31:0] i_imm,
    input  logic        i_asel,
    input  logic        i_bsel,
    input  logic        i_bru,
    input  logic [3:0]  i_alu_sel,
    input  logic [1:0]  i_fwdA_sel, 
    input  logic [1:0]  i_fwdB_sel,
    input  logic [31:0] i_alu_mem,
    input  logic [31:0] i_wb_data,

    output logic [31:0] o_alu,
    output logic [31:0] o_rs2_fwd,
    output logic [31:0] o_pc_target,
    output logic        o_pc_sel
);

    logic [31:0] forwardA, forwardB;
    logic [31:0] opA, opB;
    logic [31:0] pc_plus_imm, jalr_sum;
    logic        BrEq, BrLT;
    logic [2:0]  funct3;
    logic        is_branch, is_jal, is_jalr;
    logic        branch_condition_met;

    assign funct3    = i_inst[14:12];
    assign is_branch = (i_inst[6:0] == 7'b1100011);
    assign is_jal    = (i_inst[6:0] == 7'b1101111);
    assign is_jalr   = (i_inst[6:0] == 7'b1100111);

    always_comb begin
        case (i_fwdA_sel)
            2'b10:   forwardA = i_alu_mem;
            2'b01:   forwardA = i_wb_data;
            default: forwardA = i_rs1;
        endcase
    end

    always_comb begin
        case (i_fwdB_sel)
            2'b10:   forwardB = i_alu_mem;
            2'b01:   forwardB = i_wb_data;
            default: forwardB = i_rs2;
        endcase
    end

    assign opA = (i_asel) ? i_pc : forwardA;
    assign opB = (i_bsel) ? i_imm : forwardB;

    ALU alu_instance (
        .i_op_a     (opA),
        .i_op_b     (opB),
        .i_alu_op   (i_alu_sel),
        .o_alu_data (o_alu)
    );

    brc brc_instance (
        .i_rs1_data (forwardA),
        .i_rs2_data (forwardB),
        .i_br_un    (i_bru),
        .o_br_less  (BrLT),
        .o_br_equal (BrEq)
    );

    Add_Sub_32bit adder_pc_imm (
        .A(i_pc),
        .B(i_imm),
        .Sel(1'b0),
        .Y(pc_plus_imm),
        .Carry_out(),
        .overflow()
    );

    Add_Sub_32bit adder_jalr (
        .A(forwardA),
        .B(i_imm),
        .Sel(1'b0),
        .Y(jalr_sum),
        .Carry_out(),
        .overflow()
    );

    always_comb begin
        case (funct3)
            3'b000:  branch_condition_met = BrEq;
            3'b001:  branch_condition_met = ~BrEq;
            3'b100:  branch_condition_met = BrLT;
            3'b101:  branch_condition_met = ~BrLT;
            3'b110:  branch_condition_met = BrLT;
            3'b111:  branch_condition_met = ~BrLT;
            default: branch_condition_met = 1'b0;
        endcase
    end

    assign o_pc_sel = is_jal || is_jalr || (is_branch && branch_condition_met);

    always_comb begin
        if (is_jalr) begin
            o_pc_target = {jalr_sum[31:2], 2'b00};
        end else begin
            o_pc_target = {pc_plus_imm[31:2], 2'b00};
        end
    end

    assign o_rs2_fwd = forwardB;

endmodule
