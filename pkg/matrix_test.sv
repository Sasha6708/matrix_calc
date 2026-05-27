class matrix_test #(int N=4, int DATA_W=16);
 
  bit            add_en       = 1;
  bit            sub_en       = 1;
  bit            trans_en     = 0;
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

    if (overflow_en)  run_overflow();
    else if (flow_en) run_flow();
    else if (neg_en)  run_negative();
    else if (reset_en)run_reset();
    else if (seq_en)  run_sequential();
    else if (apb_en)  run_apb_regs();
    else if (param_en)run_param();
    else if (rand_en) run_random();
    else              run_basic(); 

    #500; 
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


    write_apb(8'h4, 32'h1); 

    wait_for_done();
    read_and_compare(expected);
  endtask


  task run_basic();
    bit signed [DATA_W-1:0] a[N][N], b[N][N], expected[N][N];
    
    repeat (num_pkts) begin
      
      void'(randomize(sel_op));
      
      case (sel_op)
        ADD: begin
          
          for (int i=0; i<N; i++)
            for (int j=0; j<N; j++) begin
              a[i][j] = i*N + j + 1;
              b[i][j] = N*N - (i*N + j);
              expected[i][j] = 17;
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
            end
          for (int i=0; i<N; i++)
            for (int j=0; j<N; j++)
                b[i][j] = 0;
            end
      endcase

      execute_op(sel_op, a, b, expected);
      check_status(1'b1, 1'b0, 1'b0);  
    end
  endtask


  task run_overflow();
    bit signed [DATA_W-1:0] a[N][N], b[N][N], expected[N][N];
    
    for(int i = 0; i < N; i++) begin
        for(int j = 0; j < N; j++) begin
            a[i][j] = 0; b[i][j] = 0;
        end
    end

    a[0][0] = (1 << (DATA_W-1)) - 1;  
    b[0][0] = 1;
    write_apb(8'h0, ADD);
    send_matrix_a(a); send_matrix_b(b);
    write_apb(8'h4, 32'h1);
    check_status(1'b1, 1'b0, 1'b1);

   
    a[0][0] = -(1 << (DATA_W-1));  
    b[0][0] = -1;
    write_apb(8'h0, ADD);
    send_matrix_a(a); send_matrix_b(b);
    write_apb(8'h4, 32'h1);
    check_status(1'b1, 1'b0, 1'b1);

    a[0][0] = 100; b[0][0] = 200;
    expected[0][0] = 300;
    write_apb(8'h0, ADD);
    send_matrix_a(a); send_matrix_b(b);
    write_apb(8'h4, 32'h1);
    check_status(1'b1, 1'b0, 1'b0);
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
 
    write_apb(8'h0, ADD);
    write_apb(8'h4, 32'h1);
    #200; check_status(1'b0, 1'b0, 1'b0);

    write_apb(8'h0, 32'h0000000B);
    write_apb(8'h4, 32'h1);
    #200; check_status(1'b0, 1'b0, 1'b0);

    send_matrix_a_early_tlast(10);
    send_matrix_b(b);
    write_apb(8'h4, 32'h1);
    #200; check_status(1'b0, 1'b0, 1'b0);
  endtask

  task run_reset();
    bit signed [DATA_W-1:0] a[N][N];
    bit signed [DATA_W-1:0] b[N][N];
    env.apb_vif.rst_n = 0; #10; env.apb_vif.rst_n = 1; #20;
    check_regs_after_reset();

  
    send_matrix_a_start();
    #50; env.apb_vif.rst_n = 0; #10; env.apb_vif.rst_n = 1; #20;
    check_regs_after_reset();

  

   
    for (int i=0; i<N; i++)
    for (int j=0; j<N; j++) begin
        a[i][j] = 10;
        b[i][j] = 5;
    end
    write_apb(8'h0, ADD);
    send_matrix_a(a); send_matrix_b(b);
    write_apb(8'h4, 32'h1);
    #150; env.apb_vif.rst_n = 0; #10; env.apb_vif.rst_n = 1; #20;
    check_regs_after_reset();
  endtask

  task check_regs_after_reset();
    bit [31:0] data;
    read_apb(8'h0, data); assert(data[7:0] == 8'h0) else $error("OP!=0 after reset");
    read_apb(8'h4, data); assert(data[0]   == 1'b0) else $error("START!=0 after reset");
    read_apb(8'h8, data); assert(data[1:0] == 2'b00) else $error("DONE/BUSY!=0 after reset");
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
    bit signed [DATA_W-1:0] a[N][N];
    bit signed [DATA_W-1:0] b[N][N];
    write_apb(8'h0, 32'h00000001); read_apb(8'h0, rd_data);
    assert(rd_data[7:0] == 8'h01) else $error("APB OP readback fail");

    write_apb(8'h4, 32'h1); read_apb(8'h4, rd_data);
    assert(rd_data[0] == 1'b0) else $error("APB START self-clear fail");

    write_apb(8'hFF, 32'hDEAD); 
    assert(env.apb_vif.pslverr == 1'b1) else $error("pslverr not asserted");

    write_apb(8'h0, ADD);
    

for (int i=0; i<N; i++)
  for (int j=0; j<N; j++) begin
    a[i][j] = 10;
    b[i][j] = 5;
  end
    send_matrix_a(a); send_matrix_b(b);
    write_apb(8'h4, 32'h1);
    #50; read_apb(8'h8, rd_data);
    assert(rd_data[1] == 1'b1) else $error("BUSY!=1 during op");
    #500; read_apb(8'h8, rd_data);
    assert(rd_data[1:0] == 2'b01) else $error("DONE!=1 or BUSY!=0 after op");
  endtask

  task run_param();

    $display("[TEST] Parameterization check for N=%0d", N);
    num_pkts = 1;
    run_basic();
  endtask

 
  task run_random();
    bit signed [DATA_W-1:0] a[N][N], b[N][N], expected[N][N];
    
    repeat (num_pkts) begin
      void'(randomize(sel_op));  

      for (int i=0; i<N; i++)
        for (int j=0; j<N; j++) begin
          a[i][j] = $urandom_range(-(2**(DATA_W-1)), (2**(DATA_W-1))-1);
          b[i][j] = $urandom_range(-(2**(DATA_W-1)), (2**(DATA_W-1))-1);
          case (sel_op)
            ADD: expected[i][j] = a[i][j] + b[i][j];
            SUB: expected[i][j] = a[i][j] - b[i][j];
            TRANS: expected[i][j] = a[j][i];
          endcase
        end
      execute_op(sel_op, a, b, expected);
      check_status(1'b1, 1'b0, 1'b0);
    end
  endtask


  protected task write_apb(bit [7:0] addr, bit [31:0] data);
    mailbox #(apb_seq_item) mb = env.apb_agent_e.get_driver_mailbox();
    apb_seq_item txn = new();
    txn.addr       = addr;
    txn.write_data = data;
    txn.write      = 1'b1;
    mb.put(txn);
    #20;
  endtask

  protected task read_apb(bit [7:0] addr, output bit [31:0] data);
    mailbox #(apb_seq_item) mb = env.apb_agent_e.get_driver_mailbox();
    apb_seq_item txn = new();
    txn.addr  = addr;
    txn.write = 1'b0;
    mb.put(txn);
    #20;
    data = txn.read_data;
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
     for (int i=0; i<N; i++)
      for (int j=0; j<N; j++)
        a[i][j] = 1; 
    send_matrix_a(a);
  endtask

  protected task send_matrix_a_early_tlast(int early_idx);
  
    bit signed [DATA_W-1:0] a[N][N];
     for (int i=0; i<N; i++)
      for (int j=0; j<N; j++)
        a[i][j] = 1;
    send_matrix_a(a);
  endtask

protected task wait_for_done();
  bit [31:0] status;
  int timeout = 0;
  int max_cycles = 2000;  
  
  $display("[TEST] ⏳ Waiting for DONE...");
  
  forever begin
    
    read_apb(8'h8, status);
    
    
    if (status[0] == 1'b1) begin
      $display("[TEST] ✅ DONE asserted (Status[3:0]=4'b%b)", status[3:0]);
      break;  
    end
    #100;
    if (++timeout > max_cycles) begin
      $error("[TEST] ❌ TIMEOUT: DONE never asserted after %0d cycles", max_cycles);
      $display("  Debug hints:");
      $display("  - Check if START was written to 0x4");
      $display("  - Check if matrices A/B were fully sent");
      $display("  - Check env.apb_vif.rst_n = %b", env.apb_vif.rst_n);
      break;
    end
  end
endtask

  protected task read_and_compare(ref bit signed [DATA_W-1:0] expected[N][N]);
    wait_for_done();
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

  function void report();
    $display("[TEST] Final report placeholder");
  endfunction
endclass