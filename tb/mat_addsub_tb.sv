module mat_addsub_tb();
    parameter int N      = 4;
    parameter int DATA_W = 8;
    
    logic [1: 0] op;
    logic signed [DATA_W - 1: 0] matrix_a [N][N];
    logic signed [DATA_W - 1: 0] matrix_b [N][N];
    logic signed [DATA_W - 1: 0] matrix_result [N][N];
    logic overflow;

mat_addsub #(
    .N      (N),
    .DATA_W (DATA_W)
)   dut (
    .op(op),
    .matrix_a      (matrix_a),
    .matrix_b      (matrix_b),
    .matrix_result (matrix_result),
    .overflow      (overflow)
);

initial begin
    for(int i = 0; i < N; i++) begin
        for(int j = 0; j < N; j++) begin
            matrix_a[i][j] = $signed($urandom_range(-100, 100));
            matrix_b[i][j] = $signed($urandom_range(-100, 100));
        end
    end
    $display("Matrix A\n");
    print_matrix(matrix_a);
    $display("Matrix B\n");
    print_matrix(matrix_b);

    //Test 1
    #10;
    op <= 2'b00;
    #5;
    $display("Operation add %0d", op);
    check_matrix(matrix_a, matrix_b, matrix_result);
    #5;
    print_matrix(matrix_result);
    $display("overflow = %0d", overflow);

    //Test 2
    #10;
    op <= 2'b01;
    #5;
    $display("Operation sub op %0d", op);
    check_matrix(matrix_a, matrix_b, matrix_result);
    #5;
    print_matrix(matrix_result);
    $display("overflow = %0d", overflow);

    //Test 3
    #10;
    op <= 2'b10;
    #5;
    $display("Operation invalid op%0d", op);
    check_matrix(matrix_a, matrix_b, matrix_result);
    $display("overflow = %0d", overflow);

    //Test 4
    #10;
    $display("Overflow add operation");
    for (int i = 0; i < N; i++) begin
        for (int j = 0 ; j < N; j++) begin
            matrix_a[i][j] = {{1'b0}, {DATA_W-1{1'b1}}};  // +127 для 8 бит
            matrix_b[i][j] = {{1'b0}, {DATA_W-1{1'b0}}, 1'b1};  // +1
        end
    end
    op <= 2'b00;
    #5;
    $display("overflow = %0d", overflow);

    //Test 5    
    #10;
    $display("Overflow sub operation");
    for (int i = 0; i < N; i++) begin
        for (int j = 0 ; j < N; j++) begin
            matrix_a[i][j] = {{1'b1}, {DATA_W-1{1'b0}}};  // -128 для 8 бит
            matrix_b[i][j] = {{1'b0}, {DATA_W-1{1'b0}}, 1'b1};  // +1
        end
    end
    op <= 2'b01;
    #5;
    $display("overflow = %0d", overflow);

    #10;
    $finish;

end

task print_matrix(logic signed [DATA_W - 1: 0] matrix [0: N - 1][0: N - 1]);
    for(int i = 0; i < N; i++) begin
        for (int j = 0; j< N; j++) begin
            $write("%6d ", matrix[i][j]);
        end
            $display("");
    end
endtask

task check_matrix(logic signed [DATA_W - 1: 0] matrix_a [0: N - 1][0: N - 1],
                  logic signed [DATA_W - 1: 0] matrix_b [0: N - 1][0: N - 1],
                  logic signed [DATA_W - 1: 0] matrix_result [0: N - 1][0: N - 1]);
                  
                  automatic bit error = 0;
                  
                  for (int i = 0; i < N; i++) begin
                       for (int j = 0; j < N; j++) begin
                            logic signed [DATA_W - 1: 0] expected_matrix;
                            if (op == 2'b00) begin
                                    expected_matrix = matrix_a[i][j] + matrix_b[i][j];
                                end
                            else if (op == 2'b01) begin
                                    expected_matrix = matrix_a[i][j] - matrix_b[i][j];
                                end
                            else begin
                                    error = 1;
                                end
                            if (matrix_result[i][j] != expected_matrix) begin
                                    error = 1;
                                    $display("Incorrect matrix");
                                end
                        end
                    end
                        if(error) begin
                                $display("Fatal, pls don't touch me");
                            end
                        else begin
                                $display("Good brooo");
                            end
endtask

endmodule