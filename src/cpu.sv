//`include "SRAM_wrapper.sv"
//`include "mux.sv"
`include "control_uint.sv"
`include "stageregister.sv"
`include "access_memory.sv"
`include "pc.sv"
`include "Imm_Gen.sv"
//`include "forward_ctrl.sv"
`include "regfile.sv"
//`include "hazard_ctrl.sv"
`include "alu.sv"
`include "alucontrol.sv"
//`include "branch_ctrl.sv"

// mux.sv hazard_ctrl.sv branch_ctrl.sv forward_ctrl.sv
/*
module top(input clk,
            input rst);
*/    
module cpu(input clk,
           input rst,
           input [31:0] IMinstr,
           input [31:0] DMdata,
           output MEM_Memread,
           output MEM_Memwrite,
           output logic [3:0] wen,
           output logic [31:0] datatoDM,
           output logic [13:0] IMaddr,
           output logic [13:0] DMaddr
           );
  
    logic [31:0] pc_in,pc_out,pc_add_4,EX_pcaddimm;
    logic flush,signalflush,IFIDwrite,PCwrite;
    logic [1:0] branchsel;
    logic [31:0] EX_aluout,EX_pc,EX_imm;

  
    //add_imm pcaddfour(pc_out,32'd4,pc_add_4);
    assign pc_add_4 = pc_out + 32'd4;
    
    MUX3to1 muxpc(EX_aluout,EX_pcaddimm,pc_add_4,branchsel,pc_in);	

    
    program_counter pc(clk,rst,pc_in,PCwrite,pc_out);
    //SRAM_wrapper IM1(~clk,1'b1,1'b1,4'b1111,pc_out[15:2],32'd0,IMinstr);
    assign IMaddr = pc_out[15:2];
	
    logic [31:0] instr;
    //MUX2to1 flushmux(IMinstr,32'd0,flush,instr);    
    assign instr = (flush)?32'd0:IMinstr;
    
    logic [1:0] Branch;
    logic zeroflag;



    logic [31:0] ID_insresult,ID_instr;
    logic [31:0] ID_pc;
    logic[4:0] IDrd,IDrs1,IDrs2;
    logic[2:0] funct3;
    logic[6:0] funct7;
    logic[31:0] imm;
    logic[31:0] rs1data,rs2data;
    
    IFID_reg IFIDstage(clk,rst,
                IFIDwrite,
                pc_out,
                instr,
                
                ID_pc,
                ID_instr);
    
    
    //MUX2to1 flushIDmux(ID_instr,32'd0,flush,ID_insresult);  
    assign ID_insresult = (flush)?32'd0:ID_instr;

    assign IDrd=ID_insresult[11:7];
    assign funct3=ID_insresult[14:12];
    assign IDrs1=ID_insresult[19:15];
    assign IDrs2=ID_insresult[24:20];
    assign funct7=ID_insresult[31:25];

    
    Imm_Gen immediate_gen(ID_insresult,imm);

    logic [2:0] Aluop;
    logic Alusrc,Memread,Memwrite,Memtoreg,Regwrite,PCtoregsrc,RDsrc;
    
    control_unit CtrlUnit(ID_insresult[6:0],
                          Aluop,
                          Branch,
                         
                          Alusrc,
                          RDsrc,
                          PCtoregsrc,
                          Regwrite,
                          Memread,
                          Memwrite,
                          Memtoreg);

    logic WB_Regwrite;
    logic [4:0] WB_rdnum;
    logic [31:0] WB_wb_data;

    regfile rf(~clk,rst,IDrs1,IDrs2,WB_rdnum,WB_Regwrite,WB_wb_data,rs1data,rs2data);

    logic [11:0] signalout;
    /*
    MUX_signal muxsignal({Branch,Aluop,Alusrc,PCtoregsrc,RDsrc,
                        Memread,Memwrite,Memtoreg,Regwrite},
                        signalflush,signalout);
    */
    always_comb begin
        if(signalflush)begin
            signalout <= 12'd0;
        end
        else begin
            signalout <= {Branch,Aluop,Alusrc,PCtoregsrc,RDsrc,
                        Memread,Memwrite,Memtoreg,Regwrite};
        end
    end


                        
    logic [31:0] EX_rs1_data,EX_rs2_data;
    logic [2:0] EX_funct3;
    logic [6:0] EX_funct7;
    logic [1:0] EX_Branch;
    logic [4:0] EXrs1,EXrs2,EXrd;
    logic [2:0] EX_Aluop;
    logic EX_Alusrc,EX_Memread,EX_Memwrite,EX_Memtoreg,EX_Regwrite,EX_PCtoregsrc,EX_RDsrc;
    //logic [31:0] EX_forward_rs2_data;
    


    IDEX_reg IDEXstage(clk,rst,
        ID_pc,
		signalout[11:10],
        signalout[9:7],
        signalout[6],
        signalout[5],
        signalout[4],
        signalout[3],
        signalout[2],
        signalout[1],
        signalout[0],

        rs1data,rs2data,imm,
        funct3,funct7,
        IDrs1,IDrs2,IDrd,
        EX_Branch,
        EX_Aluop,
        
		EX_Alusrc,
        EX_PCtoregsrc,
        EX_RDsrc,
        EX_Memread,
        EX_Memwrite,
        EX_Memtoreg,
        EX_Regwrite,
        
        EX_rs1_data,EX_rs2_data,EX_pc,
        EX_imm,EX_funct3,EX_funct7,
        EXrs1,EXrs2,EXrd);


    //Branch_ctrl BranchControl(EX_Branch,zeroflag,branchsel);
    Branch_ctrl BRANCH_Control(
                            .brch_sel(EX_Branch),
                            .zeroflag(zeroflag),
                            .brch_out(branchsel)
                            );
    
    logic [4:0] aluctrl;
    ALUCtrol ALUControl(EX_Memread,EX_funct3,EX_Aluop,EX_funct7,aluctrl);
    
    logic [1:0] forwardrs1src,forwardrs2src;
    logic forwardrdsrc;
    logic [31:0] alusrca,alusrcb;
    logic [31:0] pc2reg;
    logic [31:0] EX_pcadd4src;
    //add_imm ADDpc4(EX_pc,32'd4,EX_pcadd4src);
    //add_imm ADDpcimm(EX_pc,EX_imm,EX_pcaddimm);
    assign EX_pcadd4src = EX_pc + 32'd4;
    assign EX_pcaddimm = EX_pc + EX_imm;
    
    //MUX2to1 muxpc2reg(EX_pcaddimm,EX_pcadd4src,EX_PCtoregsrc,pc2reg);
    assign pc2reg = (EX_PCtoregsrc)?EX_pcadd4src:EX_pcaddimm;
    
    logic [31:0] MEM_rd_data;


    MUX3to1 muxex1(EX_rs1_data,MEM_rd_data,WB_wb_data,forwardrs1src,alusrca);
    MUX3to1 muxex2(EX_rs2_data,MEM_rd_data,WB_wb_data,forwardrs2src,alusrcb);


    logic [31:0] alusrcb2;
    
    //MUX2to1 muxalu(alusrcb,EX_imm,EX_Alusrc,alusrcb2);
    assign alusrcb2 = (EX_Alusrc)? EX_imm : alusrcb;

    alu AlU(alusrca,alusrcb2,aluctrl,EX_aluout,zeroflag);
	

    logic /*MEM_Memread,MEM_Memwrite,*/
          MEM_Memtoreg,MEM_Regwrite,
          MEM_PCtoregsrc,MEM_RDsrc;
    
    logic [4:0] MEM_rdnum;
    logic [31:0] MEM_pc2reg,MEM_alu_out;
    logic [31:0] MEM_data_in;
    logic [31:0] MEM_forward_rs2_data;
   
    logic [2:0] MEM_funct3; 
    //assign EX_forward_rs2_data=alusrcb;

    EXMEM_reg EXMEMstage(
        clk,rst,
        EX_RDsrc,
        EX_Memread,EX_Memwrite,EX_Memtoreg,EX_Regwrite,
        pc2reg,
        EX_aluout,
        alusrcb,
        EXrd,
	    EX_funct3,

        MEM_Memread,MEM_Memwrite,MEM_Memtoreg,MEM_Regwrite,MEM_RDsrc,
        MEM_rdnum,
	    MEM_funct3,
        MEM_pc2reg,
        MEM_alu_out,
        MEM_forward_rs2_data
        
    );

    


    logic WB_Memtoreg;
    logic [31:0] WB_rd_data, WB_data_out;
    logic [31:0] DMdata2;

    //logic [2:0] WB_funct3;
    
    //MUX2to1 muxrddata(MEM_pc2reg,MEM_alu_out,MEM_RDsrc,MEM_rd_data);
    assign MEM_rd_data = (MEM_RDsrc)? MEM_alu_out : MEM_pc2reg;

    MEMWB_reg MEMWBstage(
        clk,rst,
        MEM_Memtoreg,MEM_Regwrite,
        MEM_rd_data,
        DMdata2,
        MEM_rdnum,
        
	    WB_Memtoreg,WB_Regwrite,
        WB_rd_data,
        WB_data_out,
        WB_rdnum
    );
    
 
        



    //MUX2to1 muxwbdata(WB_rd_data,WB_data_out,WB_Memtoreg,WB_wb_data);
    assign WB_wb_data = (WB_Memtoreg)? WB_data_out:WB_rd_data;
    //MUX2to1 muxmemdatain(MEM_forward_rs2_data,WB_wb_data,forwardrdsrc,MEM_data_in);
    assign MEM_data_in = (forwardrdsrc)? WB_wb_data : MEM_forward_rs2_data;
   
    //logic [3:0] wen; 
    //logic [31:0] datatoDM;
    

    /*DMdata2*/
    loadreg_ctrl LWctrl(MEM_Memread,MEM_funct3,
    DMdata,DMdata2);

    storemem_ctrl SWctrl(MEM_Memwrite,
                         MEM_funct3,
                         MEM_alu_out,
                         MEM_data_in,
                         datatoDM,wen); 


    //SRAM_wrapper DM1(~clk,MEM_Memread|MEM_Memwrite,MEM_Memread,wen,MEM_alu_out[15:2],datatoDM,DMdata);        
    assign DMaddr = MEM_alu_out[15:2];
    /*
    hazard_ctrl HZ(EX_Memread,branchsel,EXrd,IDrs1,IDrs2,PCwrite,flush,signalflush,IFIDwrite);
    
    forward_ctrl ForwardUnit(.regw_wb(WB_Regwrite),
                      .mem_w(MEM_Memwrite),
                      .regw_mem(MEM_Regwrite),
                      .rs1ex(EXrs1),
                      .rs2ex(EXrs2),
                      .rdwb(WB_rdnum),
                      .rdmem(MEM_rdnum),
                      
                      .forward_rd(forwardrdsrc),
                      .forward_rs1(forwardrs1src),
                      .forward_rs2(forwardrs2src));

    */
    hazard_ctrl HZ(.rmem_EXE(EX_Memread),
                   .brch_mux_sel(branchsel),
                   .rd_EXE(EXrd),
                   .rs1_ID(IDrs1),
                   .rs2_ID(IDrs2),
                   
                   .flush(flush),
                   .signalflush(signalflush),
                   .PCstage_wrt(PCwrite));
    assign IFIDwrite = PCwrite;
    forward_ctrl ForwardUnit(.wreg_WB(WB_Regwrite),
                      .wmem_MEM(MEM_Memwrite),
                      .wreg_MEM(MEM_Regwrite),
                      .rs1_EX(EXrs1),
                      .rs2_EX(EXrs2),
                      .rd_WB(WB_rdnum),
                      .rd_MEM(MEM_rdnum),
                      
                      .forward_mem(forwardrdsrc),
                      .forward_rs1(forwardrs1src),
                      .forward_rs2(forwardrs2src));


