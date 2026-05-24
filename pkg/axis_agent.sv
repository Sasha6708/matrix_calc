class agent #(int N = 4, int DATA_W = 16);

    virtual axis_if                                axis_vif;
    bit                                            is_active;
    axis_driver #(N, DATA_W)                       s_driver;
    axis_monitor #(N, DATA_W)                      s_monitor;
    sv_analysis_port #(axis_seq_item #(N, DATA_W)) sap;
    mailbox #(axis_seq_item #(N, DATA_W))          seq_item_port;

    function new(virtual axis_if axis_vif, bit is_active = 1);
        this.axis_vif  = axis_vif;
        this.is_active = is_active;
        seq_item_port  = new();
        sap            = new();
        s_monitor      = new(axis_vif.monitor, sap);
        if(is_active) begin
            s_driver   = new(axis_vif.master, seq_item_port);
        end
    endfunction

    function subscribe(mailbox #(seq_item_port #(N, DATA_W)) mb);
        sap.subscribe(mb); 
    endfunction
    
    task run();
        fork
            s_monitor.run();
            if(is_active) begin
                s_driver.run();
            end
        join_none
    endtask

endclass