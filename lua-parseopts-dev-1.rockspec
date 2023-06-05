package = "lua-parseopts"
version = "dev-1"

source = {
   url = "git+https://www.github.com/caligian/lua-parseopts"
}

description = {
  homepage = "https://github.com/caligian/lua-utils",
  license = 'MIT <http://opensource.org/licenses/MIT>',
}

dependencies = {
  'lua >= 5.1',
  'lua-utils'
}

build = {
   type = "builtin",
   modules = {
      ['parseopts.OptionParser'] = "parseopts/OptionParser.lua",
      ['parseopts.Switch'] = "parseopts/Switch.lua"
   }
}
