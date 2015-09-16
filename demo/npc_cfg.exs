defmodule NpcCfg do
  use Excg

  config :npc, "NPC", srv_out_dir: "{app}/scene" do
    field :id, "标识", :integer, min: 1, max: 9999, pri_key: true
    field :name, "名称", :string, min_len: 1, unique: true
    field :desc, "描述", :string, required: false
    field :npc_type, "NPC类型", :integer, const: :npc_type
    field :dialog, "默认对话", :string
  end

end
