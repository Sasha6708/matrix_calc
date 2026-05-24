interface axis_if #(
    int N = 4,
    int DATA_W = 16
    ) (
    input bit clk,
    input bit rst_n
    );
    
    logic [DATA_W - 1: 0] tdata;
    logic                 tvalid;
    logic                 tready;
    logic                 tlast;

    modport master  ( output tdata, tvalid, tlast,
                      input  clk, rst_n, tready);

    modport slave   ( input  clk, rst_n, tdata, tvalid, tlast,
                      output tready);

    modport monitor ( input  clk, rst_n, tdata, tvalid, tlast, tready);
    
endinterface