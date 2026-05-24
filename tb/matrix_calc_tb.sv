module matrix_calc_tb();
    parameter int N;
    parameter int DATA_W;
    logic clk;
    logic rst_n;
    logic        psel;
    logic        penable;
    logic        pwrite;
    logic [7:0]  paddr;
    logic [31:0] pwdata;
    logic [31:0] prdata;
    logic        pready;
    logic        pslverr;

    //AXI4-Stream Slave: matrix A
    logic signed [DATA_W-1:0] s_axis_a_tdata;
    logic                     s_axis_a_tvalid;
    logic                     s_axis_a_tlast;
    logic                     s_axis_a_tready;

    //AXI4-Stream Slave: matrix B
    logic signed [DATA_W-1:0] s_axis_b_tdata;
    logic                     s_axis_b_tvalid;
    logic                     s_axis_b_tlast;
    logic                     s_axis_b_tready;

    //AXI4-Stream Master: result
    logic signed [DATA_W-1:0] m_axis_res_tdata;
    logic                     m_axis_res_tvalid;
    logic                     m_axis_res_tlast;
    logic                     m_axis_res_tread;

    matrix_calc #(.N(N), DATA_W(DATA_W))
    dut (.clk(clk),
         .rst_n(rst_n),
         .psel(psel),
         .penable(penable),
         .pwrite(pwrite),
         .paddr(paddr),
         .pwdata(pwdata),
         .prdata(prdata),
         .pready(pready),
         .pslverr(pslverr),
         .s_axis_a_tdata(s_axis_a_tdata),
         .s_axis_a_tvalid(s_axis_a_tvalid),
         .s_axis_a_tlast(s_axis_a_tlast),
         .s_axis_a_tready(s_axis_a_tready),
         .s_axis_b_tdata(s_axis_b_tdata),
         .s_axis_b_tvalid(s_axis_b_tvalid),
         .s_axis_b_tlast(s_axis_b_tlast),
         .s_axis_b_tready(s_axis_b_tready),
         .m_axis_res_tdata(m_axis_res_tdata),
         .m_axis_res_tvalid(m_axis_res_tvalid),
         .m_axis_res_tlast(m_axis_res_tlast),
         .m_axis_res_tready(m_axis_res_tready));

    initial begin
        forever begin
            clk <= 0;
            #10; clk <= ~clk;
        end
    end

    initial begin
        rst_n <= 1;
        repeat(5) @(posdge clk);
        rst_n <= 0;
        repeat(10) @(posedge clk);
        rst_n <= 1;
    end

    initial begin
        psel <= 0;
        penable <= 0;
        pwrite <= 0;
        paddr <= 0;
        pwdata <= 0;
        prdata <= 0;
        pready <= 0;
        pslverr <= 0

        s_axis_a_tdata <= 0;
        s_axis_a_tvalid <= 0;
        s_axis_a_tready <= 0;
        s_axis_a_tlast <= 0;

        s_axis_b_tdata <= 0;
        s_axis_b_tvalid <= 0;
        s_axis_b_tready <= 0;
        s_axis_b_tlast <= 0;

        m_axis_res_tdata <= 0;
        m_axis_res_tvalid <= 0;
        m_axis_res_tready <= 1;
        m_axis_res_tlast <= 0;

    end

    initial begin

    wait(rst_n == 1);
        #10;

        // Declare 2D matrices
        logic signed [DATA_W-1:0] mat_A [N][N];
        logic signed [DATA_W-1:0] mat_B [N][N];
        logic signed [DATA_W-1:0] expected_res [N][N];

        // 1. Generate Random Data
        $display("=== Generating Random Matrices ===");
        for (int i = 0; i < N; i++) begin
            for (int j = 0; j < N; j++) begin
                // Random values in range [-50, 50] to avoid overflow with 16-bit signed
                mat_A[i][j] = $signed($urandom_range(0, 100)) - 50;
                mat_B[i][j] = $signed($urandom_range(0, 100)) - 50;
            end
        end

        // Print Input Matrices
        $display("Matrix A:");
        for (int i = 0; i < N; i++) begin
            $write("  [");
            for (int j = 0; j < N; j++) $write("%0d ", mat_A[i][j]);
            $display("]");
        end
        
        $display("Matrix B:");
        for (int i = 0; i < N; i++) begin
            $write("  [");
            for (int j = 0; j < N; j++) $write("%0d ", mat_B[i][j]);
            $display("]");
        end

        // 2. Calculate Expected Result (Reference Model)
        ref_model_add(mat_A, mat_B, expected_res);
        $display("Expected Result (A+B):");
        for (int i = 0; i < N; i++) begin
            $write("  [");
            for (int j = 0; j < N; j++) $write("%0d ", expected_res[i][j]);
            $display("]");
        end

        $display("\n=== STARTING TEST: RANDOM ADDITION ===");

        // 3. Configure Operation (OP=0 for ADD)
        apb_write(8'h00, 32'h0000_0000);

        // 4. Send Data (Parallel Fork)
        fork
            send_matrix_A(mat_A);
            send_matrix_B(mat_B);
        join
        #10;

        // 5. Start Computation
        apb_write(8'h04, 32'h0000_0001);

        // 6. Polling Status (Wait for DONE)
        logic [31:0] status;
        $display("[%0t] Polling STATUS register...", $time);
        do begin
            apb_read(8'h08, status);
            #10; // Small delay between polls
        end while ((status & 32'h1) == 0); // Check bit 0 (DONE)

        $display("[%0t] DONE detected! Status=0x%0h", $time, status);

        // 7. Verify Results
        check_result(expected_res);

        $display("\n=== TEST FINISHED ===");
        #50;
        $finish;
    end

    task apb_write(input [7: 0] addr, input [31: 0] data)
        psel <= 0;
        penable <= 0;
        pwrite <= 1;
        @(posedge clk);
        psel <= 1;
        paddr <= addr;
        pwdata <= data;
        @(posedge clk);
        penable <= 1;
        @(posedge clk);
        psel <= 0;
        penable <= 0;
    endtask

    task apb_read(input [7: 0] addr, output [31: 0] rdata)
        psel <= 0;
        penable <= 0;
        pwrite <= 0;
        @(posedge clk);
        psel <= 1;
        paddr <= addr;
        @(posedge clk);
        penable <= 1;
        @(posedge clk);
        wait(pready == 1);
        rdata <= prdata;
        @(posedge clk);
        psel <= 0;
        penable <= 0;
    endtask

    task send_matrix_A(input logic [DATA_W - 1: 0] matrix_a [N][N])
        for (int = 0; i < N; i++) begin
            for (int j = 0; j < N; j++) begin
                s_axis_a_tvalid <= 1;
                s_axis_a_tdata <= matrix_a [i][j];
                s_axis_a_tlast <= (matrix_a [i][j] == matrix_a [N-1][N-1]);
                @(posedge clk);
                while(!s_axis_a_tready)
                    @(posedge clk);
            end
        end
        s_axis_a_tvalid <= 0;
        s_axis_a_tlast <= 0;
    endtask

    task send_matrix_B(input logic [DATA_W - 1: 0] matrix_b [N][N])
        for (int = 0; i < N; i++) begin
            for (int j = 0; j < N; j++) begin
                s_axis_b_tvalid <= 1;
                s_axis_b_tdata <= matrix_b [i][j];
                s_axis_b_tlast <= (matrix_b [i][j] == matrix_b [N-1][N-1]);
                @(posedge clk);
                while(!s_axis_b_tready)
                    @(posedge clk);
            end
        end
        s_axis_b_tvalid <= 0;
        s_axis_b_tlast <= 0;
    endtask

    function void ref_model_add(
        input  logic signed [DATA_W-1:0] A [N][N],
        input  logic signed [DATA_W-1:0] B [N][N],
        output logic signed [DATA_W-1:0] Res [N][N]
    );
        for (int i = 0; i < N; i++)
            for (int j = 0; j < N; j++)
                Res[i][j] = A[i][j] + B[i][j];
    endfunction

    
    task check_result(input logic signed [DATA_W-1:0] expected [N][N]);
        logic signed [DATA_W-1:0] hw_matrix [N][N];
        int count = 0;
        int errors = 0;
        
        $display("[%0t] Starting result verification...", $time);
        
        for (int i = 0; i < N; i++) begin
            for (int j = 0; j < N; j++) begin
                wait (axis_res_tvalid && axis_res_tready);
                
                hw_matrix[i][j] <= axis_res_tdata;
                @(posedge clk);
                if (hw_matrix[i][j] !== expected[i][j]) begin
                    $error("MISMATCH at [%0d][%0d]: Expected %0d, Got %0d", 
                           i, j, expected[i][j], hw_matrix[i][j]);
                    errors++;
                end
                count++;
            end
        end
        
        if (errors == 0)
            $display("[%0t] CHECK PASSED: All %0d elements match!", $time, count);
        else
            $error("[%0t] CHECK FAILED: %0d errors found", $time, errors);
    endtask