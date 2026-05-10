interface axis_monitor #(
    parameter N = 4,
    parameter DATA_W = 16
) (
    input logic clk,
    input logic rst_n,
    
    input logic signed [DATA_W-1:0] m_axis_res_tdata,
    input logic m_axis_res_tvalid,
    input logic m_axis_res_tlast,
    input logic m_axis_res_tready
);

    // Queue to store received data
    logic signed [DATA_W-1:0] received_data [$];
    
    // Event to signal that reception is complete
    event recv_done_event;

    task run();
        forever begin
            @(posedge clk);
            if (m_axis_res_tvalid && m_axis_res_tready) begin
                received_data.push_back(m_axis_res_tdata);  //Collects all accepted items in a queue             
                if (m_axis_res_tlast) begin
                    -> recv_done_event;
                end
            end
        end
    endtask
    
     // Call this from initial block in testbench
    /*initial begin
        axis_monitor_if.run();
    end
    initial begin
    ===test===
    // Wait event in tb
        /*@(axis_monitor_if.recv_done_event);
        
        // Reading data from the monitor queue
        for (int i = 0; i < N * N; i++) begin
            int row = i / N;
            int col = i % N;
            received_matrix[row][col] = axis_monitor_if.received_data[i];
        end 
        axis_monitor_if.received_data.delete();*/   

endinterface