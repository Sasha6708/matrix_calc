class apb_monitor;

    virtual apb_if apb_vif;
    sv_analysis_port_apb sap;

    function new(virtual apb_if apb_vif, sv_analysis_port_apb sap);
        this.apb_vif = apb_vif;
        this.sap     = sap;
    endfunction

    task run(); 
    apb_seq_item txn;
        forever begin
            @(posedge apb_vif.clk);
            capture_apb_txn(txn);
        end
    endtask

    local task capture_apb_txn(apb_seq_item txn);
        static bit in_transfer = 0;
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
            txn.error      = apb_vif.pslverr; 
            sap.write(txn);
            in_transfer    = 0;
        end
    endtask

endclass