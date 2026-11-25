-- 跨局记忆（台湾鬼月篇）：一局 = 一个鬼月。记住你熬过几个七月、当过几次交替、哪些小丑被抓过交替。
-- 只存几项计数和小丑 key，存在本 mod 的设置文件里（config/CursedGifts.jkr），不联网、不读别的东西。
-- 设置页有「记住之前的鬼月」开关和「忘掉之前的鬼月」按钮。设定见 docs/world-tw.md，设计见 docs/memory.md
local CG = CursedGifts

local function mem()
  CG.cfg.mem = CG.cfg.mem or {}
  local m = CG.cfg.mem
  m.months = m.months or 0       -- 碰过本 mod 的鬼月数（打完的局）
  m.wins = m.wins or 0           -- 熬过鬼月（通关）
  m.losses = m.losses or 0       -- 成了交替（输）
  m.taken_total = m.taken_total or 0 -- 累计被抓交替的小丑
  m.taken = m.taken or {}        -- 被抓过的小丑 key → 次数
  m.said = m.said or {}          -- 只说一次的里程碑
  return m
end
CG.mem = mem

local function on() return CG.cfg.remember ~= false end
-- 有种子的局（含自动测试）不记，避免测试污染真实记忆；测试里用 CG.MEMORY_FORCE 打开
local function recordable() return on() and G.GAME and (CG.MEMORY_FORCE or not G.GAME.seeded) end
local function save() SMODS.save_mod_config(CG.mod) end

---------------------------------------------------------------- 开局：上个月发生了什么

-- 纯函数，方便测试：给记忆，返回这局开头要说的话（en, zh, 里程碑 key）
function CG.memory_greeting(m)
  if m.months + 1 == 7 and not m.said.m7 then
    return 'the seventh July', '第七个七月了。', 'm7'
  end
  if m.taken_total >= 13 and not m.said.t13 then
    return 'it knows your name now', '它知道你的名字了。', 't13'
  end
  if m.last == 'loss' then return 'last month, you were the replacement', '上个月，你是交替。' end
  if m.last == 'win' then return 'this year, you deal', '今年，换你坐庄。' end
end

local maybe_whisper_ref = CG.maybe_whisper
function CG.maybe_whisper()
  if G.GAME and not G.GAME.cg_mem_greeted then
    G.GAME.cg_mem_greeted = true
    local m = mem()
    G.GAME.cg_prev_last = m.last -- 结算台词要用「上一局」的结果，开局先存下来
    if on() and m.months > 0 and CG.on('fourth_wall') then
      local en, zh, flag = CG.memory_greeting(m)
      if en then
        if flag then m.said[flag] = true; save() end
        CG.whisper(CG.B(en, zh))
        return
      end
    end
  end
  return maybe_whisper_ref()
end

---------------------------------------------------------------- 局中：又见面了

local add_to_deck_ref = Card.add_to_deck
function Card:add_to_deck(from_debuff)
  local r = add_to_deck_ref(self, from_debuff)
  local key = self.config and self.config.center and self.config.center.key
  if not from_debuff and G.GAME and key and self.ability and self.ability.set == 'Joker' and on() then
    local m = mem()
    G.GAME.cg_mem_seen = G.GAME.cg_mem_seen or {}
    if (m.taken[key] or 0) > 0 and not G.GAME.cg_mem_seen[key] and CG.on('fourth_wall') then
      G.GAME.cg_mem_seen[key] = true
      CG.msg(self, CG.L('Again', '又见面了'))
    end
  end
  return r
end

---------------------------------------------------------------- 局末：记账

local function finish(result)
  if not recordable() or not G.GAME.cg_touched or G.GAME.cg_mem_done then return end
  G.GAME.cg_mem_done = true
  local m = mem()
  m.months = m.months + 1
  if result == 'win' then m.wins = m.wins + 1 else m.losses = m.losses + 1 end
  m.last = result
  for _, k in ipairs(G.GAME.cg_taken or {}) do
    m.taken[k] = (m.taken[k] or 0) + 1
    m.taken_total = m.taken_total + 1
  end
  save()
end
CG.memory_finish = finish

local win_ref = win_game
function win_game(...)
  finish('win')
  return win_ref(...)
end

-- 无尽模式里输了不算「成了交替」：鬼门已经关了，你是自己留下的
local game_over_ref = Game.update_game_over
function Game:update_game_over(dt)
  if not self.STATE_COMPLETE and G.GAME and not G.GAME.won then finish('loss') end
  return game_over_ref(self, dt)
end

---------------------------------------------------------------- 设置页：开关和「忘掉」

G.FUNCS.cg_forget = function(e)
  CG.cfg.mem = nil
  mem()
  save()
  play_sound('cancel')
  if e and e.config then e.config.colour = G.C.UI.BACKGROUND_INACTIVE end
end

local config_tab_ref = CG.mod.config_tab
CG.mod.config_tab = function()
  local t = config_tab_ref()
  local col = t.nodes and t.nodes[1] and t.nodes[1].nodes
  if col then
    if CG.cfg.remember == nil then CG.cfg.remember = true end
    local m = mem()
    col[#col + 1] = create_toggle { label = CG.L('Remember past Ghost Months', '记住之前的鬼月'),
      ref_table = CG.cfg, ref_value = 'remember', w = 5 }
    col[#col + 1] = { n = G.UIT.R, config = { align = 'cm', padding = 0.05 }, nodes = {
      { n = G.UIT.T, config = { scale = 0.3, colour = G.C.UI.TEXT_INACTIVE, text = CG.L(
        ('%d months · survived %d · replaced %d'):format(m.months, m.wins, m.losses),
        ('已过 %d 个鬼月 · 熬过 %d · 当过 %d 次交替'):format(m.months, m.wins, m.losses)) } },
    } }
    col[#col + 1] = UIBox_button { button = 'cg_forget', label = { CG.L('Forget past Ghost Months', '忘掉之前的鬼月') },
      minw = 4.5, minh = 0.6, scale = 0.4, colour = G.C.RED }
  end
  return t
end
