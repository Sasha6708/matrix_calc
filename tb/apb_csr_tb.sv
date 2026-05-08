module apb_crs_tb();
	
    logic        clk;
    logic        rst_n;
    logic        psel;
    logic        penable;
    logic        pwrite;
    logic [7:0]  paddr;
    logic [31:0] pwdata;
    logic [31:0] prdata;
    logic        pready;
    logic        pslverr;
    logic [1:0]  op;
    logic        start;
    logic        done_i;
    logic        busy_i;
    logic        overflow_i;
    logic        singular_i;

    logic [31:0] read_data;
    logic [1:0]  read_op;
    logic        test_passed;


    apb_crs dut (
        .clk        (clk),
        .rst_n      (rst_n),
        .psel       (psel),
        .penable    (penable),
        .pwrite     (pwrite),
        .paddr      (paddr),
        .pwdata     (pwdata),
        .prdata     (prdata),
        .pready     (pready),
        .pslverr    (pslverr),
        .op         (op),
        .start      (start),
        .done_i     (done_i),
        .busy_i     (busy_i),
        .overflow_i (overflow_i),
        .singular_i (singular_i)
    );
    initial begin
	clk <= 0;
        forever #10 clk <= ~clk;
    end

      task apb_write(input [7:0] addr, input [31:0] data);
        @(posedge clk);
        psel    <= 1'b1;
        penable <= 1'b0;
        pwrite  <= 1'b1;
        paddr   <= addr;
        pwdata  <= data;
        
        @(posedge clk);
        penable <= 1'b1;
        
        @(posedge clk);
        psel    <= 1'b0;
        penable <= 1'b0;
        pwrite  <= 1'b0;
    endtask

    task apb_read(input [7:0] addr, output [31:0] rdata);
        @(posedge clk);
        psel    <= 1'b1;
        penable <= 1'b0;
        pwrite  <= 1'b0;
        paddr   <= addr;
        
        @(posedge clk);
        penable <= 1'b1;
        
        @(posedge clk);
        psel    <= 1'b0;
        penable <= 1'b0;
        @(posedge clk);
        rdata   <= prdata;
    endtask

    initial begin

        rst_n <= 1'b0;
        psel <= 1'b0;
        penable <= 1'b0;
        pwrite <= 1'b0;
        paddr <= 8'h0;
        pwdata <= 32'h0;
        done_i <= 1'b0;
        busy_i <= 1'b0;
        overflow_i <= 1'b0;
        singular_i <= 1'b0;
        
        test_passed <= 1'b1;
        
        repeat(5) @(posedge clk);
        rst_n <= 1'b1;
        repeat(2) @(posedge clk);

        apb_write(8'h0, 32'h2);  
        apb_read(8'h0, read_data);
        
        
        $display("Wrote: OP=2 (0b10)");
        $display("Read:  OP=%0d (0b%02b)", read_data, read_data);
        
        if (read_data == 2'b10) begin
            $display("PASS");
        end else begin
            $display("FAIL Expected OP=2, got %0b", read_data);
            test_passed <= 1'b0;
        end
        @(posedge clk);    
        $finish;
    end

endmodule
