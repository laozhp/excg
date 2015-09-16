defmodule Excg.Parser.Data do
  alias Excg.Parser.ExcelXml
  alias Excg.Parser.JsonCut

  def parse(excg) do
    Enum.reduce(excg.cfg_map, excg, fn({cfg_name, cfg}, excg) ->
      excg
      |> Map.put(:cfg, cfg)
      |> Map.put(:cfg_name, cfg_name)
      |> Map.put(:filename, Excg.cfg_xml_file(cfg.info))
      |> ExcelXml.parse
    end)
  end

  def parse_cell(excg, fld, data, row_i, fld_i, acc_map) do
    excg = %{excg | row_i: row_i, fld_i: fld_i, fld_path: []}
    data = case JsonCut.parse_char_list(List.flatten(data)) do
      {:ok, data} -> parse_data(excg, fld, data)
      {:error, reason} -> parse_error(excg, reason)
    end
    Map.put(acc_map, fld.name, data)
  end

  def parse_const(excg, map, data) do
    if is_integer(data) do
      unless map.id_map[data], do: parse_error(excg, "找不到常量：#{data}")
      data
    else
      cond do
        m = map.desc_map[data] -> m.id
        m = map.name_map[data] -> m.id
        m = map.id_map[data] -> m.id
        true -> parse_error(excg, "找不到常量：#{data}")
      end
    end
  end

  def parse_error(excg, reason) do
    raise format_error(excg, reason)
  end

  def format_error(excg, reason) do
    cell = "[cell: #{cell_name(excg.row_i, excg.fld_i)}]"
    field = "[field: #{format_fld_path(excg)}]"
    "#{excg.filename} #{cell} #{field} error: #{reason}"
  end

  defp format_fld_path(excg) do
    Enum.join(Enum.reverse(excg.fld_path), ".")
  end

  defp cell_name(row_i, fld_i) do
    "#{i2az(fld_i)}#{row_i + 1}"
  end

  defp i2az(i, li \\ []) do
    q = div(i, 26)
    r = rem(i, 26)
    li = [?A + r | li]
    if q > 0 do
      i2az(q - 1, li)
    else
      li
    end
  end

  defp parse_data(excg, fld, data) do
    excg = %{excg | fld_path: [fld.desc | excg.fld_path]}
    if fld.kind == :field do
      parse_field(excg, fld, data)
    else
      parse_array(excg, fld, data)
    end
  end

  defp parse_field(excg, fld, data) do
    %{name: name, type: type, opts: opts} = fld
    const = Keyword.get(opts, :const)
    ref = Keyword.get(opts, :refrence)

    data = if data == "" do
      if Keyword.get(opts, :required, true) do
        parse_error(excg, "字段#{name}不能为空")
      end
      Keyword.get(opts, :default, Excg.type_def_val(type))
    else
      case type do
        :boolean -> parse_boolean(data)
        :float   -> String.to_float(data)
        :integer -> if const || ref, do: data, else: String.to_integer(data)
        :string  -> data
        _ -> parse_type(excg, excg.type_map[type], data)
      end
    end

    if const, do: data = parse_const(excg, excg.const_map[const], data)
    Excg.Checker.Data.check_max(excg, opts, data)
    Excg.Checker.Data.check_min(excg, opts, data)
    Excg.Checker.Data.check_max_len(excg, opts, data)
    Excg.Checker.Data.check_min_len(excg, opts, data)
    data
  end

  defp parse_array(excg, fld, data) do
    %{name: name, opts: opts} = fld
    data = if data == "" do
      if Keyword.get(opts, :required, true) do
        parse_error(excg, "字段#{name}不能为空")
      end
      val = Keyword.get(opts, :default_items, [])
      if val != [] do
        const = Keyword.get(opts, :const)
        if const do
          map = excg.const_map[const]
          val = for item <- val, do: parse_const(excg, map, item)
        end
      end
      val
    else
      for item <- data do
        parse_field(excg, fld, item)
      end
    end

    Excg.Checker.Data.check_max_items(excg, opts, data)
    Excg.Checker.Data.check_min_items(excg, opts, data)
    Excg.Checker.Data.check_order_items(excg, opts, data)
    Excg.Checker.Data.check_seq_items(excg, opts, data)
    Excg.Checker.Data.check_unique_items(excg, opts, data)
    data
  end

  defp parse_type(excg, type, data) do
    list = type.list
    data_size = tuple_size(data)
    if data_size > length(list) do
      parse_error(excg, "#{type.info.desc}有多余的数据")
    end
    map = type.map
    list = Enum.filter(list, fn(fld_name) ->
      map[fld_name].type != :virtual
    end)
    Enum.reduce(Enum.with_index(list), %{}, fn({fld_name, i}, acc) ->
      fld = map[fld_name]
      sub_data = if i >= data_size, do: "", else: elem(data, i)
      parsed = parse_data(excg, fld, sub_data)
      Map.put(acc, fld.name, parsed)
    end)
  end

  defp parse_boolean("true"),  do: true
  defp parse_boolean("false"), do: false
  defp parse_boolean("T"),     do: true
  defp parse_boolean("F"),     do: false
  defp parse_boolean("1"),     do: true
  defp parse_boolean("0"),     do: false

end
