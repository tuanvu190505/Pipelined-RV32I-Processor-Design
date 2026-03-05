module decode_stage (
    input  logic        i_clk,
    input  logic        i_rst,

    // IF/ID pipeline outputs
    input  logic [31:0] i_pc,
    input  logic [31:0] i_inst,

    // Writeback feedback into RegFile
    input  logic [31:0] i_wb_data,
    input  logic [4:0]  i_rd_wb,
    input  logic        i_wb_en,

    // Outputs into ID/EX pipeline register
    output logic [31:0] o_pc,
    output logic [31:0] o_inst,
    output logic [31:0] o_rs1_data,
    output logic [31:0] o_rs2_data,
    output logic [31:0] o_imm,
    output logic [3:0]  o_alu_sel,
    output logic        o_bru,
    output logic        o_memrw,
    output logic [2:0]  o_load_type,
    output logic [1:0]  o_wb_sel,
    output logic        o_regwen,
    output logic        o_asel,
    output logic        o_bsel,

    // For hazard/forward units
    output logic [4:0]  o_rs1,
    output logic [4:0]  o_rs2,
    output logic        o_insn_vld,
    output logic        o_is_ctrl
);

    logic [2:0] imm_sel;

    // Register file reads
    regfile rf (
        .clk    (i_clk),
        .reset  (i_rst),
        .rs1    (o_rs1),
        .rs2    (o_rs2),
        .rsW    (i_rd_wb),
        .data_W (i_wb_data),
        .regWEn (i_wb_en),
        .data_1 (o_rs1_data),
        .data_2 (o_rs2_data)
    );

    // Immediate generator
    Imm_Gen ig (
        .instr    (i_inst),
        .Imm_Sel  (imm_sel),
        .imm_out  (o_imm)
    );

    // Control logic
    control_unit cu (
        .instr      (i_inst),
        .Imm_Sel    (imm_sel),
        .ALU_sel    (o_alu_sel),
        .regWEn     (o_regwen),
        .BrUn       (o_bru),
        .opb_sel    (o_bsel),
        .opa_sel    (o_asel),
        .MemRW      (o_memrw),
        .WBSel      (o_wb_sel),
        .load_type  (o_load_type),
        .store_type (),
        .insn_vld   (o_insn_vld)
    );

    // Decode-time helpers
    assign o_rs1 = i_inst[19:15];
    assign o_rs2 = i_inst[24:20];

    assign o_pc   = i_pc;
    assign o_inst = i_inst;

    // Identify control-flow instructions (for debug/trace)
    assign o_is_ctrl =
            (i_inst[6:0] == 7'b1100011) || // Branch
            (i_inst[6:0] == 7'b1101111) || // JAL
            (i_inst[6:0] == 7'b1100111);   // JALR

endmodule
