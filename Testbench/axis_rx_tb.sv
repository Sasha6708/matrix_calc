module axis_rx_tb();

    parameter int N      = 4;
    parameter int DATA_W = 16;
    localparam int TOTAL = N * N;

    logic                     clk;
    logic                     rst_n;
    logic signed [DATA_W-1:0] s_tdata;
    logic                     s_tvalid;
    logic                     s_tlast;
    logic                     s_tready;
    logic                     flush;
    logic signed [DATA_W-1:0] mat [N][N];
    logic                     recv_done;

    axis_rx #(
        .N(N),
        .DATA_W(DATA_W)
    ) dut(
        .clk(clk),
        .rst_n(rst_n),
        .s_tdata(s_tdata),
        .s_tvalid(s_tvalid),
        .s_tlast(s_tlast),
        .s_tready(s_tready),
        .flush(flush),
        .mat(mat),
        .recv_done(recv_done)
    );

    initial begin
        clk <= 0;
        forever begin
            #10; clk <= ~clk;
        end
    end

    initial begin
        bit cleared;
        s_tdata <= '0; s_tvalid <= 0; s_tlast <= 0; flush <= 0;       
        
        rst_n <= 0; #20; rst_n <= 1; #10;
        
        $display("AXIS_RX TESTBENCH START (N=%0d, DATA_W=%0d)", N, DATA_W);

       
        $display("\n[Test 1] Continuous transfer (values 0..15)");
        for (int k = 0; k < TOTAL; k++) begin
            send_element(k, k);
        end
        wait(recv_done);
        $display("   recv_done pulse captured.");
        check_matrix(0, "Test1");

        
        #10; 
        flush <= 1'b1; @(posedge clk); flush <= 1'b0; #5;
        $display("\n[Test 2] After flush, transfer (values 100..115)");
        for (int k = 0; k < TOTAL; k++) 
            send_element(100 + k, k);
            
        wait(recv_done);
        check_matrix(100, "Test2");

        
        $display("\n[Test 3] Transfer with random gaps");
        flush <= 1'b1; @(posedge clk); flush <= 1'b0; #5;
        
        for (int k = 0; k < TOTAL; k++) begin
            send_element(200 + k, k);
            if ($urandom_range(0, 2) == 0) 
                #($urandom_range(1, 3) * 10); 
        end
        wait(recv_done);
        check_matrix(200, "Test3");

        $display("\nALL TESTS COMPLETED");
        #1000;
        $finish;
    end

    task send_element(input logic signed [DATA_W - 1: 0] data, input int index);
        s_tdata <= data;
        s_tvalid <= 1'b1;
        s_tlast <= (index == TOTAL - 1);

        while(!s_tready) @(posedge clk);
        @(posedge clk);
        s_tvalid <= 1'b0;
        s_tlast <= 1'b0;
    endtask

    task check_matrix(input int start_val, input string tname);
        automatic bit pass = 1'b1;
        int expected;
        for (int i = 0; i < N; i++) begin
            for (int j = 0; j < N; j++) begin
                expected = start_val + (i * N + j);
                if (mat[i][j] !== expected) begin
                    $display("FAIL [%s] mat[%0d][%0d] = %0d, expected %0d", 
                             tname, i, j, mat[i][j], expected);
                    pass = 1'b0;
                end
            end
        end
        if (pass) $display("PASS [%s] Matrix content correct.", tname);
    endtask

    endmodule