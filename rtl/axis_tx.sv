module axis_tx #(
    parameter N      = 4,
    parameter DATA_W = 16
) (
    input  logic                     clk,
    input  logic                     rst_n,
    input  logic                     send,
    input  logic                     m_tready,
    //input  logic                     is_scalar,
    input  logic signed [DATA_W-1:0] mat_in [N][N],
    //input  logic signed [DATA_W-1:0] scalar_in,
    output logic signed [DATA_W-1:0] m_tdata,
    output logic                     m_tvalid,
    output logic                     m_tlast,
    output logic                     done_tx
);

    localparam int TOTAL = N * N;
    localparam int CNT_W = $clog2(TOTAL + 1);
    localparam int IDX_W = $clog2(N);

    logic [CNT_W - 1: 0] elemt_cnt;
    logic [IDX_W - 1: 0] row, col;

    typedef enum logic {IDLE = 1'b0,
                        SEND = 1'b1 } state_t;
                        
    state_t next_state, state;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state     <= IDLE;
            elemt_cnt <= '0;
            row       <= '0;
            col       <= '0;
            done_tx   <= 1'b0;
        end
        else begin
            state <= next_state;

            //Reset before send
            if (state == IDLE && next_state == SEND) begin
                elemt_cnt <= '0;
                row       <= '0;
                col       <= '0;
                done_tx   <= 1'b0;
            end

            //Write by handshake with 2 counters
            else if(state == SEND && m_tvalid && m_tready) begin
                elemt_cnt <= elemt_cnt + 1;
                if (col == N - 1) begin
                    col <= '0;
                    row <= row + 1;
                end
                else begin
                    col <= col + 1;
                end
            end

            //Sygnal about succesful transfer
            if (state == SEND && m_tready && m_tlast) begin
                done_tx <= 1'b1;
            end
            else if (state == IDLE) begin
                done_tx <= 1'b0;
            end

            
        end
    end
    
    //Logic FSM
    always_comb begin
        m_tdata = mat_in[row][col];
        case (state)
            IDLE:    begin
                        m_tvalid = 1'b0;
                        m_tlast  = 1'b0;
            end
            SEND:    begin
                        m_tvalid = 1'b1;
                        m_tlast  = (elemt_cnt == TOTAL - 1);
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
                        if (m_tvalid && m_tready && elemt_cnt == TOTAL - 1) next_state = IDLE;
            end
            default: begin  
                        next_state = IDLE;
            end
        endcase
    end

endmodule
