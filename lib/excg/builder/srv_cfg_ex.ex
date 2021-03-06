defmodule Excg.Builder.SrvCfgEx do

  def build_fields(excg, align, cfg, data) do
    map = cfg.map
    type_map = excg.type_map
    space = String.duplicate("  ", align)
    list = cfg.info[:srv_out] || cfg.list
    last = length(list) - 1
    for {fld_name, i} <- Enum.with_index(list) do
      %{kind: kind, name: name, type: type, opts: opts} = map[fld_name]
      s_name = to_string(name)
      is_tuple = Keyword.get(opts, :ext_type) == :tuple
      {arr_b, arr_e} = if is_tuple, do: {"{", "}"}, else: {"[", "]"}
      fld_data = data[fld_name]
      head = if i == 0, do: "%{", else: "  "
      tail = if i == last, do: "}", else: ",\n"
      cond do
        is_tuple ->
          tuple_data = Enum.join(Enum.map(fld_data, &inspect/1), ", ")
          [space, head, s_name, ": ", arr_b, tuple_data, arr_e, tail]
        Excg.basic_type?(type) or type == :virtual ->
          [space, head, s_name, ": ", inspect(fld_data), tail]
        true ->
          type = type_map[type]
          cond do
            kind == :field ->
              [space, head, s_name, ":\n",
               build_fields(excg, align + 2, type, fld_data),
               tail]
            fld_data == [] ->
              [space, head, s_name, ": ", arr_b, arr_e, tail]
            true ->
              j_last = length(fld_data) - 1
              [space, head, s_name, ": ", arr_b, "\n",
               (for {data, j} <- Enum.with_index(fld_data) do
                  li = build_fields(excg, align + 2, type, data)
                  [li, (if j == j_last, do: "", else: ",\n")]
                end),
               arr_e, tail]
          end
      end
    end
  end

  def build_keys(_excg, align, cfg, data) do
    pri_key = cfg.info.pri_key
    space = String.duplicate("  ", align)
    last = length(data) - 1
    for {row, i} <- Enum.with_index(data) do
      head = if i == 0, do: "[", else: " "
      tail = if i == last, do: "]", else: ",\n"
      [space, head, inspect(row[pri_key]), tail]
    end
  end

end
