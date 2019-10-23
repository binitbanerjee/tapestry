defmodule NeighborsProvider do
  use GenServer
  def start_link(args) do
    GenServer.start_link(__MODULE__, args)
   end

  @impl true
  def init(_args) do
    state = %{
      nodes_map: %{}
    }
    {:ok, state}
  end

  @impl true
  def handle_call({:assign, action, nodes_map, source},from,state) do
    if action == "Initialize" do
      state =
        %{
          nodes_map: nodes_map
        }
      {:reply,from,state}
      else
        {:ok, all} = Map.fetch(state, :nodes_map)
        target = Master.get_random_key_but_not_self(source,"" ,all)
        {:reply, target, state}
    end
  end

end
