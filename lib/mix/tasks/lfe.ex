defmodule Mix.Tasks.Lfe do
  @moduledoc """
  Start a LFE Repl.

  Loads your project source code and starts an interactive LFE environment.
  """
  use Mix.Task
  @requirements ["app.config"]

  @shortdoc "Start a LFE Repl."

  def run(_args) do
    IO.puts(banner(lfe_version(), quit_message()))
    # # Elixir sets the IO opts to return input as binaries, which messes up the
    # # LFE shell which expects charlists.
    # gl = Process.group_leader()
    # before_shell_spawns_opts = :io.getopts(gl)
    # :io.setopts(gl, binary: false)
    # # We must monitor the shell process so the task doesn't end immediately.
    # pid = :lfe_shell.start()
    # ref = Process.monitor(pid)

    # receive do
    #   {:DOWN, ^ref, _, _} ->
    #     :io.setopts(gl, before_shell_spawns_opts)
    #     :ok
    # end
    :shell.start_interactive({:lfe_shell, :start, []})
    ref = Process.monitor(:shell.whereis())

    receive do
      {:DOWN, ^ref, _, _} ->
        :ok
    end
  end

  # defp banner(version, quit_msg) do
  #   grn("   ..-~") <> ylw(".~_") <> grn("~---..")                                 <> "\n" <>
  #   grn("  (      ") <> ylw("\\\\") <> grn("     )")                       <> "    |   A Lisp-2+ on the Erlang VM\n" <>
  #   grn("  |`-.._") <> ylw("/") <> grn("_") <> ylw("\\\\") <> grn("_.-':") <> "    |   Type " <> grn("(help)") <> " for usage info.\n" <>
  #   grn("  |         ") <> red("g") <> grn(" |_ \\")                        <> "   |\n" <>
  #   grn("  |        ") <> red("n") <> grn("    | |")                         <> "  |   Docs: " <> blu("http://docs.lfe.io/") <> "\n" <>
  #   grn("  |       ") <> red("a") <> grn("    / /")                         <> "   |   Source: " <> blu("http://github.com/lfe/lfe") <> "\n" <>
  #   grn("   \\     ") <> red("l") <> grn("    |_/")                        <> "    |\n" <>
  #   grn("    \\   ") <> red("r") <> grn("     /")                        <> "      |   LFE v" <> version <> " " <> quit_msg <> "\n" <>
  #   grn("     `-") <> red("E") <> grn("___.-'")                               <> "\n\n"
  # end

  defp banner(_version, _quit) do
dmg("      @") <> "\n" <>
mag("     %") <> "\n" <>
mag("    %%%") <> lmg("`") <> "\n" <>
mag("   %%%%%%") <> lmg("`") <> "\n" <>
lmg("  /") <> dmg("@") <> mag("%%%%%%%") <> lmg("`") <> "\n" <>
lmg("  *") <> mag("%") <> dmg("@") <> mag("%%%%%%%") <> "\n" <>
lmg("  *") <> mag("%%%") <> dmg("@") <> mag("%%%%") <> dmg("*") <> "\n" <>
dmg("   `") <> mag("%%%%") <> dmg("@") <> mag("%%") <> dmg("*") <> "\n" <>
dmg("    `") <> mag("%% %%") <> dmg("*") <> "\n"
    end

# dmg("      @")
# mag("     %")
# mag("    %%%") <> lmg("`")
# mag("   %%%%%%") <> lmg("`")
# lmg("  /") <> dmg("@") <> mag("%%%%%%%") <> lmg("`")
# lmg("  *") <> mag("%") <> dmg("@") <> mag("%%%%%%%")
# lmg("  *") <> mag("%%%") <> dmg("@") <> mag("%%%%") <> dmg("*")
# dmg("   `" <> mag("%%%%") <> dmg("@") <> mag("%%") <> dmg("*")
# dmg("    `") <> mag("%% %%") <> dmg("*")
#         %@
#        %%%
#      %@%%%
#      %%%%%%
#     @%@%%%%%@
#    %%%%%%%%%%%
#    %@%%%%%%%%%%
#    @%%%%%%%%%%%
#    @%@%%%%%%%%%
#     %%%@%%%%%%
#       @  %@%
#
#
#                    .X;
#  .  . .  .  . . %; .X . .  . .  . .  .
#   .       .   :;@%88%    .     .
#     .  .    . ;S8888X.     .      . .
# .       .   .X@X;@8:@%.  .   .  .     .
#   .  .    ..@t8XX.@88S.       .    .
#  .    .  . @%88S88X88:X  . .    .    .
#    .     .SStS8X8888XStX     .    .
#  .   . . @X%8:@888S8@8:%S..    .    .
#    .    t;%8@.%8888S%%8% X:  .   .    .
#  .    ..@  88;:@88S;;8.8t;8t.     .  .
#     .  8;:88S8.S8%: 8;8;88t%8. .
#  .    ::@t8888X%X 888888:8 8:X   . .  .
#    .  StS@888888;888888888888:t.
#  .   .88@88@88@8S8888888888.88tS.  . .
#    .  X888:X%@XSXX8@@X8@8:88 888..
#  .    X8888.8t@XXS:8888888888.88; .
#     . S888.8:88:%;8:;8.8.8:8888     .
#  .    :;SX@888:@8;.8.8888888X S8 .
#    .   X  SS 8   @8:8:8888     :  .  .
#  .   .  X S S       @8888   %;: .
#    .    .X S@ :tt;;.  88    ;..   . .
#  .    .   %8:%.8SXS%t:;8:%88.   .
#     .     ...tX@SX88@tt%:.:  .     .


  defp lfe_version() do
    {:ok, [app]} = :file.consult(:code.where_is_file(~c"lfe.app"))
    version = :proplists.get_value(:vsn, :erlang.element(3, app))
    to_string(version)
  end

  defp quit_message(), do: "(abort with ^C; enter JCL with ^G)"

  # Helper functions to
  defp red(string), do: IO.ANSI.red() <> string <> IO.ANSI.reset()
  defp grn(string), do: IO.ANSI.bright() <> IO.ANSI.green() <> string <> IO.ANSI.reset()
  defp blu(string), do: IO.ANSI.bright() <> IO.ANSI.blue() <> string <> IO.ANSI.reset()
  defp ylw(string), do: IO.ANSI.bright() <> IO.ANSI.yellow() <> string <> IO.ANSI.reset()

  defp mag(string), do: IO.ANSI.magenta() <> string <> IO.ANSI.reset()
  defp lmg(string), do: IO.ANSI.light_magenta() <> string <> IO.ANSI.reset()
  defp dmg(string), do: IO.ANSI.bright() <> IO.ANSI.magenta() <> string <> IO.ANSI.reset()
end
