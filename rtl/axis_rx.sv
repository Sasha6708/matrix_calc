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
    localparam TOTAL = N*N;
    localparam CNT_W = $clog2(TOTAL + 1);
    localparam IDX_W = $clog2(N);

    logic [CNT_W - 1: 0] elem_cnt;
    logic [IDX_W - 1: 0] row;
    logic [IDX_W - 1: 0] col;
    logic buf_full;

    assign buf_full = (elem_cnt == TOTAL);

    logic s_tready_next;
    assign s_tready_next = ~flush && ~buf_full;

    always_ff @(posedge clk) begin
        if (!rst_n) begin
            s_tready <= 0;
        end
        else begin
            s_tready <= s_tready_next;
        end
    end

    always_ff @(posedge clk) begin
        if(!rst_n) begin
            elem_cnt  <= '0;
            recv_done <= '0;
            row <= '0;
            col <= '0;
           
        end
        else if (flush) begin
            elem_cnt  <= '0;
            recv_done <= '0;
            row <= '0;
            col <= '0;
        end

        else if (s_tvalid && s_tready) begin
            row <= elem_cnt / N;
            col <= elem_cnt % N;
            mat[row][col] <= s_tdata;
            elem_cnt <= elem_cnt + 1;

            if (elem_cnt == TOTAL) begin
                recv_done <= 1;
            end
            else begin
                recv_done <= 0;
            end
        end
        else begin
            recv_done <= 0;
        end
    end

endmodule

