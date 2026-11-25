-- Cursed Gifts（原型 v0.0.1）
-- 恐惧值 Dread、13 点「它来了」、诅咒只能转送且 3 回合后回来。设计稿见 ~/Desktop/项目代码/balatro-potlatch/docs/design.md
CursedGifts = CursedGifts or {}
-- 自动测试：mod 一加载就把窗口缩小（就算后面加载崩了，报错画面也不会全屏盖住用户的屏幕）
if os.getenv('CG_TEST') or os.getenv('CG_ENDINGS') or os.getenv('CG_MEMORY') then
  pcall(function()
    local dw, dh = love.window.getDesktopDimensions()
    local demo = os.getenv('CG_TEST') == 'demo' or os.getenv('CG_TEST') == 'polish' -- 录演示：1280x720、不放大像素
    local w, h = demo and 960 or 640, demo and 540 or 400
    love.window.setMode(w, h, { fullscreen = false, resizable = true, highdpi = not demo, x = dw - w - 10, y = dh - h - 40 })
  end)
end
local CG = CursedGifts
CG.mod = SMODS.current_mod
CG.cfg = CG.mod.config
CG.THRESHOLD = 13
CG.RETURN_ROUNDS = 3
-- 挑战可以改「它来了」的门槛（G.GAME.modifiers.cg_threshold）
-- 一次比一次近：每来过一次门槛 -2（13 → 11 → 9）；第 3 次来，它拿的是你
CG.STEP, CG.MAX_COMES = 2, 3
function CG.came() return (G.GAME and G.GAME.cg_came) or 0 end
function CG.threshold()
  local base = (G.GAME and G.GAME.modifiers and G.GAME.modifiers.cg_threshold) or CG.THRESHOLD
  return base - CG.STEP * math.min(CG.came(), CG.MAX_COMES - 1)
end
CG.ui = { text = '0/13', marks = '' }
CG.t = { heart = 0, flash = 0, silence = 0 }

CG.ORDER = {
  red_envelope = 0, monkey_paw = 1, under_bed = 2, exorcist = 3, doll = 4,
  chain_letter = 5, effigy = 6, joss = 7, night_watch = 8, mirror = 9,
  letter = 10, heirloom = 11, return_gift = 12, footsteps = 13, seance = 14,
}

SMODS.Atlas { key = 'jokers', path = 'jokers.png', px = 71, py = 95 }

-- 鬼月字体：故事里的话一律用台湾繁体 + 霞鹜文楷 TC（开源 OFL，可随 mod 发布；授权见 assets/fonts/OFL.txt）
-- 只含 mod 用到的字（tools/make_font.py 裁的，约 480KB）；改了中文要重跑 make_tw.py 再跑 make_font.py
SMODS.Font { key = 'ghost', path = 'wenkai_tc.ttf', render_scale = 96, TEXT_HEIGHT_SCALE = 0.8,
  TEXT_OFFSET = { x = 0, y = -20 }, FONTSCALE = 0.135, squish = 1, DESCSCALE = 1.15 }

-- 牌底小字的颜色：暗红墨（浅灰配细隶书在白底上看不见）
local loc_colour_ref = loc_colour
function loc_colour(_c, _default)
  if _c == 'cg_ink' then return HEX('6e1a1a') end
  return loc_colour_ref(_c, _default)
end

for _, s in ipairs { 'heartbeat', 'sting', 'suona', 'footstep', 'return', 'jiaobei', 'muyu', 'chant', 'temple_gong' } do
  SMODS.Sound { key = s, path = s .. '.wav' }
end

---------------------------------------------------------------- 工具

function CG.L(en, zh)
  local l = (G.SETTINGS and G.SETTINGS.language) or 'en-us'
  if l:sub(1, 2) == 'zh' then return zh end
  return en
end

function CG.on(k) return CG.cfg[k] ~= false end

-- 恐怖字体（设置页能关）；关掉或没加载到就用游戏原来的字体
function CG.font(en)
  if not CG.on('ghost_font') then return nil end
  return SMODS.Fonts and SMODS.Fonts['cg_ghost'] -- 英文一律用游戏原字体（小字号下恐怖英文字体看不清）
end

-- 故事里的话（低语 / 「它来了」）：中文一律台湾繁体；英文模式下繁体在上、英文翻译在下
-- line = CG.B(en, zh)（见 tw.lua）或已经翻好的字符串
local function story_text(line, scale, y, colour, hold, backdrop)
  local function show(text, font, sc, dy)
    attention_text({
      text = text, scale = sc, hold = hold, align = 'cm', major = G.play, font = font,
      offset = { x = 0, y = y + dy }, colour = colour, backdrop_colour = backdrop,
    })
  end
  if type(line) ~= 'table' then return show(line, CG.font(), scale, 0) end
  local zh = CG.T and CG.T(line.zh) or line.zh
  if CG.lang():sub(1, 2) == 'zh' then return show(zh, CG.font(), scale, 0) end
  if not CG.on('ghost_font') then return show(line.en, nil, scale, 0) end
  show(zh, CG.font(), scale, 0)
  -- 英文翻译用游戏原来的字体：英文恐怖字体缩小后糊成一团看不清（11/25 用户反馈）
  show(line.en, nil, math.max(0.4, scale * 0.6), scale * 0.95)
end
CG.story_text = story_text

function CG.lang() return (G.SETTINGS and G.SETTINGS.language) or 'en-us' end

CG.JUMPSCARE = { sting = true, suona = true }
function CG.play(key, pitch, vol)
  if not CG.on('sounds') then return end
  if CG.JUMPSCARE[key] and not CG.on('jumpscare') then return end -- 温和模式：没有突然的大声音
  play_sound('cg_' .. key, pitch or 1, vol or 0.7)
end

function CG.dread() return (G.GAME and G.GAME.cg_dread) or 0 end

-- 0（恐惧 ≤4）到 1（恐惧 12）
function CG.level()
  local d = CG.dread()
  if d <= 4 then return 0 end
  return math.min(1, (d - 4) / 8)
end

function CG.is_cursed(card)
  return card and card.config and card.config.center and
      (card.config.center.cg_cursed or (card.ability and card.ability.cg_cursed)) and true or false
end

function CG.gen(card) return (card.ability and card.ability.cg_gen) or 0 end

function CG.msg(card, text, colour)
  if card then
    card_eval_status_text(card, 'extra', nil, nil, nil, { message = text, colour = colour or G.C.RED })
  end
end

-- 给一张消耗牌（塔罗 / 星球 / 幻灵），没空位就算了
function CG.give(set, append)
  if not G.consumeables or not G.GAME then return end
  if #G.consumeables.cards + G.GAME.consumeable_buffer >= G.consumeables.config.card_limit then return end
  G.GAME.consumeable_buffer = G.GAME.consumeable_buffer + 1
  G.E_MANAGER:add_event(Event({ func = function()
    SMODS.add_card { set = set, key_append = append }
    G.GAME.consumeable_buffer = math.max(0, G.GAME.consumeable_buffer - 1)
    return true
  end }))
  return true
end

---------------------------------------------------------------- 恐惧值界面

function CG.update_ui()
  CG.ui.text = tostring(CG.dread()) .. '/' .. CG.threshold()
  -- 恐惧条旁边 3 个记号：来过几次就划掉几个，最后一个是你
  local c = math.min(CG.came(), CG.MAX_COMES)
  CG.ui.marks = ' ' .. ('X'):rep(c) .. ('-'):rep(CG.MAX_COMES - c)
end

-- 鼠标停在恐惧条上显示「恐惧」说明（文字和卡牌悬浮说明共用 extras.lua 的 cg_dread）
function CG.dread_tip()
  local d = G.localization and G.localization.descriptions and G.localization.descriptions.Other
  d = d and d.cg_dread
  if not d or not d.text then return nil end
  return { title = d.name, text = d.text }
end

