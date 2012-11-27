local M = {
  db_file = "layla.sqlite",
  caching = true,
  new_db = true,
  _order = 2,
  _token_cache = {},
  _expr_cache = {},
  _link_cache = {},
  _sth = {},
}
local M_mt = { __index = M }
local sqlite3 = require "lsqlite3"
local D = require "serpent".block
math.randomseed(os.time())

M._schema = [[
  CREATE TABLE info (
    attribute TEXT NOT NULL PRIMARY KEY,
    text      NOT NULL
  );
  CREATE TABLE tokens (
    id      INTEGER PRIMARY KEY AUTOINCREMENT,
    spacing INTEGER NOT NULL,
    text    TEXT NOT NULL
  );
  CREATE TABLE exprs (
    id        INTEGER PRIMARY KEY AUTOINCREMENT,
    token1_id INTEGER NOT NULL REFERENCES tokens(id),
    token2_id INTEGER NOT NULL REFERENCES tokens(id)
  );
  CREATE TABLE links (
    id           INTEGER PRIMARY KEY AUTOINCREMENT,
    prev_expr_id INTEGER NOT NULL REFERENCES exprs(id),
    next_expr_id INTEGER NOT NULL REFERENCES exprs(id),
    count        INTEGER NOT NULL
  );
  CREATE UNIQUE INDEX IF NOT EXISTS get_token_id on tokens (text, spacing);
  CREATE UNIQUE INDEX IF NOT EXISTS get_expr on exprs (token1_id, token2_id);
  CREATE UNIQUE INDEX IF NOT EXISTS get_link ON links (prev_expr_id, next_expr_id);
  CREATE INDEX IF NOT EXISTS get_link_by_next ON links (next_expr_id);
  CREATE INDEX IF NOT EXISTS get_expr_by_token2 on exprs (token2_id);
]]

--[=[
-- speeds up learning (with a non-empty DB) and replying
M.create_learn_idx = [[
  CREATE UNIQUE INDEX IF NOT EXISTS get_token_id on tokens (text, spacing);
  CREATE UNIQUE INDEX IF NOT EXISTS get_expr on exprs (token1_id, token2_id);
]]

M.drop_learn_idx = [[
  DROP INDEX get_token_id;
  DROP INDEX get_expr;
]]

-- speeds up replying
M.create_reply_idx = [[
  CREATE UNIQUE INDEX IF NOT EXISTS get_link ON links (prev_expr_id, next_expr_id);
  CREATE INDEX IF NOT EXISTS get_link_by_next ON links (next_expr_id);
  CREATE INDEX IF NOT EXISTS get_expr_by_token2 on exprs (token2_id);
]]
M.drop_reply_idx = [[
  DROP INDEX get_link;
  DROP INDEX get_link_by_next;
  DROP INDEX get_expr_by_token2;
]]
--]=]

M._statements = {
  add_token     = "INSERT INTO tokens (spacing, text) VALUES (?, ?)",
  token_spec    = "SELECT spacing, text FROM tokens WHERE id = ?;",
  token_id      = "SELECT id FROM tokens WHERE spacing = ? AND text = ?;",
  add_expr      = "INSERT INTO exprs (token1_id, token2_id) VALUES (?, ?)",
  get_expr      = "SELECT id FROM exprs WHERE token1_id = ? AND token2_id = ?;",
  add_link      = [[INSERT INTO links (prev_expr_id, next_expr_id, count)
                    VALUES (?, ?, ?);]],
  inc_link      = [[UPDATE links SET count = count + ?
                    WHERE prev_expr_id = ? AND next_expr_id = ?]],
  similar_token = [[SELECT id, spacing FROM tokens
                    WHERE text = ?
                    ORDER BY random()
                    LIMIT 1;]],
  random_token = [[SELECT id, spacing, text FROM tokens
                   WHERE rowid = (abs(random()) % (
                     SELECT seq+1 FROM sqlite_sequence
                     WHERE name = 'tokens'));]],
  random_expr  = [[SELECT * FROM exprs
                   WHERE token1_id = :id OR token2_id = :id
                   ORDER BY random()
                   LIMIT 1;]],
  prev_expr    = [[SELECT id, token1_id, token2_id FROM exprs
                   WHERE exprs.id = (
                     SELECT prev_expr_id FROM links
                     WHERE next_expr_id = :last_expr_id
                     LIMIT 1
                     OFFSET abs(random()) % (
                       SELECT count(*) FROM links
                       WHERE next_expr_id = :last_expr_id))]],
  next_expr    = [[SELECT id, token1_id, token2_id FROM exprs
                   WHERE exprs.id = (
                     SELECT next_expr_id FROM links
                     WHERE prev_expr_id = :last_expr_id
                     LIMIT 1
                     OFFSET abs(random()) % (
                       SELECT count(*) FROM links
                       WHERE prev_expr_id = :last_expr_id))]],
}

