defmodule Excg.Builder.ExcelXml do
  import SweetXml

  def update_file(excg) do
    filename = Path.join(excg.xml_dir, excg.filename)
    {doc, _rest} = :xmerl_scan.file(filename)
    doc = update_doc(excg, doc)
    xml =
      [:xmerl.export([doc], Excg.Builder.ExcelXml), "\n"]
      |> to_string
      |> String.replace(" xmlns:", "\n xmlns:")
      |> String.replace(" x:FullRows=", "\n   x:FullRows=")
    if elem(:os.type, 0) == :win32 do
      xml = String.replace(xml, "\n", "\r\n")
    end
    File.write!(filename, xml)
  end

  def unquote(:"#xml-inheritance#")(), do: []

  def unquote(:"#text#")(text), do: :xmerl_lib.export_text(text)

  def unquote(:"#element#")(tag, data, attrs, _parents, _e) do
    data = case tag do
      :Comment ->
        data
        |> List.to_string
        |> String.replace("\n", "&#10;")
        |> String.replace("<ss:Data ", "<ss:Data\n       ")
      :Data -> String.replace(List.to_string(data), "\n", "&#10;")
      _ -> data
    end
    :xmerl_lib.markup(tag, attrs, data)
  end

  def unquote(:"#root#")(data, _attrs, [], _e) do
    ['<?xml version="1.0"?>\n',
     '<?mso-application progid="Excel.Sheet"?>\n',
     data]
  end

  def cfg_rcs(_excg, map, fld_name) do
    fld = map[fld_name]
    opts = fld.opts
    required = Keyword.get(opts, :required, true)
    cli_out  = Keyword.get(opts, :cli_out,  true)
    srv_out  = Keyword.get(opts, :srv_out,  true)
    name_list = [
      (if required, do: "r", else: ""),
      (if cli_out,  do: "c", else: ""),
      (if srv_out,  do: "s", else: ""),
      ]
    desc_list = [
      (if required, do: "required", else: nil),
      (if cli_out,  do: "cli_out",  else: nil),
      (if srv_out,  do: "srv_out",  else: nil),
      ]
    desc_list = Enum.filter(desc_list, &(&1))
    {Enum.join(name_list), Enum.join(desc_list, ", ")}
  end

  def cfg_fld_desc(excg, map, fld_name) do
    %{kind: kind, desc: desc, type: type} = map[fld_name]
    if kind == :field do
      cfg_fld_type_desc(excg, desc, type)
    else
      ["[", cfg_fld_type_desc(excg, desc, type), "]"]
    end
  end

  def cfg_type_opts(excg, map, fld_name) do
    %{kind: kind, desc: fld_desc, type: type, opts: opts} = map[fld_name]
    name = if kind == :field, do: "#{type}", else: "[#{type}]"

    default = Keyword.get(opts, :default)
    min = Keyword.get(opts, :min)
    max = Keyword.get(opts, :max)
    refrence = Keyword.get(opts, :refrence)
    desc_list = [
      (if default, do: "default: #{default}", else: nil),
      (if min, do: "min: #{min}", else: nil),
      (if max, do: "max: #{max}", else: nil),
      (if refrence, do: "refrence: #{refrence}", else: nil),
      ]
    desc_list = Enum.filter(desc_list, &(&1))
    desc = Enum.join(desc_list, "\n")

    const_list = cfg_const_list(excg, fld_desc, type, opts)
    const_list = fmt_const_list(excg, const_list)
    desc = if desc == "" do
      Enum.join(const_list, "\n\n")
    else
      Enum.join([desc] ++ const_list, "\n\n")
    end
    {name, desc}
  end

  def cfg_misc_opts(_excg, map, fld_name) do
    fld = map[fld_name]
    opts = fld.opts
    pri_key = Keyword.get(opts, :pri_key, false)
    unique = Keyword.get(opts, :unique, false)
    uinque_items = Keyword.get(opts, :uinque_items, false)
    name_list = [
      (if pri_key, do: "pk", else: nil),
      (if unique, do: "u", else: nil),
      (if uinque_items, do: "ui", else: nil),
      ]
    desc_list = [
      (if pri_key, do: "pri_key", else: nil),
      (if unique, do: "unique", else: nil),
      (if uinque_items, do: "uinque_items", else: nil),
      ]
    name_list = Enum.filter(name_list, &(&1))
    desc_list = Enum.filter(desc_list, &(&1))
    name = Enum.join(name_list, ",")
    desc = Enum.join(desc_list, "\n")
    {name, desc}
  end

  defp cfg_fld_type_desc(excg, desc, type) do
    if Excg.basic_type?(type) do
      desc
    else
      type = excg.type_map[type]
      map = type.map
      list = for fld_name <- type.list, map[fld_name].type != :virtual do
        cfg_fld_desc(excg, map, fld_name)
      end
      ["{", Enum.join(list, ","), "}"]
    end
  end

  defp cfg_const_list(excg, fld_desc, type, opts) do
    Enum.reverse(cfg_const_list(excg, fld_desc, type, opts, []))
  end

  defp cfg_const_list(excg, fld_desc, type, opts, acc) do
    const = Keyword.get(opts, :const)
    if const, do: acc = [{fld_desc, const} | acc]
    cfun = Keyword.get(opts, :cfun)
    if cfun do
      cfun_const = Keyword.get(elem(cfun, 1), :const)
      if cfun_const != const, do: acc = [{fld_desc, cfun_const} | acc]
    end
    if Excg.basic_type?(type) or type == :virtual do
      acc
    else
      type = excg.type_map[type]
      map = type.map
      Enum.reduce(type.list, acc, fn(fld_name, acc) ->
        %{desc: desc, type: type, opts: opts} = map[fld_name]
        cfg_const_list(excg, desc, type, opts, acc)
      end)
    end
  end

  defp fmt_const_list(excg, const_list) do
    for {fld_desc, const_type} <- const_list do
      header = "#{fld_desc}：常量，#{const_type}"
      const = elem(List.keyfind(excg.const_list, const_type, 0), 1)
      li = for {id, name, desc} <- const, do: "#{id}, #{name}, #{desc}"
      Enum.join([header | li], "\n")
    end
  end

  defp update_doc(excg, doc) do
    table = doc |> xpath(~x"/Workbook/Worksheet/Table")
    rows = table |> xpath(~x"Row"l)
    [row1, row2, row3, row4, row5, row6 | _tail] = rows
    excg = excg |> parse_fld_names(row1) |> extract_empty_cell(row1)
    table =
      table
      |> update_column_count(excg)
      |> update_row(excg, row1, &{"#{&3}", cfg_fld_desc(&1, &2, &3)})
      |> update_row(excg, row2, &cfg_type_opts/3)
      |> update_row(excg, row3, &cfg_rcs/3)
      |> update_row(excg, row4, &cfg_misc_opts/3)
      |> update_row(excg, row5, fn(_, _, _) -> {"", ""} end)
      |> update_row(excg, row6, &{&2[&3].desc, (&1; "")})
    update_xpath(doc, "/Workbook/Worksheet/Table", table)
  end

  defp update_xpath(doc, path, new_elem) do
    path = Path.dirname(path)
    if path == "/" do
      new_elem
    else
      elem = xpath(doc, %SweetXpath{path: String.to_char_list(path)})
      pos = xmlElement(new_elem, :pos)
      content = xmlElement(elem, :content)
      content = List.keyreplace(content, pos, xmlElement(:pos), new_elem)
      new_elem = xmlElement(elem, content: content)
      update_xpath(doc, path, new_elem)
    end
  end

  defp parse_fld_names(excg, row) do
    map = excg.cfg.map
    {_index, list} = Enum.reduce(
      xpath(row, ~x"Cell"l), {0, []},
      fn(cell, {index, list}) ->
        ss_index = xpath(cell, ~x"@ss:Index")
        if ss_index do
          count = List.to_integer(ss_index) - index - 1
          index = index + count
          list = List.duplicate(nil, count) ++ list
        end
        data = xpath(cell, ~x"Data/text()")
        field = if data, do: List.to_atom(data), else: nil
        unless map[field], do: field = nil
        {index + 1, [field | list]}
      end)
    list = Enum.reduce(excg.cfg.list, list, fn(fld, list) ->
      if Enum.member?(list, fld) or map[fld].type == :virtual do
        list
      else
        [fld | list]
      end
    end)
    %{excg | fld_names: List.to_tuple(Enum.reverse(list))}
  end

  defp extract_empty_cell(excg, row) do
    data = xpath(row, ~x"Cell/Data")
    parents = xmlElement(data, :parents)
    pos = xmlElement(data, :pos)
    attributes = [xmlAttribute(
      name: :"ss:Type", nsinfo: {'ss', 'Type'},
      parents: Keyword.merge(parents, Data: pos),
      pos: 1, value: 'String', normalized: false)]
    data = xmlElement(data, attributes: attributes, content: [])
    cell = xmlElement(xpath(row, ~x"Cell"), attributes: [], content: [data])
    %{excg | empty_cell: cell}
  end

  defp update_column_count(table, excg) do
    size = tuple_size(excg.fld_names)
    attributes = xmlElement(table, :attributes)
    attr = List.keyfind(
      attributes, :"ss:ExpandedColumnCount", xmlAttribute(:name))
    count = List.to_integer(xmlAttribute(attr, :value))
    if count < size do
      attr = xmlAttribute(attr, value: "#{size}")
      attributes = List.keyreplace(
        attributes, :"ss:ExpandedColumnCount", xmlAttribute(:name), attr)
      table = xmlElement(table, attributes: attributes)
    end
    table
  end

  defp update_row(table, excg, row, data_fun) do
    row_pos = xmlElement(row, :pos)
    {index, cells} = Enum.reduce(
      xpath(row, ~x"Cell"l), {0, []},
      fn(cell, {index, cells}) ->
        ss_index = xpath(cell, ~x"@ss:Index")
        if ss_index do
          count = List.to_integer(ss_index) - index - 1
          if count > 0 do
            {index, cells} = insert_cells(
              excg, count, data_fun, row_pos, index, cells)
          end
        end
        update_cell(excg, cell, data_fun, row_pos, index, cells)
      end)
    count = tuple_size(excg.fld_names) - index
    if count > 0 do
      {_index, cells} = insert_cells(
        excg, count, data_fun, row_pos, index, cells)
    end
    row = insert_text(row, Enum.reverse(cells))
    content =
      xmlElement(table, :content)
      |> List.keyreplace(row_pos, xmlElement(:pos), row)
    xmlElement(table, content: content)
  end

  defp insert_cells(excg, count, data_fun, row_pos, index, cells) do
    Enum.reduce(1..count, {index, cells},
      fn(_i, {index, cells}) ->
        update_cell(excg, nil, data_fun, row_pos, index, cells)
      end)
  end

  defp update_cell(excg, cell, data_fun, row_pos, index, cells) do
    cell = if cell do
      xmlElement(cell, attributes: [])
    else
      excg.empty_cell
    end
    fld_name = elem(excg.fld_names, index)
    if fld_name do
      {name, desc} = data_fun.(excg, excg.cfg.map, fld_name)
      if name != "" do
        cell = update_name(excg, name, cell)
      end
      if desc != "" do
        cell = update_desc(excg, desc, cell)
      end
    end
    cell =
      cell
      |> xmlElement(pos: index_to_cell_pos(index))
      |> update_parents(Row: row_pos)
    {index + 1, [cell | cells]}
  end

  defp update_name(excg, text, cell) do
    text = text |> to_string |> String.to_char_list
    data = new_data(excg.empty_cell, text)
    content = xmlElement(cell, :content)
    content = List.keystore(content, :Data, xmlElement(:name), data)
    xmlElement(cell, content: content)
  end

  defp update_desc(excg, text, cell) do
    text = text |> to_string |> String.to_char_list
    comment = new_comment(excg.empty_cell, text)
    content = xmlElement(cell, :content)
    content = List.keystore(content, :Comment, xmlElement(:name), comment)
    xmlElement(cell, content: content)
  end

  defp update_parents(elem, parents) do
    parents = Keyword.merge(xmlElement(elem, :parents), parents)
    name = xmlElement(elem, :name)
    pos = xmlElement(elem, :pos)
    next_parents = [{name, pos} | parents]
    attributes = for attr <- xmlElement(elem, :attributes) do
      parents = Keyword.merge(xmlAttribute(attr, :parents), next_parents)
      xmlAttribute(attr, parents: parents)
    end
    content = for node <- xmlElement(elem, :content) do
      case :erlang.element(1, node) do
        :xmlElement -> update_parents(node, next_parents)
        :xmlText ->
          parents = Keyword.merge(xmlText(node, :parents), next_parents)
          xmlText(node, parents: parents)
        :xmlComment ->
          parents = Keyword.merge(xmlComment(node, :parents), next_parents)
          xmlComment(node, parents: parents)
        _ -> node
      end
    end
    xmlElement(
      elem, parents: parents, attributes: attributes, content: content)
  end

  defp new_data(empty_cell, text) do
    content = [xmlText(pos: 1, value: text)]
    xmlElement(xpath(empty_cell, ~x"Data"), content: content)
  end

  defp new_comment(empty_cell, text) do
    attributes = [xmlAttribute(
      name: :"ss:Author", nsinfo: {'ss', 'Author'},
      pos: 1, value: '', normalized: false)]
    content = [new_ss_data(empty_cell, text)]
    xmlElement(
      empty_cell, name: :Comment, expanded_name: :Comment,
      pos: 20, attributes: attributes, content: content)
  end

  defp new_ss_data(empty_cell, text) do
    attributes = [xmlAttribute(
      name: :xmlns, pos: 1, value: 'http://www.w3.org/TR/REC-html40',
      normalized: false)]
    content = [xmlText(pos: 1, value: text)]
    xmlElement(
      empty_cell, name: :"ss:Data", expanded_name: :"ss:Data",
      pos: 1, attributes: attributes, content: content)
  end

  defp index_to_cell_pos(index), do: (index + 1) * 2

  defp insert_text(row, cells) do
    text = xmlText(pos: 1, value: '\n    ')
    {pos, list} = Enum.reduce(cells, {2, [text]}, fn(cell, {pos, list}) ->
      {pos + 2, [xmlText(text, pos: pos + 1), cell | list]}
    end)
    list = [xmlText(pos: pos + 1, value: '\n   ') | tl(list)]
    xmlElement(row, content: Enum.reverse(list))
  end

end
