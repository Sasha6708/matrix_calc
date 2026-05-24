class axis_driver #(int N = 4, int DATA_W = 16);

    virtual axis_if vif;
    mailbox #(axis_seq_item #(N, DATA_W)) seq_item_port;
    
    function new(virtual axis_if vif, mailbox #(axis_seq_item) seq_item_port);
        this.vif = vif;
        this.seq_item_port = seq_item_port;
    endfunction

    task run();
        axis_seq_item #(N,DATA_W) txn;
        reset();
        forever begin
            @(posedge vif.clk);
            seq_item_port.get(txn);
            drive_matrix(txn);
        end
    endtask

    local task reset();
        vif.tvalid = 0;
        vif.tdata  = '0;
        vif.tlast  = 0;
    endtask

    local task drive_matrix(axis_seq_item #(N, DATA_W) txn);
        int idx = 0;
        for(int i = 0; i < N; i++) begin
            for(int j = 0; j < N; j++) begin
                @(posedge vif.clk);
                vif.tvalid <= 1;
                vif.tdata  <= txn.matrix[i][j];
                vif.tlast  <= (idx == N * N - 1) ? txn.tlast : 0;
                idx++;
                while(!vif.tready) begin
                    @(posedge vif.clk);
                end
            end
        end
        @(posedge vif.clk);
        vif.tvalid <= 0;
        vif.tlast  <= 0;
    endtask
endclass