function M:new(args)
  args = args or {}
  return setmetatable(args, M_mt)
end

function M:init()
  local db = sqlite3.open(self.db_file)
  self._db = db
  db:execute("PRAGMA synchronous=OFF;")
  db:execute("PRAGMA journal_mode=OFF;")

  local result = {}
  for a in db:rows("SELECT name FROM sqlite_master WHERE type ='table' AND name='tokens'") do
    table.insert(result, a)
  end
  if #result == 0 then
    db:execute(self._schema)
    if db:error_code() ~= sqlite3.OK then
      print("bar: "..db:error_message())
    end
  end

  for name, statement in pairs(self._statements) do
    self._sth[name] = self._db:prepare(statement)
    if self._db:error_code() ~= sqlite3.OK then
      print("baz: "..self._db:errmsg())
      break
    end
  end

  self._end_token_id = self:_get_or_add_token(0, '')
  --print("id: "..boundary_token_id)
  self._end_expr_id = self:_get_or_add_expr({self._end_token_id, self._end_token_id})
  --print("hlagh: "..db:errmsg())

  --if self.caching and self.new_db then
  --  db:execute(self:_create_)
  --end
end

function M:begin_transaction()
  self._db:execute("BEGIN TRANSACTION;")
end

function M:end_transaction()
  if self.caching then
    self:_flush_cache()
  end
  self._db:execute("END TRANSACTION;")
end

function M:_flush_cache()
  for link_key, count in pairs(self._link_cache) do
    local prev_expr = string.match(link_key, '^%d*')
    local next_expr = string.match(link_key, '%d*$')
    --print(prev_expr.." and "..next_expr.." with "..count)
    if self.new_db then
      self:_add_link(prev_expr, next_expr, count)
    else
      self:_inc_or_add_link(prev_expr, next_expr, count)
    end
  end
  self._link_cache = {}
  self._token_cache = {}
  self._expr_cache = {}
end

