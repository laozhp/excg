defmodule Excg.Checker.Data do
  import Excg.Parser.Data, only: [parse_error: 2]
  import Excg.Parser.ExcelXml, only: [header_rows: 0]

  def check(excg) do
    excg
    |> gen_ref_map
    |> gen_ref_map_data
    |> check_all_cfg
  end

  def check_max(excg, opts, data) do
    opt = Keyword.get(opts, :max)
    if opt do
      if is_binary(data) do
        if byte_size(data) > opt do
          parse_error(excg, "#{inspect data}的字节长度大于最大值#{opt}")
        end
      else
        if data > opt do
          parse_error(excg, "#{inspect data}大于最大值#{opt}")
        end
      end
    end
  end

  def check_min(excg, opts, data) do
    opt = Keyword.get(opts, :min)
    if opt do
      if is_binary(data) do
        if byte_size(data) < opt do
          parse_error(excg, "#{inspect data}的字节长度小于最小值#{opt}")
        end
      else
        if data < opt do
          parse_error(excg, "#{inspect data}小于最小值#{opt}")
        end
      end
    end
  end

  def check_max_len(excg, opts, data) do
    opt = Keyword.get(opts, :max_len)
    if opt do
      if String.length(data) > opt do
        parse_error(excg, "#{inspect data}的字符长度大于最大值#{opt}")
      end
    end
  end

  def check_min_len(excg, opts, data) do
    opt = Keyword.get(opts, :min_len)
    if opt do
      if String.length(data) < opt do
        parse_error(excg, "#{inspect data}的字符长度小于最小值#{opt}")
      end
    end
  end

  def check_max_items(excg, opts, data) do
    opt = Keyword.get(opts, :max_items)
    if opt do
      if length(data) > opt do
        parse_error(excg, "#{inspect data}的数组长度大于最大值#{opt}")
      end
    end
  end

  def check_min_items(excg, opts, data) do
    opt = Keyword.get(opts, :min_items)
    if opt do
      if length(data) < opt do
        parse_error(excg, "#{inspect data}的数组长度小于最小值#{opt}")
      end
    end
  end

  def check_order_items(excg, opts, data) do
    opt = Keyword.get(opts, :order_items)
    if opt do
      is_asc = opt == :asc
      Enum.reduce(data, fn(v, acc) ->
        cond do
          is_asc and acc > v ->
            parse_error(excg, "#{inspect acc}, #{inspect v}没有按照升序排列")
          not is_asc and acc < v ->
            parse_error(excg, "#{inspect acc}, #{inspect v}没有按照降序排列")
          true -> v
        end
      end)
    end
  end

  def check_seq_items(excg, opts, data) do
    opt = Keyword.get(opts, :seq_items)
    if opt do
      Enum.reduce(data, opt, fn(v, {start, step}) ->
        if v != start do
          parse_error(excg, "序列#{inspect opt}：当前值#{v}应为#{start}")
        end
        {v + step, step}
      end)
    end
  end

  def check_unique_items(excg, opts, data) do
    opt = Keyword.get(opts, :unique_items)
    if opt do
      Enum.reduce(data, %{}, fn(item, map) ->
        if map[item] do
          parse_error(excg, "数组元素重复#{inspect item}")
        end
        Map.put(map, item, true)
      end)
    end
  end

  defp gen_ref_map(excg) do
    new_ref = %{pk_map: %{}, name_map: %{}}
    map = Enum.reduce(excg.cfg_map, %{}, fn({_, cfg}, map) ->
      Enum.reduce(cfg.map, map, fn({_, fld}, map) ->
        ref = Keyword.get(fld.opts, :refrence)
        if ref, do: Map.put(map, ref, new_ref), else: map
      end)
    end)
    map = Enum.reduce(excg.type_map, map, fn({_, type}, map) ->
      Enum.reduce(type.map, map, fn({_, fld}, map) ->
        ref = Keyword.get(fld.opts, :refrence)
        if ref, do: Map.put(map, ref, new_ref), else: map
      end)
    end)
    %{excg | ref_map: map}
  end

  defp gen_ref_map_data(excg) do
    map = Enum.reduce(excg.ref_map, %{}, fn({ref, map}, acc) ->
      cfg = excg.cfg_map[ref]
      pk = cfg.info.pri_key
      rows = excg.data_map[ref]
      map = Enum.reduce(rows, map, fn(row, map) ->
        row_pk = row[pk]
        row_name = row.name
        map
        |> put_in([:pk_map, to_string(row_pk)], row_pk)
        |> put_in([:name_map, row_name], row_pk)
      end)
      Map.put(acc, ref, map)
    end)
    %{excg | ref_map: map}
  end

  defp check_all_cfg(excg) do
    data_map = Enum.reduce(
      excg.cfg_map, excg.data_map,
      fn({cfg_name, cfg}, data_map) ->
        rows = data_map[cfg_name]
        rows = if rows != [] do
          check_cfg(excg, cfg, rows)
        else
          rows
        end
        Map.put(data_map, cfg_name, rows)
      end)
    %{excg | data_map: data_map}
  end

  defp check_cfg(excg, cfg, rows) do
    excg = %{excg | cfg: cfg, cfg_name: cfg.info.name,
                    filename: Excg.cfg_xml_file(cfg.info)}
    rows = Enum.reduce(cfg.map, rows, fn({_fld_name, fld}, rows) ->
      if fld.need_check do
        check_cfg_fld(excg, fld, rows)
      else
        rows
      end
    end)
    cfun = Keyword.get(cfg.info.opts, :cfun)
    if cfun do
      {fun_name, fun_opts} = cfun
      apply(Cfun, fun_name, [excg, rows, fun_opts])
    else
      rows
    end
  end

  defp check_cfg_fld(excg, fld, rows) do
    fld_type = fld.type
    excg = %{excg | fld_i: fld.index, fld_path: [fld.desc]}
    rows = unless Excg.basic_type?(fld_type) or fld_type == :virtual do
      check_cfg_fld_type(excg, fld, rows)
    else
      rows
    end
    opts = fld.opts
    rows = if fld_type == :string && Keyword.get(opts, :eex) do
      eval_eex_tpl(excg, fld, rows)
    else
      rows
    end
    if Keyword.get(opts, :pri_key) || Keyword.get(opts, :unique) do
      check_unique(excg, fld, rows)
    end
    rows = if Keyword.get(opts, :order) do
      check_cfg_fld_order(excg, fld, rows)
    else
      rows
    end
    rows = if Keyword.get(opts, :sequence) do
      if fld_type == :virtual do
        build_cfg_fld_sequence(excg, fld, rows)
      else
        check_cfg_fld_sequence(excg, fld, rows)
      end
    else
      rows
    end
    ref_name = Keyword.get(opts, :refrence)
    excg = if ref_name do
      ref = excg.ref_map[ref_name]
      %{excg | ref: ref, ref_name: ref_name}
    else
      excg
    end
    cfun = Keyword.get(opts, :cfun)
    cond do
      cfun -> check_cfg_fld_cfun(excg, fld, cfun, rows)
      ref_name -> check_cfg_fld_refrence(excg, fld, rows)
      true -> rows
    end
  end

  defp check_cfg_fld_type(excg, fld, rows) do
    header_rows = header_rows
    fld_name = fld.name
    type = excg.type_map[fld.type]
    for {row, i} <- Enum.with_index(rows) do
      excg = %{excg | row_data: row, row_i: header_rows + i}
      if fld.kind == :field do
        Map.update!(row, fld_name, &check_type(excg, type, &1))
      else
        v = for item <- row[fld_name] do
          check_type(excg, type, item)
        end
        Map.put(row, fld_name, v)
      end
    end
  end

  defp check_cfg_fld_cfun(excg, fld, cfun, rows) do
    header_rows = header_rows
    fld_name = fld.name
    {fun_name, fun_opts} = cfun
    for {row, i} <- Enum.with_index(rows) do
      excg = %{excg | row_data: row, row_i: header_rows + i}
      data = row[fld_name]
      data = apply(Cfun, fun_name, [excg, data, fun_opts])
      Map.put(row, fld_name, data)
    end
  end

  defp check_cfg_fld_order(excg, fld, rows) do
    header_rows = header_rows
    fld_name = fld.name
    is_asc = Keyword.get(fld.opts, :order) == :asc
    Enum.reduce(Enum.with_index(rows), hd(rows)[fld_name], fn({row, i}, acc) ->
      excg = %{excg | row_i: header_rows + i}
      v = row[fld_name]
      cond do
        is_asc and acc > v ->
          parse_error(excg, "#{inspect acc}, #{inspect v}没有按照升序排列")
        (not is_asc) and acc < v ->
          parse_error(excg, "#{inspect acc}, #{inspect v}没有按照降序排列")
        true -> v
      end
    end)
    rows
  end

  defp build_cfg_fld_sequence(_excg, fld, rows) do
    fld_name = fld.name
    {start, step} = Keyword.get(fld.opts, :sequence)
    {_start, _step, rows} = Enum.reduce(
      rows, {start, step, []},
      fn(row, {start, step, rows}) ->
        row = Map.put(row, fld_name, start)
        {start + step, step, [row | rows]}
      end)
    Enum.reverse(rows)
  end

  defp check_cfg_fld_sequence(excg, fld, rows) do
    header_rows = header_rows
    fld_name = fld.name
    opt = Keyword.get(fld.opts, :sequence)
    Enum.reduce(Enum.with_index(rows), opt, fn({row, i}, {start, step}) ->
      excg = %{excg | row_i: header_rows + i}
      v = row[fld_name]
      if v != start do
        parse_error(excg, "序列#{inspect opt}：当前值#{v}应为#{start}")
      end
      {v + step, step}
    end)
    rows
  end

  defp check_cfg_fld_refrence(excg, fld, rows) do
    header_rows = header_rows
    fld_name = fld.name
    for {row, i} <- Enum.with_index(rows) do
      excg = %{excg | row_i: header_rows + i}
      Map.update!(row, fld_name, &check_refrence(excg, &1))
    end
  end

  defp check_type(excg, type, data) do
    data = Enum.reduce(type.map, data, fn({fld_name, fld}, data) ->
      fld_data = data[fld_name]
      fld_data = check_type_fld(excg, fld, fld_data)
      Map.put(data, fld_name, fld_data)
    end)
    cfun = Keyword.get(type.info.opts, :cfun)
    if cfun do
      {fun_name, fun_opts} = cfun
      apply(Cfun, fun_name, [excg, data, fun_opts])
    else
      data
    end
  end

  defp check_type_fld(excg, fld, data) do
    excg = %{excg | fld_path: [fld.desc | excg.fld_path]}
    fld_type = fld.type
    data = unless Excg.basic_type?(fld_type) or fld_type == :virtual do
      type = excg.type_map[fld_type]
      if fld.kind == :field do
        check_type(excg, type, data)
      else
        for item <- data do
          check_type(excg, type, item)
        end
      end
    else
      data
    end
    opts = fld.opts
    ref_name = Keyword.get(opts, :refrence)
    excg = if ref_name do
      ref = excg.ref_map[ref_name]
      %{excg | ref: ref, ref_name: ref_name}
    else
      excg
    end
    cfun = Keyword.get(opts, :cfun)
    cond do
      cfun ->
        {fun_name, fun_opts} = cfun
        apply(Cfun, fun_name, [excg, data, fun_opts])
      ref_name -> check_refrence(excg, data)
      true -> data
    end
  end

  defp check_unique(excg, fld, rows) do
    fld_name = fld.name
    Enum.reduce(rows, %{}, fn(row, map) ->
      v = row[fld_name]
      if map[v] do
        raise "配置：#{excg.cfg.info.name}，字段：#{fld_name}，" <>
              "数据不唯一：#{inspect v}"
      end
      Map.put(map, v, 1)
    end)
  end

  defp check_refrence(excg, data) do
    cond do
      v = excg.ref.pk_map[data] -> v
      v = excg.ref.name_map[data] -> v
      true -> parse_error(excg, "在#{excg.ref_name}里找不到引用#{data}")
    end
  end

  defp eval_eex_tpl(_excg, fld, rows) do
    fld_name = fld.name
    if fld.kind == :field do
      for row <- rows do
        Map.update!(row, fld_name, &EEx.eval_string(&1, assigns: row))
      end
    else
      for row <- rows do
        fld_data = for data <- row[fld_name] do
          EEx.eval_string(data, assigns: row)
        end
        Map.put(row, fld_name, fld_data)
      end
    end
  end

end