function CG.make_ui()
  if CG.box then CG.box:remove(); CG.box = nil end
  if not G.jokers then return end
  CG.box = UIBox {
    definition = { n = G.UIT.ROOT, config = { align = 'cm', colour = G.C.CLEAR }, nodes = {
      { n = G.UIT.R, config = { align = 'cm', padding = 0.06, r = 0.08, colour = HEX('3a0a0e'), emboss = 0.05, minw = 1.7, tooltip = CG.dread_tip() }, nodes = {
        { n = G.UIT.T, config = { text = CG.L('Dread ', '恐惧 '), scale = 0.32, colour = HEX('e8d8c0') } },
        { n = G.UIT.T, config = { ref_table = CG.ui, ref_value = 'text', scale = 0.32, colour = HEX('ff6b6b') } },
        { n = G.UIT.T, config = { ref_table = CG.ui, ref_value = 'marks', scale = 0.3, colour = HEX('9a7d6a') } },
      } },
    } },
    config = { align = 'bm', offset = { x = 0, y = 0.12 }, major = G.jokers, bond = 'Weak' },
  }
end

---------------------------------------------------------------- 背景色

local ebcb_ref = ease_background_colour_blind
function CG.tint()
  if not CG.on('ambience') or not G.GAME or G.STAGE ~= G.STAGES.RUN then return end
  local lv = CG.level()
  if lv <= 0 then
    ebcb_ref(G.STATE)
    return
  end
  ease_background_colour {
    new_colour = mix_colours(HEX('7a0d16'), HEX('2a1a1e'), 0.35 + 0.65 * lv),
    special_colour = darken(G.C.BLACK, 0.2 + 0.3 * lv),
    contrast = 1 + 2 * lv,
  }
end

function ease_background_colour_blind(state, blind_override)
  ebcb_ref(state, blind_override)
  if CG.level() > 0 then CG.tint() end
end

---------------------------------------------------------------- 恐惧值与「它来了」

function CG.add_dread(n, card)
  if not G.GAME or n == 0 then return end
  G.GAME.cg_dread = math.max(0, (G.GAME.cg_dread or 0) + n)
  CG.update_ui()
  CG.msg(card, (n > 0 and '+' or '') .. n .. ' ' .. CG.L('Dread', '恐惧'))
  CG.tint()
  CG.check_letters()
  if G.GAME.cg_dread >= 10 and G.GAME.cg_dread < CG.threshold() and not G.GAME.cg_w10 then
    G.GAME.cg_w10 = true
    CG.say('it is counting', '它在数')
  end
  if G.GAME.cg_dread >= CG.threshold() and not G.GAME.cg_coming then
    G.GAME.cg_coming = true
    CG.it_comes()
  end
end

function CG.reset_dread()
  G.GAME.cg_dread = 0
  G.GAME.cg_coming = nil
  G.GAME.cg_w10 = nil
  CG.update_ui()
  CG.tint()
end

