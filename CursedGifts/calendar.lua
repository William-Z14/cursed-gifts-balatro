-- 鬼月日历：碰过本 mod 的局，底注 4 固定是「中元普渡」，底注 8 固定是「关鬼门」（最终 Boss）
-- 没碰过的局不出现（不打扰只是装了 mod 的玩家）。卡面先用占位图（tools/make_blinds.py），等 Muse 的正式图
local CG = CursedGifts

SMODS.Atlas { key = 'blinds', path = 'blinds.png', px = 34, py = 34, atlas_table = 'ANIMATION_ATLAS', frames = 21 }

local function active(key)
  return G.GAME and G.GAME.blind and G.GAME.blind.config and G.GAME.blind.config.blind
      and G.GAME.blind.config.blind.key == key and not G.GAME.blind.disabled
end

-- 中元普渡：交一份礼物，换恐惧下降（喘口气的一关）
SMODS.Blind {
  key = 'pudu', atlas = 'blinds', pos = { x = 0, y = 0 }, discovered = true,
  boss = { min = 4, max = 4 }, mult = 2, dollars = 5, boss_colour = HEX('b8862b'),
  config = { extra = { down = 3 } },
  loc_txt = {
    ['en-us'] = { name = 'Ghost Festival', text = { 'Sell or pass on a Joker:', '{C:attention}-3{} Dread' } },
    ['zh_CN'] = { name = '中元普渡', text = { '卖出或转送一张小丑：', '恐惧 {C:attention}-3{}' } },
  },
  in_pool = function() return false end, -- 只由日历放进来
}

-- 关鬼门：最后一夜，每出一手 +1 恐惧
SMODS.Blind {
  key = 'gate', atlas = 'blinds', pos = { x = 0, y = 1 }, discovered = true,
  boss = { showdown = true, min = 8 }, mult = 2, dollars = 8, boss_colour = HEX('4a0f18'),
  loc_txt = {
    ['en-us'] = { name = 'The Gate Closes', text = { 'Each hand played', 'adds {C:red}+1{} Dread' } },
    ['zh_CN'] = { name = '关鬼门', text = { '每出一手牌', '{C:red}+1{} 恐惧' } },
  },
  in_pool = function() return false end,
}

-- 日历：换 Boss 的时候，到了日子就是它们
local new_blind_ref = SMODS.get_new_blind
function SMODS.get_new_blind(blind_type)
  local g = G.GAME
  if (blind_type == nil or blind_type == 'boss') and g and g.cg_touched and g.round_resets then
    local a = g.round_resets.ante
    local key = (a == 4 and 'bl_cg_pudu') or (a >= 8 and a % 8 == 0 and 'bl_cg_gate') or nil
    if key and G.P_BLINDS[key] then
      pcall(SMODS.add_boss_to_used_table, key, 'boss')
      return key
    end
  end
  return new_blind_ref(blind_type)
end

-- 效果挂在 mod 的全局 calculate 上
local calc_ref = CG.mod.calculate
CG.mod.calculate = function(self, context)
  local r = calc_ref and calc_ref(self, context)
  if not G.GAME then return r end
  if active('bl_cg_pudu') and context.selling_card and context.card and context.card.ability.set == 'Joker' then
    if CG.dread() > 0 then
      CG.add_dread(-math.min(3, CG.dread()))
      CG.play('muyu', 1, 0.8)
      G.GAME.blind:wiggle()
    end
  end
  if active('bl_cg_gate') and context.before and not context.blueprint then
    CG.add_dread(1)
    G.GAME.blind:wiggle()
  end
  return r
end