endmodule

module MUX3to1(
	input [31:0] in1,
	input [31:0] in2,
	input [31:0] in3,
	input [1:0] sel,
	output logic [31:0] result
	);

    always@(*) begin
    case (sel)
        2'b00:
            result = in1;
        2'b01:
            result = in2;
        2'b10:
            result = in3;
        default:
            result = 32'd0;
    endcase
end
endmodule



module forward_ctrl (
    input wreg_WB,
    input wmem_MEM,
    input wreg_MEM,
    input [4:0] rs1_EX,
    input [4:0] rs2_EX,
    input [4:0] rd_WB,
    input [4:0] rd_MEM,

    output logic forward_mem,
    output logic [1:0] forward_rs1,
    output logic [1:0] forward_rs2
);

always_comb begin
    if ( (wreg_WB) && (rd_WB != 5'd0) &&(rs1_EX == rd_WB) 
    && !(wreg_MEM && rd_MEM != 5'd0 && rd_MEM == rs1_EX)) forward_rs1=2'b10;

    else  if ( wreg_MEM && rd_MEM != 5'd0 && rd_MEM == rs1_EX ) forward_rs1=2'b01;
    else forward_rs1 = 2'b00;
end


always_comb begin
    if ( (wreg_WB) && (rd_WB != 5'd0) &&(rs2_EX == rd_WB) 
    && !(wreg_MEM && rd_MEM != 5'd0 && rd_MEM == rs2_EX)) forward_rs2=2'b10;

    else  if ( wreg_MEM && rd_MEM != 5'd0 && rd_MEM == rs2_EX ) forward_rs2=2'b01;
    else forward_rs2 = 2'b00;
end

// weird about rd_MEM==rd_WB
/*
always_comb begin
    if (wmem_MEM && wreg_WB && rd_MEM==rd_WB)forward_mem = 1;
    else forward_mem = 0;

end
*/

assign forward_mem = 0;


endmodule

module Branch_ctrl(
    input [1:0] brch_sel,
    input zeroflag,
    output logic[1:0] brch_out
);
    /*
        PC+4 from three parts
        brch_sel by control unit
            1.PC + 4        00 
            2.rs1 + imm     10 (I-TYPE JALR)
            3.PC + imm      01 (B-TYPE) or 11 (J-TYPE)

    */
    always_comb begin    
        case(brch_sel)
            2'b00: brch_out = 2'b10;
            2'b01: brch_out = (zeroflag)? 2'b01 : 2'b10;
            2'b10: brch_out = 2'b00;
            2'b11: brch_out = 2'b01;

        endcase
    end
endmodule

module hazard_ctrl(
    input rmem_EXE,     //lw
    input [1:0] brch_mux_sel,
    input [4:0] rd_EXE,
    input [4:0] rs1_ID,
    input [4:0] rs2_ID,

    //output PCwrt,
    output logic flush,   //IF and ID stage instruction flush
    output logic signalflush, // LW-Hazard happen
    output logic PCstage_wrt
);
/*
1. structure hazard: not consider
2. data hazard: load instruction
3. control hazard: B-type J-type 

*/

//flush
always_comb begin
    if(brch_mux_sel != 2'b10) begin
        flush = 1;
    end
    else flush = 0;
end

//signalflush
always_comb begin
    if((rmem_EXE) && (rs1_ID==rd_EXE || rs2_ID==rd_EXE))
        signalflush = 1;
    else signalflush = 0;
end
//pc and stage write 
always_comb begin
    if((rmem_EXE) && (rs1_ID==rd_EXE || rs2_ID==rd_EXE))
        PCstage_wrt = 0;
    else PCstage_wrt = 1;

end

endmodule