-- 「它」能带走的：不是诅咒、不是永恒、不是残影
function CG.candidates()
  local pool = {}
  for _, j in ipairs(G.jokers and G.jokers.cards or {}) do
    if not CG.is_cursed(j) and not j.ability.eternal and not j.getting_sliced and not j.ability.cg_afterimage
        and not j.removed then pool[#pool + 1] = j end
  end
  return pool
end

function CG.pick_victim()
  local pool = CG.candidates()
  if #pool == 0 then return nil end
  if G.GAME.cg_bride then return pool[#pool] end
  return pseudorandom_element(pool, pseudoseed('cg_itcomes'))
end

-- 全屏红色闪光（可在设置里关掉）
function CG.red_flash(strength, dur)
  if not CG.on('flash') then return end
  local col = { 0.75, 0.05, 0.08, strength or 0.55 }
  local box = UIBox {
    definition = { n = G.UIT.ROOT, config = { align = 'cm', colour = col, minw = G.ROOM.T.w * 1.5, minh = G.ROOM.T.h * 1.5 }, nodes = {} },
    config = { align = 'cm', major = G.ROOM_ATTACH, offset = { x = 0, y = 0 }, bond = 'Weak' },
  }
  G.E_MANAGER:add_event(Event({ trigger = 'ease', blockable = false, blocking = false, timer = 'REAL',
    ref_table = col, ref_value = 4, ease_to = 0, delay = dur or 0.5, func = function(t) return t end }))
  G.E_MANAGER:add_event(Event({ trigger = 'after', blockable = false, blocking = false, timer = 'REAL',
    delay = (dur or 0.5) + 0.05, func = function() box:remove(); return true end }))
end

-- 「它来了」演出（节奏原则：整局唯一的停顿就在这里，时长随游戏速度缩短）
--   ① 心跳停、音乐静音、背景沉到全黑，被选中的那张牌慢慢翻过去
--   ② 爆发：尖音 + 红闪 + 画面撕裂 + 那张牌碎掉
--   ③ 余波：安静两秒，心跳才回来
CG.CHOOSE_TIME = 8
function CG.it_comes()
  local speed = math.max(1, (G.SETTINGS and G.SETTINGS.GAMESPEED) or 1)
  local pause = 1.4 / math.sqrt(speed)
  -- 不在计分途中开演：等这手牌算完（blocking/blockable=false，每帧自己检查，不堵别的事件）
  G.E_MANAGER:add_event(Event({ blocking = false, blockable = false, func = function()
    if G.STATE == G.STATES.HAND_PLAYED or G.STATE == G.STATES.DRAW_TO_HAND or not G.jokers then return false end
    if G.STATE == G.STATES.GAME_OVER then return true end
    if CG.came() >= CG.MAX_COMES - 1 then CG.take_you(); return true end -- 第 3 次：它拿的是你
    CG.t.silence = pause
    CG.t.heart = pause + 2.5 -- 心跳停
    if CG.on('ambience') then
      ease_background_colour { new_colour = HEX('0a0608'), special_colour = HEX('000000'), contrast = 3 }
    end
    for _, j in ipairs(G.jokers.cards) do j:juice_up(0.05, 0.05) end
    local pool = CG.candidates()
    -- 你亲手选交出谁（新娘已经定了、或只有一张可选时不用选）
    if not G.GAME.cg_bride and #pool > 1 then CG.start_choose(pool, pause)
    else CG.begin_impact(CG.pick_victim(), pause) end
    return true
  end }))
end

-- 选好了：那张牌慢慢翻过去，pause 秒后爆发
function CG.begin_impact(victim, pause)
  CG.t.silence = math.max(CG.t.silence, pause)
  CG.t.heart = math.max(CG.t.heart, pause + 2.5)
  CG.t.impact = pause
  CG.t.impact_victim = victim
  if victim then
    victim.cg_marked = true
    victim:juice_up(0.3, 0.3)
    if victim.facing == 'front' then victim:flip() end
  end
end

-- 画面暗下来，点一张小丑交出去；CHOOSE_TIME 秒不选，它自己挑
function CG.start_choose(pool, pause)
  CG.choosing = { pool = pool, pause = pause, t = CG.CHOOSE_TIME, pulse = 0, say = 0 }
  CG.t.silence = CG.CHOOSE_TIME + pause
  CG.t.heart = CG.CHOOSE_TIME + pause + 2.5
  CG.play('footstep', 0.8, 0.8)
end

function CG.choose(card)
  local c = CG.choosing
  if not c then return end
  CG.choosing = nil
  if not card or card.removed or card.area ~= G.jokers then card = CG.pick_victim() end
  CG.begin_impact(card, c.pause)
end

-- 选人的时候：只有能交的小丑点得动
local click_ref = Card.click
function Card:click()
  local c = CG.choosing
  if c and self.area == G.jokers then
    for _, j in ipairs(c.pool) do
      if j == self then CG.choose(self); return end
    end
    return
  end
  return click_ref(self)
end

-- 第 3 次：你成了交替
function CG.take_you()
  G.GAME.cg_replaced = true
  G.GAME.cg_came = CG.came() + 1
  CG.update_ui()
  CG.t.silence, CG.t.heart = 4, 8
  if CG.on('ambience') then
    ease_background_colour { new_colour = HEX('000000'), special_colour = HEX('000000'), contrast = 3 }
  end
  CG.play('sting', 0.8, 1)
  CG.red_flash(0.8, 1.6)
  story_text(CG.B('YOU ARE THE REPLACEMENT', '你成了交替'), 1.3, -0.5, HEX('ff3b3b'), 3.2, G.C.BLACK)
  G.E_MANAGER:add_event(Event({ trigger = 'after', delay = 3, timer = 'REAL', blocking = false, blockable = false, func = function()
    if not G.GAME or G.STATE == G.STATES.GAME_OVER then return true end
    if G.GAME.blind and G.P_BLINDS.bl_cg_it then G.GAME.blind.config.blind = G.P_BLINDS.bl_cg_it end -- 结算框：被它带走
    G.STATE = G.STATES.GAME_OVER
    if not G.GAME.won and not G.GAME.seeded and not G.GAME.challenge then
      G.PROFILES[G.SETTINGS.profile].high_scores.current_streak.amt = 0
    end
    G:save_settings()
    G.FILE_HANDLER.force = true
    G.STATE_COMPLETE = false
    return true
  end }))
end

-- 去处：原位留一回合残影（不生效、不能被带走），到下一回合结束才散
function CG.afterimage(ghost, idx)
  if not ghost or not G.jokers then return end
  ghost.ability.cg_afterimage = true
  ghost.cg_sold = true -- 散掉不算被销毁
  SMODS.debuff_card(ghost, true, 'cg_afterimage')
  G.jokers:emplace(ghost)
  if idx and idx < #G.jokers.cards then
    table.remove(G.jokers.cards, #G.jokers.cards)
    table.insert(G.jokers.cards, idx, ghost)
    G.jokers:set_ranks()
  end
  ghost.sell_cost, ghost.sell_cost_label = 0, 0
end

-- ② 爆发：由 Game:update 里的计时器准时调用，不排队，避免被回合结算动画拖后
function CG.impact(victim)
    CG.t.silence = 0
    CG.play('sting', 1, 1)
    CG.red_flash(0.65, 0.9)
    if CG.on('flash') then
      CG.t.flash = 1
      G.ROOM.jiggle = G.ROOM.jiggle + 10
    end
    -- 挂在屏幕中间，不挂在会碎掉的那张牌上
    story_text(victim and CG.B('IT CAME', '它来了') or CG.B('IT LOOKED AT YOU', '它看了你一眼'),
      1.6, -0.5, HEX('ff3b3b'), 1.8, G.C.BLACK)
    local ghost, idx
    if victim and not victim.removed then
      if victim.facing == 'back' then victim:flip() end
      victim:juice_up(1.2, 1.2)
      for k, j in ipairs(G.jokers.cards) do if j == victim then idx = k end end
      ghost = copy_card(victim, nil, nil, nil, true) -- 残影：去掉版本的空壳（不 add_to_deck，没有效果）
      G.GAME.cg_last_destroyed = victim.config.center.key -- 碎掉不走 start_dissolve，手动记给招魂
      G.GAME.cg_jdestroyed = (G.GAME.cg_jdestroyed or 0) + 2 -- 水鬼：它带走的算两次
      SMODS.destroy_cards({ victim }, {
        bypass_eternal = true, immediate = true, -- 不排队：否则排在结算动画后面，「它来了」出字后牌还好好的
        destroy_func = function(c) c:shatter(); return true end,
      })
    end
    G.GAME.cg_bride = nil
    if victim then
      G.GAME.cg_w_taken = true
      CG.afterimage(ghost, idx)
      -- 它留下回礼：一张幻灵牌（回礼小丑再多给一张）
      G.E_MANAGER:add_event(Event({ trigger = 'after', delay = 1.9, timer = 'REAL', blocking = false, blockable = false, func = function()
        if not G.GAME or not G.jokers then return true end
        story_text(CG.B('Thank you.', '謝謝你。'), 0.9, -0.2, HEX('e8d8c0'), 2.2)
        CG.give('Spectral', 'cg_it')
        for _, j in ipairs(G.jokers.cards) do
          if j.config.center.key == 'j_cg_return_gift' and not j.debuff and CG.give('Spectral', 'cg_rg') then
            CG.msg(j, CG.L('A gift in return', '回礼'), G.C.SECONDARY_SET.Spectral)
          end
        end
        return true
      end }))
    end
    CG.reset_dread()
end

---------------------------------------------------------------- 诅咒 / 礼物：转送与回归

CG.GIFT_ROUNDS = 2

function CG.is_gift(card)
  return card and card.config and card.config.center and card.config.center.cg_gift and true or false
end

-- 诅咒贴纸：招魂召回的牌会带上它（card.ability.cg_cursed）
SMODS.Atlas { key = 'stickers', path = 'stickers.png', px = 71, py = 95 }
SMODS.Sticker {
  key = 'cursed', atlas = 'stickers', pos = { x = 0, y = 0 }, badge_colour = HEX('5a0f14'),
  needs_enable_flag = true, rate = 0,
  loc_txt = {
    ['en-us'] = { name = 'Cursed', label = 'Cursed', text = { "Can't be destroyed", 'Sell: {C:attention}passes on{},', 'back in {C:attention}3{} rounds' } },
    ['zh_CN'] = { name = '诅咒', label = '诅咒', text = { '毁不掉', '卖掉就是{C:attention}转送{}：{C:attention}3{} 回合后回来' } },
  },
}

function CG.curse(card)
  if card and not CG.is_cursed(card) then
    SMODS.Stickers['cg_cursed']:apply(card, true)
    card:set_cost()
  end
end

function CG.pass_on(card)
  G.GAME.cg_returning = G.GAME.cg_returning or {}
  local gift = CG.is_gift(card) and not CG.is_cursed(card)
  table.insert(G.GAME.cg_returning, {
    key = card.config.center.key, rounds = gift and CG.GIFT_ROUNDS or CG.RETURN_ROUNDS, gen = CG.gen(card) + 1,
    sticker = (card.ability.cg_cursed and not card.config.center.cg_cursed) or nil,
  })
  CG.msg(card, CG.L('Passed on...', '送出去了……'), HEX('9a7d6a'))
end

function CG.bring_back(entry)
  G.E_MANAGER:add_event(Event({ trigger = 'after', delay = 0.6, func = function()
    local card = SMODS.add_card { key = entry.key, edition = entry.edition }
    if card then
      if entry.ability then -- 魔神仔牵走的：还原成原来那张（数值、贴纸）
        for k, v in pairs(entry.ability) do card.ability[k] = v end
        card:set_cost()
      end
      card.ability.cg_gen = entry.gen
      if entry.sticker then CG.curse(card) end
      card:set_cost()
      CG.play('return', 1, 0.9)
      card:juice_up(0.8, 0.8)
      CG.msg(card, CG.L('It came back', '它回来了'))
      if pseudorandom('cg_w_back') < 0.5 then CG.say('it kept count', '它一直记着') end
      local center = card.config.center
      if center.cg_on_return then center.cg_on_return(center, card) end
      -- 回礼：每当有牌回来，生成一张幻灵牌
      for _, j in ipairs(G.jokers.cards) do
        if j.config.center.key == 'j_cg_return_gift' and not j.debuff and CG.give('Spectral', 'cg_rg') then
          CG.msg(j, CG.L('A gift in return', '回礼'), G.C.SECONDARY_SET.Spectral)
        end
      end
    end
    return true
  end }))
end

function CG.tick_returns()
  local q = G.GAME.cg_returning
  if not q or #q == 0 then return end
  local keep = {}
  for _, e in ipairs(q) do
    e.rounds = e.rounds - 1
    if e.rounds <= 0 then CG.bring_back(e) else keep[#keep + 1] = e end
  end
  G.GAME.cg_returning = keep
end

-- 诅咒 / 礼物卖价为 0：卖出 = 转送
local set_cost_ref = Card.set_cost
function Card:set_cost()
  set_cost_ref(self)
  if CG.is_cursed(self) or CG.is_gift(self) then
    self.sell_cost = 0
    self.sell_cost_label = self.facing == 'back' and '?' or 0
  end
end

-- 贴纸诅咒的牌（本身不是诅咒牌）卖出时也算转送；同时标记「是卖掉的」，招魂只认被销毁的
local sell_ref = Card.sell_card
function Card:sell_card()
  self.cg_sold = true
  local c = self.config.center
  if self.ability.set == 'Joker' and (CG.is_cursed(self) or CG.is_gift(self)) then CG.pass_on(self) end
  return sell_ref(self)
end

-- 记下最近一张被销毁（不是卖掉）的小丑，给招魂用
local dissolve_ref = Card.start_dissolve
function Card:start_dissolve(...)
  if G.GAME and self.ability and self.ability.set == 'Joker' and not self.cg_sold and self.area == G.jokers
      and not self.ability.cg_afterimage and not self.cg_counted then
    self.cg_counted = true
    G.GAME.cg_last_destroyed = self.config.center.key
    G.GAME.cg_jdestroyed = (G.GAME.cg_jdestroyed or 0) + 1 -- 水鬼：任何原因被销毁的小丑
  end
  return dissolve_ref(self, ...)
end

---------------------------------------------------------------- 第四面墙

-- 低语排队：放进自己的事件队列，一句完全消失后才说下一句（不叠在一起；按游戏时间算，和淡出同一个钟）
function CG.whisper(text)
  local q = 'cg_whisper'
  G.E_MANAGER.queues[q] = G.E_MANAGER.queues[q] or {}
  G.E_MANAGER:add_event(Event({ trigger = 'after', delay = 1.5, func = function()
    story_text(text, 0.45, -2.6, { 0.9, 0.85, 0.8, 0.55 }, 3.5)
    return true
  end }), q)
  G.E_MANAGER:add_event(Event({ trigger = 'after', delay = 4.8, func = function() return true end }), q) -- 停留 3.5 秒 + 淡出
end

CG.WHISPERS = {
  { "don't pass it back", '别把它送回来' },
  { 'it remembers', '它记得' },
  { 'you opened it', '是你拆开的' },
  { 'something is under the table', '桌子底下有东西' },
  { 'it is closer than last round', '它比上一回合近了' },
  { 'count your jokers', '数数你的小丑' },
  { 'it was never yours', '从来就不是你的' },
  { 'pass it on', '转出去' },
}

-- 按情况说的话（受「第四面墙文字」开关控制）
function CG.say(en, zh)
  if CG.on('fourth_wall') then CG.whisper(CG.B(en, zh)) end
end

function CG.maybe_whisper()
  if not CG.on('fourth_wall') then return end
  if G.GAME.cg_w_taken then
    G.GAME.cg_w_taken = nil
    CG.whisper(CG.B('that one was yours', '那张是你的'))
    return
  end
  local h = tonumber(os.date('%H'))
  if h and h < 5 and not G.GAME.cg_latenight then
    G.GAME.cg_latenight = true
    CG.whisper(CG.B(("It's %s. Who are you playing for?"):format(os.date('%H:%M')),
      ('现在是 %s。你在替谁玩？'):format(os.date('%H:%M'))))
    return
  end
  if CG.dread() >= 6 and pseudorandom('cg_whisper') < 0.4 then
    local w = pseudorandom_element(CG.WHISPERS, pseudoseed('cg_whisper_pick'))
    CG.whisper(CG.B(w[1], w[2]))
  end
end

---------------------------------------------------------------- 全局钩子

CG.mod.calculate = function(self, context)
  if not G.GAME then return end
  -- 诅咒牌不能被销毁（驱魔人用 bypass_eternal 绕过）
  if context.check_eternal and context.other_card and CG.is_cursed(context.other_card) then
    return { no_destroy = true }
  end
  if context.remove_playing_cards and context.removed and #context.removed > 0 then
    CG.add_dread(#context.removed)
  end
  if context.setting_blind and not context.blueprint then
    CG.maybe_whisper()
  end
  if context.before and not context.blueprint and CG.dread() >= 9 then
    CG.play('footstep', 0.95 + 0.01 * CG.dread(), 0.35 + 0.08 * (CG.dread() - 9))
  end
  if context.end_of_round and not context.individual and not context.repetition and not context.blueprint
      and G.GAME.cg_last_eor ~= G.GAME.round then
    G.GAME.cg_last_eor = G.GAME.round
    local first, n = nil, 0
    for _, j in ipairs(G.jokers.cards) do
      if CG.is_cursed(j) then n = n + 1; first = first or j end
    end
    if n > 0 then CG.add_dread(n, first) end
    CG.tick_returns()
    -- 残影待满一回合（来的那个回合不算）就散
    for _, j in ipairs(G.jokers.cards) do
      if j.ability.cg_afterimage then
        if j.ability.cg_afterimage == true then j.ability.cg_afterimage = 1
        else j.cg_sold = true; j:start_dissolve({ HEX('3a0a0e'), G.C.BLACK }, true, 1.6) end
      end
    end
  end
end

local start_run_ref = Game.start_run
function Game:start_run(args)
  start_run_ref(self, args)
  G.GAME.cg_dread = G.GAME.cg_dread or 0
  G.GAME.cg_returning = G.GAME.cg_returning or {}
  CG.update_ui()
  CG.make_ui()
  if CG.level() > 0 then CG.tint() end
  -- 存档时正好在「它来了」途中：读档后重新来一次，不然恐惧卡在 13 以上再也不触发
  if G.GAME.cg_coming then
    if CG.dread() >= CG.threshold() then CG.it_comes() else G.GAME.cg_coming = nil end
  end
end

local delete_run_ref = Game.delete_run
function Game:delete_run()
  CG.t.impact, CG.t.impact_victim, CG.t.silence, CG.t.flash = nil, nil, 0, 0
  CG.choosing = nil
  if CG.box then CG.box:remove(); CG.box = nil end
  return delete_run_ref(self)
end

local update_ref = Game.update
function Game:update(dt)
  update_ref(self, dt)
  if CG.t.silence > 0 then CG.t.silence = CG.t.silence - dt end
  if CG.t.flash > 0 then CG.t.flash = math.max(0, CG.t.flash - dt * 1.5) end
  local c = CG.choosing
  if c and not G.SETTINGS.paused then
    c.t = c.t - dt
    c.pulse = c.pulse - dt
    if c.pulse <= 0 then -- 心跳一样一下一下抖能交的牌
      c.pulse = 0.9
      for _, j in ipairs(c.pool) do if not j.removed then j:juice_up(0.12, 0.12) end end
    end
    c.say = c.say - dt
    if c.say <= 0 and c.t > 0.8 then -- 「交一個出去」一明一暗地反复出现；选完就不再出，不会和「它来了」叠在一起
      c.say = 1.5
      story_text(CG.B('GIVE IT ONE', '交一個出去'), 1.1, -0.6, HEX('ff3b3b'), 0.7, G.C.BLACK)
    end
    if c.t <= 0 or not G.jokers then CG.choose(nil) end
  end
  if CG.t.impact and not G.SETTINGS.paused then
    CG.t.impact = CG.t.impact - dt
    if CG.t.impact <= 0 then
      local v = CG.t.impact_victim
      CG.t.impact, CG.t.impact_victim = nil, nil
      CG.impact(v)
    end
  end
  if G.STAGE ~= G.STAGES.RUN or G.SETTINGS.paused or not G.GAME then return end
  local d = CG.dread()
  if d >= 5 and CG.on('sounds') then
    CG.t.heart = CG.t.heart - dt
    if CG.t.heart <= 0 then
      play_sound('cg_heartbeat', 1, 0.25 + 0.06 * (d - 5))
      CG.t.heart = math.max(0.75, 1.7 - 0.13 * (d - 5))
    end
  end
  -- 高恐惧时偶尔闪一帧
  if d >= 9 and CG.on('flash') and CG.on('ambience') and math.random() < dt * 0.12 then
    CG.t.flash = math.max(CG.t.flash, 0.12)
  end
end

-- 由 lovely/hooks.toml 注入：音乐降调 / 静音
-- 自动测试时整局静音（不动玩家自己的音量设置）
CG.TESTING = os.getenv('CG_TEST') or os.getenv('CG_ENDINGS') or os.getenv('CG_MEMORY')

function CG.modulate(push)
  if CG.TESTING then
    local s = {}
    for k, v in pairs(push.sound_settings or G.SETTINGS.SOUND) do s[k] = v end
    s.volume = 0
    push.sound_settings = s
  end
  if CG.t.silence > 0 then
    local s = {}
    for k, v in pairs(push.sound_settings or G.SETTINGS.SOUND) do s[k] = v end
    s.music_volume = 0
    push.sound_settings = s
  end
  if not CG.on('ambience') or G.STAGE ~= G.STAGES.RUN then return end
  local lv = CG.level()
  if lv > 0 then
    local wob = CG.dread() >= 9 and 0.015 * math.sin(G.TIMERS.REAL * 0.9) or 0
    push.pitch_mod = (push.pitch_mod or 1) * (1 - 0.1 * lv + wob)
  end
end

-- 显像管加强 / 闪烁：挂在 Steamodded 接管的 CRT 屏幕着色器上
function CG.crt_vars(v)
  local boost, glitch = 0, 0
  if CG.on('ambience') and G.STAGE == G.STAGES.RUN and CG.dread() >= 9 then
    boost = math.min(0.12, 0.04 * (CG.dread() - 8)) -- 封顶：再亮画面会发灰过曝
  end
  if CG.choosing then boost = 0 end -- 选人那几秒画面要压暗、字要看得清
  if CG.t.flash > 0 and CG.on('flash') then
    glitch = CG.t.flash * 0.6 -- 原来 *2 会把整屏刷白，像跳吓
    boost = boost + 0.3 * CG.t.flash
  end
  if boost > 0 and v.crt_intensity then v.crt_intensity = v.crt_intensity + boost end
  if glitch > 0 then v.glitch_intensity = glitch end
end

local crt_obj = SMODS.ScreenShaders and SMODS.ScreenShaders['CRT']
if crt_obj and crt_obj.send_vars then
  local crt_ref = crt_obj.send_vars
  crt_obj.send_vars = function(self)
    local v = crt_ref(self)
    CG.crt_vars(v)
    return v
  end
end

---------------------------------------------------------------- 设置页

CG.mod.config_tab = function()
  local nodes = {}
  for _, it in ipairs {
    { 'flash', 'Flashes & screen distortion', '闪屏和画面扭曲' },
    { 'sounds', 'Horror sounds', '恐怖音效' },
    { 'jumpscare', 'Jump-scare sounds (sting / suona)', '惊吓音效（尖音 / 唢呐）' },
    { 'fourth_wall', 'Fourth-wall text', '第四面墙文字' },
    { 'ambience', 'Dread ambience (colour / music / noise)', '恐惧氛围（变色 / 变调 / 噪点）' },
    { 'ghost_font', 'Ghost-month font for whispers', '低语用鬼月字体' },
  } do
    nodes[#nodes + 1] = create_toggle { label = CG.L(it[2], it[3]), ref_table = CG.cfg, ref_value = it[1], w = 5 }
  end
  return { n = G.UIT.ROOT, config = { align = 'cm', padding = 0.15, colour = G.C.BLACK, r = 0.1, minw = 8 },
    nodes = { { n = G.UIT.C, config = { align = 'cm' }, nodes = nodes } } }
end

---------------------------------------------------------------- 小丑

local CURSED_BADGE = HEX('5a0f14')

function CG.J(def)
  def.atlas = 'jokers'
  local idx = assert(CG.ORDER[def.key], def.key)
  def.pos = { x = idx, y = 0 }
  def.unlocked = true
  def.discovered = true
  if def.cg_cursed or def.cg_gift then
    def.eternal_compat = def.cg_cursed and true or def.eternal_compat
    def.perishable_compat = false
    def.set_badges = function(self, card, badges)
      if def.cg_cursed then
        badges[#badges + 1] = create_badge(CG.L('Cursed', '诅咒'), CURSED_BADGE, HEX('e8d8c0'), 1.2)
      else
        badges[#badges + 1] = create_badge(CG.L('Gift', '礼物'), HEX('8a6a1c'), HEX('f4ead2'), 1.2)
      end
    end
  end
  return SMODS.Joker(def)
end

local function eor(context)
  return context.end_of_round and context.main_eval and not context.blueprint
end

-- 1 路边红包
CG.J {
  key = 'red_envelope', rarity = 2, cost = 6, -- 平衡：只给钱不加分，稀有太贵
  cg_cursed = true, blueprint_compat = false,
  config = { extra = { dollars = 20, dread = 2 } },
  loc_txt = {
    ['en-us'] = { name = 'Red Envelope', text = {
      'Gain {C:money}$#1#{}. Scored {C:hearts}Hearts{}',
      'and {C:diamonds}Diamonds{} give {C:money}$1{}',
      '{C:red}+#2#{} Dread each round',
      '{C:cg_ink,f:cg_ghost}Pick it up, and you said yes to the wedding.{}',
    } },
    ['zh_CN'] = { name = '路边红包', text = {
      '获得 {C:money}+$#1#{}，计分的{C:hearts}红心{}/{C:diamonds}方块{} {C:money}+$1{}',
      '每回合 {C:red}+#2#{} 恐惧',
      '{C:cg_ink,f:cg_ghost}撿起來，就是答應了這門親事。{}',
    } },
  },
  loc_vars = function(self, info_queue, card)
    return { vars = { card.ability.extra.dollars, card.ability.extra.dread + CG.gen(card) } }
  end,
  add_to_deck = function(self, card, from_debuff)
    if from_debuff then return end
    ease_dollars(card.ability.extra.dollars)
    CG.play('suona', 1, 0.8)
  end,
  cg_on_return = function(self, card)
    G.GAME.cg_bride = true -- 下一次「它来了」带走最右边的小丑
    CG.msg(card, CG.L('The wedding is set', '亲事定了'), HEX('c8352b'))
  end,
  calculate = function(self, card, context)
    if context.individual and context.cardarea == G.play and not context.blueprint
        and (context.other_card:is_suit('Hearts') or context.other_card:is_suit('Diamonds')) then
      return { dollars = 1 } -- 红色花色：红包的颜色
    end
    if eor(context) then
      CG.add_dread(card.ability.extra.dread + CG.gen(card), card)
    end
  end,
}

-- 2 猴爪
CG.J {
  key = 'monkey_paw', rarity = 3, cost = 8, cg_cursed = true, blueprint_compat = true,
  config = { extra = { xmult = 3, step = 0.5 } },
  loc_txt = {
    ['en-us'] = { name = "Monkey's Paw", text = {
      '{X:mult,C:white} X#1# {} Mult',
      'End of round: destroy the',
      '{C:attention}lowest{} card in hand',
      '{C:cg_ink,f:cg_ghost}Borrowed luck must be paid back.{}',
    } },
    ['zh_CN'] = { name = '猴爪', text = {
      '{X:mult,C:white} X#1# {} 倍率',
      '回合结束：销毁手牌中{C:attention}最小{}的一张',
      '{C:cg_ink,f:cg_ghost}借來的運，要還的。{}',
    } },
  },
  loc_vars = function(self, info_queue, card)
    local e = card.ability.extra
    return { vars = { e.xmult + e.step * CG.gen(card), e.step } }
  end,
  calculate = function(self, card, context)
    local e = card.ability.extra
    if context.joker_main then
      return { xmult = e.xmult + e.step * CG.gen(card) }
    end
    -- 吃掉手里点数最小的一张：原版玩家本来就想删牌，这是交易，不是纯惩罚
    if eor(context) and G.hand and #G.hand.cards > 0 then
      local low
      for _, c in ipairs(G.hand.cards) do
        if not c.destroyed and not SMODS.has_no_rank(c) and (not low or c:get_id() < low:get_id()) then low = c end
      end
      if low then
        CG.msg(card, CG.L('It took something', '它拿走了一些东西'))
        SMODS.destroy_cards({ low })
      end
    end
  end,
}

-- 3 床底下
CG.J {
  key = 'under_bed', rarity = 2, cost = 6, blueprint_compat = true,
  config = { extra = { per = 0.15 } },
  loc_txt = {
    ['en-us'] = { name = 'Under the Bed', text = {
      '{X:mult,C:white} X#1# {} Mult per Dread',
      '{C:inactive}(Currently {X:mult,C:white} X#2# {C:inactive}){}',
      "{C:cg_ink,f:cg_ghost}Don't point your shoes at the bed.{}",
    } },
    ['zh_CN'] = { name = '床底下', text = {
      '每点恐惧 {X:mult,C:white} X#1# {} 倍率',
      '{C:inactive}（当前 {X:mult,C:white} X#2# {C:inactive}）{}',
      '{C:cg_ink,f:cg_ghost}鞋尖別朝著床。{}',
    } },
  },
  loc_vars = function(self, info_queue, card)
    return { vars = { card.ability.extra.per, 1 + card.ability.extra.per * CG.dread() } }
  end,
  calculate = function(self, card, context)
    if context.joker_main and CG.dread() > 0 then
      return { xmult = 1 + card.ability.extra.per * CG.dread() }
    end
  end,
}

-- 4 驱魔人
CG.J {
  key = 'exorcist', rarity = 2, cost = 7, -- 平衡：唯一解咒手段，稀有太难刷到
  blueprint_compat = false,
  config = { extra = { per = 2 } },
  loc_txt = {
    ['en-us'] = { name = 'Exorcist', text = {
      'Sell: destroy all {C:red}Cursed{} Jokers,',
      '{C:money}$#1#{} per Dread, Dread to 0',
      '{C:inactive}(Currently {C:money}$#2#{C:inactive}){}',
      '{C:cg_ink,f:cg_ghost}He takes the fee. And the bad luck.{}',
    } },
    ['zh_CN'] = { name = '法师', text = {
      '卖掉：销毁所有{C:red}诅咒{}小丑，',
      '每点恐惧 {C:money}+$#1#{}，恐惧清零',
      '{C:inactive}（当前 {C:money}$#2#{C:inactive}）{}',
      '{C:cg_ink,f:cg_ghost}紅包收了，煞也帶走了。{}',
    } },
  },
  loc_vars = function(self, info_queue, card)
    return { vars = { card.ability.extra.per, card.ability.extra.per * CG.dread() } }
  end,
  calculate = function(self, card, context)
    if context.selling_self and not context.blueprint then
      local cursed = {}
      for _, j in ipairs(G.jokers.cards) do
        if j ~= card and CG.is_cursed(j) then cursed[#cursed + 1] = j end
      end
      local pay = card.ability.extra.per * CG.dread()
      if pay > 0 then ease_dollars(pay) end
      -- 清掉回来路上的诅咒；被魔神仔牵走的是你自己的人：解咒，但照样放回来
      local keep = {}
      for _, e in ipairs(G.GAME.cg_returning or {}) do
        if e.mosina then e.sticker = nil; keep[#keep + 1] = e end
      end
      G.GAME.cg_returning = keep
      G.GAME.cg_bride = nil
      if #cursed > 0 then SMODS.destroy_cards(cursed, { bypass_eternal = true }) end
      CG.play('chant', 1, 0.6) -- 法师收煞
      CG.msg(card, CG.L('Begone', '散'), G.C.GOLD)
      CG.say('the ledger is closed. for now.', '账本合上了。暂时。')
      CG.reset_dread()
    end
  end,
}

-- 5 瓷娃娃
CG.J {
  key = 'doll', rarity = 2, cost = 5, cg_cursed = true, blueprint_compat = true,
  config = { extra = { xmult = 2, step = 0.5, dread = 1 } },
  loc_txt = {
    ['en-us'] = { name = 'Porcelain Doll', text = {
      '{X:mult,C:white} X#1# {} Mult if hand has a {C:attention}Pair{}',
      '{C:red}+#2#{} Dread each round',
      '{C:cg_ink,f:cg_ghost}Not by the bed. Not in the seventh month.{}',
    } },
    ['zh_CN'] = { name = '瓷娃娃', text = {
      '含{C:attention}对子{}时 {X:mult,C:white} X#1# {} 倍率',
      '每回合 {C:red}+#2#{} 恐惧',
      '{C:cg_ink,f:cg_ghost}七月，別把它擺在床頭。{}',
    } },
  },
  loc_vars = function(self, info_queue, card)
    local e = card.ability.extra
    return { vars = { e.xmult + e.step * CG.gen(card), e.dread } }
  end,
  calculate = function(self, card, context)
    local e = card.ability.extra
    if context.joker_main and next(context.poker_hands['Pair']) then
      return { xmult = e.xmult + e.step * CG.gen(card) } -- 娃娃总是成对摆的
    end
    if eor(context) then CG.add_dread(e.dread, card) end
    -- 你去商店的时候，它悄悄换了位置
    if context.starting_shop and not context.blueprint and #G.jokers.cards > 1 then
      G.E_MANAGER:add_event(Event({ func = function()
        local i
        for k, v in ipairs(G.jokers.cards) do if v == card then i = k end end
        local j = pseudorandom('cg_doll', 1, #G.jokers.cards)
        if i and j ~= i then
          table.remove(G.jokers.cards, i)
          table.insert(G.jokers.cards, j, card)
          G.jokers:set_ranks()
        end
        return true
      end }))
    end
  end,
}

-- 找某张小丑左 / 右边的邻居
function CG.neighbour(card, dir)
  for k, v in ipairs(G.jokers.cards) do
    if v == card then return G.jokers.cards[k + dir] end
  end
end

-- 没拆的信：恐惧 ≥ 7 时自己拆开，变成牌池里的随机小丑
function CG.check_letters()
  if not G.jokers or CG.dread() < 7 then return end
  for _, j in ipairs(G.jokers.cards) do
    if j.config.center.key == 'j_cg_letter' and not j.cg_opening then
      j.cg_opening = true
      G.E_MANAGER:add_event(Event({ trigger = 'after', delay = 0.5, func = function()
        if j.facing == 'back' then j:flip() end
        CG.play('return', 1.4, 0.6)
        CG.msg(j, CG.L('It opened itself', '它自己拆开了'))
        G.E_MANAGER:add_event(Event({ trigger = 'after', delay = 0.8, func = function()
          local gen = CG.gen(j)
          j.cg_sold = true -- 拆开不算「被销毁」，招魂不召它
          SMODS.destroy_cards({ j }, { bypass_eternal = true })
          local new = SMODS.add_card { set = 'Joker', rarity = 'Rare', key_append = 'cg_letter' } -- 恐惧的正面回报：一张稀有
          if new and gen > 0 then new:set_edition(poll_edition('cg_letter_ed', nil, true, true)) end
          return true
        end }))
        return true
      end }))
    end
  end
end

-- 6 连锁信
CG.J {
  key = 'chain_letter', rarity = 1, cost = 4, cg_cursed = true, blueprint_compat = true,
  config = { extra = { mult = 4, dread = 1 } },
  loc_txt = {
    ['en-us'] = { name = 'Chain Letter', text = {
      '{C:mult}+#1#{} Mult per Joker',
      '{C:red}+#3#{} Dread each round',
      '{C:inactive}(Currently {C:mult}+#2#{C:inactive}){}',
      '{C:cg_ink,f:cg_ghost}Pass it on.{}',
    } },
    ['zh_CN'] = { name = '连锁信', text = {
      '每张小丑 {C:mult}+#1#{} 倍率',
      '每回合 {C:red}+#3#{} 恐惧',
      '{C:inactive}（当前 {C:mult}+#2#{C:inactive}）{}',
      '{C:cg_ink,f:cg_ghost}轉給下一個人。{}',
    } },
  },
  loc_vars = function(self, info_queue, card)
    local e = card.ability.extra
    local per = e.mult + 2 * CG.gen(card)
    return { vars = { per, per * (G.jokers and #G.jokers.cards or 1), e.dread } }
  end,
  calculate = function(self, card, context)
    local e = card.ability.extra
    if context.joker_main then
      return { mult = (e.mult + 2 * CG.gen(card)) * #G.jokers.cards }
    end
    if eor(context) then CG.add_dread(e.dread, card) end
  end,
}

-- 7 纸人
CG.J {
  key = 'effigy', rarity = 2, cost = 5, -- 平衡：转送循环下近似常驻蓝图，普通太强
  cg_gift = true, blueprint_compat = true,
  config = { extra = { rounds = 3, held = 0, dread = 3 } },
  loc_txt = {
    ['en-us'] = { name = 'Paper Effigy', text = {
      'Copies the Joker to its {C:attention}left{}',
      'In {C:attention}#1#{} rounds, burns into a',
      '{C:tarot}Tarot{} card {C:inactive}({C:red}+#2#{C:inactive} Dread){}',
      '{C:cg_ink,f:cg_ghost}Made to take your place.{}',
    } },
    ['zh_CN'] = { name = '纸人', text = {
      '复制{C:attention}左边{}的小丑',
      '{C:attention}#1#{} 回合后烧成{C:tarot}塔罗牌{}{C:inactive}（{C:red}+#2#{C:inactive} 恐惧）{}',
      '{C:cg_ink,f:cg_ghost}紮來替你擋煞的。{}',
    } },
  },
  loc_vars = function(self, info_queue, card)
    local e = card.ability.extra
    return { vars = { e.rounds + CG.gen(card) - e.held, e.dread } }
  end,
  calculate = function(self, card, context)
    local e = card.ability.extra
    if context.end_of_round and context.main_eval and not context.blueprint then
      e.held = e.held + 1
      if e.held >= e.rounds + CG.gen(card) then
        CG.add_dread(e.dread, card)
        CG.msg(card, CG.L('It burned', '烧掉了'), G.C.ORANGE)
        CG.give('Tarot', 'cg_effigy') -- 烧纸：灰里留下一张塔罗
        SMODS.destroy_cards({ card }, { bypass_eternal = true })
        return
      end
    end
    return SMODS.blueprint_effect(card, CG.neighbour(card, -1), context)
  end,
}

-- 8 纸钱
CG.J {
  key = 'joss', rarity = 1, cost = 4, blueprint_compat = true,
  config = { extra = { dollars = 2 } },
  loc_txt = {
    ['en-us'] = { name = 'Joss Paper', text = {
      'Sell any card: {C:money}+$#1#{}, {C:red}+1{} Dread',
      '{C:cg_ink,f:cg_ghost}Silver for the dead, gold for the gods.{}',
    } },
    ['zh_CN'] = { name = '纸钱', text = {
      '卖掉任何牌：{C:money}+$#1#{}，{C:red}+1{} 恐惧',
      '{C:cg_ink,f:cg_ghost}銀紙燒給好兄弟，金紙燒給神。{}',
    } },
  },
  loc_vars = function(self, info_queue, card) return { vars = { card.ability.extra.dollars } } end,
  calculate = function(self, card, context)
    if context.selling_card and context.card ~= card then
      if not context.blueprint then CG.add_dread(1) end
      return { dollars = card.ability.extra.dollars }
    end
  end,
}

-- 9 守夜
CG.J {
  key = 'night_watch', rarity = 1, cost = 5, blueprint_compat = true,
  config = { extra = { mult = 7 } },
  loc_txt = {
    ['en-us'] = { name = 'Night Watch', text = {
      'Final hand of round: scored',
      '{C:attention}7s{} and {C:attention}4s{} give {C:mult}+#1#{} Mult',
      '{C:cg_ink,f:cg_ghost}The lamp by the door shows them the way.{}',
    } },
    ['zh_CN'] = { name = '守夜', text = {
      '本回合{C:attention}最后一手{}：',
      '计分的 {C:attention}7{} 和 {C:attention}4{} {C:mult}+#1#{} 倍率',
      '{C:cg_ink,f:cg_ghost}門口那盞燈，是給好兄弟認路的。{}',
    } },
  },
  loc_vars = function(self, info_queue, card)
    return { vars = { card.ability.extra.mult } }
  end,
  calculate = function(self, card, context)
    -- 七月、四（死）：守最后一夜
    if context.individual and context.cardarea == G.play and G.GAME.current_round.hands_left == 0 then
      local id = context.other_card:get_id()
      if id == 7 or id == 4 then return { mult = card.ability.extra.mult } end
    end
  end,
}

-- 10 镜子
local function flip_text(t)
  local ok, utf8 = pcall(require, 'utf8')
  if not ok then return t end
  local chars = {}
  for _, c in utf8.codes(t) do table.insert(chars, 1, utf8.char(c)) end
  return table.concat(chars)
end
CG.J {
  key = 'mirror', rarity = 3, cost = 8, -- 平衡：本质是蓝图（原版稀有 $10）
  blueprint_compat = true,
  config = { extra = { flip_at = 10 } },
  loc_txt = {
    ['en-us'] = { name = 'Mirror', text = {
      'Copies the ability of the Joker',
      'to its {C:attention}#1#{}',
      '{C:inactive}#2#{}',
    } },
    ['zh_CN'] = { name = '镜子', text = {
      '复制{C:attention}#1#{}小丑的能力',
      '{C:inactive}#2#{}',
    } },
  },
  loc_vars = function(self, info_queue, card)
    local flipped = CG.dread() >= card.ability.extra.flip_at
    local side = CG.L('right', '右边')
    local hint = CG.L('At 10 Dread, it is not you in the mirror.', '恐惧到 10 时，镜子里的不是你。')
    if flipped then
      side = flip_text(CG.L('left', '左边'))
      hint = flip_text(CG.L('It is not you in the mirror.', '镜子里的不是你。'))
    end
    return { vars = { side, hint } }
  end,
  calculate = function(self, card, context)
    local dir = CG.dread() >= card.ability.extra.flip_at and -1 or 1
    return SMODS.blueprint_effect(card, CG.neighbour(card, dir), context)
  end,
}

-- 11 没拆的信
CG.J {
  key = 'letter', rarity = 2, cost = 6, cg_gift = true, blueprint_compat = false,
  config = {},
  loc_txt = {
    ['en-us'] = { name = 'Unopened Invitation', text = {
      'At {C:red}7{} Dread, opens into',
      'a random {C:red}Rare{} Joker',
      '{C:cg_ink,f:cg_ghost}A Pudu invitation. You are the guest.{}',
    } },
    ['zh_CN'] = { name = '阴间帖', text = {
      '恐惧到 {C:red}7{} 时拆开，',
      '变成随机{C:red}稀有{}小丑',
      '{C:cg_ink,f:cg_ghost}普渡的請帖。你是被請的那個。{}',
    } },
  },
  add_to_deck = function(self, card, from_debuff)
    if from_debuff then return end
    G.E_MANAGER:add_event(Event({ trigger = 'after', delay = 0.4, func = function()
      if card.facing == 'front' then card:flip() end
      CG.check_letters()
      return true
    end }))
  end,
}

-- 12 传家宝
CG.J {
  key = 'heirloom', rarity = 2, cost = 6, cg_gift = true, blueprint_compat = true,
  config = { extra = { xmult = 1.5, step = 0.5 } },
  loc_txt = {
    ['en-us'] = { name = 'Heirloom', text = {
      '{X:mult,C:white} X#1# {} Mult',
      'Returns with {X:mult,C:white} +X#2# {}',
      'and an {C:dark_edition}Edition{}',
      '{C:cg_ink,f:cg_ghost}Jade knows its owner. It is not you.{}',
    } },
    ['zh_CN'] = { name = '传家宝', text = {
      '{X:mult,C:white} X#1# {} 倍率',
      '转送回来时 {X:mult,C:white} +X#2# {} 并带{C:dark_edition}版本{}',
      '{C:cg_ink,f:cg_ghost}玉會認主。它認的不是你。{}',
    } },
  },
  loc_vars = function(self, info_queue, card)
    local e = card.ability.extra
    return { vars = { e.xmult + e.step * CG.gen(card), e.step } }
  end,
  cg_on_return = function(self, card)
    card:set_edition(poll_edition('cg_heir', nil, true, true))
  end,
  calculate = function(self, card, context)
    if context.joker_main then
      local e = card.ability.extra
      return { xmult = e.xmult + e.step * CG.gen(card) }
    end
  end,
}

-- 13 回礼
CG.J {
  key = 'return_gift', rarity = 2, cost = 6, -- 平衡：配合礼物循环能稳定刷幻灵牌
  blueprint_compat = false,
  config = {},
  loc_txt = {
    ['en-us'] = { name = 'Return Gift', text = {
      'When a card {C:attention}returns{} or {C:attention}It{} comes,',
      'create a {C:spectral}Spectral{} card',
      '{C:cg_ink,f:cg_ghost}Fed well, they give a little back.{}',
    } },
    ['zh_CN'] = { name = '回礼', text = {
      '有牌{C:attention}回来{}或{C:attention}它{}来过后，',
      '生成一张{C:spectral}幻灵牌{}',
      '{C:cg_ink,f:cg_ghost}好兄弟吃飽了，會還你一點東西。{}',
    } },
  },
}

-- 14 脚步声
CG.J {
  key = 'footsteps', rarity = 1, cost = 5, blueprint_compat = true,
  config = { extra = { per = 2 } },
  loc_txt = {
    ['en-us'] = { name = 'Footsteps', text = {
      'Each played {C:attention}4{}: {C:red}+1{} Dread',
      '{C:mult}+#2#{} Mult per Dread',
      '{C:inactive}(Currently {C:mult}+#1#{C:inactive}){}',
      '{C:cg_ink,f:cg_ghost}Footprints in the ash. Pointing inward.{}',
    } },
    ['zh_CN'] = { name = '脚步声', text = {
      '每打出一张 {C:attention}4{}：{C:red}+1{} 恐惧',
      '每点恐惧 {C:mult}+#2#{} 倍率',
      '{C:inactive}（当前 {C:mult}+#1#{C:inactive}）{}',
      '{C:cg_ink,f:cg_ghost}頭七早上，灰上的腳印朝屋裡。{}',
    } },
  },
  loc_vars = function(self, info_queue, card)
    return { vars = { card.ability.extra.per * CG.dread(), card.ability.extra.per } }
  end,
  calculate = function(self, card, context)
    if context.before and not context.blueprint then
      local n = 0
      for _, c in ipairs(context.full_hand or {}) do if c:get_id() == 4 then n = n + 1 end end
      if n > 0 then CG.add_dread(n, card) end
    end
    if context.joker_main and CG.dread() > 0 then
      return { mult = card.ability.extra.per * CG.dread() }
    end
  end,
}

-- S 招魂（幻灵牌）
SMODS.Consumable {
  key = 'seance', set = 'Spectral', atlas = 'jokers', pos = { x = CG.ORDER.seance, y = 0 },
  cost = 4, unlocked = true, discovered = true,
  loc_txt = {
    ['en-us'] = { name = 'Seance', text = {
      'Revive the last {C:attention}destroyed{}',
      'Joker {C:inactive}(#1#){}, {C:red}Cursed{}',
      '{C:cg_ink,f:cg_ghost}It remembers who asked.{}',
    } },
    ['zh_CN'] = { name = '牵亡', text = {
      '召回最近被{C:attention}销毁{}的小丑{C:inactive}（#1#）{}',
      '它会带着{C:red}诅咒{}回来',
      '{C:cg_ink,f:cg_ghost}它也記得是誰問的。{}',
    } },
  },
  loc_vars = function(self, info_queue, card)
    local k = G.GAME and G.GAME.cg_last_destroyed
    local name = k and G.P_CENTERS[k] and localize { type = 'name_text', set = 'Joker', key = k } or CG.L('none yet', '还没有')
    return { vars = { name } }
  end,
  can_use = function(self, card)
    return G.GAME.cg_last_destroyed and G.P_CENTERS[G.GAME.cg_last_destroyed]
        and #G.jokers.cards < G.jokers.config.card_limit
  end,
  use = function(self, card, area, copier)
    local key = G.GAME.cg_last_destroyed
    G.E_MANAGER:add_event(Event({ trigger = 'after', delay = 0.4, func = function()
      local j = SMODS.add_card { key = key }
      if j then
        CG.curse(j)
        CG.play('return', 0.8, 0.9)
        CG.play('chant', 0.94, 0.5) -- 牵亡
        CG.msg(j, CG.L('It answered', '它应了'))
      end
      G.GAME.cg_last_destroyed = nil
      return true
    end }))
  end,
}

-- 测试时不占屏：第一帧把窗口改成右下角小窗口（只改这次运行，不写进设置）
if os.getenv('CG_TEST') then
  local done, upd0 = false, Game.update
  function Game:update(dt)
    if not done then
      done = true
      local dw, dh = love.window.getDesktopDimensions()
      local demo = os.getenv('CG_TEST') == 'demo' or os.getenv('CG_TEST') == 'polish'
      local w, h = demo and 960 or 640, demo and 540 or 400
      love.window.setMode(w, h, { fullscreen = false, resizable = true, highdpi = not demo, x = dw - w - 10, y = dh - h - 40 })
      love.resize(love.graphics.getWidth(), love.graphics.getHeight())
    end
    return upd0(self, dt)
  end
end

if os.getenv('CG_TEST') == 'fx' then assert(SMODS.load_file('test_fx.lua'))()
elseif os.getenv('CG_TEST') == 'polish' then assert(SMODS.load_file('test_polish.lua'))()
elseif os.getenv('CG_TEST') == 'interact' then assert(SMODS.load_file('test_interact.lua'))()
elseif os.getenv('CG_TEST') == 'tw' then assert(SMODS.load_file('test_tw.lua'))()
elseif os.getenv('CG_TEST') == 'whisper' then assert(SMODS.load_file('test_whisper.lua'))()
elseif os.getenv('CG_TEST') == 'show' then assert(SMODS.load_file('test_show.lua'))()
elseif os.getenv('CG_TEST') == 'demo' then assert(SMODS.load_file('test_demo.lua'))()
elseif os.getenv('CG_TEST') == 'rework' then -- test_rework.lua 在 tw.lua 之后加载
elseif os.getenv('CG_TEST') and os.getenv('CG_TEST') ~= 'pool' and os.getenv('CG_TEST') ~= 'chal' then assert(SMODS.load_file('test.lua'))() end

-- 台湾鬼月篇新牌（掷筊 / 普渡供桌 / 魔神仔 / 水鬼 / 跳钟馗），见 docs/world-tw.md
assert(SMODS.load_file('cards_tw.lua'))()

-- 输赢结算画面（前任牌客的反转台词），见 docs/endings.md
assert(SMODS.load_file('endings.lua'))()
if os.getenv('CG_ENDINGS') then assert(SMODS.load_file('test_endings.lua'))() end

-- 跨局记忆（台湾鬼月篇），见 docs/memory.md
assert(SMODS.load_file('memory.lua'))()
if os.getenv('CG_MEMORY') then assert(SMODS.load_file('test_memory.lua'))() end

-- 鬼月挑战 + 第一次启动选恐怖强度，见 challenges.lua
assert(SMODS.load_file('challenges.lua'))()
if os.getenv('CG_TEST') == 'chal' then assert(SMODS.load_file('test_chal.lua'))() end

-- 鬼月日历：底注 4 中元普渡 / 底注 8 关鬼门，见 calendar.lua
assert(SMODS.load_file('calendar.lua'))()

-- 悬浮说明、鬼月牌组、传奇、符印、优惠券、标签，见 extras.lua；装了 JokerDisplay 就挂上显示定义
assert(SMODS.load_file('extras.lua'))()
if JokerDisplay then assert(SMODS.load_file('joker_display.lua'))() end

-- 混玩定位：诅咒牌退出牌池、纸钱包、恐惧条碰到才浮现，见 pool.lua
assert(SMODS.load_file('pool.lua'))()
if os.getenv('CG_TEST') == 'pool' then assert(SMODS.load_file('test_pool.lua'))() end

-- 台湾繁体 + 英文翻译（必须最后加载），见 tw.lua
assert(SMODS.load_file('tw.lua'))()
if os.getenv('CG_TEST') == 'rework' then assert(SMODS.load_file('test_rework.lua'))() end
