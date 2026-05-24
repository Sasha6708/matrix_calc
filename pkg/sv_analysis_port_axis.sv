class sv_analysis_port_axis;

  local mailbox #(axis_seq_item) subscribers[$];

  function void subscribe(mailbox #(axis_seq_item) mb);
    subscribers.push_back(mb);
  endfunction
  
  task write(axis_seq_item item);
    axis_seq_item cloned;
    foreach (subscribers[i]) begin
      item.clone(cloned);
      subscribers[i].put(cloned);
    end
  endtask

endclass