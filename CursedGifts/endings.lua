-- 输赢结算画面：小丑都是前任牌客（台湾鬼月篇里 = 没熬过去的替身）。设计见 docs/endings.md
-- 只用包装函数挂到 main.lua 的现有逻辑上，main.lua 只需要在末尾加载本文件。
local CG = CursedGifts

---------------------------------------------------------------- 局内记录

-- 碰过本 mod 的局才接管结算画面，不打扰只是装了 mod 的玩家
local function touch() if G.GAME then G.GAME.cg_touched = true end end

local add_dread_ref = CG.add_dread
function CG.add_dread(n, card)
  if n and n > 0 then touch() end
  return add_dread_ref(n, card)
end

local add_to_deck_ref = Card.add_to_deck
function Card:add_to_deck(from_debuff)
  local key = self.config and self.config.center and self.config.center.key
  if G.GAME and key and (key:find('^j_cg_') or key:find('^c_cg_')) then
    touch()
    if key == 'j_cg_red_envelope' then G.GAME.cg_had_envelope = true end
  end
  return add_to_deck_ref(self, from_debuff)
end

-- 「它来了」：记下被带走的是谁，第 ③ 拍飘一行小字
local impact_ref = CG.impact
function CG.impact(victim)
  local bride = G.GAME.cg_bride
  local taken = victim and not victim.removed and victim.config.center.key
  local gift = taken and CG.is_gift and CG.is_gift(victim)
  G.GAME.cg_came = (G.GAME.cg_came or 0) + 1
  if taken then
    G.GAME.cg_taken = G.GAME.cg_taken or {}
    table.insert(G.GAME.cg_taken, taken)
  end
  local r = impact_ref(victim)
  touch()
  if not taken then
    CG.say('next time', '下次')
  elseif bride then
    CG.say('the bride has been chosen', '新娘选好了')
  elseif gift then
    CG.say('it took the gift back too', '礼物它也收回去了')
  elseif G.GAME.cg_came == 1 then
    CG.say('one page full', '记满一页了')
  elseif G.GAME.cg_came >= 3 then
    CG.say("it's getting used to you", '它开始习惯你了')
  else
    CG.say('your turn soon', '很快轮到你')
  end
  return r
end

-- 通关后选无尽模式：第一个盲注说一次「你留下了」
local maybe_whisper_ref = CG.maybe_whisper
function CG.maybe_whisper()
  if G.GAME.won and not G.GAME.cg_stayed and CG.on('fourth_wall') then
    G.GAME.cg_stayed = true
    CG.whisper(CG.B('You stayed.', '你留下了。'))
    return
  end
  return maybe_whisper_ref()
end

---------------------------------------------------------------- 谁站在那儿说话

local function valid(key) return key and G.P_CENTERS[key] and key or nil end

