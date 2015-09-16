defmodule ErrorCode do
  def err_ok,                   do: {0   , "没错"}
  def err_usn_or_psw_wrong,     do: {1001, "用户名或密码错"}
  def err_login_key_expired,    do: {1002, "登录密钥过期"}
  def err_login_key_wrong,      do: {1003, "登录密钥不正确"}
  def err_login_elsewhere,      do: {1004, "您已在其它地方登录"}
  def err_user_exists,          do: {1005, "用户已存在"}
  def err_user_not_exists,      do: {1006, "用户不存在"}
  def err_password_wrong,       do: {1007, "密码不正确"}
  def err_role_exists,          do: {1008, "角色已存在"}
  def err_role_not_exists,      do: {1009, "角色不存在"}
  def err_role_forbidden,       do: {1010, "角色被禁"}
  def err_role_entered,         do: {1011, "角色已进入游戏"}
  def err_not_enough_item,      do: {1101, "物品不足"}
  def err_not_enough_space,     do: {1102, "空间不足"}
  def err_item_cfg_not_found,   do: {1103, "物品配置不存在"}
  def err_item_idx_not_found,   do: {1104, "物品位置不存在"}
  def err_not_enough_coin,      do: {1105, "铜钱不足"}
  def err_not_enough_gold,      do: {1106, "元宝不足"}
  def err_config,               do: {1107, "配置错误"}
end
