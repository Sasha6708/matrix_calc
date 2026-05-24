interface apb_driver (
    input logic clk,
    input logic rst_n,
    
    output logic psel,
    output logic penable,
    output logic pwrite,
    output logic [7:0] paddr,
    output logic [31:0] pwdata,
    input logic [31:0] prdata,
    input logic pready,
    input logic pslverr
);

    task apb_write(
        input [7:0] addr,
        input [31:0] data
    );
        @(posedge clk);
        psel <= 1'b1;
        penable <= 1'b0;
        pwrite <= 1'b1;
        paddr <= addr;
        pwdata <= data;
        
        @(posedge clk);
        penable <= 1'b1;
        
        @(posedge clk);
        psel <= 1'b0;
        penable <= 1'b0;
        pwrite <= 1'b0;

    endtask
    
    task apb_read(
        input [7:0] addr,
        output [31:0] rdata
    );
        @(posedge clk);
        psel <= 1'b1;
        penable <= 1'b0;
        pwrite <= 1'b0;
        paddr <= addr;
        
        @(posedge clk);
        penable <= 1'b1;
        
        rdata = prdata;

        @(posedge clk);
        psel <= 1'b0;
        penable <= 1'b0;

    endtask

endinterface