class sv_analysis_port #(type T);
    mailbox #(T) subscribers[$];

    function void subscribe(mailbox #(T) mb);
        subscribers.push_back(mb);
    endfunction

    task write(T item);
        foreach (subscribers[i]) begin
            subscribers[i].put(item.clone());
        end
    endtask
endclass
