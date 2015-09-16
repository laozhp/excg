defmodule Excg.Parser.Schema do

  def parse(excg) do
    excg
    |> load_custom_lib
    |> parse_input_dir
    |> parse_const
    |> parse_error_code
    |> parse_cfg
    |> parse_msg
  end

  defp load_custom_lib(excg) do
    dir = excg.dir
    Path.join(dir, "ebin") |> File.mkdir_p!
    for f <- File.ls!(dir), String.ends_with?(f, ".ex") do
      module_name = load_module(excg, dir, f)
      mod_name = Mix.Utils.camelize(Path.rootname(f))
      if to_string(module_name) != "Elixir." <> mod_name do
        raise "模块名#{mod_name}与文件名#{f}不匹配"
      end
    end
    excg
  end

  defp load_module(excg, dir, file) do
    path = Path.join(dir, file)
    mod = Mix.Utils.camelize(Path.rootname(file))
    beam_file = "Elixir.#{mod}.beam"
    beam_path = Path.join([dir, "ebin", beam_file])
    if (not excg.force) and File.exists?(beam_path) do
      mtime = File.stat!(path).mtime
      beam_mtime = File.stat!(beam_path).mtime
      if beam_mtime < mtime do
        compile_module(beam_path, path, file)
      else
        Mix.shell.info("Loading #{path} ...")
        mod = String.to_atom("Elixir.#{mod}")
        {:module, mod} = :erlang.load_module(mod, File.read!(beam_path))
        mod
      end
    else
      compile_module(beam_path, path, file)
    end
  end

  defp compile_module(beam_path, path, file) do
    Mix.shell.info("Compile #{path} ...")
    string = File.read!(path)
    result = Code.compile_string(string, file)
    [{module_name, byte_code}] = result
    File.write!(beam_path, byte_code)
    module_name
  end

  defp parse_input_dir(excg) do
    dir = excg.dir
    mods = for f <- File.ls!(dir), String.ends_with?(f, ".exs") do
      module_name = load_module(excg, dir, f)
      mod_name = Mix.Utils.camelize(Path.rootname(f))
      if to_string(module_name) != "Elixir." <> mod_name do
        raise "模块名#{mod_name}与文件名#{f}不匹配"
      end
      {mod_name, Path.join(dir, f)}
    end
    {cfg_mods, msg_mods} = Enum.reduce(
      mods, {%{}, %{}},
      fn({mod, src_file}, {c, m}) ->
        cond do
          String.ends_with?(mod, "Cfg") -> {Map.put(c, mod, src_file), m}
          String.ends_with?(mod, "Msg") -> {c, Map.put(m, mod, src_file)}
          :default -> {c, m}
        end
      end)
    %{excg | cfg_mods: cfg_mods, msg_mods: msg_mods}
  end

  defp parse_const(excg) do
    functions = Const.__info__(:functions)
    types = for {name, arity} <- functions, arity == 0, do: name
    types = Enum.sort(types)
    {list, map} = Enum.reduce(
      types, {[], %{}}, fn(type, {list, map}) ->
      def_map = apply(Const, type, [])
      {li, m} = Enum.reduce(
        def_map, {[], %{id_map: %{}, name_map: %{}, desc_map: %{}}},
        fn({name, {id, desc}}, {list, map}) ->
        list = [{id, name, desc} | list]
        m = %{id: id, name: name, desc: desc}
        map =
          map
          |> put_in([:id_map, to_string(id)], m)
          |> put_in([:name_map, to_string(name)], m)
          |> put_in([:desc_map, desc], m)
        {list, map}
      end)
      len = length(li)
      if len != map_size(m.id_map), do: raise "const #{type} id duplicated"
      if len != map_size(m.name_map), do: raise "const #{type} name duplicated"
      if len != map_size(m.desc_map), do: raise "const #{type} desc duplicated"
      {[{type, Enum.sort(li)} | list], Map.put(map, type, m)}
    end)
    list = Enum.reverse(list)
    %{excg | const_types: types, const_list: list, const_map: map}
  end

  defp parse_error_code(excg) do
    functions = ErrorCode.__info__(:functions)
    error_codes = for {name, arity} <- functions, arity == 0 do
      {id, desc} = apply(ErrorCode, name, [])
      {id, name, desc}
    end
    error_codes = Enum.sort(error_codes)
    %{excg | error_codes: error_codes}
  end

  defp parse_cfg(excg) do
    {map, type_map} = Enum.reduce(
      excg.cfg_mods, {%{}, excg.type_map},
      fn({mod, src_file}, {map, type_map}) ->
        ex_mod = String.to_atom("Elixir." <> mod)
        [cfg_name] = apply(ex_mod, :cfgs, [])
        mod_name = Mix.Utils.camelize(to_string(cfg_name))
        if mod_name <> "Cfg" != mod do
          raise "module name not match: #{mod}, #{cfg_name}"
        end
        old_cfg = map[cfg_name]
        if old_cfg do
          raise "config redefined: #{cfg_name}, #{mod}, #{old_cfg.mod}"
        end
        cfg = parse_cls(mod, ex_mod, :config, cfg_name)
        cfg = put_in(cfg, [:info, :src_file], src_file)
        map = Map.put(map, cfg_name, cfg)

        type_map = parse_types(mod, ex_mod, type_map)
        {map, type_map}
      end)
    %{excg | cfg_map: map, type_map: type_map}
  end

  defp parse_msg(excg) do
    {list, map, type_map} = Enum.reduce(
      excg.msg_mods, {[], %{}, excg.type_map},
      fn({mod, src_file}, {list, map, type_map}) ->
        ex_mod = String.to_atom("Elixir." <> mod)
        mod_info = apply(ex_mod, :module, [])
        name = mod_info.name
        mod_name = Mix.Utils.camelize(to_string(name))
        if mod_name <> "Msg" != mod do
          raise "module name not match: #{mod}, #{name}"
        end
        if List.keymember?(list, mod_name, 1) do
          raise "message module redefined: #{mod}"
        end
        msgs = apply(ex_mod, :msgs, [])
        mod_info =
          mod_info
          |> Map.put(:mod_name, mod_name)
          |> Map.put(:msgs, msgs)
          |> Map.put(:src_file, src_file)
        list = [mod_info | list]

        map = Enum.reduce(msgs, map, fn(msg_name, map) ->
          old_msg = map[msg_name]
          if old_msg do
            raise "message redefined: #{msg_name}, #{mod}, #{old_msg.mod}"
          end
          msg = parse_cls(mod, ex_mod, :message, msg_name)
          Map.put(map, msg_name, msg)
        end)

        type_map = parse_types(mod, ex_mod, type_map)
        {list, map, type_map}
      end)
    list = Enum.sort(list, &(&1.id <= &2.id))
    %{excg | msg_mod_infos: list, msg_map: map, type_map: type_map}
  end

  defp parse_types(mod, ex_mod, type_map) do
    types = apply(ex_mod, :types, [])
    Enum.reduce(types, type_map, fn(type_name, type_map) ->
      old_type = type_map[type_name]
      if old_type do
        raise "type redefined: #{type_name}, #{mod}, #{old_type.mod}"
      end
      type = parse_cls(mod, ex_mod, :type, type_name)
      Map.put(type_map, type_name, type)
    end)
  end

  defp parse_cls(mod, ex_mod, cls, name) do
    info = apply(ex_mod, String.to_atom(Enum.join([cls, "_info_", name])), [])
    list = apply(ex_mod, String.to_atom(Enum.join([cls, "_list_", name])), [])
    map = apply(ex_mod, String.to_atom(Enum.join([cls, "_map_", name])), [])
    %{mod: mod, info: info, list: list, map: map}
  end

end
