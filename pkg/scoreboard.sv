class scoreboard #(int N = 4, int DATA_W = 16);

    mailbox #(apb_seq_item)               apb_mb;
    mailbox #(axis_seq_item #(N, DATA_W)) axis_a_mb;
    mailbox #(axis_seq_item #(N, DATA_W)) axis_b_mb;
    mailbox #(axis_seq_item #(N, DATA_W)) axis_res_mb;

    bit signed [DATA_W - 1: 0] ref_a[N][N];
    bit signed [DATA_W - 1: 0] ref_b[N][N];
    bit signed [DATA_W - 1: 0] ref_exp[N][N];
    bit signed [DATA_W - 1: 0] dut_out[N][N];

    int opp;
    bit cfg_valid, start_received;
    bit overflow_expected, overflow;
    int elements_received, expected_count;
    int pass_cnt, fail_cnt, overflow_pass, apb_err_pass;
    int err_i, err_j;

    function new();
        apb_mb      = new();
        axis_a_mb   = new();
        axis_b_mb   = new();
        axis_res_mb = new();
    endfunction

    task run();
        fork
            collect_apb();
            collect_a_axis();
            collect_b_axis();
            collect_res_axis();
        join_none
    endtask

    task collect_apb();
        apb_seq_item item;
        forever begin
            apb_mb.get(item);
            if(item.write && item.addr == 8'h0) begin
                opp = item.write_data[ 1: 0];
                cfg_valid = 1;
                $display("OP = %b", opp);
            end
            if(item.write && item.addr == 8'h4 && item.write_data[0]) begin
                start_received = 1'b1;
                $display("START = 1");
            end
            if(item.error) begin
                $display("pslverr detected");
                apb_err_pass++;
            end
        end
    endtask

    task collect_a_axis();
        axis_seq_item #(N, DATA_W) item;
        forever begin
            axis_a_mb.get(item);
            ref_a = item.matrix;
            $display("Matrix A received (tnx_id = %b)", item.tnx_id);
        end
    endtask

    task collect_b_axis();
        axis_seq_item #(N, DATA_W) item;
        forever begin
            axis_b_mb.get(item);
            ref_b = item.matrix;
            $display("Matrix B received (tnx_id = %b)", item.tnx_id);
        end
    endtask

    task collect_res_axis();
        axis_seq_item #(N, DATA_W) item;
        forever begin
            axis_res_mb.get(item);
            elements_received += item.valid_count;
            dut_out = item.matrix;
            if(cfg_valid && start_received) begin
                compute_expected();
                if(overflow_expected) begin
                    if(check_overflow()) begin
                        $display("Overflow detected");
                        overflow_pass++;
                    end
                    else begin
                        $display("Expected overflow not detected");
                        fail_cnt++;
                    end
                end
                if(compare_results()) begin
                    $display("PASS opp = %b elem = %b", opp, item.valid_count);
                    pass_cnt++;
                end
                else begin
                    $display("FAIL opp = %b mismatch at [%d][%d]: exp = %d, got = %d", opp, err_i, err_j, ref_exp[err_i][err_j], dut_out[err_i][err_j]);
                    fail_cnt++;
                end
            end
            else begin
                $warning("Result arrived before config/start");
            end
        end
    endtask

    function void compute_expected();
        overflow_expected = 0;
        for(int i = 0; i < N; i++) begin
            for(int j = 0; j < N; j++) begin
                bit signed [DATA_W: 0] temp;
                case(opp)
                    2'b00: begin
                                temp = ref_a[i][j] + ref_b[i][j];
                                if(temp > (1 <<(DATA_W - 1)) || temp < -(1 << (DATA_W - 1))) begin
                                    overflow_expected = 1;
                                end
                                else begin
                                    ref_exp[i][j] = temp[DATA_W - 1: 0];
                                end
                        end
                    2'b01: begin
                                temp = ref_a[i][j] - ref_b[i][j];
                                if(temp > (1 << (DATA_W - 1)) || temp < -(1 << (DATA_W -1))) begin
                                    overflow_expected = 1;
                                end
                                else begin
                                    ref_exp[i][j] = temp[DATA_W - 1: 0];
                                end
                        end
                    2'b10: begin
                                ref_exp[i][j] = ref_a[j][i];
                        end
                    default:    ref_exp[i][j] = 0;
                endcase
            end
        end
    endfunction

    function bit check_overflow();
    endfunction

    function bit compare_results();
        err_i = 0;
        err_j = 0;
        for(int i = 0; i < N; i++) begin
            for(int j = 0; j < N; j++) begin
                if(ref_exp[i][j] !== dut_out[i][j]) begin
                    err_i = i;
                    err_j = j;
                    return 0;
                end
            end
        end
        return 1;
    endfunction

    function void report();
        $display("===SCOREBOARD REPORT===");
        $display("Basic Ops: PASS = %d/ FAIL = %d", pass_cnt, fail_cnt);
        $display("Overflow: PASS = %d", overflow_pass);
        $display("APB Errors: PASS = %d", apb_err_pass);
        $display("Flow Control: Elements received = %d (expected = %d)", elements_received, expected_count * (pass_cnt + fail_cnt));
        if(fail_cnt == 0) begin
            $display("ALL CHECKS PASSED");
        end
        else begin
            $display("%d MISMATCHES DETECTED", fail_cnt);
        end
    endfunction

endclass