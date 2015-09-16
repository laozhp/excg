defmodule Cfun do
  import Excg.Parser.Data, only: [parse_const: 3, parse_error: 2]

  def random_asset(excg, data, _opts) do
    if data.min_num > data.max_num do
      parse_error(excg, "最小值#{data.min_num}比最大值#{data.max_num}还大")
    end
    %{data | avg_num: (data.min_num + data.max_num) / 2}
  end

  def asset(excg, data, opts) do
    const = Keyword.get(opts, :const, :asset_type)
    cond do
      v = excg.ref.pk_map[data] -> v
      v = excg.ref.name_map[data] -> v
      true -> parse_const(excg, excg.const_map[const], data)
    end
  end

  def item_name(excg, data, opts) do
    const = Keyword.get(opts, :const, :asset_type)
    map = excg.const_map[const]
    if map.id_map[data] || map.name_map[data] || map.desc_map[data] do
      parse_error(excg, "物品名称#{inspect data}与常量冲突")
    end
    data
  end

  def item_disp(excg, data, _opts) do
    row = excg.row_data
    row.id + 2 + (data || 0)
  end

end
