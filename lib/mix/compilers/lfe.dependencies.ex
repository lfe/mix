defmodule Mix.Compilers.Lfe.Dependencies do
  @moduledoc false
  # Handles discovery and compilation ordering of LFE dependencies

  @doc """
  Discovers all LFE dependencies (direct and transitive) for the current project.
  Returns a list of dependency names (atoms) that contain LFE source files.
  """
  def discover_lfe_deps do
    discover_lfe_deps(Mix.Project.deps_paths())
  end

  @doc """
  Discovers all LFE dependencies from the provided deps_paths map.
  Returns a list of dependency names (atoms) that contain LFE source files.

  The deps_paths should be a map of dependency names to paths: %{dep_name: "/path/to/dep", ...}
  """
  def discover_lfe_deps(deps_paths) do
    deps_paths
    |> Enum.filter(&has_lfe_sources?/1)
    |> Enum.map(fn {dep_name, _path} -> dep_name end)
  end

  @doc """
  Checks if a dependency contains LFE source files.
  Takes a tuple of {dep_name, dep_path}.
  """
  def has_lfe_sources?({_dep_name, dep_path}) do
    src_path = Path.join(dep_path, "src")
    
    cond do
      # Check for .lfe files in src/
      File.dir?(src_path) and has_lfe_files?(src_path) ->
        true
      
      # Check if rebar.config declares rebar3_lfe plugin
      has_rebar3_lfe_plugin?(dep_path) ->
        true
      
      true ->
        false
    end
  end

  @doc """
  Returns the source and destination paths for compiling a dependency's LFE files.
  Source is in deps/, destination is in _build/<env>/lib/
  """
  def dep_compile_paths(dep_name) do
    dep_compile_paths(dep_name, Mix.Project.deps_paths())
  end

  @doc """
  Returns the source and destination paths for compiling a dependency's LFE files
  using the provided deps_paths map.
  Source is in deps/, destination is in _build/<env>/lib/

  The deps_paths should be a map of dependency names to paths: %{dep_name: "/path/to/dep", ...}
  """
  def dep_compile_paths(dep_name, deps_paths) do
    case deps_paths[dep_name] do
      nil ->
        nil

      dep_path ->
        src = Path.join(dep_path, "src")
        # Output should go to build directory, not deps directory
        dest = Path.join([Mix.Project.build_path(), "lib", to_string(dep_name), "ebin"])

        if File.dir?(src) do
          {src, dest}
        else
          nil
        end
    end
  end

  @doc """
  Returns the compilation mappings for a dependency in the format expected by Mix.Compilers.Lfe.
  Returns a list of {src_dir, dest_dir} tuples.
  """
  def dep_mappings(dep_name) do
    case dep_compile_paths(dep_name) do
      nil -> []
      {src, dest} -> [{src, dest}]
    end
  end

  @doc """
  Checks if we're currently compiling within a dependency context.
  Returns {true, dep_name} if in a dependency, false otherwise.
  
  Uses working directory detection which is more reliable than Mix internals.
  """
  def in_dependency? do
    cwd = File.cwd!()
    
    # Check for _build/<env>/lib/<dep_name> pattern
    case Regex.run(~r/_build\/[^\/]+\/lib\/([^\/]+)/, cwd) do
      [_, dep_name] -> 
        {true, String.to_atom(dep_name)}
      
      nil ->
        # Also check for deps/<dep_name> pattern
        case Regex.run(~r/deps\/([^\/]+)$/, cwd) do
          [_, dep_name] ->
            {true, String.to_atom(dep_name)}
          
          nil ->
            false
        end
    end
  end

  @doc """
  Returns a topologically sorted list of LFE dependencies.
  Dependencies are ordered so that each dep appears after all its dependencies.
  """
  def topological_sort(lfe_deps) do
    # Build dependency graph
    graph = build_dependency_graph(lfe_deps)
    topological_sort(lfe_deps, graph)
  end

  @doc """
  Returns a topologically sorted list of LFE dependencies using the provided graph.
  Dependencies are ordered so that each dep appears after all its dependencies.

  The graph should be a map where keys are dependency names and values are lists
  of their dependencies: %{dep_a: [:dep_b, :dep_c], dep_b: [], ...}
  """
  def topological_sort(_lfe_deps, graph) do
    # Perform topological sort using Kahn's algorithm
    kahn_sort(graph)
  end

  # Private functions

  defp has_lfe_files?(dir) do
    dir
    |> File.ls!()
    |> Enum.any?(&String.ends_with?(&1, ".lfe"))
  rescue
    File.Error -> false
  end

  defp has_rebar3_lfe_plugin?(dep_path) do
    rebar_config = Path.join(dep_path, "rebar.config")
    
    if File.exists?(rebar_config) do
      case :file.consult(String.to_charlist(rebar_config)) do
        {:ok, terms} ->
          Enum.any?(terms, fn
            {:plugins, plugins} -> 
              Enum.any?(plugins, &is_lfe_plugin?/1)
            _ -> 
              false
          end)
        
        _ -> 
          false
      end
    else
      false
    end
  end

  defp is_lfe_plugin?(plugin) when is_atom(plugin) do
    plugin in [:rebar3_lfe, :rebar_lfe_plugin]
  end

  defp is_lfe_plugin?({plugin, _version}) when is_atom(plugin) do
    plugin in [:rebar3_lfe, :rebar_lfe_plugin]
  end

  defp is_lfe_plugin?(_), do: false

  defp build_dependency_graph(lfe_deps) do
    Enum.reduce(lfe_deps, %{}, fn dep_name, graph ->
      dep_deps = get_dep_dependencies(dep_name)
      Map.put(graph, dep_name, dep_deps)
    end)
  end

  defp get_dep_dependencies(dep_name) do
    case Mix.Project.deps_paths()[dep_name] do
      nil ->
        []
      
      dep_path ->
        rebar_config = Path.join(dep_path, "rebar.config")
        
        if File.exists?(rebar_config) do
          parse_rebar_deps(rebar_config)
        else
          []
        end
    end
  end

  defp parse_rebar_deps(rebar_config) do
    case :file.consult(String.to_charlist(rebar_config)) do
      {:ok, terms} ->
        Enum.flat_map(terms, fn
          {:deps, deps} -> extract_dep_names(deps)
          _ -> []
        end)
      
      _ ->
        []
    end
  end

  defp extract_dep_names(deps) do
    Enum.map(deps, fn
      {name, _} when is_atom(name) -> name
      {name, _, _} when is_atom(name) -> name
      name when is_atom(name) -> name
      _ -> nil
    end)
    |> Enum.reject(&is_nil/1)
  end

  defp kahn_sort(graph) do
    # Calculate in-degrees
    in_degrees = calculate_in_degrees(graph)

    # Find nodes with no incoming edges
    queue =
      Enum.filter(graph, fn {node, _} -> Map.get(in_degrees, node, 0) == 0 end)
      |> Enum.map(fn {node, _} -> node end)

    # Perform the sort
    do_kahn_sort(graph, in_degrees, queue, [])
  end

  defp do_kahn_sort(_graph, _in_degrees, [], result), do: Enum.reverse(result)

  defp do_kahn_sort(graph, in_degrees, [node | queue], result) do
    # Get neighbors of current node
    neighbors = Map.get(graph, node, [])
    
    # Reduce in-degrees of neighbors
    {new_in_degrees, new_queue} =
      Enum.reduce(neighbors, {in_degrees, queue}, fn neighbor, {degrees, q} ->
        new_degree = Map.get(degrees, neighbor, 1) - 1
        new_degrees = Map.put(degrees, neighbor, new_degree)
        
        new_q = if new_degree == 0, do: q ++ [neighbor], else: q
        {new_degrees, new_q}
      end)
    
    do_kahn_sort(graph, new_in_degrees, new_queue, [node | result])
  end

  defp calculate_in_degrees(graph) do
    Enum.reduce(graph, %{}, fn {node, neighbors}, degrees ->
      # Ensure the node exists in degrees
      degrees = Map.put_new(degrees, node, 0)

      # Increment in-degree for each neighbor
      Enum.reduce(neighbors, degrees, fn neighbor, deg ->
        Map.update(deg, neighbor, 1, &(&1 + 1))
      end)
    end)
  end
end
