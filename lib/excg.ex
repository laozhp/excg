defmodule Excg do

  defmacro __using__(_) do
    quote do
      import Excg
      @excg_cur nil
      for attr <- [:excg_flds, :excg_types, :excg_cfgs, :excg_msgs] do
        Module.register_attribute(__MODULE__, attr, accumulate: true)
      end
      @before_compile unquote(__MODULE__)
    end
  end

  defmacro __before_compile__(env) do
    flds  = Module.get_attribute(env.module, :excg_flds)
    types = Enum.reverse(Module.get_attribute(env.module, :excg_types))
    cfgs  = Enum.reverse(Module.get_attribute(env.module, :excg_cfgs))
    msgs  = Enum.reverse(Module.get_attribute(env.module, :excg_msgs))
    if length(cfgs) > 1, do: raise "一个文件只能使用一个config"
    if cfgs != [] and msgs != [] do
      raise "一个文件不能同时使用config和message"
    end
    map = reduce_flds(flds)
    [gen_types(map, types), gen_cfgs(map, cfgs), gen_msgs(map, msgs)]
  end

  defmacro field(name, desc, type, opts \\ []) do
    quote bind_quoted: [name: name, desc: desc, type: type, opts: opts] do
      cls_name = Module.get_attribute(__MODULE__, :excg_cur)
      Module.put_attribute(__MODULE__, :excg_flds, {cls_name, %{
        kind: :field, name: name, desc: desc, type: type, opts: opts}})
    end
  end

  defmacro array(name, desc, type, opts \\ []) do
    quote bind_quoted: [name: name, desc: desc, type: type, opts: opts] do
      cls_name = Module.get_attribute(__MODULE__, :excg_cur)
      Module.put_attribute(__MODULE__, :excg_flds, {cls_name, %{
        kind: :array, name: name, desc: desc, type: type, opts: opts}})
    end
  end

  defmacro type(name, desc, opts \\ [], [do: block]) do
    quote do
      name = unquote(name)
      desc = unquote(desc)
      opts = unquote(opts)
      Module.put_attribute(__MODULE__, :excg_cur, {:type, name})
      list = Module.get_attribute(__MODULE__, :excg_types)
      if List.keymember?(list, name, 0), do: raise "duplicated type #{name}"
      Module.put_attribute(__MODULE__, :excg_types, %{
        name: name, desc: desc, opts: opts})
      unquote(block)
    end
  end

  defmacro config(name, desc, opts \\ [], [do: block]) do
    quote do
      unless String.ends_with?(to_string(__MODULE__), "Cfg") do
        raise "config只能在后缀为Cfg的模块内使用"
      end
      name = unquote(name)
      desc = unquote(desc)
      opts = unquote(opts)
      Module.put_attribute(__MODULE__, :excg_cur, {:config, name})
      list = Module.get_attribute(__MODULE__, :excg_cfgs)
      if List.keymember?(list, name, 0), do: raise "duplicated config #{name}"
      Module.put_attribute(__MODULE__, :excg_cfgs, %{
        name: name, desc: desc, opts: opts})
      unquote(block)
    end
  end

  defmacro message(id, name, desc, opts \\ [], [do: block]) do
    quote do
      unless String.ends_with?(to_string(__MODULE__), "Msg") do
        raise "message只能在后缀为Msg的模块内使用"
      end
      id = unquote(id)
      name = unquote(name)
      desc = unquote(desc)
      opts = unquote(opts)
      Module.put_attribute(__MODULE__, :excg_cur, {:message, name})
      list = Module.get_attribute(__MODULE__, :excg_msgs)
      if List.keymember?(list, name, 0), do: raise "duplicated message #{name}"
      Module.put_attribute(__MODULE__, :excg_msgs, %{
        id: id, name: name, desc: desc, opts: opts})
      unquote(block)
    end
  end

  defmacro module(id, name, desc, opts \\ []) do
    quote do
      def module do
        %{id: unquote(id), name: unquote(name),
          desc: unquote(desc), opts: unquote(opts)}
      end
    end
  end

  def basic_type?(type) do
    type in [:boolean, :float, :integer, :string]
  end

  def type_def_val(:boolean), do: false
  def type_def_val(:float),   do: 0.0
  def type_def_val(:integer), do: 0
  def type_def_val(:string),  do: ""

  def cfg_xml_file(cfg_info) do
    Keyword.get(cfg_info.opts, :xml_file, "#{cfg_info.name}.xml")
  end

  defp reduce_flds(flds) do
    map = %{flds_map: %{}, name_map: %{}}
    Enum.reduce(flds, map, fn({cls_name, fld}, map) ->
      field_list = Map.get(map.flds_map, cls_name, [])
      name_map = Map.get(map.name_map, cls_name, %{})
      fld_name = fld.name
      if name_map[fld_name], do: raise "duplicated field #{fld_name}"
      map
      |> put_in([:flds_map, cls_name], [fld_name | field_list])
      |> put_in([:name_map, cls_name], Map.put(name_map, fld_name, fld))
    end)
  end

  defp gen_types(map, types) do
    list = for type <- types, do: type.name
    q = quote do
      def types, do: unquote(list)
    end
    Enum.reduce(types, [q], fn(type, acc) ->
      %{name: name, desc: desc, opts: opts} = type
      cls_name = {:type, name}
      field_list = map.flds_map[cls_name]
      unless field_list, do: raise "type #{name} has no field"
      name_map = map.name_map[cls_name]
      q = quote do
        def unquote(:"type_info_#{name}")(), do:
          %{name: unquote(name), desc: unquote(desc), opts: unquote(opts)}
        def unquote(:"type_list_#{name}")(), do:
          unquote(field_list)
        def unquote(:"type_map_#{name}")(), do:
          unquote(Macro.escape(name_map))
      end
      [q | acc]
    end)
  end

  defp gen_cfgs(map, cfgs) do
    list = for cfg <- cfgs, do: cfg.name
    q = quote do
      def cfgs, do: unquote(list)
    end
    Enum.reduce(cfgs, [q], fn(cfg, acc) ->
      %{name: name, desc: desc, opts: opts} = cfg
      cls_name = {:config, name}
      field_list = map.flds_map[cls_name]
      unless field_list, do: raise "config #{name} has no field"
      name_map = map.name_map[cls_name]
      q = quote do
        def unquote(:"config_info_#{name}")(), do:
          %{name: unquote(name), desc: unquote(desc), opts: unquote(opts)}
        def unquote(:"config_list_#{name}")(), do:
          unquote(field_list)
        def unquote(:"config_map_#{name}")(), do:
          unquote(Macro.escape(name_map))
      end
      [q | acc]
    end)
  end

  defp gen_msgs(map, msgs) do
    list = for msg <- msgs, do: msg.name
    q = quote do
      def msgs, do: unquote(list)
    end
    Enum.reduce(msgs, [q], fn(msg, acc) ->
      %{id: id, name: name, desc: desc, opts: opts} = msg
      cls_name = {:message, name}
      field_list = map.flds_map[cls_name] || []
      name_map = map.name_map[cls_name] || %{}
      q = quote do
        def unquote(:"message_info_#{name}")(), do:
          %{id: unquote(id), name: unquote(name),
            desc: unquote(desc), opts: unquote(opts)}
        def unquote(:"message_list_#{name}")(), do:
          unquote(field_list)
        def unquote(:"message_map_#{name}")(), do:
          unquote(Macro.escape(name_map))
      end
      [q | acc]
    end)
  end

end
