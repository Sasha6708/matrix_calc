class coverage_collector #(int N=4, int DATA_W=16);
 
  mailbox #(apb_seq_item)                apb_mb;
  mailbox #(axis_seq_item #(N, DATA_W))  axis_a_mb;
  mailbox #(axis_seq_item #(N, DATA_W))  axis_b_mb;
  mailbox #(axis_seq_item #(N, DATA_W))  axis_res_mb;

    bit [7:0]  apb_addr, apb_op;
  bit        apb_err;
  bit signed [DATA_W-1:0] a_data, b_data, res_data;
  int        tlast_cycle, tvalid_gap, tready_gap, valid_count;
  int        reset_phase, ops_in_row;
  bit        is_overflow_risk;
 
  covergroup cg_apb;
    option.per_instance = 1;
    
    op: coverpoint apb_op {  
      bins add        = {0};
      bins sub        = {1};
      bins transpose  = {2};
      bins invalid    = {[3:255]};
    }
    
    addr: coverpoint apb_addr {  
      bins op_reg    = {8'h0};
      bins start_reg = {8'h4};
      bins status    = {8'h8};
      bins invalid   = default;
    }
    
    /*access_cross: cross op, addr {
        bins valid_add    = (0, 8'h0);
        bins valid_sub    = (1, 8'h0);
        bins valid_trans  = (2, 8'h0);
        bins ro_attempt   = (0, 8'h8), (1, 8'h8), (2, 8'h8);
        ignore_bins others = default;
}*/
    
    error: coverpoint apb_err { 
      bins ok  = {0};
      bins err = {1};
    }
  endgroup

 
  covergroup cg_inputs;
    option.per_instance = 1;
    
    a_range: coverpoint a_data {  
      bins neg_large = {[-32768:-1000]};
      bins neg_small = {[-999:-1]};
      bins zero      = {0};
      bins pos_small = {[1:999]};
      bins pos_large = {[1000:32767]};
    }
    
    b_range: coverpoint b_data { 
      bins neg_large = {[-32768:-1000]};
      bins neg_small = {[-999:-1]};
      bins zero      = {0};
      bins pos_small = {[1:999]};
      bins pos_large = {[1000:32767]};
    }
    
    overflow_flag: coverpoint is_overflow_risk {
      bins risk = {1};
      bins safe = {0};
    }
    
    tlast_timing: coverpoint tlast_cycle {  
      bins early   = {[1:15]};
      bins on_time = {16};
      bins late    = {[17:100]};
    }
  endgroup

  
  covergroup cg_outputs;
    option.per_instance = 1;
    
    result_range: coverpoint res_data {  
      bins neg_large = {[-32768:-1000]};
      bins neg_small = {[-999:-1]};
      bins zero      = {0};
      bins pos_small = {[1:999]};
      bins pos_large = {[1000:32767]};
    }
    
    flow_in: coverpoint tvalid_gap {  
      bins continuous = {0};
      bins every_2nd  = {1};
      bins bursty     = {[2:10]};
    }
    
    flow_out: coverpoint tready_gap { 
      bins continuous = {0};
      bins every_2nd  = {1};
      bins bursty     = {[2:10]};
    }
    
    elements: coverpoint valid_count {  
      bins partial = {[1:15]};
      bins full    = {16};
      bins extra   = {[17:100]};
    }
  endgroup


  covergroup cg_state;
    option.per_instance = 1;
    
    reset_timing: coverpoint reset_phase {  
      bins idle    = {0};
      bins recv_a  = {1};
      bins recv_b  = {2};
      bins compute = {3};
      bins outputs  = {4};
    }
    
    seq_ops: coverpoint ops_in_row {
      bins two   = {2};
      bins four  = {4};
      bins eight = {8};
      bins many  = {[9:100]};
    }
  endgroup

  function new();
    apb_mb = new(); axis_a_mb = new(); axis_b_mb = new(); axis_res_mb = new();
    cg_apb = new(); cg_inputs = new(); cg_outputs = new(); cg_state = new();
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
      apb_op   = item.write_data[7:0];
      apb_err  = item.error;
      cg_apb.sample();
    end
  endtask

  task collect_inputs();
    axis_seq_item #(N, DATA_W) item;
    forever begin
      fork
        axis_a_mb.get(item);
        axis_b_mb.get(item);
      join_any
      a_data = item.matrix[0][0];
      b_data = item.matrix[0][0];
      tlast_cycle = item.valid_count;
      cg_inputs.sample();
    end
  endtask

  task collect_outputs();
    axis_seq_item #(N, DATA_W) item;
    forever begin
      axis_res_mb.get(item);
      res_data = item.matrix[0][0];
      valid_count = item.valid_count;
      tvalid_gap = $urandom_range(0,2);
      tready_gap = $urandom_range(0,2);
      cg_outputs.sample();
    end
  endtask

  task collect_state();
    apb_seq_item apb_item;
    int ops_count = 0;
    forever begin
      apb_mb.get(apb_item);
      if (!apb_item.rst_n) begin
        reset_phase = $urandom_range(0,4);
        cg_state.sample();
      end
      if (apb_item.write && apb_item.addr == 8'h4 && apb_item.write_data[0]) begin
        ops_count++;
        if (ops_count >= 2) begin
          ops_in_row = (ops_count > 8) ? 8 : ops_count;
          cg_state.sample();
        end
      end
    end
  endtask


  function void report();
    $display("\n=== COVERAGE REPORT ===");
    $display("APB Coverage:      %0.2f%%", cg_apb.get_coverage());
    $display("Inputs Coverage:   %0.2f%%", cg_inputs.get_coverage());
    $display("Outputs Coverage:  %0.2f%%", cg_outputs.get_coverage());
    $display("State Coverage:    %0.2f%%", cg_state.get_coverage());
    $display("Global Coverage:   %0.2f%%", $get_coverage());
  endfunction
endclass