function M:learn(tokens)
  if #tokens < self._order then
    return
  end
  local token_cache = {}
  if self.caching then
    token_cache = self._token_cache
  end
  local expr_cache = {}
  if self.caching then
    expr_cache = self._expr_cache
  end
  local token_ids = {}
  local expr_ids = {}
  local db_ops = 0

  -- resolve token ids
  for _, token_spec in pairs(tokens) do
    --print("token: "..token_spec[2])
    local key = table.concat(token_spec)

    local cached_id = token_cache[key]
    if cached_id then
      --print("got cached token "..cached_id)
      table.insert(token_ids, cached_id)
    else
      db_ops = db_ops + 1
      local new_id
      if self.caching and self.new_db then
        new_id = self:_add_token(unpack(token_spec))
      else
        new_id = self:_get_or_add_token(unpack(token_spec))
      end
      --print("new token id: "..new_id)
      token_cache[key] = new_id
      table.insert(token_ids, new_id)
    end
  end
  --print(D(token_cache))
  table.insert(token_ids, 1, self._end_token_id)
  table.insert(token_ids, self._end_token_id)

  --print(D(token_ids))
  -- resolve expr ids
  for i = 1, #token_ids - self._order+1 do
    --print("foo: "..i)
    local ids = {}
    for j = i, i + self._order-1 do
      table.insert(ids, token_ids[j])
    end
    --print("token_ids: "..D(ids))

    local key = table.concat(ids, '_')
    --print(key)
    local cached_id = expr_cache[key]
    if cached_id then
      --print("got cached expr "..cached_id)
      table.insert(expr_ids, cached_id)
    else
      local new_id
      if self.caching and self.new_db then
        new_id = self:_add_expr(ids)
      else
        new_id = self:_get_or_add_expr(ids)
      end
      db_ops = db_ops + 1
      expr_cache[key] = new_id
      --print("expr: "..key, new_id)
      table.insert(expr_ids, new_id)
    end
  end
  --print(D(expr_cache))
  --print("expr_ids: "..D(expr_ids))
  --for _, expr_id in pairs(expr_ids) do
  --  print("expr_id: "..expr_id, expr_cache[expr_id])
  --end

  table.insert(expr_ids, self._end_expr_id)
  table.insert(expr_ids, 1, self._end_expr_id)

  -- create/update links
  --print("count: "..#expr_ids)
  for i = 1, #expr_ids - 2 do
    --print(expr_ids[i], expr_ids[i+2])
    --print("foo")
    if self.caching then
      --print("bar")
      local link_key = expr_ids[i]..'_'..expr_ids[i+2]
      if self._link_cache[link_key] then
        self._link_cache[link_key] = self._link_cache[link_key] + 1
      else
        self._link_cache[link_key] = 1
      end
    else
      self:_inc_or_add_link(expr_ids[i], expr_ids[i+2], 1)
    end
    db_ops = db_ops + 1
  end
  --inc_or_add_link(boundary_expr_id, expr_ids[2])
  --db_ops = db_ops + 1
  --inc_or_add_link(expr_ids[#expr_ids-1], boundary_expr_id)
  --db_ops = db_ops + 1
  --print("db ops: "..db_ops)
end

-- TODO: use an expression cache?
function M:reply(tokens)
  local token_cache = self:_resolve_input_tokens(tokens)
  --print("token_cache: "..D(token_cache))

  local pivots = {}
  for token_id, _ in pairs(token_cache) do
    table.insert(pivots, token_id)
  end
  if #pivots == 0 then
    random_tokens = self:_get_random_tokens(1) -- TODO: pick a number
    for _, token in pairs(random_tokens) do
      table.insert(pivots, token[1])
      token_cache[token[1]] = {token[2], token[3]}
    end
    --table.insert(pivots, 7172)
    --token_cache[7172] = {0, teryaki}
  end

  if #pivots == 0 then
    return("I don't know enough to answer you yet!")
  end
  --print("pivots: "..D(pivots))

  -- TODO: scoring
  --for _, reply in pairs(self:_generate_replies(pivots)) do
  local reply = self:_generate_replies(pivots)[1]
  local final_reply = {}
  --print(D(reply))
  --print("reply: "..D(reply))
  -- TODO: make this a method
  for _, token_id in pairs(reply) do
    local token_spec = token_cache[token_id]
    if not token_spec then
      --print("lookup")
      token_spec = self:_get_token_spec(token_id)
      token_cache[token_id] = token_spec
    end
    --print(D(token_id))
    --print(D(token_spec))
    table.insert(final_reply, token_spec)
  end
  return final_reply
  --end
end

function M:_generate_replies(pivots)
  local replies = {}
  for _, pivot_id in pairs(pivots) do
    local reply = {self:_get_random_expr(pivot_id)}
    --print(D(reply))

    --print("reply is: "..D(reply))
    --print("making prev")
    while reply[1][2] ~= self._end_token_id do
      local prev = self:_get_connected_expr(reply[1][1], "prev")
      table.insert(reply, 1, prev)
      --print("adding "..D(prev))
      --print("reply is: "..D(reply))
    end
    --print(D(reply))
    --print("making next")
    while reply[#reply][3] ~= self._end_token_id do
      local next = self:_get_connected_expr(reply[#reply][1], "next")
      --print(D(next))
      table.insert(reply, next)
      --print("adding "..D(next))
      --print("reply is: "..D(reply))
    end
    --print("reply is: "..D(reply))

    local token_ids = {}
    for _, expr in pairs(reply) do
      --print("expr is: "..D(expr))
      table.remove(expr, 1)
      for _, token_id in pairs(expr) do
        if token_id ~= self._end_token_id then
          table.insert(token_ids, token_id)
        end
      end
    end
    table.insert(replies, token_ids)
  end
  return replies
end

function M:_get_connected_expr(expr_id, direction)
  local stmt
  if direction == "prev" then
    stmt = self._sth.prev_expr
  else
    stmt = self._sth.next_expr
  end

  stmt:bind_names({last_expr_id = expr_id})
  local status = stmt:step()
  if status == sqlite3.ROW then
    local expr = stmt:get_values()
    stmt:reset()
    return expr
  end
  stmt:reset()
end

function M:_get_random_expr(token_id)
  local stmt = self._sth.random_expr
  stmt:bind_names({id = token_id})
  local status = stmt:step()
  if status == sqlite3.ROW then
    local expr = stmt:get_values()
    stmt:reset()
    return expr
  end
  stmt:reset()
end

function M:_get_token_spec(token_id)
  local stmt = self._sth.token_spec
  stmt:bind_values(token_id)
  local status = stmt:step()
  if status == sqlite3.ROW then
    local token_spec = stmt:get_values()
    stmt:reset()
    return token_spec
  end
  stmt:reset()
  return tokens
end

function M:_get_random_tokens(amount)
  local tokens = {}
  local stmt = self._sth.random_token
  stmt:bind_values()
  for i = 1,amount do
    local status = stmt:step()
    while status == sqlite3.ROW do
      table.insert(tokens, stmt:get_values())
      status = stmt:step()
    end
    stmt:reset()
  end
  return tokens
end

function M:_resolve_input_tokens(tokens)
  local token_cache = {}

  if #tokens == 1 then
    -- When there's just one token, we'll be a bit more lax and settle
    -- for any token which matches that text, regardless of spacing.
    local text = tokens[1][2]
    local token_info = self:_get_similar_token(tokens[1][2])
    if token_info then
      local id, spacing = unpack(token_info)
      token_cache[id] = {spacing, text}
    end
  else
    for _, token_spec in pairs(tokens) do
      local spacing, text = unpack(token_spec)
      local id = self_:get_token_id(spacing, text)
      if id then
        token_cache[id] = token_spec
      end
    end
  end

  return token_cache
end

function M:_get_similar_token(text)
  local stmt = self._sth.similar_token
  stmt:bind_values(text)
  local status = stmt:step()
  if status == sqlite3.ROW then
    local token_info = stmt:get_values()
    stmt:reset()
    return token_info
  end
  stmt:reset()
end

function M:_get_token_id(spacing, text)
  local stmt = self._sth.token_id
  stmt:bind_values(spacing, text)
  local status = stmt:step()
  if status == sqlite3.ROW then
    local id = stmt:get_uvalues()
    stmt:reset()
    return id
  end
  stmt:reset()
end

function M:_add_token(spacing, text)
  local stmt = self._sth.add_token
  stmt:bind_values(spacing, text)
  stmt:step()
  stmt:reset()
  return self._db:last_insert_rowid()
end

function M:_get_or_add_token(spacing, text)
  local token_id = self:_get_token_id(spacing, text)
  if token_id then
    return token_id
  end
  return self:_add_token(spacing, text)
end

function M:_get_expr(token_ids)
  local stmt = self._sth.get_expr
  stmt:bind_values(unpack(token_ids))
  local status = stmt:step()
  if status == sqlite3.ROW then
    local id = stmt:get_uvalues()
    stmt:reset()
    return id
  end
  stmt:reset()
end

function M:_add_expr(token_ids)
  local stmt = self._sth.add_expr
  stmt:bind_values(unpack(token_ids))
  stmt:step()
  stmt:reset()
  return self._db:last_insert_rowid()
end

function M:_get_or_add_expr(token_ids)
  local expr_id = self:_get_expr(token_ids)
  if expr_id then
    return expr_id
  end
  return self:_add_expr(token_ids)
end

function M:_add_link(prev_expr, next_expr, count)
  local stmt = self._sth.add_link
  stmt:bind_values(prev_expr, next_expr, count)
  stmt:step()
  stmt:reset()
end

function M:_inc_or_add_link(prev_expr, next_expr, count)
  local stmt = self._sth.inc_link
  stmt:bind_values(count, prev_expr, next_expr)
  stmt:step()
  stmt:reset()
  if self._db:changes() == 0 then
    self:_add_link(prev_expr, next_expr, count)
  end
end

return M
