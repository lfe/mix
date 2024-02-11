defmodule Mix.Tasks.Lfe do
  @moduledoc """
  Start a LFE Repl.

  Loads your project source code and starts an interactive LFE environment.
  """
  use Mix.Task
  @requirements ["app.config"]

  @shortdoc "Start a LFE Repl."

  def run(_args) do
    IO.puts(:lfe_shell.banner())
    # Elixir sets the IO opts to return input as binaries, which messes up the
    # LFE shell which expects charlists.
    gl = Process.group_leader()
    before_shell_spawns_opts = :io.getopts(gl)
    :io.setopts(gl, binary: false)
    # We must monitor the shell process so the task doesn't end immediately.
    pid = :lfe_shell.start()
    ref = Process.monitor(pid)

    receive do
      {:DOWN, ^ref, _, _} ->
        :io.setopts(gl, before_shell_spawns_opts)
        :ok
    end
  end
end
