defmodule Excg.Parser.ExcelXml do
  import SweetXml
  alias Excg.Parser.Data

  @header_rows 6

  def header_rows, do: @header_rows

  def parse(excg) do
    filename = Path.join(excg.xml_dir, excg.filename)
    unless File.exists?(filename) do
      raise "file #{excg.filename} not found, try: mix excg.xml"
    end
    doc = File.read!(filename)
    rows = doc |> xpath(~x"/Workbook/Worksheet/Table/Row"l)
    excg = excg |> parse_fld_names(hd(rows))
    body_rows = Enum.slice(rows, @header_rows..-1)
    data = for {row, row_i} <- Enum.with_index(body_rows) do
      parse_row(excg, row, row_i + @header_rows)
    end
    data_map = Map.put(excg.data_map, excg.cfg_name, data)
    %{excg | data_map: data_map}
  end

  defp parse_fld_names(excg, row) do
    map = excg.cfg.map
    {_index, list} = Enum.reduce(
      xpath(row, ~x"Cell"l), {0, []},
      fn(cell, {index, list}) ->
        ss_index = xpath(cell, ~x"@ss:Index")
        if ss_index do
          count = List.to_integer(ss_index) - index - 1
          index = index + count
          list = List.duplicate(nil, count) ++ list
        end
        data = xpath(cell, ~x"Data/text()")
        field = if data, do: List.to_atom(data), else: nil
        unless map[field], do: field = nil
        {index + 1, [field | list]}
      end)
    list = Enum.reverse(list)
    map = Enum.reduce(map, %{}, fn({fld_name, fld}, map) ->
      if fld.type == :virtual do
        fld = Map.put(fld, :index, -1)
        Map.put(map, fld_name, fld)
      else
        index = Enum.find_index(list, &(&1 == fld_name))
        if index do
          fld = Map.put(fld, :index, index)
          Map.put(map, fld_name, fld)
        else
          raise "field #{fld_name} not found in #{excg.filename}"
        end
      end
    end)
    cfg = %{excg.cfg | map: map}
    cfg_map = Map.put(excg.cfg_map, cfg.info.name, cfg)
    %{excg | cfg: cfg, cfg_map: cfg_map, fld_names: List.to_tuple(list)}
  end

  defp parse_row(excg, row, row_i) do
    {index, map} = Enum.reduce(
      xpath(row, ~x"Cell"l), {0, %{}},
      fn(cell, {index, map}) ->
        ss_index = xpath(cell, ~x"@ss:Index")
        if ss_index do
          count = List.to_integer(ss_index) - index - 1
          if count > 0 do
            {index, map} = parse_empty_cells(excg, count, row_i, index, map)
          end
        end
        map = parse_cell(excg, cell, row_i, index, map)
        {index + 1, map}
      end)
    count = tuple_size(excg.fld_names) - index
    if count > 0 do
      {_index, map} = parse_empty_cells(excg, count, row_i, index, map)
    end
    map
  end

  defp parse_empty_cells(excg, count, row_i, index, map) do
    Enum.reduce(1..count, {index, map},
      fn(_i, {index, map}) ->
        map = parse_cell(excg, nil, row_i, index, map)
        {index + 1, map}
      end)
  end

  defp parse_cell(excg, cell, row_i, fld_i, map) do
    fld_name = get_fld_name(excg.fld_names, fld_i)
    if fld_name do
      fld = excg.cfg.map[fld_name]
      data = if cell do
        xpath(cell, ~x"Data/text()"l)
      else
        []
      end
      Data.parse_cell(excg, fld, data, row_i, fld_i, map)
    else
      map
    end
  end

  defp get_fld_name(tuple, index) do
    if index < tuple_size(tuple) do
      elem(tuple, index)
    else
      nil
    end
  end

end
