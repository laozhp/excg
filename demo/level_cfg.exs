defmodule LevelCfg do
  use Excg

  config :level, "升级", xml_file: "s升级.xml", mod_name: :role do
    field :level, "等级", :integer, pri_key: true, sequence: {1, 1}
    field :exp, "经验", :integer, min: 1
  end

end
