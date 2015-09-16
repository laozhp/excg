defmodule GlobalCfg do
  use Excg

  config :global, "全局配置",
    xml_file: "q全局配置.xml", singleton: true,
    cli_out_dir: "{app}", srv_out_dir: "{app}"
    do
    field :bag_size, "背包大小", :integer, min: 1
  end

end
