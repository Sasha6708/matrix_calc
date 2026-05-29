class apb_monitor;
  virtual apb_if vif;
  sv_analysis_port_apb sap;

  function new(virtual apb_if vif, sv_analysis_port_apb sap);
    this.vif = vif;
    this.sap = sap;
  endfunction

  task run();
    forever begin
      @(posedge vif.clk);
      capture_apb_txn();
    end
  endtask

  local task capture_apb_txn();  
    if (vif.psel && vif.penable && vif.pready) begin
      apb_seq_item txn = new();
      txn.addr      = vif.paddr;
      txn.write     = vif.pwrite;
      
      if (vif.pwrite) txn.write_data = vif.pwdata;
      else            txn.read_data  = vif.prdata;

      if (sap != null) begin
        sap.write(txn);
      end
    end
  endtask

endclass