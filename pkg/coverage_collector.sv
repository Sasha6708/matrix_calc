class coverage_collector #(int N = 4, int DATA_W = 16);

    mailbox #(apb_seq_item)               apb_mb;
    mailbox #(axis_seq_item #(N, DATA_W)) axis_a_mb;
    mailbox #(axis_seq_item #(N, DATA_W)) axis_b_mb;
    mailbox #(axis_seq_item #(N, DATA_W)) axis_res_mb;

    bit[7: 0] apb_addr, apb_opp;
    bit apb_err;
    bit signed [DATA_W - 1: 0] matrix_a, matrix_b, matrix_res;
    int tlast_cycle,tvalid_gap, tready_gap, valid_count;
    int reset_phase, ops_in_row;

    covergroup apb;
        coverpoint apb_opp{
            bins add = {0};
            bins sub = {1};
            bins transpose = {2};
            bins invalid = {[3:255]};
        }
        coverpoint apb_addr{
            bins op_reg = {8'h0};
            bins start_reg = {8'h4};
            bins status = {8'h8};
            bins invalid = default;
        }
        coverpoint apb_err{
            bins pslverr = {1};
            bins no_err = {0};
        }
    endgroup

    covergroup inputs;
        coverpoint matrix_a{
            bins large_neg = {[-32768:-1000]};
            bins small_neg = {[-999:-1]};
            bins zero = {0};
            bins small_pos = {[1:999]};
            bins large_pos = {[1000:32767]};
        }
        coverpoint matrix_b{
            bins large_neg = {[-32768:-1000]};
            bins small_neg = {[-999:-1]};
            bins zero = {0};
            bins small_pos = {[1:999]};
            bins large_pos = {[1000:32767]};
        }
    endgroup

    covergroup outputs;
        coverpoint matrix_res{
            bins large_neg = {[-32768:-1000]};
            bins small_neg = {[-999:-1]};
            bins zero = {0};
            bins small_pos = {[1:999]};
            bins large_pos = {[1000:32767]};
        }
    endgroup

    covergroup state;
        coverpoint reset_phase{
            bins idle = {0};
            bins recv_a = {1};
            bins recv_b = {2};
            bins compute = {3};
            bins outputs = {4};
        }
    endgroup

    function new();
        apb_mb      = new();
        axis_a_mb   = new();
        axis_b_mb   = new();
        axis_res_mb = new();
        apb = new();
        inputs = new();
        outputs = new();
        state = new();
    endfunction
    
    task run();
        fork
            collect_apb();
            collect_inputs();
            collect_outputs();
            collect_state();
        join_none
    endtask

    task collect_apb();
        apb_seq_item item;
        forever begin
            apb_mb.get(item);
            apb_addr = item.addr;
            apb_opp = item.write_data[7:0];
            apb_err = item.error;
            apb.sample();
        end
    endtask

    task collect_inputs();
        axis_seq_item #(N, DATA_W) item;
        int cycle = 0;
        forever begin
            fork
                axis_a_mb.get(item);
                axis_b_mb.get(item);
            join_any
            matrix_a = item.matrix[0][0];
            matrix_b = item.matrix[0][0];
            tlast_cycle = item.valid_count;
            inputs.sample();
            cycle++;
        end
    endtask

    task collect_outputs();
        axis_seq_item #(N, DATA_W) item;
        int last_valid = 0, last_ready = 0;
        forever begin
            axis_res_mb.get(item);
            matrix_res = item.matrix[0][0];
            valid_count = item.valid_count;
            tvalid_gap = $urandom_range(0,2);
            tready_gap = $urandom_range(0,2);
            outputs.sample();
        end        
    endtask

    task collect_state();
        apb_seq_item item;
        int ops_count = 0;
        forever begin
            apb_mb.get(item);
           /* if(item.rst_n) begin
                reset_phase = $urandom_range(0,4);
                state.sample();
            end*/
            if(item.write && item.addr == 8'h4 && item.write_data[0]) begin
                ops_count++;
                if(ops_count >= 2) begin
                    ops_in_row = (ops_count > 8) ? 8 : ops_count;
                    state.sample();
                end
            end
        end
    endtask

    function void report();
        $display("===COVERAGE REPORT===");
        $display("APB Coverage:      %0.2f%%", apb.get_coverage());
        $display("Inputs Coverage:   %0.2f%%", inputs.get_coverage());
        $display("Outputs Coverage:  %0.2f%%", outputs.get_coverage());
        $display("State Coverage:    %0.2f%%", state.get_coverage());
        $display("Global Coverage:   %0.2f%%", $get_coverage());

       /* $display("--- Per-Scenario Coverage ---");
        $display("1. Basic Ops:      %0.2f%% (OP bins)", 
                apb.apb_opp.get_coverage());
        $display("2. Overflow:       %0.2f%% (corner bins)", 
                inputs.cp_overflow_corner.get_coverage());
        $display("3. Flow Control:   %0.2f%% (gap bins)", 
                (outputs.cp_flow_in.get_coverage() + _outputs.cp_flow_out.get_coverage())/2);
        $display("4. Negative:       %0.2f%% (invalid OP + tlast)", 
                (apb.cp_op.invalid.get_coverage() + inputs.cp_tlast_timing.early.get_coverage())/2);
        $display("5. Reset:          %0.2f%% (reset_phase)", 
                state.cp_reset_timing.get_coverage());
        $display("6. Sequential:     %0.2f%% (ops_in_row)", 
                state.cp_seq_ops.get_coverage());
        $display("7. APB Registers:  %0.2f%% (addr x op cross)", 
                apb.cp_access.get_coverage());
        $display("8. Parameterization: N=%0d (static)", N);
        $display("9. Randomized:     %0.2f%% (data ranges)", 
                (inputs.cp_a_range.get_coverage() + inputs.cp_b_range.get_coverage())/2);*/
    endfunction

endclass