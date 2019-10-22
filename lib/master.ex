defmodule Master do
  def launch(nodes,_request) do
    nodes_map = createNodes(nodes)
    table = :ets.new(:master_table, [:set, :public])
    :ets.insert(table,{"nodes", nodes_map})
    Enum.each(nodes_map, fn {_,node_pid} ->
      GenServer.call(node_pid,{:init_route,table})
    end)

  end

  def createNodes(nodes) do
    children = Enum.map(1..nodes, fn _x ->
      {:ok,pid} = Node.start_link([])
      pid
    end)

    Enum.reduce(1..nodes, %{}, fn x, acc->
      Map.put(acc,
        String.slice(:crypto.hash(:sha,Integer.to_string(x))|> Base.encode16, 0..3),
        Enum.at(children,x-1))
    end)
  end
end
