interface axis_driver #(
    parameter N = 4,
    parameter DATA_W = 16
) (
    input logic clk,
    input logic rst_n,
    
    output logic signed [DATA_W-1:0] s_axis_a_tdata,
    output logic s_axis_a_tvalid,
    output logic s_axis_a_tlast,
    input logic s_axis_a_tready,

    output logic signed [DATA_W-1:0] s_axis_b_tdata,
    output logic s_axis_b_tvalid,
    output logic s_axis_b_tlast,
    input logic s_axis_b_tready
);

    task send_matrix(
        output logic signed [DATA_W-1:0] tdata,
        output logic tvalid,
        output logic tlast,
        input logic tready,
        input signed [DATA_W-1:0] matrix [N][N]
    );
        int total = N * N;
        
        for (int idx = 0; idx < total; idx++) begin
            int row = idx / N;
            int col = idx % N;
            
            tdata <= matrix[row][col];
            tvalid <= 1'b1;
            
            if (idx == total - 1) begin
                tlast <= 1'b1;
            end
            else begin
                tlast <= 1'b0;
            end
            
            @(posedge clk);
            while (!tready) begin
                @(posedge clk);
            end
        end
        
        tvalid <= 1'b0;
        tlast <= 1'b0;
        tdata <= {DATA_W{1'b0}};
    endtask
    
    // Task parallel send for add and sub
    task axis_send_parallel(
        input signed [DATA_W-1:0] matrix_a [N][N],
        input signed [DATA_W-1:0] matrix_b [N][N]
    );
        fork
            send_matrix(s_axis_a_tdata, s_axis_a_tvalid, s_axis_a_tlast, s_axis_a_tready, matrix_a);
            send_matrix(s_axis_b_tdata, s_axis_b_tvalid, s_axis_b_tlast, s_axis_b_tready, matrix_b);
        join
    endtask

    // Task single send
    task axis_send_single(
        input signed [DATA_W-1:0] matrix_a [N][N]
    );
        send_matrix(s_axis_a_tdata, s_axis_a_tvalid, s_axis_a_tlast, s_axis_a_tready, matrix_a);
    endtask

endinterface