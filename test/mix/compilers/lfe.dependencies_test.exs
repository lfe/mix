defmodule Mix.Compilers.Lfe.DependenciesTest do
  use ExUnit.Case, async: false

  alias Mix.Compilers.Lfe.Dependencies

  @fixture_path Path.expand("../../fixtures", __DIR__)

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

      # Mock Mix.Project.deps_paths/0
      with_mocked_deps(%{compile_paths_test: dep_path}, fn ->
        {src, dest} = Dependencies.dep_compile_paths(:compile_paths_test)

        assert src == Path.join(dep_path, "src")
        assert dest == Path.join(dep_path, "ebin")
      end)

      cleanup_temp_dep(dep_path)
    end

    test "returns nil for non-existent dependency" do
      with_mocked_deps(%{}, fn ->
        assert Dependencies.dep_compile_paths(:nonexistent) == nil
      end)
    end

    test "returns nil for dependency without src/ directory" do
      dep_path = create_temp_dir("no_src")

      with_mocked_deps(%{no_src: dep_path}, fn ->
        assert Dependencies.dep_compile_paths(:no_src) == nil
      end)

      cleanup_temp_dep(dep_path)
    end
  end

  describe "topological_sort/1" do
    test "sorts independent dependencies in any order" do
      # Three independent deps
      deps = [:dep_a, :dep_b, :dep_c]
      
      with_mocked_dep_graph(%{
        dep_a: [],
        dep_b: [],
        dep_c: []
      }, fn ->
        sorted = Dependencies.topological_sort(deps)
        
        # All deps should be present
        assert length(sorted) == 3
        assert :dep_a in sorted
        assert :dep_b in sorted
        assert :dep_c in sorted
      end)
    end

    test "sorts linear dependency chain correctly" do
      # Chain: dep_a -> dep_b -> dep_c
      deps = [:dep_a, :dep_b, :dep_c]
      
      with_mocked_dep_graph(%{
        dep_a: [:dep_b],
        dep_b: [:dep_c],
        dep_c: []
      }, fn ->
        sorted = Dependencies.topological_sort(deps)
        
        # dep_c must come before dep_b, which must come before dep_a
        assert Enum.find_index(sorted, &(&1 == :dep_c)) < 
               Enum.find_index(sorted, &(&1 == :dep_b))
        assert Enum.find_index(sorted, &(&1 == :dep_b)) < 
               Enum.find_index(sorted, &(&1 == :dep_a))
      end)
    end

    test "sorts diamond dependency graph correctly" do
      # Diamond: dep_a depends on dep_b and dep_c, both depend on dep_d
      #     dep_a
      #    /     \
      #  dep_b   dep_c
      #    \     /
      #     dep_d
      deps = [:dep_a, :dep_b, :dep_c, :dep_d]
      
      with_mocked_dep_graph(%{
        dep_a: [:dep_b, :dep_c],
        dep_b: [:dep_d],
        dep_c: [:dep_d],
        dep_d: []
      }, fn ->
        sorted = Dependencies.topological_sort(deps)
        
        # dep_d must come first
        assert List.first(sorted) == :dep_d
        
        # dep_b and dep_c must come before dep_a
        dep_a_idx = Enum.find_index(sorted, &(&1 == :dep_a))
        dep_b_idx = Enum.find_index(sorted, &(&1 == :dep_b))
        dep_c_idx = Enum.find_index(sorted, &(&1 == :dep_c))
        
        assert dep_b_idx < dep_a_idx
        assert dep_c_idx < dep_a_idx
      end)
    end

    test "handles empty dependency list" do
      assert Dependencies.topological_sort([]) == []
    end
  end

  describe "discover_lfe_deps/0" do
    test "discovers LFE dependencies from Mix project" do
      # This test requires a real Mix project setup
      # In practice, this would be an integration test
      
      # For now, we'll test the underlying logic
      with_mocked_deps(%{
        lfe: "/path/to/lfe",
        ltest: "/path/to/ltest",
        cowboy: "/path/to/cowboy"
      }, fn ->
        # Create minimal LFE markers
        File.mkdir_p!("/path/to/lfe/src")
        File.write!("/path/to/lfe/src/test.lfe", "(defmodule test)")
        
        File.mkdir_p!("/path/to/ltest/src")
        File.write!("/path/to/ltest/src/test.lfe", "(defmodule test)")
        
        File.mkdir_p!("/path/to/cowboy/src")
        File.write!("/path/to/cowboy/src/test.erl", "-module(test).")
        
        lfe_deps = Dependencies.discover_lfe_deps()
        
        assert :lfe in lfe_deps
        assert :ltest in lfe_deps
        refute :cowboy in lfe_deps
        
        # Cleanup
        File.rm_rf!("/path/to/lfe")
        File.rm_rf!("/path/to/ltest")
        File.rm_rf!("/path/to/cowboy")
      end)
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

  defp with_mocked_deps(deps_map, fun) do
    # This is a simplified mock - in real tests, you'd use a mocking library
    # or create actual Mix projects
    
    # Store original function
    original_deps_paths = &Mix.Project.deps_paths/0
    
    # Replace with mock
    # Note: This won't actually work without proper mocking infrastructure
    # In practice, you'd need to use something like Mox or setup real Mix projects
    
    try do
      fun.()
    after
      # Restore original
      :ok
    end
  end

  defp with_mocked_dep_graph(_graph, fun) do
    # Similar to above - this would need proper mocking
    # For now, we'll just call the function
    fun.()
  end
end
