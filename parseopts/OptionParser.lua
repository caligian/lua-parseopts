require 'lua-utils'

local OptionParser = class "OptionParser"
local Switch = require "Switch"

OptionParser.NoValidOptionsException = exception "no valid switches passed"
OptionParser.InvalidSpecException = exception "invalid spec passed"
OptionParser.ValidationFailureException = exception "validation failed"
OptionParser.NoCommandLineArgumentsException =
  exception "no commandline arguments passed"
OptionParser.TooManyArgumentsException = exception "too many arguments passed"
OptionParser.NotEnoughArgumentsException =
  exception "not enough arguments passed"
OptionParser.InvalidNumberOfArgumentsException =
  exception "invalid number of arguments passed"

function OptionParser:init(desc, shortdesc)
  self.desc = desc
  self.aliases = {}
  self.ARGS = arg
  self.pos = {}
  self.shortdesc = shortdesc
  self.parsed = {}
  self.switches = {}
  self.named = {}
  self.positional = {}
  self.flags = {}
  self.optional = {}
end

function OptionParser:add(switch_name, opts)
  self.switches[switch_name] = Switch.new(switch_name, opts)

  local switch = self.switches[switch_name]
  if switch.required then
    self.required[switch_name] = switch
    if switch.positional then
      self.positional[#self.positional + 1] = switch
    else
      self.named[switch_name] = switch
    end
  else
    self.optional[switch_name] = switch
    if switch.positional then
      self.positional[#self.positional + 1] = switch
    else
      self.named[switch_name] = switch
    end
  end

  return switch
end

function OptionParser:parsepositional()
  local ARGS = self.ARGS
  local n = #ARGS

  if n == 0 then OptionParser.NoCommandLineArgumentsException:throw() end

  local function findstart()
    local first_obj

    for i = 1, n do
      local x = ARGS[i]
      x = Switch.parse(x)
      first_obj = self.switches[x]

      if x and first_obj then
        first_obj.pos = i
        break
      end
    end

    return first_obj
  end

  local function findend()
    n = #ARGS
    local last_obj

    for i = n, 1, -1 do
      local x = ARGS[i]
      x = Switch.parse(x)
      last_obj = self.switches[x]
      if last_obj then
        last_obj.pos = i
        break
      end
    end

    return last_obj
  end

  local function extractstart(first_obj)
    local first_i = first_obj.pos

    if not (first_obj and first_i ~= 1) then return end

    for i = 1, first_i - 1 do
      local obj = self.positional[i]
      local value = array.shift(ARGS)
      if obj then
        obj.args = { value }
        obj.pos = i
      else
        obj = self:add(i, {
          optional = true,
          positional = true,
          desc = "param " .. i,
        })
        obj.args = { value }
        obj.pos = i
      end
    end
  end

  local function extractend(last_obj)
    local last_i = last_obj.pos

    if not (last_obj and last_i ~= n) then return end

    local spec = last_obj
    local nargs = spec.nargs
    local dist = n - last_i

    if nargs == "?" and dist ~= 1 then
      for i = dist, n do
        local obj = self.positional[#self.positional]
        obj = obj
          or self:add(i, {
            optional = true,
            positional = true,
            desc = "param " .. i,
          })
        obj.args = { array.pop(ARGS) }
        obj.pos = i
      end
    elseif dist ~= 1 then
      local last_i = last_obj.pos
      local beyond = last_i + nargs

      if beyond > n then
        OptionParser.NotEnoughArgumentsException:throw(self.ARGS[last_i])
      end

      local remaining = not (nargs == "+" or nargs == "*")
        and nargs ~= 0
        and is_a.number(nargs)
        and beyond < n
        and beyond

      if remaining then
        for i = remaining + 1, n do
          local obj = self.switches[i]
          obj = obj
            or self:add(i, {
              positional = true,
              optional = true,
              desc = "param " .. i,
            })
          obj.args = { ARGS[i] }
          ARGS[i] = nil
        end
      end
    end
  end

  extractstart(findstart())
  extractend(findend())

  self.parsed_positional = true

  return self.positional
end

local function getpos(self)
  local ARGS = self.ARGS
  for i = 1, #ARGS do
    local current = ARGS[i]
    local switch = Switch.parse(current)
    if switch and self.switches[switch] then
      self.pos[i] = switch
      self.pos[switch] = i
    end
  end

  return self.pos
end

function OptionParser:parsenamed()
  if not self.parsed_positional then self:parsepositional() end

  local pos = getpos(self)
  local switch_ind = dict.grep(pos, isstring)
  local ind = array.sort(dict.keys(dict.grep(pos, isnumber)))
  local ARGS = self.ARGS
  local n = #ARGS
  local last_i
  local nind = #ind
  local parsed = {}

  for i = 1, nind do
    local current_ind = ind[i]
    local next_ind = ind[i + 1] or n
    local switch = pos[current_ind]
    local spec = self.switches[switch]
    local obj = spec
    local nargs = spec.nargs
    local args = {}

    if i == nind then
      args = array.slice(ARGS, current_ind + 1, next_ind)
    else
      args = array.slice(ARGS, current_ind + 1, next_ind - 1)
    end

    local switch_args_n = #args
    local nargs_isnum = isnumber(nargs)
    if nargs then
      if nargs_isnum and nargs ~= switch_args_n then
        OptionParser.InvalidNumberOfArgumentsException:throw {
          switch = switch,
          args = args,
          n = switch_args_n,
          required = nargs,
        }
      elseif nargs == "+" and nargs == 0 then
        OptionParser.NotEnoughArgumentsException:throw {
          switch = switch,
          args = args,
          n = switch_args_n,
          required = nargs,
        }
      elseif nargs == "?" then
        if switch_args_n ~= 1 and switch_args_n ~= 0 then
          OptionParser.InvalidNumberOfArgumentsException:throw {
            required = "1 or 0",
            args = args,
            n = switch_args_n,
            switch = switch,
          }
        end
      end
    end

    local check = spec.validate
    if check and not check(args) then
      OptionParser.ValidationFailureException:throw(args)
    end

    local post = spec.post
    if post then args = spec.post end

    obj.args = args
  end

  self.parsed_named = true
  return self.named
end

function OptionParser:parse() 
  local parsed = {}
  local positional, named = self:parsepositional(), self:parsenamed() 

  for _, value in ipairs(positional) do
    if not is_a.number(value.name) then parsed[value.name] = value.args[1] end
    parsed[#parsed+1] = value.args[1]
  end

  for key, value in pairs(named) do
    if value.flag then
      parsed[value.name] = true
    else
      parsed[value.name] = value.args 
    end
  end

  return parsed
end

function OptionParser:print()
  local script_path = debug.getinfo(2, "S").source:sub(2)
  script_path = script_path:gsub(os.getenv "HOME", "~")
  printf("%s %s", script_path, self.shortdesc or "")
  print(self.desc)

  array.each(array.sort(dict.keys(self.switches)), printswitch)

  print()
  printf "-h | -help"
  print "Display help"
end

local ARGS =
  { 12391, -1, -2, "-x", "a", "b", 1, 2, "-y", 10, -1, "-z", 1, 2, 3, "-a", 12 }
local o = OptionParser "some description"
o.ARGS = ARGS
o:add("x", { desc = "do x", nargs = "*" })
o:add("y", { desc = "do y", nargs = 2 })
o:add("z", { desc = "do z", nargs = "+" })
o:add("a", { desc = "set a", nargs = '?' })
o:add("b", { desc = "set a", nargs = '?', positional=true })
-- pp(o:parsepositional())
-- pp(o:parse())

-- o:createhelp()

return OptionParser
