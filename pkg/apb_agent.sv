class apb_agent;

    virtual apb_if apb_vif; 
    apb_driver a_driver;
    apb_monitor a_monitor;
    sv_analysis_port_apb #(apb_seq_item) sap;
    mailbox #(apb_seq_item) seq_item_port;

    function new(virtual apb_if apb_vif);
        seq_item_port = new();
        sap           = new();
        a_driver      = new(apb_vif.driver, seq_item_port);
        a_monitor     = new(apb_vif.monitor, sap);
    endfunction

    task run();
        fork
            a_driver.run();
            a_monitor.run();
        join_none
    endtask
    
    function subscribe(mailbox #(apb_seq_item) mb);
        sap.subscribe(mb);
    endfunction

endclass