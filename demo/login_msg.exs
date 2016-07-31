defmodule LoginMsg do
  use Excg

  module 1, :login, "登录模块"

  type :login_role_info,  "登录角色信息" do
    field :role_id,       "角色ID",   :integer
    field :role_name,     "角色名",   :string
    field :sex,           "性别",     :integer
    field :career,        "职业",     :integer
    field :icon,          "头像",     :integer
    field :level,         "级别",     :integer
    field :scene_id,      "场景ID",   :integer
  end

  message 0, :login_req,  "登录请求" do
    field :username,      "用户名",   :string
    field :password,      "密码",     :string
    field :login_time,    "登录时间", :integer
    field :login_key,     "登录密钥", :string
  end

  message 1, :login_rsp,  "登录回复" do
    field :result,        "结果",     :integer
  end

  message 2, :create_user_req, "创建用户请求" do
    field :username,      "用户名",      :string
    field :password,      "密码",        :string
    field :login_time,    "登录时间",    :integer
    field :login_key,     "登录密钥",    :string
    field :anti_wallow,   "反沉迷信息",  :integer
    field :imei,          "设备识别码",  :string
    field :imsi,          "用户识别码",  :string
    field :plat_type,     "平台类型",    :string
    field :channel_id,    "渠道标识",    :string
    field :app_id,        "应用标识",    :string
    field :screen_width,  "屏幕宽度",    :string
    field :screen_height, "屏幕高度",    :string
    field :system_type,   "系统类型",    :string
    field :phone_model,   "手机型号",    :string
    field :network_type,  "网络类型",    :string
    field :package_size,  "包大小",      :string
    field :package_name,  "包名称",      :string
    field :gx,            "经度",        :string
    field :gy,            "纬度",        :string
    field :adplat_type,   "广告平台",    :string
    field :mac,           "网卡地址",    :string
    field :ios_version,   "IOS版本",     :string
    field :ifa,           "IOS广告标识", :string
  end

  message 3, :create_user_rsp, "创建用户回复" do
    field :result,        "结果",     :integer
  end

  message 4, :list_role_req, "角色列表请求" do
  end

  message 5, :list_role_rsp, "角色列表回复" do
    array :role_list,     "角色列表", :login_role_info
  end

  message 6, :create_role_req, "创建角色请求" do
    field :role_name,     "角色名",   :string
    field :sex,           "性别",     :integer
    field :career,        "职业",     :integer
    field :icon,          "头像",     :integer
  end

  message 7, :create_role_rsp, "创建角色回复" do
    field :result,        "结果",     :integer
    field :role_info,     "角色信息", :login_role_info
  end

  message 8, :enter_game_req, "进入游戏请求" do
    field :role_id,       "角色ID",   :integer
  end

  message 9, :enter_game_rsp, "进入游戏回复" do
    field :result,        "结果",     :integer
  end

  message 10, :heart_beat_req, "心跳请求" do
  end

  message 11, :heart_beat_rsp, "心跳回复" do
  end

  message 12, :client_ready, "客户端准备好" do
  end

  message 13, :server_ready, "服务端准备好" do
  end

  message 15, :err_code_notify, "错误码通知" do
    field :error_code,    "错误码",    :integer
    field :parms,         "参数",      :string
  end

  message 20, :gm_cmd_req, "GM命令请求" do
    field :text,          "文本信息",  :string
  end

  message 21, :gm_cmd_rsp, "GM命令回复" do
    field :text,          "文本信息",  :string
  end


  type :test_asset, "资产" do
    field :id, "标识", :integer
    field :num, "数量", :integer, default: 1
  end

  type :test_weighted_asset, "加权资产" do
    field :weight, "权重", :integer
    field :asset,  "资产", :test_asset
  end

  type :test_random_asset, "随机资产" do
    field :min_num, "最小数量", :integer, default: 1, min: 1
    # message不支持虚拟字段，下面的avg_num被当作普通字段处理了
    field :avg_num, "平均数量", :virtual
    field :max_num, "最大数量", :integer, default: 1, min: 1
    array :weighted_assets, "加权资产列表", :test_weighted_asset
  end

  message 120, :test_req, "测试请求" do
    field :integer, "整数", :integer
    field :string, "字符串", :string
    field :float, "浮点数", :float
    array :int_arr, "整数数组", :integer
    field :seq, "序列", :virtual, sequence: {1, 1}
    array :produce, "产出", :test_random_asset
    field :desc, "注释", :string
  end

  message 121, :test_rsp, "测试回复" do
    field :integer, "整数", :integer
    field :string, "字符串", :string
    field :float, "浮点数", :float
    array :int_arr, "整数数组", :integer
    field :seq, "序列", :virtual, sequence: {1, 1}
    array :produce, "产出", :test_random_asset
    field :desc, "注释", :string
  end

end
