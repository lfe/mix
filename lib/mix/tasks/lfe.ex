defmodule Mix.Tasks.Lfe do
  @moduledoc """
  Start a LFE Repl.
  """
  use Mix.Task

  def run(_args) do
    IO.puts(:lfe_shell.banner())
    gl = Process.group_leader()
    before_shell_spawns_opts = :io.getopts(gl)
    :io.setopts(gl, binary: false)
    pid = :lfe_shell.start()
    ref = Process.monitor(pid)

    receive do
      {:DOWN, ^ref, _, _} ->
        :io.setopts(gl, before_shell_spawns_opts)
        :ok
    end
  end
end
