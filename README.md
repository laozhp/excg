# Excg -- Elixir code generator for game client and server


## Licence

The MIT License (MIT)


## 目的

* 基于同一份定义文件，生成客户端和服务端的代码
* 使用Excel编辑xml文件，方便编辑配置数据，添加颜色、标注
* 可以指定字段的约束条件，工具可以自动对字段数据进行检查


## 安装使用

* 安装Erlang 17.0或者更新的版本
* 安装Elixir 1.0或者更新的版本
* `git clone https://github.com/laozhp/excg`
* `cd excg`
* Update dependencies: `mix deps.get`
* Play with demo: `mix excg.code`

### 基本流程

* 新建或者编辑一个配置定义文件(必须以_cfg.exs结尾)，如`item_cfg.exs`

```elixir
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
```

* 用命令`mix excg.xml`，生成xml文件

* 编辑xml文件，增加配置数据

![item_xml](https://raw.githubusercontent.com/laozhp/excg/master/priv/item_xml.png)

* 用命令`mix excg.code`，生成代码文件

![item_cfg](https://raw.githubusercontent.com/laozhp/excg/master/priv/item_cfg.png)


## 主要特点

* 支持任意层数的自定义类型
* 支持按字段的数据校验定义
* 支持自定义的数据校验函数
* 支持自定义的输出模板和自定义函数
* 支持常量和引用，使用时常量可以填id/name/desc，引用可以填id/name


## 主要功能

基于Elixir宏和模板的代码生成器，主要用于：

* 常量的定义、代码生成
* 错误码的定义、代码生成
* 配置数据的格式定义、数据校验、代码生成
* 通信数据定义、运行时数据校验、代码生成

数据编辑时使用简化的JSON语法JsonCut，工具可以使用Excel XML


## JsonCut语法

相对JSON语法做以下简化：

* 当没有歧义时，字符串可以去掉前后的双引号
* 去掉对象的属性名，按照属性定义的先后顺序，列出属性值
* 属性值为默认值的可以不写
* 如果从后面开始，连续为默认值的，连分隔符也可以不写


## 宏

### array

格式：array name, desc, type, opts \\ []

定义一个数组字段，可用在config, message, type宏里。

### config

格式：config name, desc, opts \\ [], [do: block]

定义一个配置，里面由field/array组成。

### field

格式：field name, desc, type, opts \\ []

定义一个字段，可用在config, message, type宏里。

### message

格式：message id, name, desc, opts \\ [], [do: block]

定义一个通信消息，里面由field/array组成。

### module

格式：module id, name, desc, opts \\ []

定义一个通信模块。

### type

格式：type name, desc, opts \\ [], [do: block]

定义一个类型，里面由field/array组成。

类型是全局的(配置和消息共用)，不可重名。


## 字段类型

* `:boolean` - 布尔值，接受输入true, false, T, F, 1, 0
* `:float`
* `:integer`
* `:string`
* `:virtual` - 虚拟字段(计算字段)，字段不出现在XML里，出现在生成的代码里
* 自定义类型


## 宏选项

`type`

* cfun - 指定该类型自定义的检查函数名和选项，函数在cfun.exs里定义


`type`.`field`

* cfun - 指定该字段自定义的检查函数名和选项，函数在cfun.exs里定义
* const - 整数常量，只允许填写常量表里定义的值
* default - 字段的默认值，默认为字段类型的默认值
* max - 整数/浮点数的最大值(含)，字符串的最大字节长度(含)
* max_len - 字符串的最大字符长度(含)
* min - 整数/浮点数的最小值(含)，字符串的最小字节长度(含)
* min_len - 字符串的最小字符长度(含)
* refrence - 引用表，该字段的值是另一个表的主键的值
* required - 字段不能为空，默认为true


`type`.`array`

* cfun - 指定该字段自定义的检查函数名和选项，函数在cfun.exs里定义
* const - 整数常量，只允许填写常量表里定义的值
* default - 字段的默认值，默认为字段类型的默认值
* max - 整数/浮点数的最大值(含)，字符串的最大字节长度(含)
* max_len - 字符串的最大字符长度(含)
* min - 整数/浮点数的最小值(含)，字符串的最小字节长度(含)
* min_len - 字符串的最小字符长度(含)
* refrence - 引用表，该字段的值是另一个表的主键的值
* required - 字段不能为空，默认为true

* ext_type - 扩展类型，目前只支持:tuple，将数组输出为tuple
* default_items - 数组字段的默认值
* max_items - 数组元素的最大数量(含)
* min_items - 数组元素的最小数量(含)
* order_items - 指定数组元素的顺序，:asc为升序，:desc为降序
* seq_items - 指定数组元素的连续形式，格式为{起始数值, 步长数值}
* uinque_items - 数组元素是否唯一，默认为false


`config`  暂不支持的选项：multi_field_index

* cfun - 指定该配置表自定义的检查函数名和选项，函数在cfun.exs里定义，
         该检查发生在字段检查之后
* cli_out_dir - 指定客户端输出的目录，默认为{app}/mod/{mod_name}
* cli_out_file - 指定客户端输出的文件名，默认为{cfg_name}_cfg.{lang}
* mod_name - 输出的模块目录名，可以将多个配置输出到一个模块目录，默认为cfg_name
* singleton - 默认false，如果true表示配置数据只有一行，不需要主键
* srv_out_dir - 指定服务端输出的目录，默认为{app}/mod/{mod_name}
* srv_out_file - 指定服务端输出的文件名，默认为{cfg_name}_cfg.{lang}
* xml_file - 指定输出的xml文件名，默认为{cfg_name}.xml


`config`.`field`

* cfun - 指定该字段自定义的检查函数名和选项，函数在cfun.exs里定义
* cli_out - 客户端输出，默认为true
* const - 整数常量，只允许填写常量表里定义的值
* default - 字段的默认值，默认为字段类型的默认值
* eex - 是否允许eex模板，默认false，只能用在字符串字段
* max - 整数/浮点数的最大值(含)，字符串的最大字节长度(含)
* max_len - 字符串的最大字符长度(含)
* min - 整数/浮点数的最小值(含)，字符串的最小字节长度(含)
* min_len - 字符串的最小字符长度(含)
* order - 指定输入数据的顺序，:asc为升序，:desc为降序
* pri_key - 该字段是这个表的主键，一个表有且只有一个主键
* refrence - 引用表，该字段的值是另一个表的主键的值
* required - 字段不能为空，默认为true
* sequence - 指定输入数据的连续形式，格式为{起始数值, 步长数值}
* srv_out - 服务端输出，默认为true
* unique - 该字段记录的值是否唯一，默认为false


`config`.`array`

* cfun - 指定该字段自定义的检查函数名和选项，函数在cfun.exs里定义
* cli_out - 客户端输出，默认为true
* const - 整数常量，只允许填写常量表里定义的值
* default - 字段的默认值，默认为字段类型的默认值
* eex - 是否允许eex模板，默认false，只能用在字符串字段
* max - 整数/浮点数的最大值(含)，字符串的最大字节长度(含)
* max_len - 字符串的最大字符长度(含)
* min - 整数/浮点数的最小值(含)，字符串的最小字节长度(含)
* min_len - 字符串的最小字符长度(含)
* order - 指定输入数据的顺序，:asc为升序，:desc为降序
* refrence - 引用表，该字段的值是另一个表的主键的值
* required - 字段不能为空，默认为true
* srv_out - 服务端输出，默认为true
* unique - 该字段记录的值是否唯一，默认为false

* ext_type - 扩展类型，目前只支持:tuple，将数组输出为tuple
* default_items - 数组字段的默认值
* max_items - 数组元素的最大数量(含)
* min_items - 数组元素的最小数量(含)
* order_items - 指定数组元素的顺序，:asc为升序，:desc为降序
* seq_items - 指定数组元素的连续形式，格式为{起始数值, 步长数值}
* uinque_items - 数组元素是否唯一，默认为false


## 自定义检查函数

```elixir
defmodule Cfun do
  import Excg.Parser.Data, only: [parse_const: 3, parse_error: 2]

  def random_asset(excg, data, _opts) do
    if data.min_num > data.max_num do
      parse_error(excg, "最小值#{data.min_num}比最大值#{data.max_num}还大")
    end
    data
  end
end
```


## 常量

```elixir
defmodule Const do
  def item_type, do: %{
    equip: {1, "装备"},
    gem:   {2, "宝石"},
    prop:  {3, "道具"},
    stuff: {4, "材料"},
    gift:  {5, "礼包"},
    }
end
```


## 错误码

```elixir
defmodule ErrorCode do
  def err_ok,                   do: {0   , "没错"}
  def err_usn_or_psw_wrong,     do: {1001, "用户名或密码错"}
  def err_login_key_expired,    do: {1002, "登录密钥过期"}
end
```


## 注意事项

* 只能在通信消息的尾部增删字段
* pri_key, unique, cfun, refrence, order, sequence
  选项需要在全部xml数据解析完后，再进行检查
* cfun, refrence选项可以在子字段里定义
* 如果定义了refrence选项，并且字段类型为integer，跳过解析
* 如果定义了cfun，跳过refrence的检查
