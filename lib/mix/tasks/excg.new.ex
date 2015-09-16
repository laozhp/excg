defmodule Mix.Tasks.Excg.New do
  use Mix.Task

  @shortdoc "生成Excg目录结构"

  @moduledoc """
  生成Excg目录结构

  ## 例子

      mix excg.new

  ## 命令行参数

    * `--dir`     - 指定excg文件目录，默认excg
    * `--xml-dir` - 指定xml文件目录，默认{dir}/xml
  """

  @doc false
  def run(args) do
    %Mix.Excg{excg_dir: Application.app_dir(:excg)}
    |> parse_args(args)
    |> gen_new
  end

  defp parse_args(excg, args) do
    {arg, _argv, _errors} = OptionParser.parse(args)
    env = Application.get_env(:excg, :new, [])
    dir = Mix.Excg.get_arg_env(arg, env, :dir, "excg")
    xml_dir = Mix.Excg.get_arg_env(arg, env, :xml_dir, "#{dir}/xml")
    %{excg | dir: dir, xml_dir: xml_dir}
  end

  def gen_new(excg) do
    mkdir(excg.dir)
    mkdir(excg.xml_dir)
    write(excg, excg.dir, "cfun")
    write(excg, excg.dir, "const")
    write(excg, excg.dir, "error_code")
  end

  defp mkdir(path) do
    unless File.exists?(path) do
      Mix.shell.info("Mkdir #{path} ...")
      File.mkdir_p!(path)
    end
  end

  defp write(excg, dir, filename) do
    Mix.Excg.write_unless_exists(
      dir, filename <> ".exs", excg, filename <> ".eex")
  end

end
