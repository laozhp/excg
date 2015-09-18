defmodule Excg.Builder.Yaml do

  def build_fields(excg, align, cfg, data) do
    tab = "  "
    map = cfg.map
    type_map = excg.type_map
    space = String.duplicate(tab, align)
    list = cfg.info[:cli_out] || cfg.list
    for {fld_name, i} <- Enum.with_index(list) do
      %{kind: kind, name: name, type: type} = map[fld_name]
      s_name = to_string(name)
      fld_data = data[fld_name]
      head = if i == 0, do: "", else: space
      cond do
        Excg.basic_type?(type) or type == :virtual ->
          [head, s_name, ": ", inspect(fld_data), "\n"]
        true ->
          type = type_map[type]
          cond do
            kind == :field ->
              [head, s_name, ":\n",
               space, tab, build_fields(excg, align + 1, type, fld_data)]
            fld_data == [] ->
              [head, s_name, ": []\n"]
            true ->
              [head, s_name, ":\n",
               (for data <- fld_data do
                  li = build_fields(excg, align + 2, type, data)
                  [space, tab, "- ", li]
                end)]
          end
      end
    end
  end

end
