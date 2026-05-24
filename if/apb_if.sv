interface apb_if(
    input bit clk,
    input bit rst_n
);
    logic psel, penable, pwrite;
    logic [7: 0] paddr;
    logic [31: 0] prdata, pwdata;
    logic pready, pslverr;

    modport master  ( output clk, rst_n, psel, penable, pwrite, paddr, pwdata,
                      input  prdata, pready, pslverr);

    modport monitor ( input  clk, rst_n, psel, penable, pwrite, paddr, pwdata, prdata, pready, pslverr);
    
endinterface