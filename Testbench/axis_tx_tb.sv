module tb_axis_tx();

    localparam int N      = 4;
    localparam int DATA_W = 16;
    localparam int TOTAL  = N * N;

    logic                           clk;
    logic                           rst_n;
    logic                           send;
    logic                           m_tready;
    logic signed [DATA_W-1:0]       m_tdata;
    logic                           m_tvalid;
    logic                           m_tlast;
    logic                           done_tx;


    logic signed [DATA_W-1:0]       mat_in [0:N-1][0:N-1];
    logic signed [DATA_W-1:0]       scalar_in;

    logic signed [DATA_W-1:0]       received_data [$];
    int                             expected_data [TOTAL];
    integer                         errors;
    integer                         i, j, k;

    axis_tx #(.N(N), .DATA_W(DATA_W)) dut (
        .clk        (clk),
        .rst_n      (rst_n),
        .send       (send),
        .m_tready   (m_tready),
        .is_scalar  (is_scalar),
        .mat_in     (mat_in),
        .scalar_in  (scalar_in),
        .m_tdata    (m_tdata),
        .m_tvalid   (m_tvalid),
        .m_tlast    (m_tlast),
        .done_tx    (done_tx)
    );


    initial begin clk <= 0;
    forever begin
         #10; clk <= ~clk;
    end
    end

    always @(posedge clk) begin
        if (m_tvalid && m_tready) begin
            received_data.push_back(m_tdata);
            if (m_tlast) $display("MONITOR: Received tlast at element #%0d", received_data.size());
        end
    end

    task init();
        rst_n      <= 0;
        send       <= 0;
        m_tready   <= 0;
       
        received_data.delete();
        errors     = 0;
        
        for (i = 0; i < N; i++) begin
            for (j = 0; j < N; j++) begin
                mat_in[i][j] <= i * N + j + 1;
                expected_data[i * N + j] = i * N + j + 1;
            end
        end
        
        repeat(2) @(posedge clk);
        rst_n <= 1;
        repeat(2) @(posedge clk);
    endtask

    task check_result(string test_name);
        int actual_size;
        
        actual_size = received_data.size();
        
        $display("");
        $display("=== CHECK: %s ===", test_name);
        $display("Expected %0d elements, received %0d", TOTAL, actual_size);
        
        if (actual_size != TOTAL) begin
            $display("FAIL: Wrong number of elements!");
            errors++;
            return;
        end
        
        for (k = 0; k < TOTAL; k++) begin
            if (received_data[k] !== expected_data[k]) begin
                $display("FAIL: Element #%0d mismatch. Expected %0d, got %0d", 
                         k, expected_data[k], received_data[k]);
                errors++;
            end
        end
        
        if (errors == 0)
            $display("PASS: All data correct!");
    endtask


    initial begin

        int tlast_seen_at;
        int element_count;
        // TEST 1:
        init();
        $display("\n[TEST 1] Basic matrix transmission");
        

        m_tready <= 1;
        
        send <= 1;
        @(posedge clk);
        send <= 0;
        
        repeat(TOTAL + 5) @(posedge clk);
        

        if (done_tx !== 1'b1) begin
            $display("FAIL: done_tx not asserted after transmission!");
            errors++;
        end else begin
            $display("PASS: done_tx asserted correctly");
        end
        
        check_result("TEST 1 - Basic transfer");

        //TEST 2:
        init();
        $display("\n[TEST 2] Backpressure handling");
        
        send <= 1;
        @(posedge clk);
        send <= 0;
        
        for (int cycle = 0; cycle < TOTAL * 3; cycle++) begin
            if (m_tvalid && !$urandom_range(0, 100) < 30) begin
                m_tready <= 1;
            end else begin
                m_tready <= 0;
            end
            @(posedge clk);
            
            if (done_tx) break;
        end
        
        repeat(5) @(posedge clk);
        
        check_result("TEST 2 - With backpressure");
        

        //TEST 3:
        init();
        $display("\n[TEST 3] Reset during transmission");
        
        m_tready <= 1;
        send <= 1;
        @(posedge clk);
        send <= 0;
        
        repeat(3) @(posedge clk);
        rst_n <= 0;
        repeat(2) @(posedge clk);
        rst_n <= 1;
        

        if (m_tvalid !== 1'b0) begin
            $display("FAIL: m_tvalid not de-asserted after reset!");
            errors++;
        end
        if (done_tx !== 1'b0) begin
            $display("FAIL: done_tx not cleared by reset!");
            errors++;
        end
        if (received_data.size() > 0) begin
            $display("WARNING: %0d elements were transmitted before reset (expected)", 
                     received_data.size());
        end
        $display("PASS: Reset handled correctly");

        //TEST 4:
        init();
        $display("\n[TEST 4] tlast positioning");
        
        m_tready <= 1;
        send <= 1;
        @(posedge clk);
        send <= 0;
        

        tlast_seen_at = -1;
        element_count = 0;
        
        fork

            begin
                forever begin
                    @(posedge clk);
                    if (m_tvalid && m_tready) begin
                        element_count++;
                        if (m_tlast) begin
                            tlast_seen_at = element_count;
                            $display("tlast observed at element #%0d", element_count);
                            disable fork;
                        end
                    end
                end
            end

            begin
                repeat(TOTAL + 10) @(posedge clk);
                disable fork;
            end
        join
        
        if (tlast_seen_at == TOTAL) begin
            $display("PASS: tlast correctly placed at element #%0d", TOTAL);
        end else if (tlast_seen_at == -1) begin
            $display("FAIL: tlast was never asserted!");
            errors++;
        end else begin
            $display("FAIL: tlast at wrong position #%0d (expected #%0d)", 
                     tlast_seen_at, TOTAL);
            errors++;
        end

        if (errors == 0) begin
            $display("ALL TESTS PASSED!");
        end else begin
            $display("TESTS FAILED! Total errors: %0d", errors);
        end
        
        $finish;
    end

endmodule