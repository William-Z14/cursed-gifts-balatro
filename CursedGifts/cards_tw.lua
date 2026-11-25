-- 台湾鬼月篇新牌（16–20）。设定见 docs/world-tw.md
-- 只用包装函数挂到 main.lua 的现有逻辑上；main.lua 末尾加载本文件。
local CG = CursedGifts

CG.ORDER.poe, CG.ORDER.pudu, CG.ORDER.mosina, CG.ORDER.water_ghost, CG.ORDER.zhongkui = 15, 16, 17, 18, 19

local function eor(context)
  return context.end_of_round and context.main_eval and not context.blueprint
end

local function holding(key)
  if not G.jokers then return nil end
  for _, j in ipairs(G.jokers.cards) do
    if j.config.center.key == key and not j.debuff and not j.getting_sliced then return j end
  end
end

-- 记这局一共转送了几张（普渡供桌用）
local pass_on_ref = CG.pass_on
function CG.pass_on(card)
  -- 普渡供桌自己转送不算，否则 $0 卖、2 回合回来就能白刷
  if card.config.center.key ~= 'j_cg_pudu' then
    G.GAME.cg_passed = (G.GAME.cg_passed or 0) + 1
    if holding('j_cg_pudu') then CG.play('muyu', 1, 0.7) end -- 供桌上多了一份
  end
  return pass_on_ref(card)
end


-- 16 掷筊：打出对子时掷（筊杯本来就是一对）
CG.J {
  key = 'poe', rarity = 1, cost = 4, blueprint_compat = true,
  config = { extra = { mult = 4, xmult = 2, up = 2 } },
  loc_txt = {
    ['en-us'] = { name = 'Moon Blocks', text = {
      '{C:mult}+#1#{} Mult. With a {C:attention}Pair{}, cast:',
      '{C:green}1 in 2{} {X:mult,C:white} X#2# {}, {C:green}1 in 4{} {C:red}+#3#{} Dread',
      '{C:cg_ink,f:cg_ghost}Ask again.{}',
    } },
    ['zh_CN'] = { name = '掷筊', text = {
      '{C:mult}+#1#{} 倍率，含{C:attention}对子{}时掷筊：',
      '{C:green}1/2{} {X:mult,C:white} X#2# {}，{C:green}1/4{} {C:red}+#3#{} 恐惧',
      '{C:cg_ink,f:cg_ghost}再問一次。{}',
    } },
  },
  loc_vars = function(self, info_queue, card)
    local e = card.ability.extra
    return { vars = { e.mult, e.xmult, e.up } }
  end,
  calculate = function(self, card, context)
    local e = card.ability.extra
    if context.before and not context.blueprint and next(context.poker_hands['Pair']) then
      CG.play('jiaobei', 0.95 + 0.1 * pseudorandom('cg_poe_pitch'), 0.9)
      local r = pseudorandom('cg_poe')
      if r < 0.5 then
        e.holy = true
        CG.msg(card, CG.L('Yes', '圣筊'), G.C.GREEN)
      elseif r < 0.75 then
        CG.msg(card, CG.L('It laughs', '笑筊'), G.C.UI.TEXT_INACTIVE)
      else
        CG.add_dread(e.up, card)
        CG.msg(card, CG.L('No', '阴筊'), G.C.RED)
      end
    end
    if context.joker_main then
      if e.holy then return { mult = e.mult, xmult = e.xmult } end
      return { mult = e.mult }
    end
    if context.after and not context.blueprint then e.holy = nil end
  end,
}

-- 17 普渡供桌
CG.J {
  key = 'pudu', rarity = 2, cost = 6, cg_gift = true, blueprint_compat = true,
  config = { extra = { per = 6, per_offer = 2, offer = 0 } },
  loc_txt = {
    ['en-us'] = { name = 'Offering Table', text = {
      '{C:mult}+#1#{} Mult per card {C:attention}passed on{}',
      '{C:mult}+#3#{} per {C:tarot}Tarot{}/{C:planet}Planet{} used',
      '{C:inactive}(Currently {C:mult}+#2#{C:inactive}){}',
      '{C:cg_ink,f:cg_ghost}Feed them, and they leave you be.{}',
    } },
    ['zh_CN'] = { name = '普渡供桌', text = {
      '每转送一张牌 {C:mult}+#1#{} 倍率',
      '每用一张{C:tarot}塔罗{}/{C:planet}星球{} {C:mult}+#3#{}',
      '{C:inactive}（当前 {C:mult}+#2#{C:inactive}）{}',
      '{C:cg_ink,f:cg_ghost}好兄弟吃飽了，就不找你。{}',
    } },
  },
  loc_vars = function(self, info_queue, card)
    local e = card.ability.extra
    local n = (G.GAME and G.GAME.cg_passed) or 0
    return { vars = { e.per, e.per * n + e.per_offer * (e.offer or 0), e.per_offer } }
  end,
  calculate = function(self, card, context)
    local e = card.ability.extra
    if context.using_consumeable and not context.blueprint and context.consumeable
        and (context.consumeable.ability.set == 'Tarot' or context.consumeable.ability.set == 'Planet') then
      e.offer = (e.offer or 0) + 1
      CG.msg(card, CG.L('Offered', '供上了'), G.C.MULT)
    end
    local m = e.per * (G.GAME.cg_passed or 0) + e.per_offer * (e.offer or 0)
    if context.joker_main and m > 0 then return { mult = m } end
  end,
}

