class sv_analysis_port_axis #(int N = 4, int DATA_W = 16);

  local mailbox #(axis_seq_item #(N, DATA_W)) subscribers[$];

  function void subscribe(mailbox #(axis_seq_item #(N, DATA_W)) mb);
    subscribers.push_back(mb);
  endfunction
  
  task write(axis_seq_item #(N, DATA_W) item);
    axis_seq_item cloned;
    foreach (subscribers[i]) begin
      cloned = item.clone();
      subscribers[i].put(cloned);
    end
  endtask

endclass