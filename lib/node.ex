defmodule Node do
  use GenServer
  def start_link(args) do
    GenServer.start_link(__MODULE__, args)
   end

  @impl true
  def init(_args) do
    {:ok, %{ neighbors: [], boss: []} }
  end

  @impl true
  def handle_call({:init_route,table},from,state) do
    data = :ets.lookup(table,"nodes")
    IO.puts("#{inspect data}")
    IO.puts("here")
    {:reply,from, state}
  end
end
