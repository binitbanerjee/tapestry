defmodule Master do

  def get_random_key_but_not_self(self, key, all) do
    if self != key and key != "" do
      key
    else
      {temp_node_key,_} = Enum.random(all)
      get_random_key_but_not_self(self, temp_node_key, all)
    end
  end

  def launch(nodes, request) do
    children = Enum.map(1..nodes, fn _x ->
      {:ok,pid} = Node.start_link([])
      pid
    end)

    {:ok, neighbor_provider_id} = NeighborsProvider.start_link([])
    nodes_map = createNodes(nodes, children)
    GenServer.call(neighbor_provider_id,{:assign, "Initialize", nodes_map, nil})

    table = :ets.new(:master_table, [:set, :public])
    :ets.insert(table,{"nodes", nodes_map})
    Enum.each(nodes_map, fn {node_key,node_pid} ->
      GenServer.call(node_pid,{:init_route,node_key,table,self()})
    end)

    # {node_key, node_pid} = Enum.random(nodes_map)
    # recipient = get_random_key_but_not_self(node_key,"",nodes_map)
    # GenServer.cast(node_pid,{:route_to_node,recipient,0,{node_key, node_pid}, neighbor_provider_id})
    # GenServer.cast(node_pid,{:initiate_again, {node_key, node_pid}, neighbor_provider_id,request})
    Enum.each(nodes_map, fn {node_key,node_pid} ->
      GenServer.cast(node_pid,{:initiate_again,
              {node_key, node_pid}, neighbor_provider_id,request})
    end)
    convergence_criteria(children,0,request,length(children))
    # Process.sleep(4000)
  end

  def createNodes(nodes, children) do
    Enum.reduce(1..nodes, %{}, fn x, acc->
      Map.put(acc,
        String.slice(:crypto.hash(:sha,Integer.to_string(x))|> Base.encode16, 0..3),
        Enum.at(children,x-1))
    end)
  end

  defp remove_child(all, target, request) do
    total =
    Enum.filter(all,fn item ->
      item == target
    end)

    all = if length(total)>=request do
      Process.exit(target, :normal)
      Enum.filter(all,fn item ->
        item !=target
      end)
    else
      Enum.concat(all,[target])
    end
    all
  end

  defp convergence_criteria(all, max_hop, request,total) do
    # IO.puts("I am #{inspect self()}")
    if(length(all)>0) do
      # IO.puts("I am #{inspect self()}")
      receive do
        {:ok,info}-> {:ok,info}
        # IO.puts("boss")
        {source, hop_count, _sender} = info
        # IO.puts("Sent for #{inspect sender}")
        # IO.puts("#{inspect Process.exit(source, :normal)}")
        # IO.puts("remaining #{inspect (all)}")
        IO.puts("__________________________")
        matches = Enum.filter(all,fn item ->
          item == source
        end)
        all = if length(matches)>0 do
          remove_child(all,source, request)
        else
          all
        end
        # IO.puts("remaining #{inspect (all)}")

        max_hop =
          if max_hop<hop_count do
            hop_count
          else
            max_hop
          end
        IO.puts("Max hop so far: #{inspect max_hop} and converged for #{inspect ((total-length(all))/total)}")
        convergence_criteria(all,max_hop, request,total)
      end
    end
  end
end
