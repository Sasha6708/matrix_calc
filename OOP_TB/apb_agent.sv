class apb_agent;
    virtual apb_if vif; 
    apb_driver a_driver;
    apb_monitor a_monitor;
    sv_analisys_port #(apb_seq_item) sap;
    mailbox #(apb_seq_item) seq_item_port;

    function new(virtual apb_if vif);
        seq_item_port = new();
        sap           = new();
        a_driver      = new(vif, seq_item_port);
        a_monitor     = new(vif, sap);
    endfunction

    task run();
        fork
            a_driver.run();
            a_monitor.run();
        join_none
    endtask
    
    function subcribe(mailbox #(seq_item_port) mb);
        sap.subcribe(mb);
    endfunction

endclass