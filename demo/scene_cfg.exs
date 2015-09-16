defmodule SceneCfg do
  use Excg

  config :scene, "场景", xml_file: "c场景.xml", srv_out_dir: "{app}/scene" do
    field :id, "标识", :integer, min: 1, max: 9999, pri_key: true
    field :name, "名称", :string, min_len: 1, unique: true
    field :desc, "描述", :string, required: false
    field :scene_type, "场景类型", :integer, const: :scene_type
    field :aoi_type, "同步类型", :integer, const: :aoi_type
    field :level_limit, "等级限制", :integer
  end

end
