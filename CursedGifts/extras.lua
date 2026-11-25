-- v0.2 补齐「成熟模组都有的东西」：悬浮说明、鬼月牌组、传奇小丑、符印 + 平安符、优惠券、鬼门标签
-- 混玩原则：除了牌组本身，新东西都只在「碰过本 mod 的局」进池子（G.GAME.cg_touched）
-- 卡面先用占位图（tools/make_extras.py），Muse 正式图到了直接替换 assets/{1x,2x}/extras.png、legends.png、tags.png
local CG = CursedGifts

local function touched() return G.GAME and G.GAME.cg_touched and true or false end

SMODS.Atlas { key = 'extras', path = 'extras.png', px = 71, py = 95 }  -- 0 牌组背面 / 1 平安符 / 2 符印 / 3 供品 / 4 超渡
SMODS.Atlas { key = 'legends', path = 'legends.png', px = 71, py = 95 } -- 第 0 行底图，第 1 行浮出来的头像
SMODS.Atlas { key = 'tags', path = 'tags.png', px = 34, py = 34 }

---------------------------------------------------------------- 1. 悬浮说明：恐惧 / 诅咒礼物 / 转送

local TIPS = {
  cg_dread = {
    ['en-us'] = { name = 'Dread', text = {
      'When full, {C:attention}It{} comes for a Joker',
      'Each visit it comes {C:attention}closer{}',
      'The third time, it takes {C:red}you{}',
    } },
    ['zh_CN'] = { name = '恐惧', text = {
      '满了，{C:attention}它{}就来：交出一张小丑',
      '它每来一次就{C:attention}更近{}一些',
      '第三次，它带走的是{C:red}你{}',
    } },
  },
  cg_gift_rule = {
    ['en-us'] = { name = 'Cursed', text = {
      'Never sold, only {C:attention}given{}',
      "Can't be destroyed",
      'Sell: {C:attention}passes on{}, back in {C:attention}3{} rounds',
    } },
    ['zh_CN'] = { name = '诅咒', text = {
      '商店不卖，只会被{C:attention}送{}来，毁不掉',
      '卖掉就是{C:attention}转送{}：{C:attention}3{} 回合后回来，更强',
    } },
  },
  cg_pass_on = {
    ['en-us'] = { name = 'Passing On', text = {
      'Sell: {C:attention}passes on{}, back in {C:attention}2{}',
      'rounds, a little stronger',
    } },
    ['zh_CN'] = { name = '转送', text = {
      '卖掉就是{C:attention}转送{}：{C:attention}2{} 回合后回来，更强',
    } },
  },
}

local process_ref = CG.mod.process_loc_text
CG.mod.process_loc_text = function(...)
  if process_ref then process_ref(...) end
  for key, t in pairs(TIPS) do
    if not t.zh_TW and CG.T then
      t.zh_TW = { name = CG.T(t.zh_CN.name), text = {} }
      for i, l in ipairs(t.zh_CN.text) do t.zh_TW.text[i] = CG.T(l) end
    end
    SMODS.process_loc_text(G.localization.descriptions.Other, key, t)
  end
end

