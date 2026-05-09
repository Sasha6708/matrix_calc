module axis_rx #(
    parameter N      = 4,
    parameter DATA_W = 16
) (
    input  logic                     clk,
    input  logic                     rst_n,
    input  logic signed [DATA_W-1:0] s_tdata,
    input  logic                     s_tvalid,
    input  logic                     s_tlast,
    output logic                     s_tready,
    input  logic                     flush,
    output logic signed [DATA_W-1:0] mat [N][N],
    output logic                     recv_done
);
   
    localparam TOTAL = N * N;
    localparam CNT_W = $clog2(TOTAL + 1);
    localparam IDX_W = $clog2(N);

    logic [CNT_W - 1: 0] elemr_cnt;
    logic [IDX_W - 1: 0] row, col;
    logic buf_full;

    assign buf_full = (elemr_cnt == TOTAL);
    assign s_tready = (~flush && ~buf_full);

    always_ff @(posedge clk) begin
        if (~rst_n) begin
            elemr_cnt   <= '0;
            recv_done   <= 1'b0;
            row         <= '0;
            col         <= '0;
        end
        else if (flush) begin
            elemr_cnt   <= '0;
            recv_done   <= 1'b0;
            row         <= '0;
            col         <= '0;
        end
        //Write by handshake with 2 counters
        else if (s_tvalid && s_tready) begin
            mat[row][col] <= s_tdata;
            if (col == N - 1) begin
                col <= '0;
                row <= row + 1;
            end
            else begin
                col <= col + 1;
            end
            elemr_cnt <= elemr_cnt + 1;
            //In the end signal about finish
            if (elemr_cnt == TOTAL - 1) begin
                recv_done   <= 1'b1;
            end
        end
        else begin
            recv_done <= 1'b0;
        end
    end

endmodule

