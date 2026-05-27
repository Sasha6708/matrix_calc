class sv_analysis_port_axis;

  local mailbox #(axis_seq_item #(N, DATA_W)) subscribers[$];

  function void subscribe(mailbox #(axis_seq_item #(N, DATA_W)) mb);
    subscribers.push_back(mb);
  endfunction
  
  task write(axis_seq_item #(N, DATA_W) item);
    axis_seq_item cloned;
    foreach (subscribers[i]) begin
      void'(item.clone(cloned));
      subscribers[i].put(cloned);
    end
  endtask

endclass