-- 18 魔神仔：计分的人头牌可能被牵进山里；回来时变成石头牌（嘴里塞满草和泥）
CG.J {
  key = 'mosina', rarity = 2, cost = 6, cg_cursed = true, blueprint_compat = true,
  config = { extra = { odds = 4, step = 0.25, xmult = 1, rounds = 3 } },
  loc_txt = {
    ['en-us'] = { name = 'Mo-sin-a', text = {
      'Scored {C:attention}face{} cards: {C:green}#1# in #2#{}',
      'vanish for {X:mult,C:white} +X#3# {} Mult,',
      'return as {C:attention}Stone{}',
      '{C:cg_ink,f:cg_ghost}They found him with grass in his mouth.{}',
    } },
    ['zh_CN'] = { name = '魔神仔', text = {
      '计分的{C:attention}人头牌{} {C:green}#1#/#2#{} 被牵走',
      '每张 {X:mult,C:white} +X#3# {}，变成{C:attention}石头牌{}回来',
      '{C:cg_ink,f:cg_ghost}找到的時候，嘴裡塞滿了草。{}',
    } },
  },
  loc_vars = function(self, info_queue, card)
    local e = card.ability.extra
    local num, den = SMODS.get_probability_vars(card, 1, e.odds, 'cg_mosina')
    info_queue[#info_queue + 1] = G.P_CENTERS.m_stone
    return { vars = { num, den, e.step, e.xmult, e.rounds } }
  end,
  calculate = function(self, card, context)
    local e = card.ability.extra
    if context.destroy_card and context.cardarea == G.play and not context.blueprint then
      local c = context.destroy_card
      if c:is_face() and not c.cg_led and SMODS.pseudorandom_probability(card, 'cg_mosina', 1, e.odds, 'cg_mosina') then
        c.cg_led = true
        e.xmult = e.xmult + e.step
        G.GAME.cg_hills = G.GAME.cg_hills or {}
        table.insert(G.GAME.cg_hills, { suit = c.base.suit, rank = c.base.value, rounds = e.rounds })
        CG.msg(card, CG.L('Led away', '被牵走了'), HEX('5f7a3a'))
        return { remove = true }
      end
    end
    if context.joker_main and e.xmult > 1 then return { xmult = e.xmult } end
  end,
}

-- 山里的人：每回合结束数一次，到了就以石头牌回到牌组
local tick_ref = CG.tick_returns
function CG.tick_returns()
  local q, keep = G.GAME.cg_hills or {}, {}
  for _, e in ipairs(q) do
    e.rounds = e.rounds - 1
    if e.rounds > 0 then keep[#keep + 1] = e else
      G.E_MANAGER:add_event(Event({ trigger = 'after', delay = 0.4, func = function()
        local ok = pcall(SMODS.add_card, { set = 'Enhanced', enhancement = 'm_stone', suit = e.suit, rank = e.rank, area = G.deck, key_append = 'cg_hills' })
        if ok then
          CG.play('return', 0.85, 0.7)
          CG.say('it came back with mud in its mouth', '它回来了，嘴里都是泥')
        end
        return true
      end }))
    end
  end
  G.GAME.cg_hills = keep
  return tick_ref()
end

-- 19 水鬼：这局每有一张小丑被销毁 +X0.5（「它」带走的算两次）
CG.J {
  key = 'water_ghost', rarity = 3, cost = 8, cg_cursed = true, blueprint_compat = true,
  config = { extra = { per = 0.5 } },
  loc_txt = {
    ['en-us'] = { name = 'Water Ghost', text = {
      '{X:mult,C:white} +X#1# {} Mult per Joker destroyed',
      '{C:inactive}(Currently {X:mult,C:white} X#2# {C:inactive}){}',
      '{C:cg_ink,f:cg_ghost}It is waiting for a replacement too.{}',
    } },
    ['zh_CN'] = { name = '水鬼', text = {
      '每有小丑被销毁 {X:mult,C:white} +X#1# {} 倍率',
      '{C:inactive}（当前 {X:mult,C:white} X#2# {C:inactive}）{}',
      '{C:cg_ink,f:cg_ghost}它也在等交替。{}',
    } },
  },
  loc_vars = function(self, info_queue, card)
    local n = (G.GAME and G.GAME.cg_jdestroyed) or 0
    return { vars = { card.ability.extra.per, 1 + card.ability.extra.per * n } }
  end,
  calculate = function(self, card, context)
    local n = G.GAME.cg_jdestroyed or 0 -- main.lua：start_dissolve 记 +1，「它」碎掉的记 +2
    if context.joker_main and n > 0 then return { xmult = 1 + card.ability.extra.per * n } end
  end,
}

-- 20 跳钟馗：「它」要来时代替整场，自己碎掉
CG.J {
  key = 'zhongkui', rarity = 3, cost = 7, blueprint_compat = true, eternal_compat = false, -- 会自己碎，不能带永恒
  config = { extra = { xmult = 1.2 } },
  loc_txt = {
    ['en-us'] = { name = 'Zhong Kui Dance', text = {
      'Scored {C:attention}Kings{} give {X:mult,C:white} X#1# {} Mult',
      'Drives off {C:attention}It{} once, then shatters',
      '{C:cg_ink,f:cg_ghost}The dancer must not look back.{}',
    } },
    ['zh_CN'] = { name = '跳钟馗', text = {
      '计分的 {C:attention}K{} {X:mult,C:white} X#1# {} 倍率',
      '替你赶走{C:attention}它{}一次，然后碎掉',
      '{C:cg_ink,f:cg_ghost}跳的人不能回頭。{}',
    } },
  },
  loc_vars = function(self, info_queue, card) return { vars = { card.ability.extra.xmult } } end,
  calculate = function(self, card, context)
    -- 钟馗就是那张 K
    if context.individual and context.cardarea == G.play and context.other_card:get_id() == 13 then
      return { xmult = card.ability.extra.xmult }
    end
  end,
}

local it_comes_ref = CG.it_comes
function CG.it_comes()
  local z = holding('j_cg_zhongkui')
  if not z then return it_comes_ref() end
  z.getting_sliced = true
  G.E_MANAGER:add_event(Event({ blocking = false, blockable = false, func = function()
    if G.STATE == G.STATES.HAND_PLAYED or G.STATE == G.STATES.DRAW_TO_HAND or not G.jokers then return false end
    if z.removed or z.area ~= G.jokers then -- 等的这段时间钟馗没了：它照常来
      it_comes_ref(); return true
    end
    CG.play('temple_gong', 1, 0.9)
    CG.play('suona', 0.8, 0.7)
    z:juice_up(1, 1)
    CG.msg(z, CG.L('Driven off', '赶走了'), HEX('c8352b'))
    CG.say('not this time', '这次不算')
    G.GAME.cg_driven = (G.GAME.cg_driven or 0) + 1
    SMODS.destroy_cards({ z }, { bypass_eternal = true, immediate = true, destroy_func = function(c) c:shatter(); return true end })
    CG.reset_dread()
    return true
  end }))
end

---------------------------------------------------------------- 鬼月的低语

-- 随机池加入鬼月禁忌
for _, w in ipairs {
  { "don't answer if it calls your name", '有人叫你名字，别回头' },
  { 'your shoes are pointing at the bed', '你的鞋尖朝着床' },
  { "don't whistle tonight", '今晚别吹口哨' },
  { 'someone tapped your shoulder', '有人拍了你的肩膀' },
  { 'it needs a replacement', '它需要一个交替' },
} do table.insert(CG.WHISPERS, w) end

-- 每个底注第一个盲注：鬼门的进度（一局 = 一个鬼月）
CG.GATE = {
  [1] = { 'the gate is open', '鬼门开了' },
  [3] = { 'they are all out now', '它们都出来了' },
  [5] = { 'half the month is gone', '这个月过了一半' },
  [7] = { 'pudu is over. they are still hungry', '普渡过了。它们还饿' },
  [8] = { 'the gate closes tonight', '今晚关鬼门' },
}
local mw_ref = CG.maybe_whisper
function CG.maybe_whisper()
  local a = G.GAME.round_resets and G.GAME.round_resets.ante
  local g = a and CG.GATE[a]
  if g and G.GAME.cg_gate_said ~= a and CG.on('fourth_wall') and not G.GAME.won
      and G.GAME.cg_touched and not G.GAME.cg_w_taken then
    G.GAME.cg_gate_said = a
    CG.play('temple_gong', a == 8 and 0.85 or 1, 0.45) -- 鬼门：庙口的锣
    CG.whisper(CG.B(g[1], g[2]))
    return
  end
  return mw_ref()
end
