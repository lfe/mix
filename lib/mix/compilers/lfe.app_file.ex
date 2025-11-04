defmodule Mix.Compilers.Lfe.AppFile do
  @moduledoc """
  Handles OTP application file processing for LFE dependencies.
  
  LFE projects follow the rebar3 convention of maintaining an `.app.src` file
  in the `src/` directory with template variables. This module processes these
  files to create proper `.app` files in the `ebin/` directory.
  
  ## Template Variables Supported
  
  - `{vsn, git}` - Version from git describe
  - `{vsn, semver}` - Version from git describe (same as git)
  - `{vsn, {git, _}}` - Version from git describe
  - `{vsn, {cmd, command}}` - Version from shell command output
  - `{vsn, "1.0.0"}` - Literal version (unchanged)
  
  ## Example
  
      # Process ltest's .app.src file
      Mix.Compilers.Lfe.AppFile.process("deps/ltest/src", "_build/dev/lib/ltest/ebin", :ltest)
      
      # This reads deps/ltest/src/ltest.app.src
      # Processes template variables
      # Writes _build/dev/lib/ltest/ebin/ltest.app
  """

  @doc """
  Processes an `.app.src` file to create an `.app` file.
  
  Reads `src_dir/<app_name>.app.src`, processes any rebar3 template variables,
  and writes the result to `ebin_dir/<app_name>.app`.
  
  If the `.app.src` file doesn't exist, this is a no-op (some projects may not have one).
  
  ## Parameters
  
  - `src_dir` - Directory containing the .app.src file (typically `src/`)
  - `ebin_dir` - Directory where .app file should be written (typically `ebin/`)
  - `app_name` - Application name (atom or string)
  
  ## Returns
  
  - `:ok` if successful or file doesn't exist
  - Logs errors but doesn't crash on failure
  """
  def process(src_dir, ebin_dir, app_name) when is_atom(app_name) do
    process(src_dir, ebin_dir, Atom.to_string(app_name))
  end
  
  def process(src_dir, ebin_dir, app_name) when is_binary(app_name) do
    app_src_file = Path.join(src_dir, "#{app_name}.app.src")
    app_file = Path.join(ebin_dir, "#{app_name}.app")
    
    if File.exists?(app_src_file) do
      case read_and_process(app_src_file) do
        {:ok, processed_term} ->
          write_app_file(app_file, processed_term)
          :ok
          
        {:error, reason} ->
          Mix.shell().error("Warning: Could not process #{app_name}.app.src: #{inspect(reason)}")
          :ok
      end
    else
      # No .app.src file - this is OK, some projects might not have one
      :ok
    end
  end

  # Private functions

  defp read_and_process(app_src_file) do
    case :file.consult(String.to_charlist(app_src_file)) do
      {:ok, [app_term]} ->
        processed_term = process_app_term(app_term)
        {:ok, processed_term}
        
      {:ok, terms} when is_list(terms) ->
        # Multiple terms - take the first application term
        case Enum.find(terms, &match?({:application, _, _}, &1)) do
          nil -> {:error, :no_application_term}
          app_term -> {:ok, process_app_term(app_term)}
        end
        
      {:error, reason} ->
        {:error, reason}
    end
  end

  defp write_app_file(app_file, term) do
    # Format as Erlang term with proper indentation
    app_content = :io_lib.format("~tp.~n", [term])
    File.write!(app_file, app_content)
  end

  defp process_app_term({:application, app_name, properties}) when is_list(properties) do
    # Process properties list, handling rebar3 template variables
    processed_props = Enum.map(properties, &process_property/1)
    {:application, app_name, processed_props}
  end

  defp process_app_term(other), do: other

  defp process_property({:vsn, template}) do
    {:vsn, process_version_template(template)}
  end

  defp process_property(other), do: other

  defp process_version_template(:git), do: get_version_from_git()
  defp process_version_template(:semver), do: get_version_from_git()
  defp process_version_template({:git, _}), do: get_version_from_git()
  defp process_version_template({:semver, _}), do: get_version_from_git()
  defp process_version_template({:cmd, cmd}), do: get_version_from_cmd(cmd)
  defp process_version_template(literal) when is_binary(literal), do: literal
  defp process_version_template(literal) when is_list(literal), do: literal
  defp process_version_template(_), do: "0.0.0"

  defp get_version_from_git do
    case System.cmd("git", ["describe", "--always", "--tags"], stderr_to_stdout: true) do
      {version, 0} -> 
        version
        |> String.trim()
        |> String.to_charlist()
        
      _ -> 
        ~c"0.0.0"
    end
  rescue
    _ -> ~c"0.0.0"
  end

  defp get_version_from_cmd(cmd) when is_list(cmd) do
    cmd_str = to_string(cmd)
    case System.shell(cmd_str) do
      {version, 0} -> 
        version
        |> String.trim()
        |> String.to_charlist()
        
      _ -> 
        ~c"0.0.0"
    end
  rescue
    _ -> ~c"0.0.0"
  end
  
  defp get_version_from_cmd(_), do: ~c"0.0.0"
end
