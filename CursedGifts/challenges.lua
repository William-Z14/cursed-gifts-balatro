-- 鬼月挑战（参考 SDM_0 / Seven Sins：挑战不用画图，能把一种玩法讲清楚）
-- + 第一次启动选恐怖强度 + 内容警告（参考 Cryptid 首次启动选 gameset、LobotomyCorp 的内容警告）
local CG = CursedGifts

---------------------------------------------------------------- 挑战规则文字

local RULES = {
  cg_threshold = { 'It comes at {C:red}#1#{} Dread', '恐惧到 {C:red}#1#{} 它就来' },
  cg_start_dread = { 'Start with {C:red}#1#{} Dread', '开局恐惧 {C:red}#1#{}' },
  cg_door = { 'After each Boss Blind, someone leaves', '每过一个 Boss 盲注，门口会多一份' },
  cg_door2 = { 'a {C:attention}gift{} at your door (maybe a {C:red}curse{})', '{C:attention}礼物{}（也可能是{C:red}诅咒{}）' },
  cg_only_kui = { 'No Exorcist. Only {C:attention}Zhong Kui{} drives it away, once', '没有法师，只有{C:attention}跳钟馗{}能赶走它一次' },
}

local process_ref = CG.mod.process_loc_text
CG.mod.process_loc_text = function(...)
  if process_ref then process_ref(...) end
  local vt = G.localization.misc.v_text
  for id, t in pairs(RULES) do vt['ch_c_' .. id] = { CG.L(t[1], t[2]) } end
end

local function name(en, zh)
  return { ['en-us'] = { name = en }, ['zh_CN'] = { name = zh } } -- 繁体由 tw.lua 补
end

---------------------------------------------------------------- 三个挑战

-- 抓交替：开局就被送了两份诅咒，而且它来得更早
SMODS.Challenge {
  key = 'replacement', loc_txt = name('Find a Replacement', '抓交替'),
  rules = { custom = { { id = 'cg_threshold', value = 9 } }, modifiers = {} },
  jokers = { { id = 'j_cg_red_envelope' }, { id = 'j_cg_mosina' } },
}

-- 七月半：普渡那天，门口一直有人放东西
SMODS.Challenge {
  key = 'zhongyuan', loc_txt = name('Ghost Festival', '七月半'),
  rules = { custom = { { id = 'cg_start_dread', value = 6 }, { id = 'cg_door' }, { id = 'cg_door2' } }, modifiers = {} },
  jokers = { { id = 'j_cg_pudu' }, { id = 'j_cg_doll' } },
  calculate = function(self, context)
    if context.end_of_round and context.main_eval and not context.blueprint
        and G.GAME.blind and G.GAME.blind.boss and G.GAME.cg_door_round ~= G.GAME.round then
      G.GAME.cg_door_round = G.GAME.round
      CG.door_gift()
    end
  end,
}

-- 跳钟馗：法师不来了，三份诅咒在身上，只剩钟馗
SMODS.Challenge {
  key = 'zhongkui', loc_txt = name('Dance of Zhong Kui', '跳钟馗'),
  rules = { custom = { { id = 'cg_threshold', value = 9 }, { id = 'cg_only_kui' } }, modifiers = {} },
  jokers = { { id = 'j_cg_zhongkui' }, { id = 'j_cg_monkey_paw' }, { id = 'j_cg_water_ghost' } },
  restrictions = { banned_cards = { { id = 'j_cg_exorcist' } }, banned_tags = {}, banned_other = {} },
}

