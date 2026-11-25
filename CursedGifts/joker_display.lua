-- JokerDisplay 对接：装了 JokerDisplay 的玩家，在小丑下面实时看到加成（没装就不加载）
local CG = CursedGifts
local D = JokerDisplay.Definitions

local function xm(field) -- 「X 数字」带框，和原版显示一致
  return { { border_nodes = { { text = 'X' }, { ref_table = 'card.joker_display_values', ref_value = field or 'x', retrigger_type = 'exp' } } } }
end
local function plus(field) return { { text = '+' }, { ref_table = 'card.joker_display_values', ref_value = field or 'mult', retrigger_type = 'mult' } } end
local function gen(card) return CG.gen(card) end

-- 当前选中的牌型里有没有对子
local function has_pair()
  local text, poker_hands = JokerDisplay.evaluate_hand()
  return text ~= 'Unknown' and poker_hands and poker_hands['Pair'] and next(poker_hands['Pair']) and true or false
end

D.j_cg_monkey_paw = { text = xm(), calc_function = function(c) local e = c.ability.extra; c.joker_display_values.x = e.xmult + e.step * gen(c) end }
D.j_cg_under_bed = { text = xm(), calc_function = function(c) c.joker_display_values.x = 1 + c.ability.extra.per * CG.dread() end }
D.j_cg_heirloom = { text = xm(), calc_function = function(c) local e = c.ability.extra; c.joker_display_values.x = e.xmult + e.step * gen(c) end }
D.j_cg_mosina = { text = xm(), calc_function = function(c) c.joker_display_values.x = c.ability.extra.xmult end }
D.j_cg_water_ghost = { text = xm(), calc_function = function(c) c.joker_display_values.x = 1 + c.ability.extra.per * (G.GAME.cg_jdestroyed or 0) end }
D.j_cg_city_god = { text = xm(), calc_function = function(c) c.joker_display_values.x = c.ability.extra.x end }
D.j_cg_doll = { text = xm(), calc_function = function(c)
  local e = c.ability.extra
  c.joker_display_values.x = has_pair() and (e.xmult + e.step * gen(c)) or 1
end }

D.j_cg_chain_letter = { text = plus(), text_config = { colour = G.C.MULT }, calc_function = function(c)
  c.joker_display_values.mult = (c.ability.extra.mult + 2 * gen(c)) * (G.jokers and #G.jokers.cards or 0)
end }
D.j_cg_footsteps = { text = plus(), text_config = { colour = G.C.MULT }, calc_function = function(c)
  c.joker_display_values.mult = c.ability.extra.per * CG.dread()
end }
D.j_cg_poe = { text = plus(), text_config = { colour = G.C.MULT }, calc_function = function(c) c.joker_display_values.mult = c.ability.extra.mult end }
D.j_cg_pudu = { text = plus(), text_config = { colour = G.C.MULT }, calc_function = function(c)
  local e = c.ability.extra
  c.joker_display_values.mult = e.per * (G.GAME.cg_passed or 0) + e.per_offer * (e.offer or 0)
end }

D.j_cg_exorcist = {
  text = { { text = '+$' }, { ref_table = 'card.joker_display_values', ref_value = 'd' } }, text_config = { colour = G.C.GOLD },
  calc_function = function(c) c.joker_display_values.d = c.ability.extra.per * CG.dread() end,
}
D.j_cg_effigy = {
  reminder_text = { { text = '(' }, { ref_table = 'card.joker_display_values', ref_value = 'left' }, { text = ')' } },
  calc_function = function(c) local e = c.ability.extra; c.joker_display_values.left = e.rounds + gen(c) - e.held end,
}
D.j_cg_qiye_baye = {
  retrigger_function = function(playing_card, scoring_hand, held_in_hand, joker_card)
    if held_in_hand or not has_pair() then return 0 end
    return JokerDisplay.calculate_joker_triggers(joker_card)
  end,
}
