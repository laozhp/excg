defmodule MonsterCfg do
  use Excg

  config :monster, "怪物", xml_file: "g怪物.xml", mod_name: :battle do
    field :id, "标识", :integer, min: 1, max: 9999, pri_key: true
    field :name, "名称", :string, min_len: 1
    field :level, "等级", :integer
    field :hp, "血气", :integer
    field :attack, "攻击", :integer
    field :defence, "防御", :integer
  end

end
