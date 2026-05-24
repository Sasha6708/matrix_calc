class axis_monitor #(int N = 4; int DATA_W = 16);
    virtual axis_if vif;
    sv_analysis_port #(axis_seq_item #(N, DATA_W)) sap;

    function new(virtual axis_if vif, sv_analysis_port #(axis_seq_item #(N, DATA_W)) sap);
        this.vif = vif;
        this.sap = sap;
    endfunction

    task run();
        axis_seq_item #(N, DATA_W) txn;
        int valid_count;
        int k, l;
        bit collecting;

        forever begin
            @(posedge vif.clk);
            if(vif.tvalid && vif.tready) begin
                if(!collecting) begin
                    collecting = 1;
                    k = 0;
                    l = 0;
                    valid_count = 0;
                    txn = new();
                end
                if(k < N && l < N) begin
                    txn.matrix[k][l] = vif.tdata;
                    l++;
                    if(l == N) begin
                        l = 0;
                        k++;
                    end
                    valid_count++;
                end
                if(vif.tlast) begin
                    txn.valid_count = valid_count;
                    sap.write(txn);
                    collecting = 0;
                end
            end
            if(!vif.tvalid) begin
                collecting = 0;
            end
        end
    endtask
endclass