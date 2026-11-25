-- 和别的 mod 混着玩时的定位（参考 Cryptid 的诅咒稀有度、LobotomyCorp 的专属卡包）：
--   1. 诅咒牌不进商店 / 卡包 / 随机生成的牌池：诅咒不是买来的，是被送来的
--   2. 纸钱包：商店里和别的卡包一起出现，开包选一张鬼月牌，可能夹着一份诅咒
--   3. 恐惧条先藏着，第一次碰到鬼月牌才浮现（不碰就像没装这个 mod）
-- 在 memory.lua 之后、tw.lua 之前加载
local CG = CursedGifts

---------------------------------------------------------------- 1. 诅咒牌退出牌池

local function cursed_def(c) return c and c.cg_cursed end

for key, c in pairs(SMODS.Centers) do
  if type(key) == 'string' and key:find('^j_cg_') and cursed_def(c) and not c.in_pool then
    c.in_pool = function() return false end -- 指定 key 生成（转送回来、纸钱包、测试）不受影响
  end
end

---------------------------------------------------------------- 2. 纸钱包

SMODS.Atlas { key = 'packs', path = 'packs.png', px = 71, py = 95 }

local function ghost_keys(cursed)
  local out = {}
  for k, c in pairs(G.P_CENTERS) do
    if k:find('^j_cg_') and (cursed_def(c) and true or false) == cursed then out[#out + 1] = k end
  end
  table.sort(out) -- pairs 顺序不固定，排序后同种子结果才一样
  return out
end
CG.ghost_keys = ghost_keys

local function taken_keys()
  local seen = {}
  for _, area in ipairs { G.jokers, G.pack_cards } do
    for _, c in ipairs(area and area.cards or {}) do seen[c.config.center.key] = true end
  end
  return seen
end

CG.PACK_CURSE_ODDS = 0.3 -- 每个格子有 30% 是诅咒，一包最多一张

SMODS.Booster {
  key = 'joss_paper', atlas = 'packs', pos = { x = 0, y = 0 },
  kind = 'cg_ghost', weight = 1, cost = 5, discovered = true, draw_hand = false,
  config = { extra = 3, choose = 1 },
  loc_txt = {
    ['en-us'] = { name = 'Joss Paper Pack', group_name = 'Joss Paper', text = {
      'Choose {C:attention}#1#{} of up to',
      '{C:attention}#2#{} Ghost Month Jokers.',
      'One of them may be a {C:red}curse{}',
      '{C:cg_ink,f:cg_ghost}Someone left it at the door. No name on it.{}',
    } },
    ['zh_CN'] = { name = '纸钱包', group_name = '纸钱包', text = {
      '从最多 {C:attention}#2#{} 张鬼月小丑里',
      '选 {C:attention}#1#{} 张，',
      '里面可能夹着一份{C:red}诅咒{}',
      '{C:cg_ink,f:cg_ghost}有人放在门口的，没写名字。{}',
    } },
  },
  create_card = function(self, card, i)
    local seen = taken_keys()
    local has_curse = false
    for _, c in ipairs(G.pack_cards and G.pack_cards.cards or {}) do
      if cursed_def(c.config.center) then has_curse = true end
    end
    local want_curse = not has_curse and pseudorandom('cg_pack_curse') < CG.PACK_CURSE_ODDS
    local pool = {}
    for _, k in ipairs(ghost_keys(want_curse)) do if not seen[k] then pool[#pool + 1] = k end end
    if #pool == 0 then -- 鬼月牌都拿光了：退回普通小丑
      return { set = 'Joker', area = G.pack_cards, skip_materialize = true, key_append = 'cg_pack' }
    end
    local key = pseudorandom_element(pool, pseudoseed('cg_pack_pick'))
    return { set = 'Joker', key = key, area = G.pack_cards, skip_materialize = true, key_append = 'cg_pack' }
  end,
  ease_background_colour = function(self)
    ease_colour(G.C.DYN_UI.MAIN, HEX('5a0f14'))
    ease_background_colour { new_colour = HEX('3a0a0e'), special_colour = G.C.BLACK, contrast = 2 }
  end,
}

---------------------------------------------------------------- 3. 恐惧条：碰到才浮现

function CG.awake()
  local g = G.GAME
  return g and (g.cg_awake or g.cg_touched or CG.dread() > 0 or #(g.cg_returning or {}) > 0) and true or false
end

local make_ui_ref = CG.make_ui
function CG.make_ui()
  if not CG.awake() then
    if CG.box then CG.box:remove(); CG.box = nil end
    return
  end
  if G.GAME then G.GAME.cg_awake = true end -- 读旧档：已经碰过的直接显示，不再说「你收下了」
  return make_ui_ref()
end

-- 第一次碰到：恐惧条浮现 + 一声心跳 + 一句低语
function CG.awaken()
  if not G.GAME or G.GAME.cg_awake then return end
  G.GAME.cg_awake = true
  G.E_MANAGER:add_event(Event({ trigger = 'after', delay = 0.3, func = function()
    CG.make_ui()
    if CG.box then CG.box:juice_up(0.4, 0.4) end
    CG.play('heartbeat', 0.9, 0.7)
    return true
  end }))
  CG.say('you accepted it', '你收下了')
end

local function watch(fn)
  return function(...)
    local before = G.GAME and G.GAME.cg_touched
    local r = fn(...)
    if G.GAME and G.GAME.cg_touched and not before and G.STAGE == G.STAGES.RUN then CG.awaken() end
    return r
  end
end

Card.add_to_deck = watch(Card.add_to_deck)
CG.add_dread = watch(CG.add_dread)