-- 门口的礼物：一半好礼物、一半诅咒；位置满了就放不下（它会再来）
function CG.door_gift()
  G.E_MANAGER:add_event(Event({ trigger = 'after', delay = 0.8, func = function()
    if not G.jokers or #G.jokers.cards >= G.jokers.config.card_limit then return true end
    local keys = CG.ghost_keys(pseudorandom('cg_door') < 0.5)
    local have = {}
    for _, j in ipairs(G.jokers.cards) do have[j.config.center.key] = true end
    local pool = {}
    for _, k in ipairs(keys) do if not have[k] then pool[#pool + 1] = k end end
    if #pool == 0 then return true end
    local card = SMODS.add_card { key = pseudorandom_element(pool, pseudoseed('cg_door_pick')) }
    if card then
      CG.play('footstep', 0.9, 0.6) -- 门外的脚步声
      CG.msg(card, CG.L('At your door', '放在门口的'), HEX('9a7d6a'))
    end
    return true
  end }))
end

-- 开局恐惧
local start_run_ref = Game.start_run
function Game:start_run(args)
  start_run_ref(self, args)
  local m = G.GAME and G.GAME.modifiers
  if m and m.cg_start_dread and not G.GAME.cg_chal_init then
    G.GAME.cg_chal_init = true
    G.GAME.cg_dread = m.cg_start_dread
    CG.update_ui(); CG.make_ui(); CG.tint()
  end
  CG.update_ui() -- 挑战改了门槛，「0/13」要跟着变
end

---------------------------------------------------------------- 第一次启动：选恐怖强度

CG.INTENSITY = {
  full = { flash = true, jumpscare = true },
  gentle = { flash = false, jumpscare = false },
}

function CG.pick_intensity(which)
  for k, v in pairs(CG.INTENSITY[which]) do CG.cfg[k] = v end
  CG.cfg.intro_done = true
  if not CG.TESTING then SMODS.save_mod_config(CG.mod) end
  G.FUNCS.exit_overlay_menu()
end
G.FUNCS.cg_pick_full = function() CG.pick_intensity('full') end
G.FUNCS.cg_pick_gentle = function() CG.pick_intensity('gentle') end

local function line(en, zh, colour, scale)
  return { n = G.UIT.R, config = { align = 'cm', padding = 0.04 }, nodes = {
    { n = G.UIT.T, config = { text = CG.L(en, zh), scale = scale or 0.4, colour = colour or G.C.UI.TEXT_LIGHT } },
  } }
end

-- 标题和故事文字一样用繁体
function CG.intro_ui()
  return create_UIBox_generic_options { no_back = true, contents = {
    { n = G.UIT.R, config = { align = 'cm', padding = 0.1 }, nodes = {
      { n = G.UIT.T, config = { text = CG.T(CG.L('Cursed Gifts · Ghost Month', '诅咒礼物 · 台湾鬼月')), scale = 0.6, colour = HEX('ff6b6b'), font = CG.font() } },
    } },
    line('This mod contains horror: sudden sounds, screen flashes', '本 mod 含恐怖内容：突然的声音、画面闪烁和扭曲，'),
    line('and distortion, and text about death and folk taboos.', '以及关于死亡和民俗禁忌的文字。'),
    line('You can change this any time in Mods > Cursed Gifts > Config.', '随时可以在 模组 → Cursed Gifts → 配置 里改。', HEX('b8a99a'), 0.32), -- 原来的灰色在深底上看不清
    { n = G.UIT.R, config = { align = 'cm', padding = 0.15 }, nodes = {
      { n = G.UIT.C, config = { align = 'cm', padding = 0.08 }, nodes = {
        UIBox_button { button = 'cg_pick_full', colour = HEX('7a1414'), minw = 4.2, minh = 0.9, scale = 0.42,
          label = { CG.L('Ghost Month', '鬼月'), CG.L('full horror', '完整恐怖') } } } },
      { n = G.UIT.C, config = { align = 'cm', padding = 0.08 }, nodes = {
        UIBox_button { button = 'cg_pick_gentle', colour = G.C.GREY, minw = 4.2, minh = 0.9, scale = 0.42,
          label = { CG.L('Gentle', '温和'), CG.L('no flashes / jump scares', '不闪烁、不惊吓') } } } },
    } },
  } }
end

function CG.show_intro()
  G.FUNCS.overlay_menu { definition = CG.intro_ui() }
end

local main_menu_ref = Game.main_menu
function Game:main_menu(change_context)
  local r = main_menu_ref(self, change_context)
  if not CG.cfg.intro_done and not CG.TESTING then
    G.E_MANAGER:add_event(Event({ trigger = 'after', delay = 1.2, blockable = false, func = function()
      if not G.OVERLAY_MENU then CG.show_intro() end
      return true
    end }))
  end
  return r
end

---------------------------------------------------------------- 设置页「鬼月挑战」分页
-- 原版要用 5 种牌组各赢一次才开放挑战页（新存档打不开）；不改原版进度，在这里直接开挑战

CG.CHAL = {
  { key = 'c_cg_replacement', en = { 'Red Envelope + Mo-sin-a. It comes at 9.' },
    zh = { '路边红包 + 魔神仔，恐惧到 9 它就来' } },
  { key = 'c_cg_zhongyuan', en = { 'Offering Table + Doll, 6 Dread.', 'A gift at the door after each Boss.' },
    zh = { '普渡供桌 + 瓷娃娃，恐惧 6', '每过一个 Boss，门口多一份礼物' } },
  { key = 'c_cg_zhongkui', en = { "Zhong Kui + Monkey's Paw + Water Ghost.", 'No Exorcist. It comes at 9.' },
    zh = { '跳钟馗 + 猴爪 + 水鬼', '没有法师，恐惧到 9 它就来' } },
}

function CG.start_challenge(key)
  for _, ch in ipairs(G.CHALLENGES) do
    if ch.id == key then
      if G.OVERLAY_MENU then G.FUNCS.exit_overlay_menu() end
      G.FUNCS.start_run(nil, { stake = 1, challenge = ch })
      return true
    end
  end
end
for i, c in ipairs(CG.CHAL) do G.FUNCS['cg_chal_' .. i] = function() CG.start_challenge(c.key) end end
G.FUNCS.cg_replay_intro = function() CG.show_intro() end

CG.mod.extra_tabs = function()
  return { {
    label = CG.L('Ghost Month Challenges', '鬼月挑战'),
    tab_definition_function = function()
      local rows = {}
      for i, c in ipairs(CG.CHAL) do
        local desc = {}
        for _, s in ipairs(CG.L(c.en, c.zh)) do
          if CG.lang() == 'zh_TW' then s = CG.T(s) end
          desc[#desc + 1] = { n = G.UIT.R, config = { align = 'cl', padding = 0.02 }, nodes = {
            { n = G.UIT.T, config = { text = s, scale = 0.32, colour = G.C.UI.TEXT_LIGHT } } } }
        end
        -- 按钮单独包一列，说明文字在右边一列（之前按钮直接放进行里，会和说明叠在一起）
        rows[#rows + 1] = { n = G.UIT.R, config = { align = 'cl', padding = 0.08 }, nodes = {
          { n = G.UIT.C, config = { align = 'cm', minw = 3 }, nodes = {
            UIBox_button { button = 'cg_chal_' .. i, colour = HEX('7a1414'), minw = 2.8, minh = 0.7, scale = 0.4,
              label = { localize(c.key, 'challenge_names') } } } },
          { n = G.UIT.C, config = { align = 'cl', padding = 0.05, minw = 5.2 }, nodes = desc },
        } }
      end
      rows[#rows + 1] = { n = G.UIT.R, config = { align = 'cm', padding = 0.15 }, nodes = {
        { n = G.UIT.C, config = { align = 'cm' }, nodes = {
          UIBox_button { button = 'cg_replay_intro', colour = G.C.GREY, minw = 4, minh = 0.6, scale = 0.35,
            label = { CG.L('Choose horror intensity again', '重新选择恐怖强度') } } } } } }
      return { n = G.UIT.ROOT, config = { align = 'cm', padding = 0.15, colour = G.C.BLACK, r = 0.1, minw = 8 },
        nodes = { { n = G.UIT.C, config = { align = 'cm' }, nodes = rows } } }
    end,
  } }
end
