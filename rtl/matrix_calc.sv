module matrix_calc #(
    parameter N      = 4,
    parameter DATA_W = 16
) (
    //System sygnals
    input  logic        clk,
    input  logic        rst_n,

    //APB Slave
    input  logic        psel,
    input  logic        penable,
    input  logic        pwrite,
    input  logic [7:0]  paddr,
    input  logic [31:0] pwdata,
    output logic [31:0] prdata,
    output logic        pready,
    output logic        pslverr,

    //AXI4-Stream Slave: matrix A
    input  logic signed [DATA_W-1:0] s_axis_a_tdata,
    input  logic                     s_axis_a_tvalid,
    input  logic                     s_axis_a_tlast,
    output logic                     s_axis_a_tready,

    //AXI4-Stream Slave: matrix B
    input  logic signed [DATA_W-1:0] s_axis_b_tdata,
    input  logic                     s_axis_b_tvalid,
    input  logic                     s_axis_b_tlast,
    output logic                     s_axis_b_tready,

    //AXI4-Stream Master: result
    output logic signed [DATA_W-1:0] m_axis_res_tdata,
    output logic                     m_axis_res_tvalid,
    output logic                     m_axis_res_tlast,
    input  logic                     m_axis_res_tready,

    output debug_fsm_state
);

//APB_CSR signals
logic done_i, busy_i, overflow_i, singular_i, start;
logic        [1: 0] op;
logic start_cmd;

//AXIS_RX signals
logic flush, recv_done_a, recv_done_b;
//Buffers
logic signed [DATA_W - 1: 0]                matrix_a [N][N];
logic signed [DATA_W - 1: 0]                matrix_b [N][N];

//Computing units
logic add, sub, addsub_overflow;
logic signed [DATA_W - 1: 0]    matrix_result_addsub [N][N];
logic signed [DATA_W - 1: 0] matrix_result_transpose [N][N];

//AXIS_TX signals
logic send_tx, done_tx;
logic done_hold;

//OTHER
logic need_matric_b;
logic signed [DATA_W - 1: 0]              mux_result [N][N];

//Define FSM
typedef enum logic [2:0]   { IDLE       = 3'b000,
                             RECV       = 3'b001,
                             WAIT_START = 3'b010,
                             COMPUTE    = 3'b011,
                             SEND       = 3'b100,
                             DONE_WAIT  = 3'b101 } state_t;

state_t state, next_state;

apb_csr #(.N                (N                      ),
          .DATA_W           (DATA_W                 )
) apb_csr_dut (
          .clk              (clk                    ),
	      .rst_n            (rst_n                  ),
	      .psel             (psel                   ),
	      .penable          (penable                ),
	      .pwrite           (pwrite                 ),
	      .paddr            (paddr                  ),
          .pwdata           (pwdata                 ),
          .prdata           (prdata                 ),
          .pready           (pready                 ),
          .pslverr          (pslverr                ),
          .op               (op                     ),
          .start            (start                  ),
          .done_i           (done_i                 ),
          .busy_i           (busy_i                 ),
          .overflow_i       (overflow_i             ),
          .singular_i       (singular_i             )
);
axis_rx #(.N                (N                      ),
          .DATA_W           (DATA_W                 )
) axis_rx_dut1 (
          .clk              (clk                    ),
          .rst_n            (rst_n                  ),
          .s_tdata          (s_axis_a_tdata         ),
          .s_tvalid         (s_axis_a_tvalid        ),
          .s_tlast          (s_axis_a_tlast         ),
          .s_tready         (s_axis_a_tready        ),
          .flush            (flush                  ),
          .mat              (matrix_a               ),
          .recv_done        (recv_done_a            )
);
axis_rx #(.N                (N                      ),
          .DATA_W           (DATA_W                 )
) axis_rx_dut2 (
          .clk              (clk                    ),
          .rst_n            (rst_n                  ),
          .s_tdata          (s_axis_b_tdata         ),
          .s_tvalid         (s_axis_b_tvalid        ),
          .s_tlast          (s_axis_b_tlast         ),
          .s_tready         (s_axis_b_tready        ),
          .flush            (flush                  ),
          .mat              (matrix_b               ),
          .recv_done        (recv_done_b            )
);
mat_addsub #(
          .N                (N                      ),
          .DATA_W           (DATA_W                 )
) mat_addsub_dut (
          .add              (add                    ),
          .sub              (sub                    ),
          .mat_a            (matrix_a               ),
          .mat_b            (matrix_b               ),
          .mat_result       (matrix_result_addsub   ),
          .overflow         (addsub_overflow        )
);
mat_transpose #(
          .N                (N                      ),
          .DATA_W           (DATA_W                 )
) mat_transpose_dut (
          .matrix_in        (matrix_a               ),
          .matrix_out       (matrix_result_transpose)
);

