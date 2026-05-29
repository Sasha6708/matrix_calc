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
        expected_count = N * N;
        reset_state();
    endfunction

    task run();
        fork
            collect_apb();
            collect_res_axis(); 
        join_none
    endtask

    task collect_apb();
        apb_seq_item item;
        forever begin
            apb_mb.get(item);  
            
            if (!item.write) continue; 
            
            case (item.addr)
            8'h0: begin  // OP register
                opp = item.write_data[1:0];
                cfg_valid = 1'b1;  
                $display("[SCOREBOARD] OP=0x%0h configured", opp);
            end
            8'h4: begin  // START register
                if (item.write_data[0]) begin
                start_received = 1'b1;  
                $display("[SCOREBOARD] START received");
                end
            end
            8'h8: begin  // STATUS (read) 
            
            end
            endcase
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
    axis_seq_item #(N, DATA_W) res_item, item_a, item_b;
    forever begin
        
        wait (cfg_valid && start_received);  
       
        wait (axis_a_mb.num() > 0 && axis_b_mb.num() > 0);
        axis_a_mb.get(item_a); axis_b_mb.get(item_b); 
        ref_a = item_a.matrix;
        ref_b = item_b.matrix;
        
        compute_expected_from_items(ref_a, ref_b);
        
       
       
        fork
            wait (axis_res_mb.num() > 0);
            begin #2000; $display("[SCB]  TIMEOUT: result not get!"); end
        join_any
        disable fork;
        
        if (axis_res_mb.num() == 0) begin
            cfg_valid = 1'b0;
            start_received = 1'b0;
            continue;
        end

        axis_res_mb.get(res_item);
        dut_out = res_item.matrix;
        
        
        
         print_matrix("Expected(ref_exp)", ref_exp);
        print_matrix("Result DUT (dut_out)", dut_out);

        if (compare_results()) begin
            $display("[SCOREBOARD] PASS opp=%b | elem=%0d", opp, res_item.valid_count);
            pass_cnt++;
        end else begin
            $display("[SCOREBOARD] FAIL opp=%b at [%d][%d]: exp=%d, got=%d", 
                     opp, err_i, err_j, ref_exp[err_i][err_j], dut_out[err_i][err_j]);
            fail_cnt++;
        end
        cfg_valid = 1'b0; start_received = 1'b0;
    end
endtask

    protected task compute_expected_from_items(input bit signed [DATA_W-1:0] mat_a[N][N], 
                                            input bit signed [DATA_W-1:0] mat_b[N][N]);
        for (int i=0; i<N; i++) begin
            for (int j=0; j<N; j++) begin
                case (opp)
                    2'b00: ref_exp[i][j] = mat_a[i][j] + mat_b[i][j];
                    2'b01: ref_exp[i][j] = mat_a[i][j] - mat_b[i][j];
                    2'b10: ref_exp[i][j] = mat_a[j][i];
                    default: ref_exp[i][j] = 0;
                endcase
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
                                if(temp > ((1 <<(DATA_W - 1)) - 1) || temp < -(1 << (DATA_W - 1))) begin
                                    overflow_expected = 1;
                                end
                                else begin
                                    ref_exp[i][j] = temp[DATA_W - 1: 0];
                                end
                        end
                    2'b01: begin
                                temp = ref_a[i][j] - ref_b[i][j];
                                if(temp > ((1 << (DATA_W - 1)) - 1) || temp < -(1 << (DATA_W -1))) begin
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
        return overflow_expected;
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

    protected task print_matrix(string name, bit signed [DATA_W-1:0] m[N][N]);
        $display(" === %s ===", name);
        for (int i = 0; i < N; i++) begin
            $write("   [");
            for (int j = 0; j < N; j++) $write("%5d ", m[i][j]);
            $display("]");
        end
    endtask

    function reset_state();
    cfg_valid        = 1'b0;
    start_received   = 1'b0;
    overflow_expected = 1'b0;
    elements_received = 0;
    ref_a[N][N] = 0; ref_b[N][N] =0; ref_exp[N][N] = 0; dut_out[N][N] = 0;
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