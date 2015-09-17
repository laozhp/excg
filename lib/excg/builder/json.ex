defmodule Excg.Builder.Json do

  def build_fields(excg, align, cfg, data) do
    tab = "  "
    map = cfg.map
    type_map = excg.type_map
    space = String.duplicate(tab, align)
    list = cfg.info[:cli_out] || cfg.list
    last = length(list) - 1
    for {fld_name, i} <- Enum.with_index(list) do
      %{kind: kind, name: name, type: type, opts: opts} = map[fld_name]
      s_name = to_string(name)
      is_tuple = Keyword.get(opts, :ext_type) == :tuple
      {arr_b, arr_e} = {"[", "]"}
      fld_data = data[fld_name]
      head = if i == 0, do: ["{\n", space, tab], else: [space, tab]
      tail = if i == last, do: ["\n", space, "}"], else: ",\n"
      cond do
        is_tuple ->
          tuple_data = Enum.join(Enum.map(fld_data, &inspect/1), ", ")
          [head, "\"", s_name, "\": ", arr_b, tuple_data, arr_e, tail]
        Excg.basic_type?(type) or type == :virtual ->
          [head, "\"", s_name, "\": ", inspect(fld_data), tail]
        true ->
          type = type_map[type]
          cond do
            kind == :field ->
              [head, "\"", s_name, "\": ",
               build_fields(excg, align + 1, type, fld_data),
               tail]
            fld_data == [] ->
              [head, "\"", s_name, "\": ", arr_b, arr_e, tail]
            true ->
              j_last = length(fld_data) - 1
              [head, "\"", s_name, "\": ", arr_b, "\n",
               (for {data, j} <- Enum.with_index(fld_data) do
                  li = build_fields(excg, align + 2, type, data)
                  [space, tab, tab, li, (if j == j_last, do: "", else: ",\n")]
                end), "\n",
               space, tab, arr_e, tail]
          end
      end
    end
  end

end
