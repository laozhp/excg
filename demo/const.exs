defmodule Const do

  def item_type, do: %{
    equip: {1, "装备"},
    gem:   {2, "宝石"},
    prop:  {3, "道具"},
    stuff: {4, "材料"},
    gift:  {5, "礼包"},
    }

  def equip_type, do: %{
    not_equip: {0, "不是装备"},
    weapon:    {1, "武器"},
    }

  def item_use_type, do: %{
    no_use: {0, "不能直接使用"},
    assets: {1, "使用后产出资产"},
    }

  def asset_type, do: %{
    coin: {1, "铜钱"},
    gold: {2, "金币"},
    exp:  {3, "经验"},
    }

  def asset_opt_type, do: %{
    exp_time: {1, "过期时间"},
    }

  def notice_type, do: %{
    do_not_notice: {0, "不通知"},
    system_notice: {1, "系统通知"},
    }

  def task_type, do: %{
    main: {1, "主线"},
    side: {2, "支线"},
    }

  def task_act_type, do: %{
    give_item:  {1, "给予物品"},
    give_skill: {2, "给予技能"},
    give_mount: {3, "给予坐骑"},
    give_vip:   {4, "给予VIP"},
    }

  def task_unit_type, do: %{
    kill_monster: {1, "杀怪[scene_id,monster_id,num]"},
    collect_item: {2, "收集物品[item_id,num]"},
    }

  def npc_type, do: %{
    unknown: {0, "未知"},
    }

  def scene_type, do: %{
    main_town: {1, "主城"},
    town:      {2, "城镇"},
    dungeon:   {3, "副本"},
    }

  def aoi_type, do: %{
    whole_map: {1, "全地图"},
    nine_grid: {9, "九宫格"},
    }

end
