defmodule Excg.Parser.JsonCutTest do
  use ExUnit.Case, async: true

  import Excg.Parser.JsonCut

  test "basic" do
    assert parse("") == {:ok, ""}
    assert parse("abcd") == {:ok, "abcd"}
    assert parse("中文") == {:ok, "中文"}
    assert parse("1234") == {:ok, "1234"}
    assert parse("12.34") == {:ok, "12.34"}
    assert parse("\"\\u0045\"") == {:ok, "E"}
    assert parse("\"\\U00000045\"") == {:ok, "E"}
    assert parse("[]") == {:ok, []}
    assert parse("{}") == {:ok, {}}
  end

  test "space" do
    assert parse(" \t \r\n ") == {:ok, ""}
    assert parse(" abcd ") == {:ok, "abcd"}
    assert parse(" [ ] ") == {:ok, []}
    assert parse("{  }") == {:ok, {}}
  end

  test "quoted" do
    assert parse(" \" ab\\\", [中] {cd} \" ") == {:ok, " ab\", [中] {cd} "}
  end

  test "empty field" do
    assert parse("[,]") == {:ok, ["", ""]}
    assert parse("{ , }") == {:ok, {"", ""}}
    assert parse("{,,}") == {:ok, {"", "", ""}}
    assert parse("{,,,}") == {:ok, {"", "", "", ""}}
  end

  test "compose1" do
    assert parse("[{a,b,[{1,{c,500,[]}}]}]") ==
      {:ok, [{"a","b",[{"1",{"c","500",[]}}]}]}
  end

  test "compose2" do
    assert parse("[{a,,[{,{\"b,c\",500}}]}]") ==
      {:ok, [{"a","",[{"",{"b,c","500"}}]}]}
  end

  test "compose3" do
    assert parse("[{1,3,[{5,{2,500,[]}},{5,{3,30,[]}}]},\n" <>
                 " {2,4,[{3,{2,50,[]}},{7,{3,3,[]}}]}]") == {:ok, [
      {"1","3",[{"5",{"2","500",[]}},{"5",{"3","30",[]}}]},
      {"2","4",[{"3",{"2","50",[]}},{"7",{"3","3",[]}}]}]}
  end

end
