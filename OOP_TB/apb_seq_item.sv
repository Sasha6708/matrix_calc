class apb_seq_item;
    rand bit [ 7: 0] addr;
    rand bit [31: 0] write_data;
    rand bit [31: 0] read_data;
    rand bit         write;
         bit         error;
endclass