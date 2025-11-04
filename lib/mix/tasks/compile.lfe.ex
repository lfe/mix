defmodule Mix.Tasks.Compile.Lfe do
  use Mix.Task.Compiler
  alias Mix.Compilers.Lfe
  alias Mix.Compilers.Lfe.{Dependencies, AppFile}

  @recursive true
  @manifest "compile.lfe"
  @switches [force: :boolean, all_warnings: :boolean]

  @moduledoc """
  Compiles LFE source files for both the project and its dependencies.

  This compiler handles all `.lfe` files in the project and its dependencies,
  bypassing rebar3 entirely for LFE compilation. It compiles dependencies
  in topological order before compiling project files.

  Uses an [idea](https://github.com/elixir-lang/elixir/blob/e1c903a5956e4cb9075f0aac00638145788b0da4/lib/mix/lib/mix/compilers/erlang.ex#L20) from the Erlang Mix compiler to do so.

  These options are supported:

  ## Command line options
    * `--force` - forces compilation regardless of modification times
    * `--all-warnings` - prints warnings even from files that do not need to be recompiled

  ## Configuration

  The [Erlang compiler configuration](https://github.com/elixir-lang/elixir/blob/master/lib/mix/lib/mix/tasks/compile.erlang.ex#L31) is supported.
  Specific configuration options for the LFE compiler will be supported in future.
  """

  @doc """
  Runs this task.
  """
  def run(args) do
    {opts, _, _} = OptionParser.parse(args, switches: @switches)

    # Check if we're being invoked in a dependency context
    case Dependencies.in_dependency?() do
      {true, dep_name} ->
        # We're compiling a dependency - only compile this dependency's LFE files
        compile_dependency(dep_name, opts)

      false ->
        # We're compiling the main project - compile deps first, then project
        compile_project(opts)
    end
  end

  @doc """
  Returns LFE manifests.
  """
  def manifests, do: [manifest()]

  @doc """
  Cleans up compilation artifacts.
  """
  def clean, do: Lfe.clean(manifest())

  # Private functions

  defp compile_dependency(dep_name, opts) do
    case Dependencies.dep_compile_paths(dep_name) do
      nil ->
        {:noop, []}

      {src, dest} ->
        # Ensure destination directory exists
        File.mkdir_p!(dest)
        
        # Ensure lib path is in code path for -include_lib directives
        lib_path = Path.join(Mix.Project.build_path(), "lib") |> String.to_charlist()
        unless lib_path in :code.get_path() do
          :code.add_patha(lib_path)
        end
        
        # Also add the specific app directory to code path
        app_path = Path.join([Mix.Project.build_path(), "lib", to_string(dep_name)]) |> String.to_charlist()
        unless app_path in :code.get_path() do
          :code.add_patha(app_path)
        end
        
        # Step 1: Process .app.src → .app using shared module
        AppFile.process(src, dest, dep_name)
        
        # Step 2: Copy include files if they exist
        copy_include_files(src, dest)
        
        # Step 3: Compile .lfe files
        # Use a dependency-specific manifest
        dep_manifest = Path.join(Mix.Project.manifest_path(), "compile.lfe.#{dep_name}")
        
        mappings = [{src, dest}]
        Lfe.compile(dep_manifest, mappings, opts)
    end
  end

  defp compile_project(opts) do
    # First, compile all LFE dependencies in topological order
    lfe_deps = Dependencies.discover_lfe_deps()
    sorted_deps = Dependencies.topological_sort(lfe_deps)

    # Compile each dependency
    dep_results = 
      Enum.map(sorted_deps, fn dep_name ->
        compile_dep_if_needed(dep_name, opts)
      end)

    # Check if any dependency compilation failed
    dep_errors = 
      Enum.filter(dep_results, fn
        {:error, _, _} -> true
        _ -> false
      end)

    if dep_errors != [] do
      # Return the first error
      List.first(dep_errors)
    else
      # All dependencies compiled successfully, now compile the project
      dest = Mix.Project.compile_path()
      mappings = [{"src", dest}]
      
      Lfe.compile(manifest(), mappings, opts)
    end
  end

  defp compile_dep_if_needed(dep_name, opts) do
    case Dependencies.dep_compile_paths(dep_name) do
      nil ->
        {:noop, []}

      {src, dest} ->
        # Ensure destination directory exists
        File.mkdir_p!(dest)
        
        # Ensure lib path is in code path for -include_lib directives
        lib_path = Path.join(Mix.Project.build_path(), "lib") |> String.to_charlist()
        unless lib_path in :code.get_path() do
          :code.add_patha(lib_path)
        end
        
        # Also add the specific app directory to code path
        app_path = Path.join([Mix.Project.build_path(), "lib", to_string(dep_name)]) |> String.to_charlist()
        unless app_path in :code.get_path() do
          :code.add_patha(app_path)
        end
        
        # Step 1: Process .app.src → .app using shared module
        AppFile.process(src, dest, dep_name)
        
        # Step 2: Copy include files if they exist
        copy_include_files(src, dest)
        
        # Step 3: Compile .lfe files
        # Use a dependency-specific manifest to track compilation state
        dep_manifest = Path.join(Mix.Project.manifest_path(), "compile.lfe.#{dep_name}")
        
        mappings = [{src, dest}]
        
        # Compile the dependency
        result = Lfe.compile(dep_manifest, mappings, opts)
        
        # Add compiled beams to code path if not already there
        unless dest in :code.get_path() do
          :code.add_pathz(String.to_charlist(dest))
        end
        
        # Load the application so Mix can see it
        _ = Application.load(dep_name)
        
        result
    end
  end

  defp copy_include_files(src_dir, dest_dir) do
    # LFE projects often have include/ directory alongside src/
    dep_root = Path.dirname(src_dir)
    include_src = Path.join(dep_root, "include")
    include_dest = Path.join(Path.dirname(dest_dir), "include")
    
    if File.dir?(include_src) do
      File.rm_rf!(include_dest)
      File.mkdir_p!(include_dest)
      
      # Copy all files from include_src/* to include_dest/
      File.ls!(include_src)
      |> Enum.each(fn file ->
        src_file = Path.join(include_src, file)
        dest_file = Path.join(include_dest, file)
        File.cp_r!(src_file, dest_file)
      end)
    end
  end

  defp manifest, do: Path.join(Mix.Project.manifest_path(), @manifest)
end
