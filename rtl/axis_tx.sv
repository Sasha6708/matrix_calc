module axis_tx #(
    parameter N      = 4,
    parameter DATA_W = 16
) (
    input  logic                     clk,
    input  logic                     rst_n,
    input  logic                     send,
    input  logic                     is_scalar,
    input  logic signed [DATA_W-1:0] mat_in [N][N],
    input  logic signed [DATA_W-1:0] scalar_in,
    output logic signed [DATA_W-1:0] m_tdata,
    output logic                     m_tvalid,
    output logic                     m_tlast,
    input  logic                     m_tready
);

    localparam int TOTAL = N * N;
    localparam int CNT_W = $clog2(TOTAL + 1);
    localparam int IDX_W = $clog2(N);

    logic [CNT_W - 1: 0] elem_cnt;
    wire [IDX_W - 1: 0] row, col;
    assign row = elem_cnt / N;
    assign col = elem_cnt % N;

    typedef enum logic {IDLE, SEND} state_t;
    state_t next_state, state;

    always_ff @(posedge clk) begin
        if (!rst_n) begin
            state <= IDLE;
            elem_cnt <= '0;
        end
        else begin
            state <= next_state;
            if(m_tvalid && m_tready) begin
                elem_cnt <= elem_cnt + 1;
            end
            else if (state == IDLE && send) begin
                elem_cnt <= '0;
            end
        end
    end
    
    always_comb begin
        m_tdata = mat_in[row][col];
        case (state)
            IDLE:    begin
                        m_tvalid = 1'b0;
                        m_tlast  = 1'b0;
            end
            SEND:    begin
                        m_tvalid = 1'b1;
                        m_tlast  = (elem_cnt == TOTAL - 1);
            end
            default: begin
                        m_tvalid = 1'b0;
                        m_tlast  = 1'b0;
            end
        endcase
    end

    always_comb begin
        next_state = state;
        case (state)
            IDLE:    begin 
                        if (send) next_state = SEND;
            end
            SEND:    begin
                        if (m_tvalid && m_tready && elem_cnt == TOTAL - 1) next_state = IDLE;
            end
            default: begin  
                        next_state = IDLE;
            end
        endcase
    end

endmodule
