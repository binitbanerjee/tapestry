defmodule Node do
  use GenServer
  def start_link(args) do
    GenServer.start_link(__MODULE__, args)
   end

  @impl true
  def init(_args) do
    {:ok, %{finger_table: %{}, boss: [], id: "", count: 0} }
  end

  def handle_cast({:initiate_again, original_source, neighbor_provider_id,count}, state) do
    if(count>=0) do
      {self_id,_} = original_source
      random_neighbor = GenServer.call(neighbor_provider_id,
                          {:assign, "get",[], self_id})
      GenServer.cast(self(),{:route_to_node,
                            random_neighbor,0,
                            original_source,
                            neighbor_provider_id,
                            self_id})
      Process.sleep(1000)
      handle_cast({:initiate_again, original_source, neighbor_provider_id,count-1}, state)
    end
    Map.replace!(state, :count, 1)
    {:noreply,state}
  end

  @impl true
  def handle_cast({:route_to_node, target, hop_count, original_source, neighbor_provider_id,last_hop_id}, state) do
    {:ok, boss_id} =Map.fetch(state, :boss)
    {:ok, finger_table} = Map.fetch(state, :finger_table)
    {:ok, id} = Map.fetch(state, :id)
    {:ok, current_count} = Map.fetch(state,:count)
    {_,pid} = original_source

    if(id==target) do
      send boss_id,{:ok,{pid,hop_count}}
    else
      if hop_count<10 do
        next_hop(id,target,hop_count,finger_table,original_source, neighbor_provider_id,last_hop_id)
      else
        send boss_id,{:ok,{pid,hop_count}}
      end
    end
    Map.replace!(state,:count,current_count+1)
    {:noreply,state}
  end

  @impl true
  def handle_call({:new_node_multicast,_self_key,new_key,new_pid},_from,state) do
    {:ok,route_table} =Map.fetch(state,:finger_table)
    Enum.each(0..7, fn level_idx ->
      level_map = Map.get(route_table, level_idx)
      if level_map != nil do
        Enum.each(level_map, fn slot ->
          neighbor_tuple = elem(slot, 1)
          neighbor_key = elem(neighbor_tuple, 0)
          neighbor_pid = elem(neighbor_tuple, 1)
          GenServer.cast(neighbor_pid,{:update_finger_table,neighbor_key,new_key,new_pid})
        end)
      end
    end)
    {:reply, route_table, state}
  end

  @impl true
  def handle_call({:new_node_update_state,root_finger_table, root_key, node_key, boss_id},_from,_state) do
    matched_level = find_prefix_len(root_key, node_key)

    route_table = Enum.reduce(0..matched_level, %{}, fn level_idx, acc ->
      level_map = Map.get(root_finger_table,level_idx)
      Map.put(acc, level_idx, level_map)
    end)
    route_table = Enum.reduce(matched_level+1..7, route_table, fn level_idx, acc ->
      slot = String.at(node_key,level_idx)
      level_map = %{slot => {node_key, self()}}
      Map.put(acc, level_idx, level_map)
    end)

    state = %{
      finger_table: route_table,
      boss: boss_id,
      id: node_key,
      count: 0
    }
    {:reply, :ok, state}
  end


  @impl true
  def handle_cast({:update_finger_table,self_key,new_key,new_pid},state) do
    {:ok,route_table} =Map.fetch(state,:finger_table)
    {:ok,boss_id} =Map.fetch(state,:boss)
    {:ok,count} =Map.fetch(state,:count)
    matched_level = find_prefix_len(self_key,new_key)
    route_table = Enum.reduce(0..matched_level, route_table, fn level_idx, acc ->
      level_map = Map.get(acc,level_idx)
      slot = String.at(new_key,level_idx)
      old_val = Map.get(level_map,slot)
      level_map =
      if check_new_key_nearest(old_val, new_key, self_key) ==1 do
        Map.put(level_map,slot,{new_key,new_pid})
      else
        level_map
      end
      Map.put(acc, level_idx, level_map)
    end)
    state = %{
              finger_table: route_table,
              boss: boss_id,
              id: self_key,
              count: count
            }
    {:noreply, state}
  end


  def find_prefix_len(node1, node2) do
    Enum.reduce_while(0..7, 0, fn char_idx, acc ->
      if String.at(node1, char_idx) == String.at(node2, char_idx) do
        {:cont, acc+1}
      else
        {:halt, acc}
      end
    end)
  end

  def next_hop(self,target,hop_count, finger_table,original_source,neighbor_provider_id,_last_hop_id) do
    level_match =
        find_prefix_len(self,target)
    next_hop =
      cond do
        level_match >= 0 -> find_next_hop(target,finger_table,level_match)
        true -> nil
      end
    if(next_hop != nil) do
      {_node_id,pid} = next_hop
      GenServer.cast(pid,{:route_to_node,target,
      hop_count+1,original_source, neighbor_provider_id,self})
    end
  end

  defp find_next_hop(target,finger_table,level) do
    level_data = Map.get(finger_table,level)
    # IO.puts("level data: #{inspect level_data}")
    hop = cond do
        level >= 0 -> get_best_match(target,level_data,String.at(target,level),"")
        true -> IO.puts("may")
      end
    hop
  end

  defp get_next_char(target) do
    char = cond do
      target=="0"->"1"
      target=="1"->"2"
      target=="2"->"3"
      target=="3"->"4"
      target=="4"->"5"
      target=="5"->"6"
      target=="6"->"7"
      target=="7"->"8"
      target=="8"->"9"
      target=="9"->"A"
      target=="A"->"B"
      target=="B"->"C"
      target=="C"->"D"
      target=="D"->"E"
      target=="E"->"F"
      target=="F"->"0"
      true -> target
    end
    char
  end

  def get_best_match(target,level_data,level,found) do
    if found != "" do
      found
    else
      if(Map.get(level_data,level) != nil)do
        matched_data = Map.get(level_data, level)
        get_best_match(target,level_data,"",matched_data)
      else
        get_best_match(target,level_data,get_next_char(level),"")
      end
    end
  end

  @impl true
  def handle_call({:init_route,self_key,table,boss_id},from,_state) do

    formatted_finger_table = Enum.reduce(0..7, %{}, fn level, acc ->
      Map.put(acc, level, %{})
    end)

    data = :ets.lookup(table,"nodes")
    nodes_map = elem(Enum.at(data,0), 1)
    formatted_finger_table = Enum.reduce(0..7, formatted_finger_table, fn level_idx, acc ->
      Enum.reduce(nodes_map, acc, fn {node_key,node_pid}, acc ->
        bit_matched =
        if String.slice(self_key, 0, level_idx) == String.slice(node_key, 0, level_idx) do
          1
        else
          0
        end
        if bit_matched==1 do
          slot = String.at(node_key,level_idx)
          level_map = Map.get(acc,level_idx)
          old_value = Map.get(level_map,slot)
          level_map =
            if check_new_key_nearest(old_value, node_key, self_key) ==1 do
              Map.put(level_map, slot, {node_key, node_pid})
            else
              level_map
            end

          Map.put(acc, level_idx, level_map)
        else
          acc
        end
      end)
    end)
    state = %{
      finger_table: formatted_finger_table,
      boss: boss_id,
      id: self_key,
      count: 0
    }
    {:reply,from, state}
  end

  def check_new_key_nearest(old_value, node_key, self_key) do
    old_diff =
      if old_value != nil do
        old_key=elem(old_value, 0)
        abs(elem(Integer.parse(old_key, 16),0)-elem(Integer.parse(self_key, 16), 0))
      else
        elem(Integer.parse("FFFFFFFFF", 16), 0)
      end
    new_diff = abs(elem(Integer.parse(node_key, 16), 0)-elem(Integer.parse(self_key, 16), 0))
    if new_diff < old_diff do
      1
    else
      0
    end
  end

end
