defmodule Mix.Excg do

  defstruct \
    excg_dir:       ".",
    app:            "app",
    app_mod:        "App",
    dir:            "excg",
    xml_dir:        "excg/xml",
    cli_out:        nil,
    srv_out:        "lib",
    json_out:       nil,
    yaml_out:       nil,
    cli_lang:       "lua",
    srv_lang:       "ex",
    force:          false,
    mtime_map:      %{},
    msg_mods:       %{},
    cfg_mods:       %{},
    const_types:    [],
    const_list:     [],
    const_map:      %{},
    error_codes:    [],
    type_map:       %{},
    cfg_map:        %{},
    msg_mod_infos:  [],
    msg_map:        %{},
    data_map:       %{},
    ref_map:        %{},
    cfg:            nil,
    cfg_name:       :config,
    filename:       "XXX.xml",
    fld_names:      {},
    empty_cell:     nil,
    row_data:       %{},
    row_i:          0,
    fld_i:          0,
    fld_path:       [],
    ref:            %{},
    ref_name:       :refrence

  def get_arg_env(arg, env, key, default) do
    Keyword.get(arg, key, Keyword.get(env, key, default))
  end

  def patch(string, min_len) do
    pat_len = min_len - byte_size(string)
    if pat_len > 0 do
      string <> String.duplicate(" ", pat_len)
    else
      string
    end
  end

  def write_unless_exists(output_dir, filename, excg, tpl, bindings \\ []) do
    path = Path.join(output_dir, filename)
    if File.exists?(path) do
      Mix.shell.info("Skip    #{path} ...")
    else
      tpl_file = find_template(excg, tpl)
      write_with_tpl(output_dir, path, excg, tpl_file, bindings)
    end
  end

  def write_with_tpl(output_dir, path, excg, tpl_file, bindings) do
    bindings = Keyword.merge([excg: excg], bindings)
    data = EEx.eval_file(tpl_file, bindings)
    output_dir |> File.mkdir_p!
    Mix.shell.info("Writing #{path} ...")
    File.write!(path, data)
  end

  def find_template(excg, filename) do
    tpl_file = Path.join(excg.dir, filename)
    unless File.exists?(tpl_file) do
      tpl_file = Path.join([excg.excg_dir, "priv", "templates", filename])
    end
    tpl_file
  end

  def now do
    {{year, mon, day}, {hour, min, sec}} = :erlang.localtime
    "#{year}-#{p2(mon)}-#{p2(day)}T#{p2(hour)}:#{p2(min)}:#{p2(sec)}Z"
  end

  defp p2(i) do
    if i < 10 do
      "0#{i}"
    else
      "#{i}"
    end
  end

end
