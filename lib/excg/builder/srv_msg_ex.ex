defmodule Excg.Builder.SrvMsgEx do

  def build(excg, msg_name) do
    msg = excg.msg_map[msg_name]
    id = msg.info.id
    if rem(id, 2) == 1 do
      build_packer(excg, msg_name, msg.list, msg.map)
    else
      build_unpacker(excg, msg_name, msg.list, msg.map)
    end
  end

  def build_def_val(excg, msg_name) do
    msg = excg.msg_map[msg_name]
    list = msg.list
    if list == [] do
      ["  def ", to_string(msg_name), "_body do\n",
       "    %{}\n",
       "  end\n"]
    else
      ["  def ", to_string(msg_name), "_body do\n",
       build_def_val_fields(excg, 2, list, msg.map), "\n",
       "  end\n"]
    end
  end

  defp build_def_val_fields(excg, align, list, map) do
    type_map = excg.type_map
    space = String.duplicate("  ", align)
    last = length(list) - 1
    for {fld_name, i} <- Enum.with_index(list) do
      %{kind: kind, name: name, type: type, opts: opts} = map[fld_name]
      s_name = to_string(name)
      head = if i == 0, do: "%{", else: "  "
      tail = if i == last, do: "}", else: ",\n"
      cond do
        kind == :array ->
          def_val = Keyword.get(opts, :default_items, [])
          [space, head, s_name, ": ", inspect(def_val), tail]
        def_val = Keyword.get(opts, :default) ->
          [space, head, s_name, ": ", inspect(def_val), tail]
        type == :virtual ->
          [space, head, s_name, ": ", inspect(nil), tail]
        Excg.basic_type?(type) ->
          def_val = Excg.type_def_val(type)
          [space, head, s_name, ": ", inspect(def_val), tail]
        true ->
          type = type_map[type]
          [space, head, s_name, ":\n",
           build_def_val_fields(excg, align + 2, type.list, type.map),
           tail]
      end
    end
  end

  defp build_packer(excg, msg_name, list, map) do
    if list == [] do
      ["  defp pack_", to_string(msg_name), "(_body) do\n",
       "    \"\"\n",
       "  end\n"]
    else
      ["  defp pack_", to_string(msg_name), "(body) do\n",
       "    v1 = body\n",
       "    list = [\n",
       build_pkr_fields(excg, 3, 1, list, map),
       "      ]\n",
       "    Msgpax.pack!(list)\n",
       "  end\n"]
    end
  end

  defp build_unpacker(excg, msg_name, list, map) do
    if list == [] do
      ["  defp unpack_", to_string(msg_name), "(_body) do\n",
       "    %{}\n",
       "  end\n"]
    else
      ["  defp unpack_", to_string(msg_name), "(body) do\n",
       "    list = Msgpax.unpack!(body)\n",
       build_upr_fields(excg, 2, 1, "list", list, map),
       "\n",
       "  end\n"]
    end
  end

  defp build_pkr_fields(excg, align, var, list, map) do
    type_map = excg.type_map
    space = String.duplicate("  ", align)
    for fld_name <- list do
      %{kind: kind, name: name, type: type} = map[fld_name]
      s_var = to_string(var)
      s_name = to_string(name)
      if Excg.basic_type?(type) or type == :virtual do
        [space, "v", s_var, ".", s_name, ",\n"]
      else
        type = type_map[type]
        {align1, var1, list1, map1} = {
          align + 1, var + 1, type.list, type.map}
        s_var1 = to_string(var1)
        if kind == :field do
          [space, "(v", s_var1, " = v", s_var, ".", s_name, "; [\n",
           build_pkr_fields(excg, align1, var1, list1, map1),
           space, "  ]),\n"]
        else
          [space, "(for v", s_var1, " <- v", s_var, ".", s_name, ", do: [\n",
           build_pkr_fields(excg, align1, var1, list1, map1),
           space, "  ]),\n"]
        end
      end
    end
  end

  defp build_upr_fields(excg, align, var, lv_name, list, map) do
    type_map = excg.type_map
    space1 = String.duplicate("  ", align + 1)
    li_var = for {_, i} <- Enum.with_index(list), do: var_name(var, i)
    li = for {fld_name, i} <- Enum.with_index(list) do
      %{kind: kind, name: name, type: type} = map[fld_name]
      {s_i, s_var, s_name, s_var_i} = {
        to_string(i), to_string(var), to_string(name), var_name(var, i)}
      space = if i == 0, do: "", else: space1
      if Excg.basic_type?(type) or type == :virtual do
        [space, s_name, ": v", s_var, "_", s_i, ",\n"]
      else
        type = type_map[type]
        {align2, var1, list1, map1} = {
          align + 2, var + 1, type.list, type.map}
        if kind == :field do
          [space, s_name, ": (\n",
           build_upr_fields(excg, align2, var1, s_var_i, list1, map1),
           "),\n"]
        else
          [space, s_name, ":\n",
           space1, "  for ", s_var_i, "i <- ", s_var_i, " do\n",
           build_upr_fields(
             excg, align2 + 1, var1, s_var_i <> "i", list1, map1),
           "\n",
           space1, "  end,\n"]
        end
      end
    end
    space = String.duplicate("  ", align)
    [space, "[", Enum.join(li_var, ",\n#{space} "), "] = ", lv_name, "\n",
     space, "%{", li,
     space, "  }"]
  end

  defp var_name(var, i) do
    "v#{var}_#{i}"
  end

end
