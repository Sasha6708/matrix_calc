module tb_top;

    bit clk;
    bit rst_n;

    apb_if                            apb_vif(.clk(clk), .rst_n(rst_n));
    axis_if #(.N(4), .DATA_WIDTH(16)) axis_a_vif(.clk(clk), .rst_n(rst_n));
    axis_if #(.N(4), .DATA_WIDTH(16)) axis_b_vif(.clk(clk), .rst_n(rst_n));
    axis_if #(.N(4), .DATA_WIDTH(16)) axis_res_vif(.clk(clk), .rst_n(rst_n));

    matrix_calc #(
        .N                  (4                  ),
        .DATA_WIDTH         (16                 )
    ) dut (
        .clk                (clk                ),
        .rst_n              (rst_n              ),
        .psel               (apb_vif.psel       ),
        .penable            (apb_vif.penable    ),
        .pwrite             (apb_vif.pwrite     ),
        .paddr              (apb_vif.paddr      ),
        .pwdata             (apb_vif.pwdata     ),
        .prdata             (apb_vif.prdata     ),
        .pready             (apb_vif.pready     ),
        .pslverr            (apb_vif.pslverr    ),
        .s_axis_a_tdata     (axis_a_vif.tdata   ),
        .s_axis_a_tvalid    (axis_a_vif.tvalid  ),
        .s_axis_a_tlast     (axis_a_vif.tlast   ),
        .s_axis_a_tready    (axis_a_vif.tready  ),
        .s_axis_b_tdata     (axis_b_vif.tdata   ),
        .s_axis_b_tvalid    (axis_b_vif.tvalid  ),
        .s_axis_b_tlast     (axis_b_vif.tlast   ),
        .s_axis_b_tready    (axis_b_vif.tready  ),
        .m_axis_res_tdata   (axis_res_vif.tdata ),
        .m_axis_res_tvalid  (axis_res_vif.tvalid),
        .m_axis_res_tlast   (axis_res_vif.tlast ),
        .m_axis_res_tready  (axis_res_vif.tready)        
    );

    matrix_env #(.N(4), .DATA_W(16)) env;

    initial begin
        clk <= 0;
        forever #10 clk <= ~clk;
    end

    initial begin
        rst_n <= 0;
        #100 
        rst_n <= 1;
        #20
        env = new(apb_vif, axis_a_vif, axis_b_vif, axis_res_vif);
        env.build();
        env.run();
        #200;
        $display("Testbench completed");
        $finish;
    end

endmodule