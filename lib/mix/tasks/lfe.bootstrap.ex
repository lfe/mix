defmodule Mix.Tasks.Lfe.Bootstrap do
  use Mix.Task
  
  alias Mix.Compilers.Lfe.AppFile

  @requirements []  # Don't check dependencies before running this task
  @shortdoc "Bootstrap LFE dependencies before compilation"
  @moduledoc """
  Manually compiles LFE dependencies that rebar3 bare compile can't handle.
  
  This task:
  1. Compiles .lfe files to .beam files using :lfe_comp
  2. Processes .app.src files to .app files (rebar3 convention)
  
  This is needed during the initial compilation of the mix_lfe plugin itself,
  since it depends on ltest (an LFE project) which requires the rebar3_lfe plugin
  that isn't available in rebar3 bare compile mode.
  
  Usage:
      mix lfe.bootstrap
  """

  def run(_args) do
    Mix.shell().info("==> Bootstrapping LFE dependencies")
    
    # Ensure LFE itself is available
    unless Code.ensure_loaded?(:lfe_comp) do
      Mix.raise("""
      LFE compiler not available. Please ensure LFE is compiled first.
      
      Try:
          cd deps/lfe && make compile && cd ../..
      """)
    end
    
    # Bootstrap ltest
    bootstrap_ltest()
    
    Mix.shell().info("==> Bootstrap complete")
  end

  defp bootstrap_ltest do
    deps_path = Mix.Project.deps_path()
    ltest_src = Path.join([deps_path, "ltest", "src"])
    ltest_ebin = Path.join([Mix.Project.build_path(), "lib", "ltest", "ebin"])
    
    # Check if ltest needs compilation
    needs_compile = !File.exists?(Path.join(ltest_ebin, "ltest.beam"))
    
    if needs_compile do
      Mix.shell().info("==> Compiling ltest")
      
      # Ensure source exists
      unless File.dir?(ltest_src) do
        Mix.raise("ltest source not found. Run 'mix deps.get' first.")
      end
      
      # Create output directory
      File.mkdir_p!(ltest_ebin)
      
      # Step 1: Copy include files
      copy_include_files(deps_path, Mix.Project.build_path())
      
      # Step 2: Process .app.src file using shared module
      Mix.shell().info("  Processing ltest.app.src")
      AppFile.process(ltest_src, ltest_ebin, :ltest)
      
      # Step 3: Compile .lfe files
      lfe_files = Path.wildcard(Path.join(ltest_src, "*.lfe"))
      
      if lfe_files == [] do
        Mix.shell().info("==> No .lfe files found in ltest")
      else
        # Compile each file
        Enum.each(lfe_files, fn file ->
          Mix.shell().info("  Compiling #{Path.basename(file)}")
          
          # Use lfe_comp to compile
          case :lfe_comp.file(
            String.to_charlist(file),
            [{:outdir, String.to_charlist(ltest_ebin)}, :return, :report]
          ) do
            {:ok, _module, _warnings} ->
              :ok
              
            {:error, errors, _warnings} ->
              Mix.raise("Failed to compile #{file}: #{inspect(errors)}")
          end
        end)
        
        Mix.shell().info("==> ltest compiled successfully")
      end
    else
      Mix.shell().info("==> ltest already compiled")
    end
  end

  defp copy_include_files(deps_path, build_path) do
    # Copy include files from deps/ltest/include to _build/dev/lib/ltest/include
    include_src = Path.join([deps_path, "ltest", "include"])
    include_dest = Path.join([build_path, "lib", "ltest", "include"])
    
    if File.dir?(include_src) do
      Mix.shell().info("  Copying include files")
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
end
