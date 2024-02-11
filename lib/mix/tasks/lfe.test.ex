defmodule Mix.Tasks.Lfe.Test do
  use Mix.Task.Compiler
  alias Mix.Compilers.Lfe

  @recursive true
  @manifest "test.lfe"
  @switches [force: :boolean, all_warnings: :boolean]
  @preferred_cli_env :test
  @requirements ["app.config"]

  @shortdoc "Runs a LFE project's tests"

  @moduledoc """
  Compiles the source LFE source files of the project, using `Mix.Compilers.Lfe`
  and also compiles and runs all the test LFE files with the '-tests.lfe' extension in the
  'test' folder of the project.

  Uses the [ltest](https://github.com/lfex/ltest) library to do so.

  For the compilation it supports the command line options and the configuration of the `Mix.Tasks.Compile.Lfe` task.
  """

  @doc """
  Runs this task.
  """
  def run(args) do
    Logger.configure(level: :info)
    {opts, _, _} = OptionParser.parse(args, switches: @switches)

    dest = Mix.Project.compile_path()

    File.rmdir(dest)
    File.mkdir_p!(dest)

    Lfe.compile(manifest(), [{"src", dest}, {"test", dest}], opts)

    :ltest.all()
  end

  @doc """
  Returns LFE test manifests.
  """
  def manifests, do: [manifest()]

  defp manifest, do: Path.join(Mix.Project.manifest_path(), @manifest)
end
