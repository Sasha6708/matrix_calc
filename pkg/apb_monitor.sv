class apb_monitor;

    virtual apb_if.monitor apb_vif;
    sv_analysis_port #(apb_seq_item) sap;

    function new(virtual apb_if.monitor apb_vif, sv_analysis_port #(apb_seq_item) sap);
        this.apb_vif = apb_vif;
        this.sap = sap;
    endfunction

    task run()
        forever begin
            @(posedge apb_vif.clk);
            capture_apb_txn();
            end
    endtask

    local task capture_apb_txn();
        static bit in_transfer = 0;
        static apb_seq_item txn;
        if(apb_vif.psel && !apb_vif.penable && !in_transfer) begin //SETUP PHASE
                in_transfer = 1;
                txn         = new();
                txn.addr    = apb_vif.paddr;
                txn.write   = apb_vif.pwrite;
                if(apb_vif.pwrite) begin
                    txn.write_data = apb_vif.pwdata;
                end
            end
        else if(apb_vif.psel && apb_vif.penable && in_transfer) begin //ACCESS PHASE 
            if(!txn.write) begin
                txn.read_data = apb_vif.prdata;
            end               
            txn.error   = apb_vif.pslverr; 
            sap.write(txn);
            in_transfer = 0;
        end
    endtask

endclass