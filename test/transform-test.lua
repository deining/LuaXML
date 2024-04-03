require "busted.runner" ()
kpse.set_program_name "luatex"

local domobject = require "luaxml-domobject"
local transform = require "luaxml-transform"

describe("Basic DOM functions", function() 
  local transformer1 = transform.new()
  local transformer2 = transform.new()
  local text="<b>hello</b>"
  transformer1:add_action("b", "transform1: %s")
  transformer2:add_action("b", "transform2: %s")
  it("should do basic transformations", function()
    assert.same("transform1: hello", transformer1:parse_xml(text))
  end)
  it("should support multiple tranformer objects", function()
    assert.same("transform2: hello", transformer2:parse_xml(text))
  end)
end)

describe("Transform DOM object", function()
  local transformer = transform.new()
  local dom = domobject.parse  [[<section>hello <b>world</b></section>]]
  transformer:add_action("section", "sect: %s")
  transformer:add_action("b", "b: %s")
  it("should transform dom object", function()
    assert.same("sect: hello b: world", transformer:process_dom(dom))
  end)
end)

describe("Selectors support", function()
  local transformer = transform.new()
  local dom1 = domobject.parse  [[<x>hello <b>world</b></x>]]
  local dom2 = domobject.parse  [[<v>hello <b>world</b></v>]]
  local dom3 = domobject.parse  [[<v>hello <b class="hello">world</b></v>]]
  local dom4 = domobject.parse  [[<v>hello <b id="id">world</b></v>]]


  transformer:add_action("x b", "xb: %s")
  transformer:add_action("v b", "vb: %s")
  transformer:add_action(".hello", "hello: %s")
  -- try the alternative syntax for content
  transformer:add_action("#id", "id: @<.>")
  it("should support css selectors", function()
    assert.same("hello xb: world", transformer:process_dom(dom1))
    assert.same("hello vb: world", transformer:process_dom(dom2))
    assert.same("hello hello: world", transformer:process_dom(dom3))
    assert.same("hello id: world", transformer:process_dom(dom4))
  end)

end)

describe("Function test", function()
  local transformer = transform.new()
  local dom1 = domobject.parse  [[<x>hello <b>world</b></x>]]
  transformer:add_custom_action("b", function(el) 
    return "fn: " ..el:get_text()
  end)
  it("should support function transformers", function()
    assert.same("hello fn: world", transformer:process_dom(dom1))
  end)
  local dom2 = domobject.parse [[<x><a>world</a><b>hello, </b></x>]]
  local transformer = transform.new()
  local get_child_element = transform.get_child_element
  local process_children = transform.process_children
  transformer:add_custom_action("x", function(el)
    local first = process_children(get_child_element(el, 1))
    local second = process_children(get_child_element(el, 2))
    return second .. first
  end)
  it("should correctly transform children",function()
    assert.same("hello, world", transformer:process_dom(dom2))
  end)
  -- try the new syntax
  local transformer2 = transform.new()
  transformer2:add_action("x", "@<2>@<1>")
  it("should correctly transform children using the @<number> syntax", function()
    assert.same("hello, world", transformer2:process_dom(dom2))
  end)
  
end)

describe("Attribute conversion", function()
  local transformer = transform.new()
  local dom1 = domobject.parse  [[<x><b>hello</b> <b style="red">world</b></x>]]
  transformer:add_action("b", "%s")
  transformer:add_action("b[style]", "s=@{style} %s")
  it("should transform attributes", function()
    assert.same("hello s=red world", transformer:process_dom(dom1))
  end)
end)

describe("Escapes", function()
  local transformer1 = transform.new()
  local transformer2 = transform.new()
  local dom1 = domobject.parse  [[<x>{}&amp;</x>]]
  -- reset unicodes table in the second object
  transformer2.unicodes = {}
  it("should correctly escape special characters", function()
    assert.same('\\{\\}\\&', transformer1:process_dom(dom1))
    -- the second object shouldn't escape special characters
    assert.same('{}&', transformer2:process_dom(dom1))
  end)
  
end)

describe("children selection templates", function()
  local transformer = transform.new()
  local dom = domobject.parse "<x><a>hello</a> insignificant <a>world</a></x>"
  transformer:add_action("x", "@<a>", {separator=", "})
  it("selects just <a> elements", function()
    assert.same("hello, world", transformer:process_dom(dom))
  end)
end)


describe("support pseudo classes", function()
  local transformer = transform.new()
  local dom = domobject.parse "<x><a>hello</a>, <a>world</a></x>"
  transformer:add_action("a:last-child", "last")
  it("select last child", function()
    assert.same("hello, last", transformer:process_dom(dom))
  end)
end)

describe("children transformation", function()
  local transformer = transform.new()
  local dom = domobject.parse "<mfrac><mrow>a+b</mrow><mfrac><mi>a</mi><mi>b</mi></mfrac></mfrac>"
  transformer:add_action("mfrac","\\frac{@<1>}{@<2>}")
  -- transformer:add_action("mfrac","\\frac{@<.>}")
  it("correctly process child elements", function()  
    assert.same("\\frac{a+b}{\\frac{a}{b}}",transformer:process_dom(dom))
  end)
  
end)

describe("remove action", function()
  local transformer = transform.new()
  local dom = domobject.parse "<x><a>first</a>, <b>second</b></x>"
  transformer:add_action("a", "hello")
  transformer:add_action("b", "world")
  it("should change words", function()
    assert.same("hello, world", transformer:process_dom(dom))
  end)
  it("should change only the first word", function()
    -- remove action for the <b> element
    transformer:reset_actions("b")
    assert.same("hello, second", transformer:process_dom(dom))
  end)
end)
