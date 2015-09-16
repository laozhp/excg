defmodule Excg.Parser.JsonCut do

  def parse(string) do
    parse_char_list(String.to_char_list(string))
  end

  def parse_char_list(char_list) do
    case :json_cut_lexer.string(char_list) do
      {:ok, [], _line} -> {:ok, ""}
      {:ok, tokens, _line} ->
        case :json_cut_parser.parse(tokens) do
          {:ok, parsed} -> {:ok, parsed}
          {:error, {_error_line, module, reason}} ->
            {:error, apply(module, :format_error, [reason])}
        end
      {:error, {_error_line, module, reason}, _line} ->
        {:error, apply(module, :format_error, [reason])}
    end
  end

end
