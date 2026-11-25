-- 台湾繁体 + 英文翻译（最后加载：要在所有牌、台词都注册完之后处理它们的文字）
-- 规则：
--   · 讲规则的文字：按游戏语言显示（简体 / 繁体中文 / 英文），用游戏原来的字体
--   · 故事里的话（牌底小字、低语、「它来了」）：中文一律台湾繁体 + 霞鹜文楷 TC；
--     英文模式下保留繁体当氛围，下面加一行英文翻译（英文用游戏原字体，保证看得清）
-- 繁体对照表由 tools/make_tw.py 生成（mod/tw_strings.lua）
local CG = CursedGifts
local utf8 = require('utf8') -- mod 加载时 utf8 还不是全局变量（11/25 崩过一次）

CG.TW = assert(SMODS.load_file('tw_strings.lua'))()

-- 逐字对照（给格式化过的字符串兜底，比如「现在是 03:12。」）
local CHAR = {}
for a, b in pairs(CG.TW) do
  local ca, cb = {}, {}
  for _, c in utf8.codes(a) do ca[#ca + 1] = utf8.char(c) end
  for _, c in utf8.codes(b) do cb[#cb + 1] = utf8.char(c) end
  if #ca == #cb then
    for i = 1, #ca do if ca[i] ~= cb[i] then CHAR[ca[i]] = cb[i] end end
  end
end

function CG.T(s)
  if type(s) ~= 'string' then return s end
  if CG.TW[s] then return CG.TW[s] end
  local out = {}
  for _, c in utf8.codes(s) do local ch = utf8.char(c); out[#out + 1] = CHAR[ch] or ch end
  return table.concat(out)
end

function CG.B(en, zh) return { en = en, zh = zh } end

-- 繁体中文语言：规则文字也换成繁体
function CG.L(en, zh)
  local l = CG.lang()
  if l == 'zh_TW' then return CG.T(zh) end
  if l:sub(1, 2) == 'zh' then return zh end
  return en
end

---------------------------------------------------------------- 牌和台词的文字

local function is_story(line) return type(line) == 'string' and line:find('f:cg_ghost', 1, true) end

local function map(v, f)
  if type(v) == 'string' then return f(v) end
  if type(v) ~= 'table' then return v end
  local t = {}
  for k, x in pairs(v) do t[k] = map(x, f) end
  return t
end

local function process(obj)
  local lt = obj.loc_txt
  if type(lt) ~= 'table' then return end
  local zh, en = lt['zh_CN'], lt['en-us']
  if type(zh) ~= 'table' then return end
  -- 繁体中文：全部转繁体
  if not lt['zh_TW'] then lt['zh_TW'] = map(zh, CG.T) end
  local text = zh.text
  if type(text) ~= 'table' then return end
  -- 简体模式：故事小字也用繁体
  local story = {}
  for i, line in ipairs(text) do
    if is_story(line) then text[i] = CG.T(line); story[#story + 1] = text[i] end
  end
  -- 英文模式：规则照旧；故事小字 = 繁体一行（霞鹜文楷）+ 英文翻译（游戏原字体）
  if #story > 0 and type(en) == 'table' and type(en.text) == 'table' and not en.cg_story_done then
    local rules, trans = {}, {}
    for _, line in ipairs(en.text) do
      if is_story(line) then trans[#trans + 1] = (line:gsub(',f:cg_ghost', '')) -- 英文翻译用游戏原字体，小字号下恐怖字体看不清
      else rules[#rules + 1] = line end
    end
    for _, l in ipairs(story) do rules[#rules + 1] = l end
    for _, l in ipairs(trans) do rules[#rules + 1] = l end
    en.text = rules
    en.cg_story_done = true
  end
end

local function mine(key) return type(key) == 'string' and (key:find('^j_cg_') or key:find('^c_cg_') or key:find('^cg_')) end

for _, tbl in ipairs { SMODS.Centers or {}, SMODS.Stickers or {}, SMODS.JimboQuips or {}, SMODS.Challenges or {}, SMODS.Blinds or {}, SMODS.Seals or {}, SMODS.Tags or {} } do
  for key, obj in pairs(tbl) do
    if type(obj) == 'table' and (mine(key) or obj.mod == CG.mod) then process(obj) end
  end
end
