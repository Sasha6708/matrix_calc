class matrix_test #(int N=4, int DATA_W=16);
 
  bit            add_en       = 1;
  bit            sub_en       = 1;
  bit            trans_en     = 1;
  bit            overflow_en  = 0;
  bit            flow_en      = 0;
  bit            neg_en       = 0;
  bit            reset_en     = 0;
  bit            seq_en       = 0;
  bit            apb_en       = 0;
  bit            param_en     = 0;
  bit            rand_en      = 0;
  int            num_pkts     = 10;

 
  typedef enum bit [1:0] {ADD=0, SUB=1, TRANS=2} op_e;
  rand op_e sel_op;
  constraint c_op_dist {
    sel_op dist {
      ADD    :/ add_en,
      SUB    :/ sub_en,
      TRANS  :/ trans_en
    };
  }

  
  matrix_env #(.N(N), .DATA_W(DATA_W)) env;

 
  function new(matrix_env #(.N(N), .DATA_W(DATA_W)) env);
    this.env = env;
    parse_plusargs();
  endfunction

  function void parse_plusargs();
    void'($value$plusargs("add=%b",        add_en));
    void'($value$plusargs("sub=%b",        sub_en));
    void'($value$plusargs("trans=%b",      trans_en));
    void'($value$plusargs("overflow=%b",   overflow_en));
    void'($value$plusargs("flow=%b",       flow_en));
    void'($value$plusargs("neg=%b",        neg_en));
    void'($value$plusargs("reset=%b",      reset_en));
    void'($value$plusargs("seq=%b",        seq_en));
    void'($value$plusargs("apb=%b",        apb_en));
    void'($value$plusargs("param=%b",      param_en));
    void'($value$plusargs("rand=%b",       rand_en));
    
   
    if (!$value$plusargs("num_pkts=%d", num_pkts)) begin
      num_pkts = 10;
    end

    
    if (!add_en && !sub_en && !trans_en && !overflow_en && !flow_en &&
        !neg_en && !reset_en && !seq_en && !apb_en && !param_en && !rand_en) begin
      add_en = 1; sub_en = 1; trans_en = 1;
    end
  endfunction

  
  task run();
    env.build();
    env.run();

    env.apb_vif.rst_n = 0;
    repeat(10) @(posedge env.apb_vif.clk);
    env.apb_vif.rst_n = 1;
    repeat(5) @(posedge env.apb_vif.clk);

    if (overflow_en)  run_overflow();
    else if (flow_en) run_flow();
    else if (neg_en)  run_negative();
    else if (reset_en)run_reset();
    else if (seq_en)  run_sequential();
    else if (apb_en)  run_apb_regs();
    else if (param_en)run_param();
    else if (rand_en) run_random();
    else              run_basic(); 

    repeat(1000) @(posedge env.apb_vif.clk);
    env.report();
    $display("[TEST] ✅ Finished");
    $finish;
  endtask


    protected task execute_op(op_e op, ref bit signed [DATA_W-1:0] a[N][N], 
                        ref bit signed [DATA_W-1:0] b[N][N],
                        ref bit signed [DATA_W-1:0] expected[N][N]);
    write_apb(8'h0, {30'b0, op});
    
    send_matrix_a(a);
    send_matrix_b(b);
    
    
    wait(!env.axis_a_vif.tvalid && !env.axis_b_vif.tvalid);
    repeat(20) @(posedge env.apb_vif.clk); 
    
    write_apb(8'h4, 32'h1); 
    wait_for_done();
    
    read_and_compare(expected);
  endtask

    task run_basic();
    bit signed [DATA_W-1:0] a[N][N], b[N][N], expected[N][N];
    
    repeat (num_pkts) begin
      void'(randomize(sel_op));
      //sel_op = 2'b10;
      case (sel_op)
        ADD: begin
          for (int i=0; i<N; i++)
            for (int j=0; j<N; j++) begin
              a[i][j] = i*N + j + 1;
              b[i][j] = N*N - (i*N + j);
              expected[i][j] = a[i][j] + b[i][j];  
            end
        end
        SUB: begin
          for (int i=0; i<N; i++)
            for (int j=0; j<N; j++) begin
              a[i][j] = 20 - (i*N + j);
              b[i][j] = i*N + j + 1;
              expected[i][j] = a[i][j] - b[i][j];
            end
        end
        TRANS: begin
          for (int i=0; i<N; i++)
            for (int j=0; j<N; j++) begin
              a[i][j] = i*N + j + 1;
              expected[i][j] = a[j][i]; 
              b[i][j] = 0;
            end
        end
      endcase

    
      print_matrix("A", a);
      print_matrix("B", b);
      print_matrix("EXP", expected);

      execute_op(sel_op, a, b, expected);
      check_status(1'b1, 1'b0, 1'b0);  
    end
  endtask


  task run_overflow();
    bit signed [DATA_W-1:0] A[N][N], B[N][N], expected[N][N];
    bit exp_ovf;
    longint tmp;


    $display("=== CASE 1: FULL MATRIX ADD OVERFLOW ===");
    exp_ovf = 1'b0;
    for (int i=0; i<N; i++) begin
      for (int j=0; j<N; j++) begin
        A[i][j] = 30000 + i*4 + j;   // ~30000..30015
        B[i][j] =  4000 + i*4 + j;   // ~4000..4015 -> sum > 32767
        tmp = longint'(A[i][j]) + longint'(B[i][j]);
        expected[i][j] = tmp[DATA_W-1:0];
        if (tmp > 32767 || tmp < -32768) exp_ovf = 1'b1;
      end
    end
    print_matrix("Input A", A);
    print_matrix("Input B", B);
    print_matrix("Expected Result (wrapped)", expected);
    $display("Expected OVERFLOW: %0b", exp_ovf);

    execute_op(ADD, A, B, expected);
    check_status(1'b1, 1'b0, exp_ovf);

  
    $display("===CASE 2: FULL MATRIX SUB OVERFLOW ===");
    exp_ovf = 1'b0;
    for (int i=0; i<N; i++) begin
      for (int j=0; j<N; j++) begin
        A[i][j] = -30000 - i*4 - j;
        B[i][j] =   4000 + i*4 + j;
        tmp = longint'(A[i][j]) - longint'(B[i][j]);
        expected[i][j] = tmp[DATA_W-1:0];
        if (tmp > 32767 || tmp < -32768) exp_ovf = 1'b1;
      end
    end
    print_matrix("Input A", A);
    print_matrix("Input B", B);
    print_matrix("Expected Result (wrapped)", expected);
    $display("Expected OVERFLOW: %0b", exp_ovf);

    execute_op(SUB, A, B, expected);
    check_status(1'b1, 1'b0, exp_ovf);

    
  endtask


  task run_flow();
    bit signed [DATA_W-1:0] a[N][N], b[N][N], expected[N][N];
    
    for (int i=0; i<N; i++)
      for (int j=0; j<N; j++) begin
        a[i][j] = i*N + j + 1;
        b[i][j] = N*N - (i*N + j);
        expected[i][j] = 17;
      end

    write_apb(8'h0, ADD);
    send_matrix_a(a); send_matrix_b(b);
    write_apb(8'h4, 32'h1);
    
    #1000; 
    check_status(1'b1, 1'b0, 1'b0);
   
  endtask

  task run_negative();
    bit signed [DATA_W-1:0] a[N][N], b[N][N];
    bit [31:0] status;  

    $display("[NEG] 1. START before data...");
    write_apb(8'h0, ADD);
    write_apb(8'h4, 32'h1);
    #200;
    read_apb(8'h8, status);
    if (status[1] !== 1'b0) $display("[NEG] BUSY asserted without data (expected 0, got 1)");
    env.apb_vif.rst_n = 0; #20; env.apb_vif.rst_n = 1; #50;

    $display("[NEG] 2. Invalid OP=0x3...");
    write_apb(8'h0, 32'h3);
    write_apb(8'h4, 32'h1);
    #200;
    read_apb(8'h8, status);
    $display("[NEG] Status after invalid OP: BUSY=%b, DONE=%b", status[1], status[0]);
    env.apb_vif.rst_n = 0; #20; env.apb_vif.rst_n = 1; #50;

    $display("[NEG] 3. Early tlast (10th element)...");
    for(int i=0; i<N; i++) for(int j=0; j<N; j++) begin a[i][j]=i*N+j+1; b[i][j]=0; end
    send_matrix_a_early_tlast(10);
    send_matrix_b(b);
    write_apb(8'h0, ADD);
    write_apb(8'h4, 32'h1);
    #500; 
    read_apb(8'h8, status);
    $display("[NEG] Status after early tlast: BUSY=%b, DONE=%b", status[1], status[0]);   
    $display("[NEG] Recovering via reset...");
    env.apb_vif.rst_n = 0;
    repeat(5) @(posedge env.apb_vif.clk);
    env.apb_vif.rst_n = 1;
    wait(!env.apb_vif.psel && !env.apb_vif.penable);
    repeat(5) @(posedge env.apb_vif.clk); 
    read_apb(8'h8, status);
    $display("[NEG] Post-reset status: BUSY=%b, DONE=%b", status[1], status[0]);
    
    if (status[1:0] !== 2'b00) begin
      $error("[NEG] FAIL: DONE/BUSY != 00 after reset (got %b)", status[1:0]);
    end else begin
      $display("[NEG] Recovery successful. Block is ready for new operation.");
    end
endtask
       
  task run_reset();
    bit signed [DATA_W-1:0] a[N][N], b[N][N];
    bit [31:0] status;
    bit check_pass;
    mailbox #(apb_seq_item) mb;
    apb_seq_item dummy;
    int timeout;

    $display("[RESET] 1. Reset in IDLE...");
    @(posedge env.apb_vif.clk);
    env.apb_vif.rst_n = 0; repeat(5) @(posedge env.apb_vif.clk);
    env.apb_vif.rst_n = 1;
    
    timeout = 0;
    while (!(env.apb_vif.psel === 0 && env.apb_vif.penable === 0) && timeout < 50) begin
      @(posedge env.apb_vif.clk); timeout++;
    end
    if (timeout >= 50) $warning("[RESET] APB bus timeout in IDLE reset");
    repeat(5) @(posedge env.apb_vif.clk);
    
    mb = env.apb_agent_e.get_driver_mailbox(); 
    while (mb.try_get(dummy));
    
    read_apb(8'h8, status);
    
    timeout = 0;
    while (env.axis_a_vif.tready !== 1 && timeout < 50) begin
      @(posedge env.apb_vif.clk); timeout++;
    end
    if (timeout >= 50) $warning("[RESET] tready timeout in IDLE reset");
    repeat(2) @(posedge env.apb_vif.clk);
    
    check_pass = (status[1:0] == 2'b00) && (env.axis_a_vif.tready == 1'b1);
    if (!check_pass) $error("[RESET] FAIL IDLE: OP=0x%0h, DONE/BUSY=%b, tready=%b", status[7:0], status[1:0], env.axis_a_vif.tready);
    else $display("[RESET] IDLE OK");

    $display("[RESET] 2. Reset during reception...");
    send_matrix_a_start(); repeat(3) @(posedge env.apb_vif.clk);
    env.apb_vif.rst_n = 0; repeat(5) @(posedge env.apb_vif.clk);
    env.apb_vif.rst_n = 1;

    repeat(5) @(posedge env.apb_vif.clk);
    
    timeout = 0;
    while (!(env.apb_vif.psel === 0 && env.apb_vif.penable === 0) && timeout < 50) begin
      @(posedge env.apb_vif.clk); timeout++;
    end
    if (timeout >= 50) $warning("[RESET] APB bus timeout in Reception reset");
    repeat(5) @(posedge env.apb_vif.clk);
    
    mb = env.apb_agent_e.get_driver_mailbox(); while (mb.try_get(dummy));
    read_apb(8'h8, status);
    
    timeout = 0;
    while (env.axis_a_vif.tready !== 1 && timeout < 50) begin
      @(posedge env.apb_vif.clk); timeout++;
    end
    if (timeout >= 50) $warning("[RESET] tready timeout in Reception reset");
    repeat(2) @(posedge env.apb_vif.clk);
    
    check_pass = (status[7:0] == 8'h00) && (status[1:0] == 2'b00) && (env.axis_a_vif.tready == 1'b1);
    if (!check_pass) $error("[RESET] FAIL Reception: OP=0x%0h, DONE/BUSY=%b, tready=%b", status[7:0], status[1:0], env.axis_a_vif.tready);
    else $display("[RESET] Reception OK");

    $display("[RESET] 3. Reset during compute/send...");
    for (int i=0; i<N; i++) for (int j=0; j<N; j++) begin a[i][j]=10; b[i][j]=5; end
    write_apb(8'h0, 2'b00); 
    send_matrix_a(a); send_matrix_b(b);
    write_apb(8'h4, 32'h1);
    repeat(5) @(posedge env.apb_vif.clk);
    
    env.apb_vif.rst_n = 0; repeat(5) @(posedge env.apb_vif.clk);
    env.apb_vif.rst_n = 1;
    
    timeout = 0;
    while (!(env.apb_vif.psel === 0 && env.apb_vif.penable === 0) && timeout < 50) begin
      @(posedge env.apb_vif.clk); timeout++;
    end
    if (timeout >= 50) $warning("[RESET] APB bus timeout in Compute reset");
    repeat(5) @(posedge env.apb_vif.clk);
    
    mb = env.apb_agent_e.get_driver_mailbox(); while (mb.try_get(dummy));
    read_apb(8'h8, status);
    
    timeout = 0;
    while (env.axis_a_vif.tready !== 1 && timeout < 50) begin
      @(posedge env.apb_vif.clk); timeout++;
    end
    if (timeout >= 50) $warning("[RESET]  tready timeout in Compute reset");
    repeat(2) @(posedge env.apb_vif.clk);
    
    check_pass = (status[7:0] == 8'h00) && (status[1:0] == 2'b00) && (env.axis_a_vif.tready == 1'b1);
    if (!check_pass) $error("[RESET]  FAIL Compute: OP=0x%0h, DONE/BUSY=%b, tready=%b", status[7:0], status[1:0], env.axis_a_vif.tready);
    else $display("[RESET]  Compute/Send OK");

    $display("[RESET]  Reset scenario finished.");
  endtask

  task run_sequential();
    op_e ops[$] = {ADD, SUB, TRANS}; 
    bit signed [DATA_W-1:0] a[N][N], b[N][N], expected[N][N];
    
    foreach (ops[i]) begin
      for (int r=0; r<N; r++)
        for (int c=0; c<N; c++) begin
          a[r][c] = $urandom_range(1, 100);
          b[r][c] = $urandom_range(1, 100);
          case (ops[i])
            ADD: expected[r][c] = a[r][c] + b[r][c];
            SUB: expected[r][c] = a[r][c] - b[r][c];
            TRANS: expected[r][c] = a[c][r];
          endcase
        end
      execute_op(ops[i], a, b, expected);
      check_status(1'b1, 1'b0, 1'b0);  
    end
  endtask

  task run_apb_regs();
    bit [31:0] rd_data;
    bit signed [DATA_W-1:0] a[N][N], b[N][N];

    $display("[APB] 1. OP readback test...");
    write_apb(8'h0, 32'h00000001);
    read_apb(8'h0, rd_data);
    if (rd_data[7:0] !== 8'h01) $error("[APB] FAIL: OP readback (got 0x%0h)", rd_data[7:0]);

    $display("[APB] 2. START self-clear test...");
    write_apb(8'h4, 32'h1);
    @(posedge env.apb_vif.clk); 
    read_apb(8'h4, rd_data);
    if (rd_data[0] !== 1'b0) $error("[APB] FAIL: START self-clear");

    $display("[APB] 3. Invalid address pslverr test...");
    
    @(posedge env.apb_vif.clk);
    env.apb_vif.psel    <= 1; env.apb_vif.paddr <= 8'hFF; env.apb_vif.pwrite <= 0;
    @(posedge env.apb_vif.clk);
    env.apb_vif.penable <= 1;
    @(posedge env.apb_vif.clk);
    wait(env.apb_vif.pready === 1'b1);
    if (env.apb_vif.pslverr !== 1'b1) $error("[APB] FAIL: pslverr not asserted for 0xFF");
    env.apb_vif.psel    <= 0; env.apb_vif.penable <= 0;

    $display("[APB] 4. BUSY/DONE during operation test...");
    for (int i=0; i<N; i++) for (int j=0; j<N; j++) begin a[i][j]=10; b[i][j]=5; end
    write_apb(8'h0, ADD);
    send_matrix_a(a); send_matrix_b(b);
    write_apb(8'h4, 32'h1);
    
    
    repeat(5) @(posedge env.apb_vif.clk);
    read_apb(8'h8, rd_data);
    if (rd_data[1] !== 1'b1) $error("[APB] FAIL: BUSY!=1 during op");

   
    wait_for_done();
    read_apb(8'h8, rd_data);
    if (rd_data[1:0] !== 2'b01) $error("[APB] FAIL: DONE/BUSY mismatch (got %b)", rd_data[1:0]);

    $display("[APB] All APB register tests passed.");
  endtask

  task run_param();

    $display("[TEST] Parameterization check for N=%0d", N);
    num_pkts = 1;
    run_basic();
  endtask

 
  task run_random();
    bit signed [DATA_W-1:0] a[N][N], b[N][N], expected[N][N];
    longint tmp;
    bit exp_ovf;

    repeat (num_pkts) begin
      void'(randomize(sel_op));
      exp_ovf = 1'b0;

      for (int i=0; i<N; i++) begin
        for (int j=0; j<N; j++) begin
          a[i][j] = $urandom_range(-(2**(DATA_W-1)), (2**(DATA_W-1))-1);
          b[i][j] = $urandom_range(-(2**(DATA_W-1)), (2**(DATA_W-1))-1);

          case (sel_op)
            ADD: begin
              expected[i][j] = a[i][j] + b[i][j];
              tmp = longint'(a[i][j]) + longint'(b[i][j]);
              if (tmp > 32767 || tmp < -32768) exp_ovf = 1'b1;
            end
            SUB: begin
              expected[i][j] = a[i][j] - b[i][j];
              tmp = longint'(a[i][j]) - longint'(b[i][j]);  
              if (tmp > 32767 || tmp < -32768) exp_ovf = 1'b1;
            end
            TRANS: begin
              expected[i][j] = a[j][i];
            end
          endcase
        end
      end
      execute_op(sel_op, a, b, expected);
      check_status(1'b1, 1'b0, exp_ovf);  
    end
  endtask

 
protected task write_apb(bit [7:0] addr, bit [31:0] data);
    mailbox #(apb_seq_item) mb;
    apb_seq_item txn;
   if (env == null) begin
    $fatal(1, "[TEST] CRITICAL: env is NULL! Did you call new() in tb_top?");
  end

 
  if (env.apb_agent_e == null) begin
    $fatal(2, "[TEST] CRITICAL: apb_agent_e is NULL! Did you call env.build()?");
  end
  mb = env.apb_agent_e.get_driver_mailbox();
  txn = new();
  txn.addr = addr;
  txn.write_data = data;
  txn.write = 1'b1;
  mb.put(txn);
  wait(env.apb_vif.penable && env.apb_vif.pready);  
  wait(!env.apb_vif.psel);                  
  #5;  
 
endtask

protected task read_apb(bit [7:0] addr, output bit [31:0] data);
  mailbox #(apb_seq_item) mb = env.apb_agent_e.get_driver_mailbox();
  apb_seq_item txn = new();
  txn.addr = addr;
  txn.write = 1'b0;
  
  mb.put(txn); #0;

  forever begin
    @(posedge env.apb_vif.clk);
    if (env.apb_vif.psel && env.apb_vif.penable && env.apb_vif.pready) begin
      data = env.apb_vif.prdata;
      break;
    end
  end
        
  wait(!env.apb_vif.psel);
  #2;
endtask

  protected task send_matrix_a(ref bit signed [DATA_W-1:0] mat[N][N]);
    mailbox #(axis_seq_item #(N, DATA_W)) mb = env.axis_a_agent_e.get_driver_mailbox();
    axis_seq_item #(N, DATA_W) txn = new();
    txn.matrix = mat;
    mb.put(txn);
    #10;
  endtask

  protected task send_matrix_b(ref bit signed [DATA_W-1:0] mat[N][N]);
    mailbox #(axis_seq_item #(N, DATA_W)) mb = env.axis_b_agent_e.get_driver_mailbox();
    axis_seq_item #(N, DATA_W) txn = new();
    txn.matrix = mat;
    mb.put(txn);
    #10;
  endtask

  protected task send_matrix_a_start();
    bit signed [DATA_W-1:0] a[N][N];
     for (int i=0; i<N; i++) begin
      for (int j=0; j<N; j++) begin
        a[i][j] = 1; 
        end
      end
    send_matrix_a(a);
  endtask

  protected task send_matrix_a_early_tlast(int early_idx);
    for (int i = 0; i < early_idx; i++) begin
      @(posedge env.axis_a_vif.clk);
      env.axis_a_vif.tvalid <= 1'b1;
      env.axis_a_vif.tdata  <= 16'h0001;
    
      env.axis_a_vif.tlast  <= (i == early_idx - 1) ? 1'b1 : 1'b0;
    end
   
    @(posedge env.axis_a_vif.clk);
    env.axis_a_vif.tvalid <= 1'b0;
    env.axis_a_vif.tlast  <= 1'b0;
    $display("[NEG] Sent early TLAST at cycle %0d (expected 16)", early_idx);
  endtask

  protected task wait_for_done();
    bit [31:0] status;
    int timeout = 0;
    
    $display("[TEST] ⏳ Polling DONE...");
    forever begin
    
      
      read_apb(8'h8, status);
      if (status[0] === 1'b1) begin
        $display("[TEST] DONE asserted!");
        break;
      end
      #100;
      if (++timeout > 50) begin
        $fatal("[TEST] TIMEOUT: done_i=%b, prdata[0]=%b", 
              tb_top.dut.done_i, status[0]);
      end
    end
  endtask

  
  protected task get_result_from_monitor(output bit signed [DATA_W-1:0] result[N][N]);
    mailbox #(axis_seq_item #(N, DATA_W)) mb;
    axis_seq_item #(N, DATA_W) res_txn;
   
    mb = env.axis_res_agent_e.get_driver_mailbox(); 
 
    if (mb.num() == 0) begin
      #200; 
    end
    
    if (mb.try_get(res_txn)) begin
      result = res_txn.matrix;
      $display("[TEST] Result captured: [0][0]=%0d", result[0][0]);
    end else begin
      $warning("[TEST]  No result in monitor mailbox yet");
  
      for (int i=0; i<N; i++)
        for (int j=0; j<N; j++)
          result[i][j] = '0;
    end
  endtask

        protected task read_and_compare(ref bit signed [DATA_W-1:0] expected[N][N]);

    $display("[TEST] Result verification delegated to scoreboard.");
  endtask
    
    

  protected task check_status(bit expected_done, bit expected_busy, bit expected_overflow);
    bit [31:0] status;
     if (expected_done) wait_for_done();
    #50; 
    
    read_apb(8'h8, status);
    
    if (status[0] !== expected_done)   $error("DONE mismatch: got %b, exp %b", status[0], expected_done);
    if (status[1] !== expected_busy)   $error("BUSY mismatch: got %b, exp %b", status[1], expected_busy);
    if (status[2] !== expected_overflow)$error("OVERFLOW mismatch: got %b, exp %b", status[2], expected_overflow);
  
  endtask

    protected task print_matrix(string name, ref bit signed [DATA_W-1:0] mat[N][N]);
    $display(" Matrix %s:", name);
    for (int i=0; i<N; i++) begin
      $write("   [");
      for (int j=0; j<N; j++) $write("%4d ", mat[i][j]);
      $display("]");
    end
  endtask

  function void report();
    $display("[TEST] Final report placeholder");
  endfunction
endclass
