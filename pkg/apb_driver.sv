class apb_driver;

    virtual apb_if.master apb_vif;
    mailbox #(apb_seq_item) seq_item_port;

    function new (virtual apb_if.master apb_vif, mailbox #(apb_seq_item) seq_item_port);
        this.apb_vif           = apb_vif;
        this.seq_item_port = seq_item_port;
    endfunction

    task run();
        apb_seq_item sqtm;
        reset();
        forever begin
            seq_item_port.get(sqtm);
            drive_transaction(sqtm);
        end
    endtask

    local task reset();
        apb_vif.psel    = 1'b0;
        apb_vif.penable = 1'b0;
        apb_vif.pwrite  = 1'b0;
        apb_vif.paddr   = 8'h0;
        apb_vif.pwdata  = 32'h0;
    endtask

    local task drive_transaction(apb_seq_item sqtm);
        if(sqtm.write) begin
            apb_write(sqtm.addr, sqtm.write_data);
        end else begin
            apb_read(sqtm.addr, sqtm.read_data);
        end
    endtask
    

    task apb_write(
        input [ 7: 0] addr,
        input [31: 0] data
    );
        @(posedge apb_vif.clk);
        apb_vif.psel    <= 1'b1;
        apb_vif.penable <= 1'b0;
        apb_vif.pwrite  <= 1'b1;
        apb_vif.paddr   <= addr;
        apb_vif.pwdata  <= data;        
        @(posedge apb_vif.clk);
        apb_vif.penable <= 1'b1;       
        @(posedge apb_vif.clk);
        apb_vif.psel    <= 1'b0;
        apb_vif.penable <= 1'b0;
        apb_vif.pwrite  <= 1'b0;
    endtask
    
    task apb_read(
        input  [ 7: 0] addr,
        output [31: 0] rdata
    );
        @(posedge apb_vif.clk);
        apb_vif.psel    <= 1'b1;
        apb_vif.penable <= 1'b0;
        apb_vif.pwrite  <= 1'b0;
        apb_vif.paddr   <= addr;       
        @(posedge apb_vif.clk);
        apb_vif.penable <= 1'b1;        
        rdata            = apb_vif.prdata;
        @(posedge apb_vif.clk);
        apb_vif.psel    <= 1'b0;
        apb_vif.penable <= 1'b0;
    endtask

endclass