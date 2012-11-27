local M = {}
local M_mt = { __index = M }
local slnuni = require 'unicode'.utf8
local D = require "serpent".block
local lpeg   = require 'lpeg'
-- TODO use lpeg_utf8 from LuaRocks when it's released
local locale = package.loadlib("../lpeg_utf8/lpeg_utf8.so", "luaopen_lpeg_utf8")().locale()
local B, P, C, Cs, R, S, V = lpeg.B, lpeg.P, lpeg.C, lpeg.Cs, lpeg.R, lpeg.S, lpeg.V

local function aux_power(n, t)
 local name = "p" .. n
 if n == 1 then
   return name
 else
   local m = aux_power(math.floor(n/2), t)
   m = lpeg.V(m)
   t[name] = m * m
   if n % 2 ~= 0 then
     t[name] = lpeg.V("p1") * t[name]
   end
 end
 return name
end

-- quantifier like Perl's /foo{3}/
local function Q(p, n)
  local a = {p1 = lpeg.P(p)}
  a[1] = aux_power(n, a)
  return lpeg.P(a)
end

-- spacing constants
local S_NORMAL  = 0
local S_PREFIX  = 1
local S_POSTFIX = 2
local S_INFIX   = 3

-- general character classes
local anything   = P(1)
local eof        = P(-1)
local word_char  = locale.alnum + P('_')
local space      = locale.space
local ascii_w    = R('AZ') + R('az') + R('09') + P('_')
local alphabet   = locale.alpha
local digit      = locale.digit
local lower      = locale.lower
local upper      = locale.upper
local nonspace   = 1-space
local newline    = (P('\r') + '') * P('\010')

-- tokenization
local dash       = P('–') + P('-')
local point      = S('.,')
local apostrophe = P("'") + P('’') + P('´')
local ellipsis   = P('.')^2 + P('…')
local nonword    = (1-(word_char + space))^1
local and_word   = alphabet^1 * (P('&') * alphabet^1)^1
local bare_word  = and_word + word_char^1
local currency   = P('¤') + P('¥') + P('¢') + P('£') + P('$')
local number     = (currency + '') * (point + '') * digit^1 * (point * digit^1)^0 * ((currency + alphabet^0) + '') * -(digit + alphabet)
local apost_word = alphabet^1 * (apostrophe * alphabet^1)^1
local dot        = P('.')
local abbrev     = alphabet^1 * (dot * alphabet^1)^1 * dot
local dotted     = (bare_word + '') * dot * bare_word * (dot * bare_word)^0
local word_types = number + abbrev + dotted + apost_word + bare_word
local word_apost = word_types * (dash * word_types)^0 * apostrophe * -(alphabet + number)
local word       = word_types * (((dash * word_types)^1 + dash * -dash) + '')
local mixed_case = P{((lower^1 * upper) + (upper^2 * lower)) + 1 * V(1)}
local upper_nonw = #(-(P('I') * apostrophe)) * (upper^1 * (1-word_char)^1) * upper^0 * lower

