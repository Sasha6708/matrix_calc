class apb_driver;

    virtual apb_if vif;
    mailbox #(apb_seq_item) seq_item_port;

    function new (virtual apb_if vif, mailbox #(apb_seq_item) seq_item_port);
        this.vif = vif;
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
        vif.psel    <= 1'b0;
        vif.penable <= 1'b0;
        vif.pwrite  <= 1'b0;
        vif.paddr   <= 8'h00;
        vif.pwdata  <= 32'h00000000;
    endtask

    local task drive_transaction(apb_seq_item sqtm);
        if(sqtm.write) begin
            apb_write(sqtm.addr, sqtm.data);
        end else begin
            apb_read(sqtm.addr, sqtm.read_data);
        end
    endtask
    

    task apb_write( input [ 7: 0] addr,
                    input [31: 0] data
                  );
        @(posedge vif.clk);
        vif.psel    <= 1'b1;
        vif.penable <= 1'b0;
        vif.pwrite  <= 1'b1;
        vif.paddr   <= addr;
        vif.pwdata  <= data;        
        @(posedge vif.clk);
        vif.penable <= 1'b1;       
        @(posedge vif.clk);
        vif.psel    <= 1'b0;
        vif.penable <= 1'b0;
        vif.pwrite  <= 1'b0;
    endtask
    
    task apb_read(
        input  [ 7: 0] addr,
        output [31: 0] rdata
    );
        @(posedge vif.clk);
        vif.psel    <= 1'b1;
        vif.penable <= 1'b0;
        vif.pwrite  <= 1'b0;
        vif.paddr   <= addr;
        
        @(posedge vif.clk);
        vif.penable <= 1'b1;
        
        rdata        = vif.prdata;

        @(posedge vif.clk);
        vif.psel    <= 1'b0;
        vif.penable <= 1'b0;
    endtask

endclass