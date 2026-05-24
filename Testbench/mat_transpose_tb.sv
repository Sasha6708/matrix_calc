module mat_transpose_tb();
    parameter int N = 4;
    parameter int DATA_W = 16;

    logic signed [DATA_W - 1: 0] matrix_in  [N][N];
    logic signed [DATA_W - 1: 0] matrix_out [N][N];

    mat_transpose #(
        .N(N),
        .DATA_W(DATA_W)
    ) dut(
        .matrix_in (matrix_in),
        .matrix_out(matrix_out)
    );

    initial begin

        bit pass = 1'b1;
        $display("Start simulation");
        for (int i = 0; i < N; i++) begin
            for (int j = 0; j < N; j++) begin
                matrix_in[i][j] = $urandom_range(-100, 100);
            end
        end
        #10;
        print_matrix(matrix_in, N);
        $display("\n");
        #10;
        print_matrix(matrix_out, N);
        #10;
        
        for (int i = 0; i < N; i++) begin
            for (int j = 0; j < N; j++) begin
                if (matrix_out[i][j] !== matrix_in[j][i]) begin
                    pass = 1'b0;
                end
            end
        end
        if (pass) begin
            $display("It's okey");
        end
        else begin
            $display("Test failed");
        end
        #10;
        $finish;

    end

task print_matrix(logic signed [DATA_W - 1: 0] matrix [0: N - 1][0: N - 1], input int N);
    for(int i = 0; i < N; i++) begin
        for (int j = 0; j< N; j++) begin
            $write("%6d ", matrix[i][j]);
        end
        $display();
    end
endtask

endmodule