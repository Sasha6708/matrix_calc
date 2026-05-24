class sv_analysis_port_apb;

  local mailbox #(apb_seq_item) subscribers[$];

  function void subscribe(mailbox #(apb_seq_item) mb);
    subscribers.push_back(mb);
  endfunction
  
  task write(apb_seq_item item);
    apb_seq_item cloned;
    foreach (subscribers[i]) begin
      item.clone(cloned);
      subscribers[i].put(cloned);
    end
  endtask

endclass