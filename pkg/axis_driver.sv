class axis_driver #(int N = 4, int DATA_W = 16);

    virtual axis_if axis_vif;
    mailbox #(axis_seq_item #(N, DATA_W)) seq_item_port;
    
    function new(virtual axis_if axis_vif, mailbox #(axis_seq_item #(N, DATA_W)) seq_item_port);
        this.axis_vif      = axis_vif;
        this.seq_item_port = seq_item_port;
    endfunction

    task run();
        axis_seq_item #(N, DATA_W) txn;
        reset();
        forever begin
            @(posedge axis_vif.clk);
            seq_item_port.get(txn);
            drive_matrix(txn);
        end
    endtask

    local task reset();
        axis_vif.tvalid = 0;
        axis_vif.tdata  = '0;
        axis_vif.tlast  = 0;
    endtask

    local task drive_matrix(axis_seq_item #(N, DATA_W) txn);
        int idx = 0;
        for(int i = 0; i < N; i++) begin
            for(int j = 0; j < N; j++) begin
                @(posedge axis_vif.clk);
                axis_vif.tvalid <= 1;
                axis_vif.tdata  <= txn.matrix[i][j];
                axis_vif.tlast  <= (idx == N * N - 1) ? txn.tlast : 0;
                idx++;
                while(!axis_vif.tready) begin
                    @(posedge axis_vif.clk);
                end
            end
        end
        @(posedge axis_vif.clk);
        axis_vif.tvalid <= 0;
        axis_vif.tlast  <= 0;
    endtask

endclass