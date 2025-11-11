defmodule Mix.Tasks.New.Lfe do
  use Mix.Task
  import Mix.Generator

  @shortdoc "Creates a new LFE project"
  @manifest "new.lfe"

  @switches [app: :string, sup: :boolean]

  @impl true
  def run(argv) do
    {opts, argv} = OptionParser.parse!(argv, strict: @switches)

    case argv do
      [] ->
        Mix.raise(
          "Expected PATH to be given. " <>
            "Use \"mix #{@manifest} PATH\" or run \"mix help #{@manifest}\" for more information"
        )

      [path | _] ->
        app = opts[:app] || Path.basename(Path.expand(path))
        mod = opts[:module] || app
        is_name_already_in_use?(mod)

        if path != "." do
          check_directory_existence!(path)
          File.mkdir_p!(path)
        end

        File.cd!(path, fn ->
          generate(app, mod, path, opts)
        end)
    end
  end

  defp is_name_already_in_use?(name) do
    name = Module.concat(Elixir, name)

    if Code.ensure_loaded?(name) do
      Mix.raise("Module name #{inspect(name)} is already taken, please choose another name")
    end
  end

  defp check_directory_existence!(path) do
    msg = "The directory #{inspect(path)} already exists. Are you sure you want to continue?"

    if File.dir?(path) and not Mix.shell().yes?(msg) do
      Mix.raise("Please select another directory for installation")
    end
  end

  defp sup_app(_mod, false), do: ""
  defp sup_app(mod, true), do: ",\n      mod: {#{mod}-app, []}"

  defp to_pascal_case(str) do
    str
    |> String.replace(~r/[-_]/, " ")
    |> String.split()
    |> Enum.map(&String.capitalize/1)
    |> Enum.join("")
  end


  defp generate(app, mod, _path, opts) do
    project = [
      app: app,
      mod: mod,
      mod_mix_name: to_pascal_case(app),
      sup_app: sup_app(mod, !!opts[:sup]),
      version: get_version(System.version())
    ]

    create_file("mix.exs", mix_lfe_exs_template(project))

    create_directory("src")
    create_file("src/#{mod}.lfe", lib_template(project))

    if opts[:sup] do
      create_file("src/#{mod}-app.lfe", lfe_app_template(project))
      create_file("src/#{mod}-sup.lfe", lfe_sup_template(project))
    end

    create_directory("test")
    create_file("test/#{mod}-test.lfe", lfe_test_template(project))
  end

  defp get_version(version) do
    {:ok, version} = Version.parse(version)

    "#{version.major}.#{version.minor}" <>
      case version.pre do
        [h | _] -> "-#{h}"
        [] -> ""
      end
  end

  embed_template(:mix_lfe_exs,
    """
    defmodule <%= @mod_mix_name %>.MixProject do
      use Mix.Project

      def project do
        [
          app: :'<%= @app %>',
          version: "0.1.0",
          elixir: "~> <%= @version %>",
          start_permanent: Mix.env() == :prod,
          compilers: [:lfe] ++ Mix.compilers(),
          deps: deps()
        ]
      end

      # Run "mix help compile.app" to learn about applications.
      def application do
        [
          extra_applications: [:logger, :rebar3_lfe]<%= @sup_app %>
        ]
      end

      # Run "mix help deps" to learn about dependencies.
      defp deps do
        [
          # {:dep_from_hexpm, "~> 0.3.0"},
          # {:dep_from_git, git: "https://github.com/elixir-lang/my_dep.git", tag: "0.1.0"}
          {:rebar3_lfe, "0.5.4"},
          {:lfe, "2.2.0"}
        ]
      end
    end
    """)

  embed_template(:lib,
    """
    (defmodule <%= @app %>
      (export
        (a-function 0)))

    (defun a-function ()
      'true)
    """)

  embed_template(:lfe_app,
    """
    (defmodule <%= @app %>-app
      (behaviour application)
      ;; app implementation
      (export
       (start 2)
       (stop 1)))

    ;;; --------------------------
    ;;; application implementation
    ;;; --------------------------

    (defun start (_type _args)
      (logger:set_application_level '<%= @app %> 'all)
      (logger:info "Starting <%= @app %> application ...")
      (<%= @app %>-sup:start_link))

    (defun stop (_state)
      (<%= @app %>-sup:stop)
      'ok)
    """)

  embed_template(:lfe_sup,
    """
    (defmodule <%= @app %>-sup
      (behaviour supervisor)
      ;; supervisor implementation
      (export
       (start_link 0)
       (stop 0))
      ;; callback implementation
      (export
        (init 1)))

    ;;; ----------------
    ;;; config functions
    ;;; ----------------

    (defun SERVER () (MODULE))
    (defun supervisor-opts () '())
    (defun sup-flags ()
      `#M(strategy one_for_one
          intensity 3
          period 60))

    ;;; -------------------------
    ;;; supervisor implementation
    ;;; -------------------------

    (defun start_link ()
      (supervisor:start_link `#(local ,(SERVER))
                             (MODULE)
                             (supervisor-opts)))

    (defun stop ()
      (gen_server:call (SERVER) 'stop))

    ;;; -----------------------
    ;;; callback implementation
    ;;; -----------------------

    (defun init (_args)
      `#(ok #(,(sup-flags) (,(child '<%= @app %>-sup 'start_link '())))))

    ;;; -----------------
    ;;; private functions
    ;;; -----------------

    (defun child (mod fun args)
      `#M(id ,mod
          start #(,mod ,fun ,args)
          restart permanent
          shutdown 2000
          type worker
          modules (,mod)))
    """)

  embed_template(:lfe_test,
    """
    (defmodule <%= @app %>-tests
      (behaviour ltest-unit))

    (include-lib "ltest/include/ltest-macros.lfe")

    ;;; -----------
    ;;; library API
    ;;; -----------

    (deftest my-function
      (is-equal 'hellow-orld (<%= @app %>:a-function)))
    """)

end
