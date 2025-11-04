defmodule Mix.Compilers.Lfe.DependenciesTest do
  use ExUnit.Case, async: false

  alias Mix.Compilers.Lfe.Dependencies


  setup do
    # Ensure Mix is started
    Mix.start()
    Mix.shell(Mix.Shell.Process)

    on_exit(fn ->
      Mix.Shell.Process.flush()
      delete_tmp_paths()
    end)

    :ok
  end

  describe "has_lfe_sources?/1" do
    test "detects LFE project by .lfe files in src/" do
      # Create a temporary dependency with .lfe files
      dep_path = create_temp_dep("test_lfe_dep", """
      (defmodule test-module
        (export (hello 0)))
      
      (defun hello () 'world)
      """)

      assert Dependencies.has_lfe_sources?({:test_lfe_dep, dep_path})

      cleanup_temp_dep(dep_path)
    end

    test "detects LFE project by rebar3_lfe plugin in rebar.config" do
      dep_path = create_temp_dep_with_rebar("test_rebar_dep", """
      {plugins, [rebar3_lfe]}.
      {deps, []}.
      """)

      assert Dependencies.has_lfe_sources?({:test_rebar_dep, dep_path})

      cleanup_temp_dep(dep_path)
    end

    test "detects LFE project by rebar_lfe_plugin in rebar.config" do
      dep_path = create_temp_dep_with_rebar("test_old_plugin", """
      {plugins, [{rebar_lfe_plugin, "0.1.0"}]}.
      """)

      assert Dependencies.has_lfe_sources?({:test_old_plugin, dep_path})

      cleanup_temp_dep(dep_path)
    end

    test "returns false for non-LFE projects" do
      dep_path = create_temp_dep_erlang("test_erlang_dep", """
      -module(test_erlang).
      -export([hello/0]).
      
      hello() -> world.
      """)

      refute Dependencies.has_lfe_sources?({:test_erlang_dep, dep_path})

      cleanup_temp_dep(dep_path)
    end

    test "returns false for project without src/ directory" do
      dep_path = create_temp_dir("no_src_dep")

      refute Dependencies.has_lfe_sources?({:no_src_dep, dep_path})

      cleanup_temp_dep(dep_path)
    end
  end

  describe "dep_compile_paths/1" do
    test "returns correct src and dest paths for a dependency" do
      dep_path = create_temp_dep("compile_paths_test", """
      (defmodule test (export (foo 0)))
      (defun foo () 'bar)
      """)

      {src, dest} = Dependencies.dep_compile_paths(:compile_paths_test, %{compile_paths_test: dep_path})

      assert src == Path.join(dep_path, "src")
      assert dest == Path.join([Mix.Project.build_path(), "lib", "compile_paths_test", "ebin"])

      cleanup_temp_dep(dep_path)
    end

    test "returns nil for non-existent dependency" do
      assert Dependencies.dep_compile_paths(:nonexistent, %{}) == nil
    end

    test "returns nil for dependency without src/ directory" do
      dep_path = create_temp_dir("no_src")

      assert Dependencies.dep_compile_paths(:no_src, %{no_src: dep_path}) == nil

      cleanup_temp_dep(dep_path)
    end
  end

  describe "topological_sort/1" do
    test "sorts independent dependencies in any order" do
      # Three independent deps
      deps = [:dep_a, :dep_b, :dep_c]

      graph = %{
        dep_a: [],
        dep_b: [],
        dep_c: []
      }

      sorted = Dependencies.topological_sort(deps, graph)

      # All deps should be present
      assert length(sorted) == 3
      assert :dep_a in sorted
      assert :dep_b in sorted
      assert :dep_c in sorted
    end

    @tag :skip
    test "sorts linear dependency chain correctly" do
      # Chain: dep_a -> dep_b -> dep_c
      deps = [:dep_a, :dep_b, :dep_c]

      graph = %{
        dep_a: [:dep_b],
        dep_b: [:dep_c],
        dep_c: []
      }

      sorted = Dependencies.topological_sort(deps, graph)

      # dep_c must come before dep_b, which must come before dep_a
      assert Enum.find_index(sorted, &(&1 == :dep_c)) <
             Enum.find_index(sorted, &(&1 == :dep_b))
      assert Enum.find_index(sorted, &(&1 == :dep_b)) <
             Enum.find_index(sorted, &(&1 == :dep_a))
    end

    @tag :skip
    test "sorts diamond dependency graph correctly" do
      # Diamond: dep_a depends on dep_b and dep_c, both depend on dep_d
      #     dep_a
      #    /     \
      #  dep_b   dep_c
      #    \     /
      #     dep_d
      deps = [:dep_a, :dep_b, :dep_c, :dep_d]

      graph = %{
        dep_a: [:dep_b, :dep_c],
        dep_b: [:dep_d],
        dep_c: [:dep_d],
        dep_d: []
      }

      sorted = Dependencies.topological_sort(deps, graph)

      # dep_d must come first
      assert List.first(sorted) == :dep_d

      # dep_b and dep_c must come before dep_a
      dep_a_idx = Enum.find_index(sorted, &(&1 == :dep_a))
      dep_b_idx = Enum.find_index(sorted, &(&1 == :dep_b))
      dep_c_idx = Enum.find_index(sorted, &(&1 == :dep_c))

      assert dep_b_idx < dep_a_idx
      assert dep_c_idx < dep_a_idx
    end

    test "handles empty dependency list" do
      assert Dependencies.topological_sort([]) == []
    end
  end

  describe "discover_lfe_deps/1" do
    test "discovers LFE dependencies from provided deps_paths" do
      # Create temp directories with LFE and non-LFE content
      lfe_path = create_temp_dep("lfe", "(defmodule lfe-test)")
      ltest_path = create_temp_dep("ltest", "(defmodule ltest-test)")
      cowboy_path = create_temp_dep_erlang("cowboy", "-module(cowboy_test).")

      deps_paths = %{
        lfe: lfe_path,
        ltest: ltest_path,
        cowboy: cowboy_path
      }

      lfe_deps = Dependencies.discover_lfe_deps(deps_paths)

      assert :lfe in lfe_deps
      assert :ltest in lfe_deps
      refute :cowboy in lfe_deps

      # Cleanup
      cleanup_temp_dep(lfe_path)
      cleanup_temp_dep(ltest_path)
      cleanup_temp_dep(cowboy_path)
    end
  end

  # Helper functions

  defp create_temp_dep(name, lfe_content) do
    path = Path.join([System.tmp_dir!(), "mix_lfe_test", to_string(name)])
    src_path = Path.join(path, "src")
    
    File.rm_rf!(path)
    File.mkdir_p!(src_path)
    File.write!(Path.join(src_path, "#{name}.lfe"), lfe_content)
    
    path
  end

  defp create_temp_dep_with_rebar(name, rebar_content) do
    path = Path.join([System.tmp_dir!(), "mix_lfe_test", to_string(name)])
    
    File.rm_rf!(path)
    File.mkdir_p!(path)
    File.write!(Path.join(path, "rebar.config"), rebar_content)
    
    path
  end

  defp create_temp_dep_erlang(name, erl_content) do
    path = Path.join([System.tmp_dir!(), "mix_lfe_test", to_string(name)])
    src_path = Path.join(path, "src")
    
    File.rm_rf!(path)
    File.mkdir_p!(src_path)
    File.write!(Path.join(src_path, "#{name}.erl"), erl_content)
    
    path
  end

  defp create_temp_dir(name) do
    path = Path.join([System.tmp_dir!(), "mix_lfe_test", to_string(name)])
    
    File.rm_rf!(path)
    File.mkdir_p!(path)
    
    path
  end

  defp cleanup_temp_dep(path) do
    File.rm_rf!(path)
  end

  defp delete_tmp_paths do
    tmp_path = Path.join([System.tmp_dir!(), "mix_lfe_test"])
    File.rm_rf!(tmp_path)
  end

end
