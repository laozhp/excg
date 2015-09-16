defmodule Mix.Tasks.Excg.Xml do
  use Mix.Task

  @shortdoc "生成ExcelXML文件"

  @moduledoc """
  生成ExcelXML文件

  ## 例子

      mix excg.xml

  ## 命令行参数

    * `--dir`     - 指定输入目录，默认excg
    * `--xml-dir` - 指定输出目录，默认{dir}/xml
  """

  @doc false
  def run(args) do
    %Mix.Excg{excg_dir: Application.app_dir(:excg)}
    |> parse_args(args)
    |> Excg.Parser.Schema.parse
    |> Excg.Checker.Schema.check
    |> gen_all_xml
  end

  defp parse_args(excg, args) do
    {arg, _argv, _errors} = OptionParser.parse(args)
    env = Application.get_env(:excg, :xml, [])
    dir = Mix.Excg.get_arg_env(arg, env, :dir, "excg")
    xml_dir = Mix.Excg.get_arg_env(arg, env, :xml_dir, "#{dir}/xml")
    %{excg | dir: dir, xml_dir: xml_dir}
  end

  defp gen_all_xml(excg) do
    xml_dir = excg.xml_dir
    for {_name, cfg} <- excg.cfg_map do
      filename = Excg.cfg_xml_file(cfg.info)
      path = Path.join(xml_dir, filename)
      if File.exists?(path) do
        Mix.shell.info("Updating #{path} ...")
        excg
        |> Map.put(:cfg, cfg)
        |> Map.put(:filename, filename)
        |> Excg.Builder.ExcelXml.update_file
      else
        tpl_file = Mix.Excg.find_template(excg, "excel_xml.eex")
        Mix.Excg.write_with_tpl(xml_dir, path, excg, tpl_file, [cfg: cfg])
      end
    end
    excg
  end

end
