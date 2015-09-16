defmodule TaskCfg do
  use Excg

  type :task_act, "任务动作" do
    field :type, "任务动作类型", :integer, const: :task_act_type
    array :args, "任务动作参数", :integer, ext_type: :tuple
  end

  type :task_npc, "任务NPC" do
    field :scene_id, "场景ID", :integer, refrence: :scene
    field :npc_id, "NPC标识", :integer, refrence: :npc
    field :dialog, "任务对话", :string
  end

  type :task_unit, "任务单元" do
    field :type, "任务单元类型", :integer, const: :task_unit_type
    array :args, "任务单元参数", :integer, ext_type: :tuple
    field :disp, "显示内容", :string, required: false
  end

  config :task, "任务", xml_file: "r任务.xml" do
    field :id, "标识", :integer, min: 1, max: 9999, pri_key: true
    field :name, "名称", :string, min_len: 1
    field :desc, "描述", :string, required: false
    field :task_type, "任务类型", :integer, const: :task_type
    field :pre_task, "前置任务", :integer
    field :level_limit, "等级限制", :integer
    array :reward_assets, "奖励资产", :asset
    field :accept_npc, "接受NPC", :task_npc
    field :commit_npc, "提交NPC", :task_npc
    array :accept_act, "接受时的动作列表", :task_act, required: false
    array :commit_act, "提交时的动作列表", :task_act, required: false
    array :units, "任务单元列表", :task_unit
    field :sort_id, "排序标识", :integer
  end

end
