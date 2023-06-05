local Switch = {}

function Switch.new(name, opts)
  validate {
    switch = { is { "string", "number" }, name },
    opts = {
      {
        opt_nargs = is { "number", "string" },
        opt_validate = "callable",
        opt_post = "callable",
        opt_metavar = "string",
        desc = "string",
      },
      opts,
    },
  }

  opts = array.deepcopy(opts)

  if opts.flag and opts.positional then
    OptionParser.InvalidSpecException:throw(
      "positional switch cannot be a flag: " .. name
    )
  end

  if opts.nargs == 0 or opts.flag then
    opts.flag = true
    opts.nargs = 0
    opts.required = nil
  end

  local self = {}
  self.name = name
  self.flag = opts.flag
  self.positional = opts.positional and true or false
  self.required = opts.required and true or false
  self.desc = opts.desc
  self.post = opts.post
  self.validate = opts.validate
  self.nargs = opts.nargs
  self.aliases = opts.aliases
  self.metavar = opts.metavar
  self.pos = false
  self.parsed_positional = false
  self.parsed_named = false

  function self.print(cls)
    local metavar = cls.metavar or "ARGUMENT"
    local nargs = cls.nargs

    if is_a.number(nargs) and nargs > 0 or nargs == "*" or nargs == "+" then
      metavar = sprintf("%s [%s {...}]", metavar)
    elseif nargs == "?" then
      metavar = sprintf("[%s]", metavar)
    end

    print("-" .. cls.name .. " " .. metavar)
    print("positional: " .. tostring(cls.positional))
    print("required:   " .. tostring(cls.required))
    print("nargs:      " .. cls.nargs)
    print("aliases:    " .. array.join(cls.aliases, " "))
    print(cls.desc)
    print()
  end

  return self
end

function Switch.parse(s)
  s = tostring(s)
  local isswitch = s:sub(1, 1)
  local rest = s:sub(2, #s)
  local firstalpha = rest:sub(1, 1)

  return isswitch
    and firstalpha:match "[0-9a-zA-Z]"
    and rest:match "([a-zA-Z0-9_-]+)"
end

return Switch
