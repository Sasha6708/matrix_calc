module mat_transpose #(
    parameter N      = 4,
    parameter DATA_W = 16
) (
    input  logic signed [DATA_W - 1: 0] matrix_in  [N][N],
    output logic signed [DATA_W - 1: 0] matrix_out [N][N]
);

//Transpose matrix
genvar i, j;
generate
    for (i = 0; i < N; i++) begin
        for (j = 0; j < N; j++) begin
            assign matrix_out[i][j] = matrix_in[j][i];
        end
    end
endgenerate  

endmodule