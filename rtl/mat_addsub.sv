module mat_addsub#(
    parameter int N      = 4,
    parameter int DATA_W = 16
)(
    input  logic                        add,
    input  logic                        sub,
    input  logic signed [DATA_W - 1: 0] mat_a      [N][N],
    input  logic signed [DATA_W - 1: 0] mat_b      [N][N],
    output logic signed [DATA_W - 1: 0] mat_result [N][N],
    output logic                        overflow
);

    logic part_overflow [N][N];

    //Computing matrix and check overflow
    genvar i,j;
    generate
        for (i = 0; i < N; i++) begin
            for (j = 0; j < N; j++) begin
                    always_comb begin
                        logic signed [DATA_W: 0] mat_a_ext, mat_b_ext, mat_result_ext;
                        
                        mat_a_ext = {{1{mat_a[i][j][DATA_W - 1]}}, mat_a[i][j]};
                        mat_b_ext = {{1{mat_b[i][j][DATA_W - 1]}}, mat_b[i][j]};
                        
                        if (add)
                            mat_result_ext = mat_a_ext + mat_b_ext;
                        else if (sub)
                            mat_result_ext = mat_a_ext - mat_b_ext;

                        mat_result[i][j] =  mat_result_ext[DATA_W - 1: 0];
                        part_overflow[i][j] = (mat_result_ext[DATA_W] != mat_result_ext[DATA_W - 1]);      
                    end           
            end
        end
    endgenerate

    //OR all overflow       
    always_comb begin
        overflow = 1'b0;
        for (int k = 0; k < N; k++) begin
            for (int m = 0; m < N; m++) begin
                overflow = overflow | part_overflow[k][m];
            end 
        end
    end

endmodule