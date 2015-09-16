defmodule Mix.Tasks.Excg.Code do
  use Mix.Task

  @shortdoc "生成源代码"

  @moduledoc """
  生成源代码

  ## 例子

      mix excg.code

  ## 命令行参数

    * `--app` - 指定应用名称，默认为当前应用
    * `--dir` - 指定输入目录，默认excg
    * `--xml-dir` - 指定xml数据文件输入目录，默认{dir}/xml
    * `--cli-out` - 指定客户端输出目录，默认不输出
    * `--srv-out` - 指定服务端输出目录，默认lib
    * `--cli-lang` - 指定客户端语言，默认lua
    * `--srv-lang` - 指定服务端语言，默认ex
    * `-f`, `--force` - 不检测变化(该检测并不完美)，强制输出
  """

  @doc false
  def run(args) do
    %Mix.Excg{excg_dir: Application.app_dir(:excg)}
    |> parse_args(args)
    |> Excg.Parser.Schema.parse
    |> Excg.Checker.Schema.check
    |> Excg.Parser.Data.parse
    |> Excg.Checker.Data.check
    |> build_mtime_map
    |> gen_const_srv
    |> gen_error_code_srv
    |> gen_mod_msg_srv
    |> gen_all_msg_srv
    |> gen_all_cfg_srv
    |> gen_const_cli
    |> gen_error_code_cli
    |> gen_mod_msg_cli
    |> gen_all_msg_cli
    |> gen_all_cfg_cli
  end

  defp parse_args(excg, args) do
    {arg, _argv, _errors} = OptionParser.parse(
      args, aliases: [f: :force], switches: [force: :boolean])
    env = Application.get_env(:excg, :code, [])
    app = Keyword.get(Mix.Project.config, :app)
    app = to_string(Mix.Excg.get_arg_env(arg, env, :app, app))
    dir = Mix.Excg.get_arg_env(arg, env, :dir, "excg")
    xml_dir = Mix.Excg.get_arg_env(arg, env, :xml_dir, "#{dir}/xml")
    cli_out_dir = Mix.Excg.get_arg_env(arg, env, :cli_out, nil)
    srv_out_dir = Mix.Excg.get_arg_env(arg, env, :srv_out, "lib")
    cli_lang = Mix.Excg.get_arg_env(arg, env, :cli_lang, "lua")
    srv_lang = Mix.Excg.get_arg_env(arg, env, :srv_lang, "ex")
    force = Mix.Excg.get_arg_env(arg, env, :force, false)
    app_mod = Mix.Utils.camelize(app)
    %{excg | app: app, app_mod: app_mod, dir: dir, xml_dir: xml_dir,
             cli_out_dir: cli_out_dir, srv_out_dir: srv_out_dir,
             cli_lang: cli_lang, srv_lang: srv_lang, force: force}
  end

  defp build_mtime_map(excg) do
    unless excg.force do
      excg = do_build_mtime_map(excg)
    end
    excg
  end

  defp gen_const_srv(excg) do
    if excg.srv_out_dir do
      do_gen_const_srv(excg)
    end
    excg
  end

  defp gen_error_code_srv(excg) do
    if excg.srv_out_dir do
      do_gen_error_code_srv(excg)
    end
    excg
  end

  defp gen_mod_msg_srv(excg) do
    if excg.srv_out_dir do
      do_gen_mod_msg_srv(excg)
    end
    excg
  end

  defp gen_all_msg_srv(excg) do
    if excg.srv_out_dir do
      do_gen_all_msg_srv(excg)
    end
    excg
  end

  defp gen_all_cfg_srv(excg) do
    if excg.srv_out_dir do
      do_gen_all_cfg_srv(excg)
    end
    excg
  end

  defp gen_const_cli(excg) do
    if excg.cli_out_dir do
      do_gen_const_cli(excg)
    end
    excg
  end

  defp gen_error_code_cli(excg) do
    if excg.cli_out_dir do
      do_gen_error_code_cli(excg)
    end
    excg
  end

  defp gen_mod_msg_cli(excg) do
    if excg.cli_out_dir do
      do_gen_mod_msg_cli(excg)
    end
    excg
  end

  defp gen_all_msg_cli(excg) do
    if excg.cli_out_dir do
      do_gen_all_msg_cli(excg)
    end
    excg
  end

  defp gen_all_cfg_cli(excg) do
    if excg.cli_out_dir do
      do_gen_all_cfg_cli(excg)
    end
    excg
  end

  defp do_gen_const_cli(excg) do
    lang = excg.cli_lang
    dir = Path.join(excg.cli_out_dir, excg.app)
    write_if_expired(
      dir, "const.ex", excg, "cli_const_#{lang}.eex",
      src: "const.exs")
  end

  defp do_gen_const_srv(excg) do
    lang = excg.srv_lang
    dir = Path.join(excg.srv_out_dir, excg.app)
    write_if_expired(
      dir, "const.ex", excg, "srv_const_#{lang}.eex",
      src: "const.exs")
  end

  defp do_gen_error_code_cli(excg) do
    lang = excg.cli_lang
    dir = Path.join(excg.cli_out_dir, excg.app)
    write_if_expired(
      dir, "error_code.ex", excg, "cli_error_code_#{lang}.eex",
      src: "error_code.exs")
  end

  defp do_gen_error_code_srv(excg) do
    lang = excg.srv_lang
    dir = Path.join(excg.srv_out_dir, excg.app)
    write_if_expired(
      dir, "error_code.ex", excg, "srv_error_code_#{lang}.eex",
      src: "error_code.exs")
  end

  defp do_gen_mod_msg_cli(excg) do
    lang = excg.cli_lang
    dir = Path.join([excg.cli_out_dir, excg.app, "plug"])
    write_if_expired(
      dir, "packer.ex", excg, "cli_mod_packer_#{lang}.eex", all_msg: true)
    write_if_expired(
      dir, "router.ex", excg, "cli_mod_router_#{lang}.eex", all_msg: true)
  end

  defp do_gen_mod_msg_srv(excg) do
    lang = excg.srv_lang
    dir = Path.join([excg.srv_out_dir, excg.app, "plug"])
    write_if_expired(
      dir, "packer.ex", excg, "srv_mod_packer_#{lang}.eex", all_msg: true)
    write_if_expired(
      dir, "router.ex", excg, "srv_mod_router_#{lang}.eex", all_msg: true)
  end

  defp do_gen_all_msg_cli(excg) do
    lang = excg.cli_lang
    out_dir = excg.cli_out_dir
    app = excg.app
    for mod <- excg.msg_mod_infos do
      mod_name = to_string(mod.name)
      dir = Path.join([out_dir, app, "mod", mod_name])
      bindings = [mod: mod]
      Mix.Excg.write_unless_exists(
        dir, "msg_handler.ex", excg, "cli_msg_handler_#{lang}.eex", bindings)
      write_if_expired(
        dir, "packer.ex", excg, "cli_msg_packer_#{lang}.eex",
        bindings: bindings, msg_mod: mod)
      write_if_expired(
        dir, "router.ex", excg, "cli_msg_router_#{lang}.eex",
        bindings: bindings, msg_mod: mod)
    end
  end

  defp do_gen_all_msg_srv(excg) do
    lang = excg.srv_lang
    out_dir = excg.srv_out_dir
    app = excg.app
    for mod <- excg.msg_mod_infos do
      mod_name = to_string(mod.name)
      dir = Path.join([out_dir, app, "mod", mod_name])
      bindings = [mod: mod]
      Mix.Excg.write_unless_exists(
        dir, "msg_handler.ex", excg, "srv_msg_handler_#{lang}.eex", bindings)
      write_if_expired(
        dir, "packer.ex", excg, "srv_msg_packer_#{lang}.eex",
        bindings: bindings, msg_mod: mod)
      write_if_expired(
        dir, "router.ex", excg, "srv_msg_router_#{lang}.eex",
        bindings: bindings, msg_mod: mod)
    end
  end

  defp do_gen_all_cfg_cli(excg) do
    lang = excg.cli_lang
    excg_out_dir = excg.cli_out_dir
    app = excg.app
    data_map = excg.data_map
    for {cfg_name, cfg} <- excg.cfg_map do
      if cfg.info.cli_out != [] do
        opts = cfg.info.opts
        mod_name = Keyword.get(opts, :mod_name, cfg_name)
        vars = %{
          app: app, mod_name: to_string(mod_name),
          cfg_name: to_string(cfg_name), lang: lang}
        dir =
          Keyword.get(opts, :cli_out_dir, "{app}/mod/{mod_name}")
          |> replace_vars(vars)
        ex_mod = path_to_ex_mod(Path.join(dir, cfg.mod))
        dir = Path.join(excg_out_dir, dir)
        filename =
          Keyword.get(opts, :cli_out_file, "{cfg_name}_cfg.{lang}")
          |> replace_vars(vars)
        data = data_map[cfg_name]
        bindings = [cfg: cfg, data: data, ex_mod: ex_mod]
        tpl = if cfg.info.singleton do
          "cli_cfg_singleton_#{lang}.eex"
        else
          "cli_cfg_#{lang}.eex"
        end
        write_if_expired(
          dir, filename, excg, tpl,
          bindings: bindings, cfg: cfg)
      end
    end
  end

  defp do_gen_all_cfg_srv(excg) do
    lang = excg.srv_lang
    excg_out_dir = excg.srv_out_dir
    app = excg.app
    data_map = excg.data_map
    for {cfg_name, cfg} <- excg.cfg_map do
      if cfg.info.srv_out != [] do
        opts = cfg.info.opts
        mod_name = Keyword.get(opts, :mod_name, cfg_name)
        vars = %{
          app: app, mod_name: to_string(mod_name),
          cfg_name: to_string(cfg_name), lang: lang}
        dir =
          Keyword.get(opts, :srv_out_dir, "{app}/mod/{mod_name}")
          |> replace_vars(vars)
        ex_mod = path_to_ex_mod(Path.join(dir, cfg.mod))
        dir = Path.join(excg_out_dir, dir)
        filename =
          Keyword.get(opts, :srv_out_file, "{cfg_name}_cfg.{lang}")
          |> replace_vars(vars)
        data = data_map[cfg_name]
        bindings = [cfg: cfg, data: data, ex_mod: ex_mod]
        tpl = if cfg.info.singleton do
          "srv_cfg_singleton_#{lang}.eex"
        else
          "srv_cfg_#{lang}.eex"
        end
        write_if_expired(
          dir, filename, excg, tpl,
          bindings: bindings, cfg: cfg)
      end
    end
  end

  defp path_to_ex_mod(path) do
    list = for dir <- Path.split(path) do
      Mix.Utils.camelize(dir)
    end
    Enum.join(list, ".")
  end

  defp replace_vars(string, vars) do
    Enum.reduce(vars, string, fn({k, v}, string) ->
      String.replace(string, "{#{k}}", v)
    end)
  end

  defp do_build_mtime_map(excg) do
    dirs = [Path.join([excg.excg_dir, "priv", "templates"]),
            excg.dir, excg.xml_dir]
    files = Enum.reduce(dirs, [], fn(dir, list) ->
      (for file <- File.ls!(dir), do: Path.join(dir, file)) ++ list
    end)
    map = Enum.reduce(files, %{}, fn(file, map) ->
      stat = File.stat!(file)
      if stat.type == :regular do
        Map.put(map, file, stat.mtime)
      else
        map
      end
    end)
    %{excg | mtime_map: map}
  end

  defp write_if_expired(output_dir, filename, excg, tpl, opts) do
    tpl_file = Mix.Excg.find_template(excg, tpl)
    path = Path.join(output_dir, filename)
    if (not excg.force) and File.exists?(path) do
      src_files = get_src_files(excg, opts)
      if mtime_expired?(excg, path, [tpl_file | src_files]) do
        bindings = Keyword.get(opts, :bindings, [])
        Mix.Excg.write_with_tpl(output_dir, path, excg, tpl_file, bindings)
      else
        Mix.shell.info("Skip    #{path} ...")
      end
    else
      bindings = Keyword.get(opts, :bindings, [])
      Mix.Excg.write_with_tpl(output_dir, path, excg, tpl_file, bindings)
    end
  end

  defp get_src_files(excg, opts) do
    cond do
      src = Keyword.get(opts, :src) ->
        [Path.join(excg.dir, src)]
      Keyword.get(opts, :all_msg) ->
        Map.values(excg.msg_mods)
      msg_mod = Keyword.get(opts, :msg_mod) ->
        [msg_mod.src_file]
      cfg = Keyword.get(opts, :cfg) ->
        cfun = Path.join(excg.dir, "cfun.exs")
        const = Path.join(excg.dir, "const.exs")
        src_file = cfg.info.src_file
        xml_file = Path.join(excg.xml_dir, Excg.cfg_xml_file(cfg.info))
        [cfun, const, src_file, xml_file]
      true -> []
    end
  end

  defp mtime_expired?(excg, dst_file, src_files) do
    dst_mtime = File.stat!(dst_file).mtime
    mtime_map = excg.mtime_map
    src_mtimes = for f <- src_files, do: mtime_map[f]
    dst_mtime < Enum.max(src_mtimes)
  end

end
