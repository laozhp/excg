defmodule ItemCfg do
  use Excg

  type :asset_opt, "资产选项" do
    field :type, "资产选项类型", :integer, const: :asset_opt_type
    field :value, "资产选项值", :string
  end

  type :asset, "资产" do
    field :id, "资产标识", :integer,
      refrence: :item, cfun: {:asset, [const: :asset_type]}
    field :num, "资产数量", :integer, required: false, default: 1
    array :opts, "资产选项列表", :asset_opt,
      required: false, uinque_items: true
  end

  type :weighted_asset, "加权资产" do
    field :weight, "权重", :integer
    field :asset,  "资产", :asset
  end

  type :random_asset, "随机资产", cfun: {:random_asset, []} do
    field :min_num, "最小数量", :integer, default: 1, min: 1
    field :avg_num, "平均数量", :virtual
    field :max_num, "最大数量", :integer, default: 1, min: 1
    array :weighted_assets, "加权资产列表", :weighted_asset
    field :unique, "是否唯一", :boolean, required: false
  end

  config :item, "物品", xml_file: "w物品.xml" do
    field :id, "标识", :integer, pri_key: true, min: 1000, max: 9999
    field :name, "名称", :string,
      min_len: 1, unique: true, cfun: {:item_name, [const: :asset_type]}
    field :desc, "描述", :string, eex: true, cli_out: true, srv_out: false
    field :item_type, "物品类型", :integer, const: :item_type
    field :equip_type, "装备类型", :integer, const: :equip_type
    field :disp, "显示测试", :virtual, cfun: {:item_disp, []}, sequence: {3, 7}
    field :item_use_type, "物品使用类型", :integer, const: :item_use_type
    field :use_data, "使用类型所需的数据", :string, required: false
    array :assets_after_use, "使用之后的产出", :random_asset
    field :seq, "序列测试", :virtual, sequence: {1, 1}
    field :stack_num, "堆叠数量", :integer, default: 1, min: 1
    field :sort_id, "排序标识", :integer
  end

end