-- 给本 mod 的牌挂悬浮说明，像原版一样最多一个：诅咒牌挂「诅咒」，普通礼物挂「转送」
-- 「恐惧」的说明挂在恐惧条上（main.lua CG.make_ui），不再每张牌都弹
for key, c in pairs(SMODS.Centers) do
  if type(key) == 'string' and (key:find('^j_cg_') or key:find('^c_cg_')) and (c.cg_cursed or c.cg_gift) then
    local tip = c.cg_cursed and 'cg_gift_rule' or 'cg_pass_on'
    local lv = c.loc_vars
    c.loc_vars = function(self, info_queue, card)
      local r = lv and lv(self, info_queue, card) or nil
      info_queue[#info_queue + 1] = { set = 'Other', key = tip }
      return r
    end
  end
end

---------------------------------------------------------------- 2. 符印 + 平安符（幻灵）

SMODS.Seal {
  key = 'talisman', atlas = 'extras', pos = { x = 2, y = 0 }, badge_colour = HEX('d4a017'), discovered = true,
  loc_txt = {
    ['en-us'] = { name = 'Talisman Seal', label = 'Talisman Seal', text = { 'When this card scores,', '{C:attention}-1{} Dread' } },
    ['zh_CN'] = { name = '符印', label = '符印', text = { '这张牌计分时，', '恐惧 {C:attention}-1{}' } },
  },
  calculate = function(self, card, context)
    if context.main_scoring and context.cardarea == G.play and CG.dread() > 0 then
      CG.add_dread(-1)
      return { message = CG.L('Warded', '镇'), colour = G.C.GOLD }
    end
  end,
}

SMODS.Consumable {
  key = 'peace_talisman', set = 'Spectral', atlas = 'extras', pos = { x = 1, y = 0 },
  cost = 4, discovered = true, config = { max_highlighted = 2 },
  loc_txt = {
    ['en-us'] = { name = 'Peace Talisman', text = { 'Add a {C:attention}Talisman Seal{}', 'to up to {C:attention}#1#{} selected cards', '{C:cg_ink,f:cg_ghost}From the temple. Keep it on you.{}' } },
    ['zh_CN'] = { name = '平安符', text = { '给最多 {C:attention}#1#{} 张选中的牌', '加上{C:attention}符印{}', '{C:cg_ink,f:cg_ghost}廟裡求來的，要隨身帶著。{}' } },
  },
  loc_vars = function(self, info_queue, card)
    info_queue[#info_queue + 1] = { set = 'Other', key = 'cg_talisman_seal' }
    return { vars = { card.ability.max_highlighted } }
  end,
  in_pool = function() return touched() end,
  can_use = function(self, card)
    return G.hand and #G.hand.highlighted >= 1 and #G.hand.highlighted <= card.ability.max_highlighted
  end,
  use = function(self, card, area, copier)
    for _, c in ipairs(G.hand.highlighted) do
      G.E_MANAGER:add_event(Event({ trigger = 'after', delay = 0.2, func = function()
        c:set_seal('cg_talisman', nil, true); c:juice_up(0.3, 0.4)
        return true
      end }))
    end
    CG.play('muyu', 1.1, 0.6)
    G.E_MANAGER:add_event(Event({ trigger = 'after', delay = 0.3, func = function() G.hand:unhighlight_all(); return true end }))
  end,
}

---------------------------------------------------------------- 3. 鬼月牌组

SMODS.Back {
  key = 'ghost_month', atlas = 'extras', pos = { x = 0, y = 0 }, unlocked = true, discovered = true,
  loc_txt = {
    ['en-us'] = { name = 'Ghost Month Deck', text = {
      'Start with a {C:red}Red Envelope{}',
      'and {C:attention}4{} {C:attention}Talisman Seals{}',
      '{C:inactive}(The Ghost Month calendar is on){}',
    } },
    ['zh_CN'] = { name = '鬼月牌组', text = {
      '开局自带{C:red}路边红包{}',
      '和 {C:attention}4{} 张{C:attention}符印{}牌',
      '{C:inactive}（鬼月日历开启）{}',
    } },
  },
  apply = function(self, back)
    G.GAME.cg_touched = true
    G.E_MANAGER:add_event(Event({ func = function()
      if not G.playing_cards or not G.jokers then return false end
      local pool = {}
      for _, c in ipairs(G.playing_cards) do pool[#pool + 1] = c end
      for i = 1, math.min(4, #pool) do
        local c, k = pseudorandom_element(pool, pseudoseed('cg_deck_seal'))
        table.remove(pool, k)
        c:set_seal('cg_talisman', true, true)
      end
      SMODS.add_card { key = 'j_cg_red_envelope' }
      return true
    end }))
  end,
}

---------------------------------------------------------------- 4. 优惠券：中元供品 → 超渡

SMODS.Voucher {
  key = 'offering', atlas = 'extras', pos = { x = 3, y = 0 }, cost = 10, discovered = true, unlocked = true,
  loc_txt = {
    ['en-us'] = { name = 'Ghost Offerings', text = { '{C:attention}-1{} Dread at the', 'end of every round' } },
    ['zh_CN'] = { name = '中元供品', text = { '每回合结束时', '恐惧 {C:attention}-1{}' } },
  },
  in_pool = function() return touched() end,
}
SMODS.Voucher {
  key = 'deliverance', atlas = 'extras', pos = { x = 4, y = 0 }, cost = 10, discovered = true, unlocked = true,
  requires = { 'v_cg_offering' },
  loc_txt = {
    ['en-us'] = { name = 'Deliverance', text = { '{C:attention}It{} needs {C:attention}2{} more Dread', 'before it comes' } },
    ['zh_CN'] = { name = '超渡', text = { '恐惧要多 {C:attention}2{} 点，', '{C:attention}它{}才会来' } },
  },
  in_pool = function() return touched() end,
}

local threshold_ref = CG.threshold
function CG.threshold()
  local t = threshold_ref()
  if G.GAME and G.GAME.used_vouchers and G.GAME.used_vouchers.v_cg_deliverance then t = t + 2 end
  return t
end

---------------------------------------------------------------- 5. 鬼门标签：免费开一个纸钱包

SMODS.Tag {
  key = 'gate', atlas = 'tags', pos = { x = 0, y = 0 }, discovered = true, min_ante = 2,
  loc_txt = {
    ['en-us'] = { name = 'Gate Tag', text = { 'Gives a free', '{C:attention}Joss Paper Pack{}' } },
    ['zh_CN'] = { name = '鬼门标签', text = { '免费获得一个', '{C:attention}纸钱包{}' } },
  },
  in_pool = function() return touched() end,
  apply = function(self, tag, context)
    if context.type ~= 'new_blind_choice' then return end
    local lock = tag.ID
    G.CONTROLLER.locks[lock] = true
    tag:yep('+', HEX('c8352b'), function()
      local key = 'p_cg_joss_paper'
      local card = Card(G.play.T.x + G.play.T.w / 2 - G.CARD_W * 1.27 / 2, G.play.T.y + G.play.T.h / 2 - G.CARD_H * 1.27 / 2,
        G.CARD_W * 1.27, G.CARD_H * 1.27, G.P_CARDS.empty, G.P_CENTERS[key], { bypass_discovery_center = true, bypass_discovery_ui = true })
      card.cost = 0
      card.from_tag = true
      G.FUNCS.use_card({ config = { ref_table = card } })
      card:start_materialize()
      G.CONTROLLER.locks[lock] = nil
      return true
    end)
    tag.triggered = true
    return true
  end,
}

---------------------------------------------------------------- 6. 传奇：七爷八爷、城隍爷（只从灵魂牌出，且只在碰过本 mod 的局）

local function legend(def)
  def.rarity, def.cost, def.atlas = 4, 20, 'legends'
  def.unlocked, def.discovered = true, true
  def.in_pool = function() return touched() end
  return SMODS.Joker(def)
end

legend {
  key = 'qiye_baye', pos = { x = 0, y = 0 }, soul_pos = { x = 0, y = 1 }, blueprint_compat = true,
  loc_txt = {
    ['en-us'] = { name = 'Lord Seven & Lord Eight', text = {
      'If hand contains a {C:attention}Pair{},',
      '{C:attention}retrigger{} all scored cards',
      '{C:cg_ink,f:cg_ghost}Tonight they walk you home.{}',
    } },
    ['zh_CN'] = { name = '七爷八爷', text = {
      '牌型含{C:attention}对子{}时，',
      '计分的牌{C:attention}再触发{}一次',
      '{C:cg_ink,f:cg_ghost}一高一矮，今晚送你回家。{}',
    } },
  },
  calculate = function(self, card, context)
    if context.repetition and context.cardarea == G.play and context.poker_hands and next(context.poker_hands['Pair'] or {}) then
      return { repetitions = 1 }
    end
  end,
}

legend {
  key = 'city_god', pos = { x = 1, y = 0 }, soul_pos = { x = 1, y = 1 }, blueprint_compat = true,
  config = { extra = { x = 1, step = 0.2 } },
  loc_txt = {
    ['en-us'] = { name = 'City God', text = {
      'Gains {X:mult,C:white} X#1# {} Mult per',
      'point of Dread {C:attention}lifted{}',
      '{C:inactive}(Currently {X:mult,C:white} X#2# {C:inactive}){}',
      '{C:cg_ink,f:cg_ghost}Every deed is in his ledger.{}',
    } },
    ['zh_CN'] = { name = '城隍爷', text = {
      '每消掉 1 点恐惧',
      '获得 {X:mult,C:white} X#1# {} 倍率',
      '{C:inactive}（当前 {X:mult,C:white} X#2# {C:inactive}）{}',
      '{C:cg_ink,f:cg_ghost}善惡簿上，每一筆都記著。{}',
    } },
  },
  loc_vars = function(self, info_queue, card)
    return { vars = { card.ability.extra.step, card.ability.extra.x } }
  end,
  calculate = function(self, card, context)
    if context.joker_main and card.ability.extra.x > 1 then return { xmult = card.ability.extra.x } end
  end,
}

-- 城隍爷记账：恐惧往下走多少，就记多少
local function lifted(n)
  if n <= 0 or not G.jokers then return end
  for _, j in ipairs(G.jokers.cards) do
    if j.config.center.key == 'j_cg_city_god' and not j.debuff then
      j.ability.extra.x = j.ability.extra.x + j.ability.extra.step * n
      CG.msg(j, CG.L('Recorded', '记上了'), G.C.MULT)
    end
  end
end
local add_ref = CG.add_dread
function CG.add_dread(n, card)
  local before = CG.dread()
  local r = add_ref(n, card)
  if n and n < 0 then lifted(before - CG.dread()) end
  return r
end
local reset_ref = CG.reset_dread
function CG.reset_dread()
  local before = CG.dread()
  local r = reset_ref()
  lifted(before)
  return r
end

---------------------------------------------------------------- 优惠券效果（挂在 mod 的全局 calculate 上）

local calc_ref = CG.mod.calculate
CG.mod.calculate = function(self, context)
  local r = calc_ref and calc_ref(self, context)
  if G.GAME and context.end_of_round and not context.individual and not context.repetition and not context.blueprint
      and G.GAME.cg_offer_round ~= G.GAME.round then
    G.GAME.cg_offer_round = G.GAME.round
    if G.GAME.used_vouchers.v_cg_offering and CG.dread() > 0 then CG.add_dread(-1) end
  end
  return r
end
