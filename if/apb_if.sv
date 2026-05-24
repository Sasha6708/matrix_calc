interface apb_if();
    logic psel, penable, pwrite, clk;
    logic [7: 0] paddr;
    logic [31: 0] prdata, pwdata;
    logic pready, pslverr;

    modport master  ( output psel, penable, pwrite, paddr, pwdata,
                      input  prdata, pready, pslverr);

    modport slave   ( input  psel, penable, pwrite, paddr, pwdata,
                      output prdata, pready, pslverr);

    modport monitor ( input  psel, penable, pwrite, paddr, pwdata, prdata, pready, pslverr);
    
endinterface