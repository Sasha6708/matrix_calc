class scoreboard #(int N, int DATA_W);

    mailbox #(apb_seq_item)               apb_mb;
    mailbox #(axis_seq_item #(N, DATA_W)) axis_a_mb;
    mailbox #(axis_seq_item #(N, DATA_W)) axis_b_mb;
    mailbox #(axis_seq_item #(N, DATA_W)) axis_res_mb;

    function new();
        apb_mb = new();
        axis_a_mb = new();
        axis_b_mb = new();
        axis_res_mb = new();
    endfunction

endclass