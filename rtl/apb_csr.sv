module apb_csr #(
    parameter N      = 4,
    parameter DATA_W = 16
) (
	input  logic        clk,
	input  logic        rst_n,

	input  logic        psel,
	input  logic        penable,
	input  logic        pwrite,
	input  logic [7:0]  paddr,
	input  logic [31:0] pwdata,
	output logic [31:0] prdata,
	output logic        pready,
	output logic        pslverr,

    output logic [1:0]  op,
    output logic        start,

    input  logic        done_i,
    input  logic        busy_i,
    input  logic        overflow_i,
    input  logic        singular_i
);

	typedef struct packed{	
				logic 	  done;
				logic 	  busy;
				logic overflow;
				logic singular; } status_t;

	status_t    reg_status;
	logic [1:0] reg_op;
	logic 	    reg_ctrl;

	assign pready  = 1'b1;
		
	always_ff @(posedge clk or negedge rst_n) begin
		if(!rst_n) begin
			reg_op   <= 2'b0;
			pslverr  <= 1'b0;
			reg_ctrl <= 1'b0;
		end
		else if(psel && pwrite && penable)
			case(paddr)
				8'h0:    reg_op   <= pwdata[1:0];
				8'h4:    reg_ctrl <= pwdata[0];
				default: pslverr  <= 1'b1;
			endcase	
		else if(reg_ctrl)
			reg_ctrl <= 1'b0;
	end

	always_comb begin
		prdata = 32'b0;
		if(psel && penable && ~pwrite) begin
			case(paddr)
				8'h0:    prdata[1:0]	 = reg_op;
				8'h4:    prdata[0]    	 = reg_ctrl;
				8'h8:    prdata[3:0]	 = reg_status;
			endcase
		end
	end

	always_ff @(posedge clk) begin
		if(!rst_n) 
			reg_status <= 4'b0;
		else begin
			reg_status.busy <= busy_i;
		if(done_i) begin
			reg_status.done <= 1'b1;
			reg_status.overflow <= overflow_i;
			reg_status.singular <= singular_i;
		end
		else if(reg_ctrl)
			reg_status.done <= 1'b0;	
		end
	end
	
	assign op = reg_op;
	assign start = reg_ctrl;

endmodule
