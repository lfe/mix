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
    # Think this is OTP 26+, need to figure out what to do on lower versions
    :shell.start_interactive({:lfe_shell, :start, []})
    ref = Process.monitor(:shell.whereis())

    receive do
      {:DOWN, ^ref, _, _} ->
        :ok
    end
  end
end
