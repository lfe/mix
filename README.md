# Mix LFE Compiler

A very simple Mix task that compiles LFE (lisp (flavoured (erlang))).

It is a Mix compiler which uses the Erlang Mix compiler.

Lisp is a great language to get into the functional way of thinking and LFE is Lisp 2+ which runs on the greatest platform (personal opinion).
Elixir's Mix is a great (or the greatest) configuration/package/build manager, so why not use it to compile LFE?
Also Elixir developers should try LFE! This little project has the purpose to make that easier.

## Installation and setup

First you must have a mix project setup:

```
mix new <project_name>
```

You can then add `mix_lfe` to your project dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:mix_lfe, github: "lfe/mix", branch: "master", only: [:dev, :test], runtime: false}
  ]
```

## Compilation

Compiling `*.lfe` sources, located in the `src` folder can be done with:

```
mix compile
```

To use the compiled modules with the LFE REPL, you can run:

```
mix lfe
```

The compiled LFE modules can be used from Elixir too:

```
iex -S mix
```

Now the modules will be accessible just like Erlang modules are accessible in Elixir.

## Running tests

The compiler can compile and run [ltest](https://github.com/lfex/ltest) tests.
Just put all the tests in the `test` folder of the project and run:

```
mix lfe.test
```

Works with umbrella applications, meaning that some of applications in the umbrella can be LFE ones.

## Example projects

A list of projects created with `mix_lfe`. More to come.

* [Echo](https://github.com/meddle0x53/echo) is an example LFE OTP application, created with an outdated version of mix_lfe.

## TODO

The tests of this project mirror the ones for the Erlang Mix compiler.
For now the source is very simple and uses  an [idea](https://github.com/elixir-lang/elixir/blob/e1c903a5956e4cb9075f0aac00638145788b0da4/lib/mix/lib/mix/compilers/erlang.ex#L20) from the Erlang Mix compiler.
All works well, but requires some manual work and doesn't support LFE compiler fine tuning, so that's what we'll be after next.

1. Pass more options to the LFE compiler, using mix configuration.
2. More and more examples.
3. Add CI to this project.
4. Make it possible to add options when running `mix lfe.test`.
5. Run ltest tests from exunit or possibly vice versa.
6. Figure out how to use Elixir macros from LFE and vice versa.

## License

Same as Elixir.