local function taken_key()
  local t = G.GAME and G.GAME.cg_taken
  return t and valid(t[#t])
end

local function held(pred)
  if not G.jokers then return nil end
  for _, j in ipairs(G.jokers.cards) do
    if pred(j) then return j.config.center.key end
  end
end

local function holding(key) return held(function(j) return j.config.center.key == key end) end
local function leftmost() return G.jokers and G.jokers.cards[1] and valid(G.jokers.cards[1].config.center.key) end
local function cursed_held() return held(function(j) return CG.is_cursed(j) end) end
local function came() return (G.GAME and G.GAME.cg_came) or 0 end
local function touched() return G.GAME and G.GAME.cg_touched end

local function speaker(...)
  for i = 1, select('#', ...) do
    local k = valid((select(i, ...)))
    if k then return { center = k } end
  end
  return { center = 'j_joker' }
end

---------------------------------------------------------------- 台词

CG.QUIPS = {}

local function quip(def)
  -- extra 必须是表：Card_Character:say_stuff 会直接读 quip.extra.sound 等字段（写成函数会崩，11/25 实测）
  -- 所以在 filter 里（抽签前）把这局该谁说话写进 extra.center
  local q = SMODS.JimboQuip {
    key = def.key, type = def.type,
    loc_txt = { ['en-us'] = def.en, ['zh_CN'] = def.zh },
    extra = { center = 'j_joker' },
    filter = function(self, t)
      if not touched() then return false end
      local ok = def.when()
      if ok then self.extra.center = speaker(def.who()).center end
      return ok, { weight = def.weight or 1 }
    end,
  }
  -- 注册后 key 可能被加上 mod 前缀，对象和两种 key 都记下
  CG.QUIPS[def.key] = true
  if type(q) == 'table' then
    CG.QUIPS[q] = true
    if q.key then CG.QUIPS[q.key] = true end
  end
end

local always = function() return true end

-- 输
quip { key = 'lq_chair', type = 'loss', weight = 3,
  en = { 'I sat in that', 'chair too.' }, zh = { '那把椅子，', '我也坐过。' },
  when = function() return taken_key() end, who = function() return taken_key() end }
quip { key = 'lq_room', type = 'loss', weight = 2,
  en = { 'Move over.', "There's room in the hand." }, zh = { '挪一挪。', '手里还有位置。' },
  when = function() return taken_key() end, who = function() return taken_key() end }
quip { key = 'lq_warm', type = 'loss', weight = 2,
  en = { "It's warmer in here", "than you'd think." }, zh = { '这里面', '比你想的暖和。' },
  when = function() return taken_key() end, who = function() return taken_key() end }
quip { key = 'lq_wedding', type = 'loss', weight = 3,
  en = { 'Congratulations', 'on the wedding.' }, zh = { '恭喜。', '新婚快乐。' },
  when = function() return G.GAME.cg_had_envelope end, who = function() return 'j_cg_red_envelope' end }
quip { key = 'lq_kept', type = 'loss', weight = 2,
  en = { 'You kept its gift.', 'It kept you.' }, zh = { '你留着它的礼物，', '它就留着你。' },
  when = function() return cursed_held() end, who = function() return cursed_held() end }
quip { key = 'lq_nocome', type = 'loss', weight = 2,
  en = { "It didn't even", 'have to come.' }, zh = { '它连来', '都不用来。' },
  when = function() return came() == 0 and (G.GAME.cg_driven or 0) == 0 end, who = function() return 'j_joker' end }
quip { key = 'lq_full', type = 'loss', weight = 2,
  en = { 'The page was', 'almost full anyway.' }, zh = { '反正那一页', '也快写满了。' },
  when = function() return CG.dread() >= 10 end, who = function() return taken_key() end }
quip { key = 'lq_dealt', type = 'loss', weight = 1,
  en = { 'Your turn', 'to be dealt.' }, zh = { '轮到你', '被发出去了。' },
  when = always, who = function() return 'j_joker' end }

-- 台湾鬼月篇：抓交替（docs/world-tw.md）
quip { key = 'lq_thanks', type = 'loss', weight = 4,
  en = { 'Thank you.', 'I can go now.' }, zh = { '谢谢你。', '我可以走了。' },
  when = function() return taken_key() end, who = function() return taken_key() end }
quip { key = 'lq_water', type = 'loss', weight = 3,
  en = { "You'll get used", 'to the water.' }, zh = { '水里，', '会习惯的。' },
  when = function() return holding('j_cg_water_ghost') end, who = function() return 'j_cg_water_ghost' end }

-- 赢
local function elder() return holding('j_cg_exorcist') or leftmost() end
quip { key = 'wq_page', type = 'win', weight = 3,
  en = { 'The ledger turns a page.', 'The table needs a dealer.' }, zh = { '账本翻了一页。', '这张桌子需要一个发牌的人。' },
  when = always, who = elder }
quip { key = 'wq_closed', type = 'win', weight = 3,
  en = { 'I closed it once too.', 'Look where I sit.' }, zh = { '我也合上过一次。', '你看我现在坐在哪儿。' },
  when = function() return holding('j_cg_exorcist') end, who = function() return 'j_cg_exorcist' end }
quip { key = 'wq_waiting', type = 'win', weight = 2,
  en = { 'It never came.', "That means it's waiting." }, zh = { '它一次都没来。', '那说明它在等。' },
  when = function() return came() == 0 and (G.GAME.cg_driven or 0) == 0 end, who = leftmost }
quip { key = 'wq_few', type = 'win', weight = 3,
  en = { 'We lost a few.', 'We always do.' }, zh = { '我们少了几个人。', '每次都会少。' },
  when = function() return came() >= 3 end, who = leftmost }
quip { key = 'wq_road', type = 'win', weight = 1,
  en = { 'Shuffle.', "Someone's coming up the road." }, zh = { '洗牌吧。', '路上有人来了。' },
  when = always, who = leftmost }
quip { key = 'wq_heir', type = 'win', weight = 2,
  en = { 'Hand it down.', 'It was never yours.' }, zh = { '传下去吧。', '它本来就不是你的。' },
  when = function() return holding('j_cg_heirloom') end, who = function() return 'j_cg_heirloom' end }

quip { key = 'wq_gate', type = 'win', weight = 3,
  en = { 'The gate is closed.', 'See you next July.' }, zh = { '鬼门关了。', '明年七月见。' },
  when = always, who = elder }
quip { key = 'wq_dance', type = 'win', weight = 3,
  en = { 'Someone danced for you.', "Don't forget to thank him." }, zh = { '有人替你跳了一场。', '记得谢谢他。' },
  when = function() return (G.GAME.cg_driven or 0) > 0 end, who = leftmost }

-- 跨局记忆（memory.lua 开局时把上一局结果存进 G.GAME.cg_prev_last）
quip { key = 'lq_again', type = 'loss', weight = 4,
  en = { 'You again?', 'Last July too.' }, zh = { '又是你？', '去年七月也是。' },
  when = function() return G.GAME.cg_prev_last == 'loss' end, who = function() return taken_key() end }
quip { key = 'wq_dealer', type = 'win', weight = 4,
  en = { 'You dealt last year too.', 'Same seat.' }, zh = { '去年也是你发的牌。', '老位置。' },
  when = function() return G.GAME.cg_prev_last == 'win' end, who = elder }

-- 碰过本 mod 的局，把原版和别的 mod 的结算台词拿掉；兜底台词（lq_dealt / wq_page）保证池子不会空
CG.mod.quip_filter = function(q, t)
  if not touched() then return true end
  if t ~= 'win' and t ~= 'loss' then return true end
  return CG.QUIPS[q] or CG.QUIPS[q.key] or false
end
