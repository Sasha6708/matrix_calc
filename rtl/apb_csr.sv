module apb_csr #(
    parameter N = 4, parameter DATA_W = 16
) (
    input  logic        clk, rst_n,
    input  logic        psel, penable, pwrite,
    input  logic [7:0]  paddr,
    input  logic [31:0] pwdata,
    output logic [31:0] prdata,
    output logic        pready, pslverr,
    output logic [1:0]  op,
    output logic        start,
    input  logic        done_i, busy_i, overflow_i, singular_i
);

    logic [1:0] reg_op;
    logic       reg_ctrl;

    assign pready = 1'b1;
    assign op     = reg_op;
    assign start  = reg_ctrl;

   
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin reg_op <= 2'b0; reg_ctrl <= 1'b0; end
        else if (psel && pwrite && penable) begin
            case (paddr)
                8'h0: reg_op   <= pwdata[1:0];
                8'h4: reg_ctrl <= pwdata[0];
            endcase
        end else if (reg_ctrl) begin reg_ctrl <= 1'b0; end
    end

    
    always_comb begin
        prdata  = 32'b0;
        pslverr = 1'b0;

        if (psel && penable && !pwrite) begin  
            case (paddr)
                8'h0: prdata[1:0] = reg_op;
                8'h4: prdata[0]   = 1'b0;      
                8'h8: begin                    
                    prdata[0] = done_i;       
                    prdata[1] = busy_i;
                    prdata[2] = overflow_i;
                    prdata[3] = singular_i;
                end
                default: pslverr = 1'b1;
            endcase
        end else if (psel && penable && pwrite) begin 
            case (paddr)
                8'h0, 8'h4: pslverr = 1'b0;
                default:    pslverr = 1'b1;
            endcase
        end
    end
endmodule