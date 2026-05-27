class apb_agent;

    virtual apb_if apb_vif; 
    bit            is_active;
    apb_driver a_driver;
    apb_monitor a_monitor;
    sv_analysis_port_apb sap;
    mailbox #(apb_seq_item) seq_item_port;

    function new(virtual apb_if apb_vif, bit is_active = 1);
        seq_item_port = new();
        sap           = new();
        a_monitor     = new(apb_vif, sap);
        if(is_active) begin
            a_driver  = new(apb_vif, seq_item_port);
        end
    endfunction

    task run();
        fork
            a_monitor.run();
            if(is_active) begin
                a_driver.run();
            end
        join_none
    endtask
    
    function subscribe(mailbox #(apb_seq_item) mb);
        sap.subscribe(mb);
    endfunction

    function mailbox #(apb_seq_item) get_driver_mailbox();
        return seq_item_port;
    endfunction

endclass