defmodule Runner do
  def run(argv) do
    start_time = System.system_time(:millisecond)
    [nodes, requests] = argv
    nodes = String.to_integer(nodes)
    requests = String.to_integer(requests)
    Master.launch(nodes,requests)
    IO.puts("Converged in #{(System.system_time(:millisecond) - start_time) / 1000} seconds")
  end
end