axis_tx #(
          .N                (N                      ),
          .DATA_W           (DATA_W                 )
) axis_tx_dut (
          .clk              (clk                    ),
          .rst_n            (rst_n                  ),
          .send             (send_tx                ),        
          .mat_in           (mux_result             ),         
          .m_tdata          (m_axis_res_tdata       ),
          .m_tvalid         (m_axis_res_tvalid      ),
          .m_tlast          (m_axis_res_tlast       ),
          .m_tready         (m_axis_res_tready      ),
          .done_tx          (done_tx                )
        //.is_scalar        (0                      ),
        //.scalar_in        (0                      )
);

//Determine which operation <add> or <sub>
always_comb begin
    add = 1'b0;
    sub = 1'b0;
    add = (op == 2'b00); // 1 только для ADD
    sub = (op == 2'b01); // 1 только для SUB
   
end

//Choose the way to AXIS_TX
always_comb begin
    mux_result = '{default: '0};
    if (op[1] == 1'b0) begin
        mux_result = matrix_result_addsub;
    end
    else if (op[1] == 1'b1) begin
        mux_result = matrix_result_transpose;
    end
end

//Checking need to use matrix_b and addsub_overflow
assign need_matric_b = (op[1] == 1'b0);
assign overflow_i = addsub_overflow;


always_ff @(posedge clk or negedge rst_n) begin
  if (!rst_n) 
    start_cmd <= 1'b0;
  else if (start)         
    start_cmd <= 1'b1;
  else if (state == COMPUTE) 
    start_cmd <= 1'b0;
end

//Logic FSM
always_comb begin
    next_state = state;
    case (state)
        IDLE:   if (s_axis_a_tvalid) begin 
                    next_state = RECV;
                end
         RECV:

            if (recv_done_a && recv_done_b) begin
                next_state = WAIT_START;
            end
        
        WAIT_START: if (start_cmd) begin 
                    next_state = COMPUTE;
                    end
        COMPUTE:    next_state = SEND;
        SEND:   if (done_tx) begin
                    next_state = DONE_WAIT;
                end
        DONE_WAIT:  next_state = IDLE;
        default:    next_state = IDLE;
    endcase
end

always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        state <= IDLE;
    end
    else begin
        state <= next_state;
    end
end


always_ff @(posedge clk or negedge rst_n) begin
  if (!rst_n) 
    done_hold <= 1'b0;
  else if (state == DONE_WAIT) 
    done_hold <= 1'b1;  
  else if (s_axis_a_tvalid) 
    done_hold <= 1'b0;  
end
assign done_i = done_hold;
//Decribe the flush
assign flush = (state == IDLE) & ~s_axis_a_tvalid;

//Control signal AXIS_TX
assign send_tx         = (state == SEND);

//Flags for APB_CSR
assign busy_i          = (state != IDLE) && (state != DONE_WAIT);
assign singular_i = 1'b0;
assign debug_fsm_state = state;


endmodule