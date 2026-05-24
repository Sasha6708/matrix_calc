class apb_monitor;
    virtual apb_if vif;
    sv_analisys_port #(apb_seq_item) sap;

    function new(virtual apb_if vif, sv_analisys_port #(apb_seq_item) sap);
        this.vif = vif;
        this.sap = sap;
    endfunction

    task run()
        apb_seq_item txn;
        bit in_transfer = 0;
        forever begin
            @(posedge vif.clk);
            if(vif.psel && !vif.penable && !in_transfer) begin //SETUP PHASE
                in_transfer = 1;
                txn = new();
                txn.addr = vif.paddr;
                txn.write = vif.pwrite;
            end
            else if(vif.psel && vif.penable && in_transfer) begin//ACCESS PHASE 
                if(!pwrite) begin
                    txn.read_data = vif.prdata;
                end
                else begin
                    txn.write_data = vif.pwdata;
                end
                sap.write(txn);
                in_transfer = 0;
            end
        end
    endtask

endclass