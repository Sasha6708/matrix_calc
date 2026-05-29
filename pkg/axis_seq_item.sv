class axis_seq_item #(int N = 4, int DATA_W = 16);

    rand int unsigned               tnx_id;
    rand bit                        tlast;
    int                             valid_count;
    rand bit signed [DATA_W - 1: 0] matrix [N][N];

    localparam MIN_SIGNED = -(1 << (DATA_W - 1));
    localparam MAX_SIGNED =  (1 << (DATA_W - 1)) - 1;

    constraint range { foreach(matrix[i, j]) 
                    matrix[i][j] inside {[MIN_SIGNED : MAX_SIGNED]};
    }
    constraint tlast_default {tlast == 1;}
        
    function new();
        tnx_id      = $urandom_range(1,10);
        tlast       = 1;
        valid_count = N * N;   
    endfunction

    function axis_seq_item #(N, DATA_W) clone();
        clone             = new();
        clone.tnx_id      = this.tnx_id;
        clone.tlast       = this.tlast;
        clone.valid_count = this.valid_count;
        clone.matrix      = this.matrix;
    endfunction

endclass