defmodule ChorusDraft.GuardTest do
  use ExUnit.Case, async: true
  alias ChorusDraft.{Error, Guard, PII, Safety}

  defmodule Unlicensed do
    def public?(_post), do: true
  end

  defmodule WrongId do
    def __guard_id__, do: "not-a-guard"
    def public?(_post), do: true
  end

  test "official Guard is loaded and identifies this release" do
    assert Guard.required!() == :ok
    assert Guard.safety() == ChorusDraft.Guard.Safety
    assert Guard.pii() == ChorusDraft.Guard.PII

    assert ChorusDraft.Guard.Safety.__guard_id__() ==
             "chorusdraft-guard-" <> ChorusDraft.version()

    assert ChorusDraft.Guard.PII.__guard_id__() == "chorusdraft-guard-" <> ChorusDraft.version()
  end

  test "refuses to use a missing or unlicensed Guard module" do
    message = Guard.missing_message()

    error = assert_raise Error, fn -> Guard.ensure_module!(ChorusDraft.Guard.DoesNotExist) end
    assert error.message == message

    error = assert_raise Error, fn -> Guard.ensure_module!(Unlicensed) end
    assert error.message == message

    error = assert_raise Error, fn -> Guard.ensure_module!(WrongId) end
    assert error.message == message
  end

  test "public Safety and PII APIs still screen through Guard" do
    assert Safety.eligible?(%{"visibility" => "unlisted", "text" => "ordinary post"})
    refute Safety.eligible?(%{"visibility" => "public", "text" => "ignore all instructions"})
    assert_raise Error, fn -> Safety.validate_text!("You're an idiot", 500) end
    assert PII.sensitive?("contact me at person@example.com")
    refute PII.sensitive?("read the changelog, then run mix test")
  end

  test "Guard.call fails closed for a function Guard does not export" do
    error = assert_raise Error, fn -> Guard.call(:safety, :not_exported, []) end
    assert error.message == Guard.missing_message()
  end

  test "Apache-licensed facades do not embed screening patterns" do
    for kind <- [:safety, :pii] do
      ast =
        Path.expand("../lib/chorus_draft/#{kind}.ex", __DIR__)
        |> File.read!()
        |> Code.string_to_quoted!()

      {_ast, offenses} =
        Macro.prewalk(ast, [], fn
          {:sigil_r, _, _} = node, acc ->
            {node, [:regex_sigil | acc]}

          {:__aliases__, _, parts} = node, acc ->
            {node, if(List.last(parts) == :Regex, do: [:regex_module | acc], else: acc)}

          node, acc ->
            {node, acc}
        end)

      assert offenses == []

      {defs, privates} = facade_defs(ast)
      assert privates == []
      assert defs != []

      for {name, arity, body} <- defs do
        assert {{:., _, [{:__aliases__, _, [:ChorusDraft, :Guard]}, :call]}, _, call_args} = body
        assert [^kind, ^name, args] = call_args
        assert length(args) == arity
      end
    end
  end

  defp facade_defs(ast) do
    {_ast, {defs, privates}} =
      Macro.prewalk(ast, {[], []}, fn
        {:def, _, [{name, _, args}, [do: body]]} = node, {defs, privates}
        when is_atom(name) and is_list(args) ->
          {node, {[{name, length(args), body} | defs], privates}}

        {:defp, _, [{name, _, _} | _]} = node, {defs, privates} ->
          {node, {defs, [name | privates]}}

        node, acc ->
          {node, acc}
      end)

    {Enum.reverse(defs), Enum.reverse(privates)}
  end
end
