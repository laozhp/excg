defmodule Excg.Checker.Schema do

  def check(excg) do
    excg
    |> check_cfg_pri_key  # set cfg.info.pri_key
    |> check_type  # set type.info.need_check
    |> check_cfg  # set cfg.info.cli_out/srv_out, fld.need_check
  end

  defp check_type(excg) do
    map = Enum.reduce(excg.type_map, %{}, fn({type_name, type}, map) ->
      type = put_in(type, [:info, :need_check], false)
      type = check_type_opts(excg, type)
      type = Enum.reduce(type.map, type, fn({_fld_name, fld}, type) ->
        check_type_fld(excg, type, fld)
      end)
      Map.put(map, type_name, type)
    end)
    dep_map = build_type_dep(map)
    map = fix_type_need_check(map, dep_map)
    %{excg | type_map: map}
  end

  defp build_type_dep(map) do
    Enum.reduce(map, %{}, fn({type_name, type}, map) ->
      dep = Enum.reduce(type.map, %{}, fn({_fld_name, fld}, dep) ->
        fld_type = fld.type
        if Excg.basic_type?(fld_type) do
          dep
        else
          Map.put(dep, fld_type, 1)
        end
      end)
      if dep == %{} do
        Map.put(map, type_name, type.info.need_check)
      else
        Map.put(map, type_name, dep)
      end
    end)
  end

  defp fix_type_need_check(map, dep_map) do
    {map, dep_map, changed, sure} = Enum.reduce(
      map, {map, dep_map, false, true},
      fn({type_name, type}, {map, dep_map, changed, sure}) ->
        dep = dep_map[type_name]
        if is_map(dep) do
          result = Enum.reduce(
            dep, type.info.need_check,
            fn({dep_type, _}, acc) ->
              case acc do
                nil -> nil
                true -> true
                false ->
                  case dep_map[dep_type] do
                    true -> true
                    false -> false
                    _ -> nil
                  end
              end
            end)
          if result == nil do
            {map, dep_map, changed, false}
          else
            map2 = put_in(map, [type_name, :info, :need_check], result)
            dep_map2 = Map.put(dep_map, type_name, result)
            {map2, dep_map2, true, sure}
          end
        else
          {map, dep_map, changed, sure}
        end
      end)
    fix_type_need_check_result(map, dep_map, changed, sure)
  end

  defp fix_type_need_check_result(map, dep_map, changed, sure) do
    cond do
      sure -> map
      changed -> fix_type_need_check(map, dep_map)
      true ->
        deps = for {type_name, dep} <- dep_map, is_map(dep) do
          {type_name, Enum.sort(Map.keys(dep))}
        end
        deps = inspect(Enum.sort(deps))
        raise "类型之间有循环引用#{deps}"
    end
  end

  defp check_type_opts(excg, type) do
    Enum.reduce(type.info.opts, type, fn({opt, val}, type) ->
      check_type_opt(excg, type, opt, val)
    end)
  end

  defp check_type_opt(excg, type, opt, val) do
    case opt do
      :cfun -> check_type_cfun(excg, type, opt, val)
      _ -> raise "类型#{type.info.name}：未知选项#{opt}"
    end
  end

  defp check_type_cfun(_excg, type, opt, val) do
    if reason = check_cfun(val) do
      raise "类型#{type.info.name}，选项#{opt}，错误：#{reason}"
    end
    put_in(type, [:info, :need_check], true)
  end

  defp check_cfun(val) do
    if is_tuple(val) and tuple_size(val) == 2 do
      {name, opts} = val
      if is_atom(name) and is_list(opts) do
        functions = apply(Cfun, :__info__, [:functions])
        case List.keyfind(functions, name, 0) do
          {^name, 3} -> nil
          _ -> "找不到函数#{name}"
        end
      else
        "格式错，应为{:name, [opts]}"
      end
    else
      "格式错，应为{:name, [opts]}"
    end
  end

  defp check_type_fld(excg, type, fld) do
    type = if fld.type == :virtual do
      put_in(type, [:info, :need_check], true)
    else
      type
    end
    if fld.kind == :field do
      Enum.reduce(fld.opts, type, fn({opt, val}, type) ->
        check_type_fld_opt(excg, type, fld, opt, val)
      end)
    else
      Enum.reduce(fld.opts, type, fn({opt, val}, type) ->
        check_type_arr_opt(excg, type, fld, opt, val)
      end)
    end
  end

  defp check_type_fld_opt(excg, type, fld, opt, val) do
    case opt do
      :cfun -> check_type_fld_cfun(excg, type, fld, opt, val)
      :const -> check_type_fld_const(excg, type, fld, opt, val)
      :default -> type
      :max -> check_type_fld_integer(excg, type, fld, opt, val)
      :max_len -> check_type_fld_integer(excg, type, fld, opt, val)
      :min -> check_type_fld_integer(excg, type, fld, opt, val)
      :min_len -> check_type_fld_integer(excg, type, fld, opt, val)
      :refrence -> check_type_fld_refrence(excg, type, fld, opt, val)
      :required -> check_type_fld_boolean(excg, type, fld, opt, val)
      _ -> raise "类型#{type.info.name}，字段#{fld.name}：未知选项#{opt}"
    end
  end

  defp check_type_arr_opt(excg, type, fld, opt, val) do
    case opt do
      :cfun -> check_type_fld_cfun(excg, type, fld, opt, val)
      :const -> check_type_fld_const(excg, type, fld, opt, val)
      :default -> type
      :max -> check_type_fld_integer(excg, type, fld, opt, val)
      :max_len -> check_type_fld_integer(excg, type, fld, opt, val)
      :min -> check_type_fld_integer(excg, type, fld, opt, val)
      :min_len -> check_type_fld_integer(excg, type, fld, opt, val)
      :refrence -> check_type_fld_refrence(excg, type, fld, opt, val)
      :required -> check_type_fld_boolean(excg, type, fld, opt, val)
      :ext_type -> check_type_fld_ext_type(excg, type, fld, opt, val)
      :default_items -> type
      :max_items -> check_type_fld_integer(excg, type, fld, opt, val)
      :min_items -> check_type_fld_integer(excg, type, fld, opt, val)
      :order_items -> check_type_fld_order_items(excg, type, fld, opt, val)
      :seq_items -> check_type_fld_seq_items(excg, type, fld, opt, val)
      :uinque_items -> check_type_fld_boolean(excg, type, fld, opt, val)
      _ -> raise "类型#{type.info.name}，字段#{fld.name}：未知选项#{opt}"
    end
  end

  defp check_type_fld_boolean(_excg, type, fld, opt, val) do
    if val != true and val != false do
      err_type_fld_opt(type, fld, opt, "#{val}不是合法的布尔值")
    end
    type
  end

  defp check_type_fld_integer(_excg, type, fld, opt, val) do
    unless is_integer(val) do
      err_type_fld_opt(type, fld, opt, "#{val}不是合法的整数值")
    end
    type
  end

  defp check_type_fld_cfun(_excg, type, fld, opt, val) do
    if reason = check_cfun(val) do
      err_type_fld_opt(type, fld, opt, reason)
    end
    put_in(type, [:info, :need_check], true)
  end

  defp check_type_fld_const(excg, type, fld, opt, val) do
    if fld.type != :integer do
      err_type_fld_opt(type, fld, opt, "const字段类型必须为integer")
    end
    unless excg.const_map[val] do
      err_type_fld_opt(type, fld, opt, "找不到常量#{val}")
    end
    type
  end

  defp check_type_fld_ext_type(_excg, type, fld, opt, val) do
    if val != :tuple do
      err_type_fld_opt(type, fld, opt, "不支持的ext_type: #{inspect val}")
    end
    type
  end

  defp check_type_fld_refrence(excg, type, fld, opt, val) do
    ref = excg.cfg_map[val]
    unless ref, do: err_type_fld_opt(type, fld, opt, "找不到引用#{val}")
    ref_fld = ref.map[:name]
    unless ref_fld && Keyword.get(ref_fld.opts, :unique) do
      err_type_fld_opt(type, fld, opt, "被引用的配置#{val}必须定义unique name")
    end
    unless fld.type == ref.map[ref.info.pri_key].type do
      err_type_fld_opt(type, fld, opt, "引用的字段类型必须与被引用主键一样")
    end
    put_in(type, [:info, :need_check], true)
  end

  defp check_type_fld_order_items(_excg, type, fld, opt, val) do
    if val != :asc and val != :desc do
      err_type_fld_opt(type, fld, opt, "不支持的order_items: #{inspect val}")
    end
    type
  end

  defp check_type_fld_seq_items(_excg, type, fld, opt, val) do
    if is_tuple(val) do
      {start, step} = val
      if is_integer(start) and is_integer(step) and step != 0 do
        type
      else
        reason = "seq_items的{start, step}必须为整数，并且step不能为0"
        err_type_fld_opt(type, fld, opt, reason)
      end
    else
      err_type_fld_opt(type, fld, opt, "seq_items的格式为{start, step}")
    end
  end

  defp check_cfg_pri_key(excg) do
    cfg_map = Enum.reduce(excg.cfg_map, %{}, fn({cfg_name, cfg}, cfg_map) ->
      cfg = if Keyword.get(cfg.info.opts, :singleton) do
        cfg
        |> put_in([:info, :singleton], true)
        |> put_in([:info, :pri_key], nil)
      else
        list = for {fld_name, fld} <- cfg.map do
          if Keyword.get(fld.opts, :pri_key), do: fld_name, else: nil
        end
        cfg = case Enum.filter(list, &(&1)) do
          [] -> raise "配置#{cfg.info.name}，错误：没有定义pri_key"
          [pri_key] -> put_in(cfg, [:info, :pri_key], pri_key)
          _ -> raise "配置#{cfg.info.name}，错误：定义了多个pri_key"
        end
        put_in(cfg, [:info, :singleton], false)
      end
      Map.put(cfg_map, cfg_name, cfg)
    end)
    %{excg | cfg_map: cfg_map}
  end

  defp init_cfg_acc_opts(cfg) do
    info =
      cfg.info
      |> Map.put(:cli_out, [])
      |> Map.put(:srv_out, [])
    %{cfg | info: info}
  end

  defp fini_cfg_acc_opts(cfg) do
    info =
      cfg.info
      |> Map.update!(:cli_out, &Enum.reverse/1)
      |> Map.update!(:srv_out, &Enum.reverse/1)
    %{cfg | info: info}
  end

  defp check_cfg(excg) do
    cfg_map = Enum.reduce(excg.cfg_map, %{}, fn({cfg_name, cfg}, cfg_map) ->
      cfg = init_cfg_acc_opts(cfg)
      cfg = check_cfg_opts(excg, cfg)
      map = cfg.map
      cfg = Enum.reduce(cfg.list, cfg, fn(fld_name, cfg) ->
        check_cfg_fld(excg, cfg, map[fld_name])
      end)
      cfg = fini_cfg_acc_opts(cfg)
      Map.put(cfg_map, cfg_name, cfg)
    end)
    %{excg | cfg_map: cfg_map}
  end

  defp check_cfg_opts(excg, cfg) do
    Enum.reduce(cfg.info.opts, cfg, fn({opt, val}, cfg) ->
      check_cfg_opt(excg, cfg, opt, val)
    end)
  end

  defp check_cfg_opt(excg, cfg, opt, val) do
    case opt do
      :cfun -> check_cfg_opt_cfun(excg, cfg, opt, val)
      :cli_out_dir -> cfg
      :cli_out_file -> cfg
      :mod_name -> check_cfg_opt_module(excg, cfg, opt, val)
      :singleton -> cfg
      :srv_out_dir -> cfg
      :srv_out_file -> cfg
      :xml_file -> check_cfg_opt_xml_file(excg, cfg, opt, val)
      _ -> raise "配置#{cfg.info.name}：未知选项#{opt}"
    end
  end

  defp check_cfg_opt_cfun(_excg, cfg, opt, val) do
    if reason = check_cfun(val) do
      raise "配置#{cfg.info.name}，选项#{opt}，错误：#{reason}"
    end
    cfg
  end

  defp check_cfg_opt_module(_excg, cfg, opt, val) do
    if is_atom(val) do
      cfg
    else
      raise "配置#{cfg.info.name}，选项#{opt}，错误：类型必须是atom"
    end
  end

  defp check_cfg_opt_xml_file(_excg, cfg, opt, val) do
    if is_binary(val) do
      if length(Path.split(val)) == 1 do
        cfg
      else
        raise "配置#{cfg.info.name}，选项#{opt}，错误：文件名不能包含目录"
      end
    else
      raise "配置#{cfg.info.name}，选项#{opt}，错误：类型必须是string"
    end
  end

  defp set_cfg_fld_need_check(cfg, fld, bool \\ true) do
    fld = Map.put(fld, :need_check, bool)
    put_in(cfg, [:map, fld.name], fld)
  end

  defp check_cfg_fld(excg, cfg, fld) do
    type = fld.type
    bool = if type == :virtual, do: true, else: false
    cfg = set_cfg_fld_need_check(cfg, fld, bool)
    cfg = unless Excg.basic_type?(type) or type == :virtual do
      excg_type = excg.type_map[type]
      if excg_type do
        if excg_type.info.need_check do
          set_cfg_fld_need_check(cfg, fld)
        else
          cfg
        end
      else
        raise "配置#{cfg.info.name}，字段#{fld.name}，错误：找不到类型#{type}"
      end
    else
      cfg
    end
    cfg = if Keyword.get(fld.opts, :cli_out, true) do
      update_in(cfg, [:info, :cli_out], &[fld.name | &1])
    else
      cfg
    end
    cfg = if Keyword.get(fld.opts, :srv_out, true) do
      update_in(cfg, [:info, :srv_out], &[fld.name | &1])
    else
      cfg
    end
    if fld.kind == :field do
      Enum.reduce(fld.opts, cfg, fn({opt, val}, cfg) ->
        check_cfg_fld_opt(excg, cfg, fld, opt, val)
      end)
    else
      Enum.reduce(fld.opts, cfg, fn({opt, val}, cfg) ->
        check_cfg_arr_opt(excg, cfg, fld, opt, val)
      end)
    end
  end

  defp check_cfg_fld_opt(excg, cfg, fld, opt, val) do
    case opt do
      :cfun -> check_cfg_fld_cfun(excg, cfg, fld, opt, val)
      :cli_out -> check_cfg_fld_boolean(excg, cfg, fld, opt, val)
      :const -> check_cfg_fld_const(excg, cfg, fld, opt, val)
      :default -> cfg
      :eex -> check_cfg_fld_eex(excg, cfg, fld, opt, val)
      :max -> check_cfg_fld_integer(excg, cfg, fld, opt, val)
      :max_len -> check_cfg_fld_integer(excg, cfg, fld, opt, val)
      :min -> check_cfg_fld_integer(excg, cfg, fld, opt, val)
      :min_len -> check_cfg_fld_integer(excg, cfg, fld, opt, val)
      :order -> check_cfg_fld_order(excg, cfg, fld, opt, val)
      :pri_key -> check_cfg_fld_pri_key(excg, cfg, fld, opt, val)
      :refrence -> check_cfg_fld_refrence(excg, cfg, fld, opt, val)
      :required -> check_cfg_fld_boolean(excg, cfg, fld, opt, val)
      :sequence -> check_cfg_fld_sequence(excg, cfg, fld, opt, val)
      :srv_out -> check_cfg_fld_boolean(excg, cfg, fld, opt, val)
      :unique -> check_cfg_fld_unique(excg, cfg, fld, opt, val)
      _ -> raise "配置#{cfg.info.name}，字段#{fld.name}：未知选项#{opt}"
    end
  end

  defp check_cfg_arr_opt(excg, cfg, fld, opt, val) do
    case opt do
      :cfun -> check_cfg_fld_cfun(excg, cfg, fld, opt, val)
      :cli_out -> check_cfg_fld_boolean(excg, cfg, fld, opt, val)
      :const -> check_cfg_fld_const(excg, cfg, fld, opt, val)
      :default -> cfg
      :eex -> check_cfg_fld_eex(excg, cfg, fld, opt, val)
      :max -> check_cfg_fld_integer(excg, cfg, fld, opt, val)
      :max_len -> check_cfg_fld_integer(excg, cfg, fld, opt, val)
      :min -> check_cfg_fld_integer(excg, cfg, fld, opt, val)
      :min_len -> check_cfg_fld_integer(excg, cfg, fld, opt, val)
      :order -> check_cfg_fld_order(excg, cfg, fld, opt, val)
      :refrence -> check_cfg_fld_refrence(excg, cfg, fld, opt, val)
      :required -> check_cfg_fld_boolean(excg, cfg, fld, opt, val)
      :srv_out -> check_cfg_fld_boolean(excg, cfg, fld, opt, val)
      :unique -> check_cfg_fld_unique(excg, cfg, fld, opt, val)
      :ext_type -> check_cfg_fld_ext_type(excg, cfg, fld, opt, val)
      :default_items -> cfg
      :max_items -> check_cfg_fld_integer(excg, cfg, fld, opt, val)
      :min_items -> check_cfg_fld_integer(excg, cfg, fld, opt, val)
      :order_items -> check_cfg_fld_order_items(excg, cfg, fld, opt, val)
      :seq_items -> check_cfg_fld_seq_items(excg, cfg, fld, opt, val)
      :uinque_items -> check_cfg_fld_boolean(excg, cfg, fld, opt, val)
      _ -> raise "配置#{cfg.info.name}，字段#{fld.name}：未知选项#{opt}"
    end
  end

  defp check_cfg_fld_boolean(_excg, cfg, fld, opt, val) do
    if val != true and val != false do
      err_cfg_fld_opt(cfg, fld, opt, "#{val}不是合法的布尔值")
    end
    cfg
  end

  defp check_cfg_fld_integer(_excg, cfg, fld, opt, val) do
    unless is_integer(val) do
      err_cfg_fld_opt(cfg, fld, opt, "#{val}不是合法的整数值")
    end
    cfg
  end

  defp check_cfg_fld_cfun(_excg, cfg, fld, opt, val) do
    if reason = check_cfun(val) do
      err_cfg_fld_opt(cfg, fld, opt, reason)
    end
    set_cfg_fld_need_check(cfg, fld)
  end

  defp check_cfg_fld_const(excg, cfg, fld, opt, val) do
    if fld.type == :integer do
      if excg.const_map[val] do
        cfg
      else
        err_cfg_fld_opt(cfg, fld, opt, "找不到常量#{val}")
      end
    else
      err_cfg_fld_opt(cfg, fld, opt, "const字段类型必须为integer")
    end
  end

  defp check_cfg_fld_eex(excg, cfg, fld, opt, val) do
    if fld.type == :string do
      check_cfg_fld_boolean(excg, cfg, fld, opt, val)
      if val do
        set_cfg_fld_need_check(cfg, fld)
      else
        cfg
      end
    else
      err_cfg_fld_opt(cfg, fld, opt, "eex选项只能用在字符串字段里")
    end
  end

  defp check_cfg_fld_ext_type(_excg, cfg, fld, opt, val) do
    if val != :tuple do
      err_cfg_fld_opt(cfg, fld, opt, "不支持的ext_type: #{inspect val}")
    end
    cfg
  end

  defp check_cfg_fld_order(_excg, cfg, fld, opt, val) do
    if val != :asc and val != :desc do
      err_cfg_fld_opt(cfg, fld, opt, "不支持的order: #{inspect val}")
    end
    set_cfg_fld_need_check(cfg, fld)
  end

  defp check_cfg_fld_pri_key(excg, cfg, fld, opt, val) do
    check_cfg_fld_boolean(excg, cfg, fld, opt, val)
    if val do
      set_cfg_fld_need_check(cfg, fld)
    else
      cfg
    end
  end

  defp check_cfg_fld_refrence(excg, cfg, fld, opt, val) do
    ref = excg.cfg_map[val]
    unless ref, do: err_cfg_fld_opt(cfg, fld, opt, "找不到引用#{val}")
    ref_fld = ref.map[:name]
    unless ref_fld && Keyword.get(ref_fld.opts, :unique) do
      err_cfg_fld_opt(cfg, fld, opt, "被引用的配置#{val}必须定义unique name")
    end
    unless fld.type == ref.map[ref.info.pri_key].type do
      err_cfg_fld_opt(cfg, fld, opt, "引用的字段类型必须与被引用主键一样")
    end
    set_cfg_fld_need_check(cfg, fld)
  end

  defp check_cfg_fld_sequence(_excg, cfg, fld, opt, val) do
    if fld.type != :integer and fld.type != :virtual do
      err_cfg_fld_opt(cfg, fld, opt, "sequence选项只能用在整数类型字段")
    end
    if is_tuple(val) and tuple_size(val) == 2 do
      {start, step} = val
      if is_integer(start) and is_integer(step) and step != 0 do
        set_cfg_fld_need_check(cfg, fld)
      else
        reason = "sequence的{start, step}必须为整数，并且step不能为0"
        err_cfg_fld_opt(cfg, fld, opt, reason)
      end
    else
      err_cfg_fld_opt(cfg, fld, opt, "sequence的格式为{start, step}")
    end
  end

  defp check_cfg_fld_unique(excg, cfg, fld, opt, val) do
    check_cfg_fld_boolean(excg, cfg, fld, opt, val)
    if val do
      set_cfg_fld_need_check(cfg, fld)
    else
      cfg
    end
  end

  defp check_cfg_fld_order_items(_excg, cfg, fld, opt, val) do
    if val != :asc and val != :desc do
      err_cfg_fld_opt(cfg, fld, opt, "不支持的order_items: #{inspect val}")
    end
    cfg
  end

  defp check_cfg_fld_seq_items(_excg, cfg, fld, opt, val) do
    if is_tuple(val) do
      {start, step} = val
      if is_integer(start) and is_integer(step) and step != 0 do
        cfg
      else
        reason = "seq_items的{start, step}必须为整数，并且step不能为0"
        err_cfg_fld_opt(cfg, fld, opt, reason)
      end
    else
      err_cfg_fld_opt(cfg, fld, opt, "seq_items的格式为{start, step}")
    end
  end

  defp err_type_fld_opt(type, fld, opt, err) do
    raise "类型#{type.info.name}，字段#{fld.name}，选项#{opt}，错误：#{err}"
  end

  defp err_cfg_fld_opt(cfg, fld, opt, err) do
    raise "配置#{cfg.info.name}，字段#{fld.name}，选项#{opt}，错误：#{err}"
  end

end