-- special tokens
local twat_name  = P('@') * ascii_w^1
local email      = (ascii_w + S('.%+-'))^1
                   * P('@')
                   * (R('AZ') + R('az') + R('09') + S('.-'))^1
                   * (dot * (#((R('AZ') + R('az'))^2) * (R('AZ') + R('az'))^-4))^0
local perl_class = (((P('::') * ascii_w^1 * (P('::') * ascii_w^1)^0) + (ascii_w^1 * (P('::') * ascii_w^1)^1)) * (P('::') + '')) + (ascii_w^1 * P('::'))
local esc_space  = P('\\ ')^1
local name       = (bare_word + esc_space)^1
local filename   = ((name + '') * dot * name * (dot * name)^0) + name
local unix_path  = P('/') * filename * (P('/') * filename)^0 * (P('/') + '')
local win_path   = (R('AZ') + R('az')) * P(':\\') * filename * (P('\\') * filename)^0 * (P('\\') + '')
local path       = unix_path + win_path
local date       = Q(R('09'), 4) * P('-') * (S('Ww') + '') * Q(R('09'), 1) * R('09')^(1-2) * P('-') * R('09') * R('09')^(1-2)
local time       = R('09') * R('09')^(1-2) * P(':') * Q(R('09'), 2)
                   * ((P(':') * Q(R('09'), 2)) + '')
                   * ((P('Z')
                       + ((P(' ') + '') * S('AaPp') * S('Mm'))
                       + ((P('±') + S('+-')) * Q(R('09'), 2) * (((P(':') + '') * Q(R('09'), 2)) + ''))) + '')
local datetime   = date * P('T') * time
local irc_nick   = P('<')
                     * ((P(' ') + ((S('&~') + '') * S('@%+~&'))) + '')
                     * (R('AZ') + R('az') + S('_`-^|\\{}[]')) * (R('AZ') + R('az') + R('09') + S('_`-^|\\{}[]'))^1
                   * P('>')
local chan_char  = 1-S(' \a\000\010\013,:')
local irc_chan   = S('#&+') * chan_char * chan_char^(1-199)
local numero     = P('#') * R('09')^1
-- these tickle a bug in lpeg_utf8
--local close_tag  = P('</') * (word_char + P('-'))^1 * P('>')
--local uri        = (((R('AZ') + R('az') + R('09'))^1 * '+') + '') * (R('AZ') + R('az') + R('09'))^1 * P('://') * ((1-(space + P('«') + P('»') + S(',;<>[]{}()´`')))^1 + '')
local uri        = (((R('AZ') + R('az') + R('09'))^1 * '+') + '') * (R('AZ') + R('az') + R('09'))^1 * P('://') * ((1-(S(',;<>[]{}()´`') + P('«') + P('»') + space))^1 + '')
local cased_word = irc_nick + irc_chan + datetime + date + time
                   + perl_class + uri + email + twat_name + path + numero

local open_quote  = P("'") + P('"') + P('‘') + P('“') + P('„') + P('«') + P('»') + P('「') + P('『') + P('‹') + P('‚')
local close_quote = P("'") + P('"') + P('’') + P('“') + P('”') + P('«') + P('»') + P('」') + P('』') + P('›') + P('‘')
local terminator  = (S('?!') + P('‽')) + B(-dot) * dot
local address     = P(':')
local punctuation = S('?!,;.:') + P('‽')
local boundary    = (close_quote + '') * ((space^0 * terminator) + address) * space^1 * (open_quote + '') * space^0
local loose_word  = irc_chan + datetime + date + time + path + number + abbrev + apost_word + numero + bare_word * ((dash * (word_types + bare_word)) + (apostrophe * #(-(alphabet + number + apostrophe)) + (dash * #(-(Q(dash, 2))))) )^0
local split_word  = loose_word * (P('/') * loose_word + '') * #((punctuation * (space^1 + eof)) + close_quote + terminator + space + eof)

local dotted_strict = loose_word * ((point * (digit^1 + word_char^2)) + '')
local word_strict   = dotted_strict * (apostrophe * dotted_strict)^0

local get_cased_word = C(cased_word) * C(anything^0)
local get_word       = C(word) * C(anything^0)
local get_nonword    = C(nonword) * C(anything^0)
local join_dashed    = Cs(((B(dash) * (space - newline)^0 * newline^1 * (space - newline)^0) / '' + 1)^0)
local replace_nl     = Cs(((space^0 * newline^1 * space^0) / ' ' + 1)^0)
local trim_before    = P(space^0 * C(anything^0))

function M:new(args)
  args = args or {}
  return setmetatable(args, M_mt)
end

function M:make_tokens(input)
  local tokens = {}
  input = lpeg.match(join_dashed, input)
  input = lpeg.match(replace_nl, input)

  while string.len(input) > 0 do
    input = lpeg.match(trim_before, input)

    local got_word = false
    while lpeg.match(nonspace, input) do
      local done = false

      if not got_word then
        local rest, cased_word
        cased_word, rest = lpeg.match(get_cased_word, input)
        if cased_word then
          input = rest
          table.insert(tokens, {S_NORMAL, cased_word})
          got_word = true
          done = true
        end
      end

      if not done then
        local word, rest
        word, rest = lpeg.match(get_word, input)
        if word then
          input = rest

           -- TODO: handle "ridin'"

          if word ~= slnuni.upper(word)
              and not lpeg.match(mixed_case, word)
              and not lpeg.match(upper_nonw, word) then
            word = slnuni.lower(word)
          end
          table.insert(tokens, {S_NORMAL, word})
          got_word = true
          done = true
        end
      end

      if not done then
        local nonword
        nonword, input = lpeg.match(get_nonword, input)
        spacing = S_NORMAL
        if got_word then
          spacing = lpeg.match(nonspace, input)
            and S_INFIX
            or S_POSTFIX
        elseif lpeg.match(nonspace, input) then
          spacing = S_PREFIX
        end
        table.insert(tokens, {spacing, nonword})
        got_word = false
      end
    end
  end

  --print(D(tokens))
  return tokens
end

function M:make_output(tokens)
  local reply = {}

  for i, token_spec in next,tokens,nil do
    local spacing, text = token_spec[1], token_spec[2]
    table.insert(reply, text)
    if i ~= #tokens
       and spacing ~= S_PREFIX
       and spacing ~= S_INFIX
       and not(i < #tokens
               and tokens[i+1][1] == S_POSTFIX
               or tokens[i+1][1] == S_INFIX) then
      table.insert(reply, ' ')
    end
  end

  -- TODO: capitalize text and add paragraph terminators

  return table.concat(reply, '')
end

return M
