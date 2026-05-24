module mat_addsub_tb();
    parameter int N      = 4;
    parameter int DATA_W = 16;
    
    logic add, sub;
    logic signed [DATA_W - 1: 0] mat_a [N][N];
    logic signed [DATA_W - 1: 0] mat_b [N][N];
    logic signed [DATA_W - 1: 0] mat_result [N][N];
    logic overflow;

mat_addsub #(
    .N      (N),
    .DATA_W (DATA_W)
)   dut (
    .add                (add),
    .sub                (sub),
    .mat_a            (mat_a),
    .mat_b            (mat_b),
    .mat_result  (mat_result),
    .overflow      (overflow)
);

initial begin
    for(int i = 0; i < N; i++) begin
        for(int j = 0; j < N; j++) begin
            mat_a[i][j] = $signed($urandom_range(-100, 100));
            mat_b[i][j] = $signed($urandom_range(-100, 100));
        end
    end
    $display("Matrix A\n");
    print_matrix(mat_a);
    $display("Matrix B\n");
    print_matrix(mat_b);

    //Test 1
    #10;
    add <= 1;
    sub <= 0;
    #5;
    $display("Operation add add = %0d, sub = %0d", add, sub);
    check_matrix(mat_a, mat_b, mat_result);
    #5;
    print_matrix(mat_result);
    $display("overflow = %0d", overflow);

    //Test 2
    #10;
    add <= 0;
    sub <= 1;
    #5;
    $display("Operation sub  add = %0d, sub = %0d", add, sub);
    check_matrix(mat_a, mat_b, mat_result);
    #5;
    print_matrix(mat_result);
    $display("overflow = %0d", overflow);

    //Test 3
    #10;
    add <= 1;
    sub <= 1;
    #5;
    $display("Operation invalid add = %0d, sub = %0d", add, sub);
    check_matrix(mat_a, mat_b, mat_result);
    $display("overflow = %0d", overflow);

    //Test 4
    #10;
    $display("Overflow add operation");
    for (int i = 0; i < N; i++) begin
        for (int j = 0 ; j < N; j++) begin
            mat_a[i][j] = {{1'b0}, {DATA_W-1{1'b1}}};  // +127 для 8 бит
            mat_b[i][j] = {{1'b0}, {DATA_W-1{1'b0}}, 1'b1};  // +1
        end
    end
    add <= 1;
    #5;
    $display("overflow = %0d", overflow);

    //Test 5    
    #10;
    $display("Overflow sub operation");
    for (int i = 0; i < N; i++) begin
        for (int j = 0 ; j < N; j++) begin
            mat_a[i][j] = {{1'b1}, {DATA_W-1{1'b0}}};  // -128 для 8 бит
            mat_b[i][j] = {{1'b0}, {DATA_W-1{1'b0}}, 1'b1};  // +1
        end
    end
    sub <= 1;
    #5;
    $display("overflow = %0d", overflow);

    #10;
    $finish;

end

task print_matrix(logic signed [DATA_W - 1: 0] mat [0: N - 1][0: N - 1]);
    for(int i = 0; i < N; i++) begin
        for (int j = 0; j< N; j++) begin
            $write("%6d ", mat[i][j]);
        end
            $display("");
    end
endtask

task check_matrix(logic signed [DATA_W - 1: 0] mat_a [0: N - 1][0: N - 1],
                  logic signed [DATA_W - 1: 0] mat_b [0: N - 1][0: N - 1],
                  logic signed [DATA_W - 1: 0] mat_result [0: N - 1][0: N - 1]);
                  
                  automatic bit error = 0;
                  
                  for (int i = 0; i < N; i++) begin
                       for (int j = 0; j < N; j++) begin
                            logic signed [DATA_W - 1: 0] expected_mat;
                            if (add == 1'b1 && sub == 1'b0) begin
                                    expected_mat = mat_a[i][j] + mat_b[i][j];
                                end
                            else if (sub == 1'b1 && add == 1'b0) begin
                                    expected_mat = mat_a[i][j] - mat_b[i][j];
                                end
                            else begin
                                    error = 1;
                                end
                            if (mat_result[i][j] != expected_mat) begin
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