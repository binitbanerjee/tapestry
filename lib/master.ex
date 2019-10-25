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
    initial_count = round(nodes*0.9)
    left_count = nodes-initial_count
    IO.puts("#{inspect initial_count} #{inspect left_count}")
    children = Enum.map(1..initial_count, fn _x ->
      {:ok,pid} = Node.start_link([])
      pid
    end)

    {:ok, neighbor_provider_id} = NeighborsProvider.start_link([])
    nodes_map = createNodes(initial_count, children)

    table = :ets.new(:master_table, [:set, :public])
    :ets.insert(table,{"nodes", nodes_map})
    Enum.each(nodes_map, fn {node_key,node_pid} ->
      GenServer.call(node_pid,{:init_route,node_key,table,self()})
    end)

    Enum.each((initial_count+1)..nodes,fn x->
      nodes_map = add_dynamic_node(x,table)
      GenServer.call(neighbor_provider_id,{:assign, "Initialize", nodes_map, nil})
    end)

    # nodes_map = add_dynamic_node(nodes,table,neighbor_provider_id,request)
    # GenServer.call(neighbor_provider_id,{:assign, "Initialize", nodes_map, nil})
    Enum.each(nodes_map, fn {node_key,node_pid} ->
      GenServer.cast(node_pid,{:initiate_again,
              {node_key, node_pid}, neighbor_provider_id,request})
    end)
    # add_dynamic_node(nodes,table)
    convergence_criteria(children,0,request,length(children))
  end

  def createNodes(nodes, children) do
    Enum.reduce(0..(nodes-1), %{}, fn x, acc->
      Map.put(acc,
        String.slice(:crypto.hash(:sha,Integer.to_string(x))|> Base.encode16, 0..7),
        Enum.at(children,x))
    end)
  end

  defp remove_child(all, target, request) do
    total =
    Enum.filter(all,fn item ->
      item == target
    end)

    all = if length(total)>=request do
      Enum.filter(all,fn item ->
        item !=target
      end)
    else
      Enum.concat(all,[target])
    end
    all
  end

  def add_dynamic_node(node_idx, global_table) do
    {:ok,pid} = Node.start_link([])
    node_key = String.slice(:crypto.hash(:sha,Integer.to_string(node_idx))|> Base.encode16, 0..7)
    data = :ets.lookup(global_table,"nodes")
    nodes_map = elem(Enum.at(data,0), 1)
    root_key =  findroot(node_key, nodes_map)
    root_pid = Map.get(nodes_map,root_key)
    Map.put(nodes_map,root_key,root_pid)
    root_finger_table = GenServer.call(root_pid,{:new_node_multicast,root_key,node_key, pid})
    GenServer.call(pid,{:new_node_update_state,root_finger_table, root_key, node_key,self()})
    nodes_map
  end

  def nearest_match(filtered_nodes, index, source,found) do
    if found == true do
      filtered_nodes
    else
      char = String.at(source,index)
      matched = Enum.filter(filtered_nodes, fn n->
        String.at(n,index)==char
      end)
      if(length(matched)>0)do
        nearest_match(matched,index+1,source,false)
      else
        nearest_match(filtered_nodes,index+1,source,true)
      end
    end
  end

  def findroot(node_key, nodes_map) do
    # find root from master table
    node_ids = Enum.map(nodes_map, fn {id,_}->
      id
    end)
    resp = nearest_match(node_ids,0,node_key,false)
    # IO.puts("nodes: #{inspect resp}")
    if length(resp)>0 do
      Enum.at(resp,0)
    else
      "9E6A55B6"
    end

  end

  defp convergence_criteria(all, max_hop, request,total) do
    if(length(all)>0) do
      receive do
        {:ok,info}-> {:ok,info}
        {source, hop_count} = info
        matches = Enum.filter(all,fn item ->
          item == source
        end)
        all = if length(matches)>0 do
          remove_child(all,source, request)
        else
          all
        end
        if length(all)==1 do
          IO.puts("remaining #{inspect (all)}")
        end

        max_hop =
          if max_hop<hop_count do
            hop_count
          else
            max_hop
          end
        convergence_criteria(all,max_hop, request,total)
      end
    else
      IO.puts("Max hop: #{inspect max_hop}")
    end
  end
end
