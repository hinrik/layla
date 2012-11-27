package = "layla"
version = "scm-1"
source = {
  url = "git://github.com/hinrik/layla.git",
}

description = {
  summary = "A Markov engine inspired by MegaHAL",
  homepage = "https://github.com/hinrik/layla",
  maintainer = "Hinrik Örn Sigurðsson <hinrik.sig@gmail.com>",
  license = "MIT",
}

dependencies = {
  "lua >= 5.1",
  "lua-testmore",
  "lsqlite3",
  "lpeg",
  "slnunicode",
  "lua_cliargs",
  "serpent",
}

build = {
  type = "builtin",
  modules = {
    ["layla"]                 = "lib/layla.lua",
    ["layla.model"]           = "lib/layla/model.lua",
    ["layla.tokenizer.words"] = "lib/layla/tokenizer/words.lua",
  },
  install = {
    bin = { "bin/layla" }
  },
  copy_directories = { "test" },
}

-- vim: ft=lua
