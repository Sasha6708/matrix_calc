class apb_seq_item;

    rand bit [ 7: 0] addr;
    rand bit [31: 0] write_data;
    rand bit [31: 0] read_data;
    rand bit         write;
         bit         error;

    function new ();
        addr       = '0;
        write_data = '0;
        write      = 0;
        read_data  = '0;
        error      = 0;
    endfunction

    function apb_seq_item clone();
        clone            = new();
        clone.addr       = this.addr;
        clone.write_data = this.write_data;
        clone.write      = this.write;
        clone.read_data  = this.read_data;
        clone.error      = this.error;
    endfunction

endclass