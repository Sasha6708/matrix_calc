module mat_addsub#(
    parameter int N      = 4,
    parameter int DATA_W = 8
)(
    input                        [1: 0] op,
    input  logic signed [DATA_W - 1: 0] matrix_a      [N][N],
    input  logic signed [DATA_W - 1: 0] matrix_b      [N][N],
    output logic signed [DATA_W - 1: 0] matrix_result [N][N],
    output logic                        overflow
);

    logic part_overflow [N][N];

    genvar i,j;
    generate
        for(i=0; i < N; i++) begin
            for(j = 0; j < N; j++) begin
                    always_comb begin

                        logic signed [DATA_W: 0] matrix_a_ext, matrix_b_ext, matrix_result_ext;
                        
                        matrix_a_ext = {{1{matrix_a[i][j][DATA_W - 1]}}, matrix_a[i][j]};
                        matrix_b_ext = {{1{matrix_b[i][j][DATA_W - 1]}}, matrix_b[i][j]};
                        
                        case(op)
                                2'b00:    matrix_result_ext = matrix_a_ext + matrix_b_ext;
                                2'b01:    matrix_result_ext = matrix_a_ext - matrix_b_ext;
                                default:  matrix_result_ext = '0;
                        endcase
                    
                        matrix_result[i][j] = matrix_result_ext[DATA_W - 1: 0];
                        part_overflow[i][j]= (matrix_result_ext[DATA_W] != matrix_result_ext[DATA_W - 1]);
                    end                   
            end
        end
    endgenerate
           
    always_comb begin
        overflow = 1'b0;
        for(int k = 0; k < N; k++) begin
            for(int m = 0; m < N; m++) begin
                overflow = overflow | part_overflow[k][m];
            end 
        end
    end

endmodule