class matrix_env #(int N = 4, int DATA_W = 16);

    apb_agent                            apb_agent_e;
    axis_agent #(.N(N), .DATA_W(DATA_W)) axis_a_agent_e;
    axis_agent #(.N(N), .DATA_W(DATA_W)) axis_b_agent_e;
    axis_agent #(.N(N), .DATA_W(DATA_W)) axis_res_agent_e;

    scoreboard                           scoreboard_e;
    coverage_collector                   coverage_collector_e;

    virtual apb_if                       apb_vif;
    virtual axis_if                      axis_a_vif;
    virtual axis_if                      axis_b_vif;
    virtual axis_if                      axis_res_vif;

    function new(virtual apb_if apb_vif,
                 virtual axis_if axis_a_vif,
                 virtual axis_if axis_b_vif,
                 virtual axis_if axis_res_vif);
        this.apb_vif               = apb_vif;
        this.axis_a_vif     = axis_a_vif;
        this.axis_b_vif     = axis_b_vif;
        this.axis_res_vif   = axis_res_vif;
    endfunction

    function void build();
        scoreboard_e         = new();
        coverage_collector_e = new();
        apb_agent_e          = new(apb_vif, 1);
        axis_a_agent_e       = new(axis_a_vif, 1);
        axis_b_agent_e       = new(axis_b_vif, 1);
        axis_res_agent_e     = new(axis_res_vif, 0);

        void'(apb_agent_e.subscribe(scoreboard_e.apb_mb));
        void'(axis_a_agent_e.subscribe(scoreboard_e.axis_a_mb));
        void'(axis_b_agent_e.subscribe(scoreboard_e.axis_b_mb));
        void'(axis_res_agent_e.subscribe(scoreboard_e.axis_res_mb));

        void'(apb_agent_e.subscribe(coverage_collector_e.apb_mb));
        void'(axis_a_agent_e.subscribe(coverage_collector_e.axis_a_mb));
        void'(axis_b_agent_e.subscribe(coverage_collector_e.axis_b_mb));
        void'(axis_res_agent_e.subscribe(coverage_collector_e.axis_res_mb));   
    endfunction

    task run();
        fork
            apb_agent_e.run();
            axis_a_agent_e.run();
            axis_b_agent_e.run();
            axis_res_agent_e.run();
            scoreboard_e.run();
            coverage_collector_e.run();
        join_none
    endtask

    function void report();
        coverage_collector_e.report();
    endfunction
    
endclass