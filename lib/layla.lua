local M = {}
local M_mt = { __index = M }
local D = require "serpent".block
local tokenizer_class = require "layla.tokenizer.words"
local model_class = require "layla.model"

function M:new(args)
  args = args or {}
  args._model = model_class:new()
  args._model:init()
  args._toke = tokenizer_class:new()
  return setmetatable(args, M_mt)
end

function M:train(filename)
  local model = self._model

  file = io.open(filename, 'r')
  text = file:read('*all')
  file:close()

  model:begin_transaction()
  local i = 1
  -- process all non-empty lines
  for line in text:gmatch("[^\n]+") do
    local tokens = self._toke:make_tokens(line)
    model:learn(tokens)
    if i % 1000 == 0 then
      print(i)
    end
    i = i+1
  end
  model:end_transaction()
end

function M:reply(tokens)
  tokens = self._toke:make_tokens(tokens)
  local reply = self._model:reply(tokens)
  return self._toke:make_output(reply)
end

return M
