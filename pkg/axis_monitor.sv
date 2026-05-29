class axis_monitor #(int N = 4, int DATA_W = 16);

    virtual axis_if axis_vif;
    sv_analysis_port_axis sap;
    axis_seq_item #(N, DATA_W) txn;
    int valid_count = 0;
    int k = 0;
    int l = 0;
    bit collecting = 0;

    function new(virtual axis_if axis_vif, sv_analysis_port_axis sap);
        this.axis_vif = axis_vif;
        this.sap = sap;
    endfunction

    task run();
        forever begin
            @(posedge axis_vif.clk);
            capture_axis_tnx();
        end
    endtask

    local task capture_axis_tnx();     
        if(axis_vif.tvalid && axis_vif.tready) begin
                if(!collecting) begin
                    collecting  = 1;
                    k           = 0;
                    l           = 0;
                    valid_count = 0;
                    txn = new();
                end

                if (txn == null) return;
                if(k < N && l < N) begin
                    txn.matrix[k][l] = axis_vif.tdata;
                    l++;
                    if(l == N) begin
                        l = 0;
                        k++;
                    end
                    valid_count++;
                end
                if(axis_vif.tlast) begin
                    txn.valid_count = valid_count;
                    sap.write(txn);
                    collecting      = 0;
                end
            end
            if(!axis_vif.tvalid) begin
                collecting      = 0;
            end
    endtask

endclass