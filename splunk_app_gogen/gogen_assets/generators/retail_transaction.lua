function countlines(t)
  local count = 0
  for k, v in pairs(t) do
    count = count + 1
  end
  return count
end

function countentries(ud)
  local count = 0
  for k, v in ud() do
    count = count + 1
  end
  return count
end

function getline(t, i)
  local count = 0
  for k,v in pairsByKeys(t) do
    if count >= i then
      return v
    else 
      count = count + 1
    end
  end
end

function getentry(ud, i)
  local count = 0
  for k, v in ud() do
    if count >= i then
      return v
    else
      count = count + 1
    end
  end
end

function pairsByKeys (t, f)
  local a = {}
  for n in pairs(t) do table.insert(a, n) end
  if f ~= nil then
    table.sort(a, f)
  else
    table.sort(a)
  end
  local i = 0      -- iterator variable
  local iter = function ()   -- iterator function
    i = i + 1
    if a[i] == nil then return nil
    else return a[i], t[a[i]]
    end
  end
  return iter
end

function sendevent(i, choices)
  l = getline(lines, tonumber(i))
  if choices == nil then
    l, ret = replaceTokens(l)
  else
    l, ret = replaceTokens(l, choices)
  end
  events = { }
  table.insert(events, l)
  send(events)
  return ret
end

function getudvalue(ud, key)
  for k, v in ud() do
    if tostring(k) == key then
      return v
    end
  end
end

function setcountdown()
  -- Countdown a random amount of seconds
  local upper = getudvalue(options["traversaldelay"], tostring(state["stage"]))
  math.randomseed(os.time())
  local countdown =  math.random(1, upper)
  state["countdown"] = countdown
end

function setmaxtraversalsteps()
  local upper = state["maxtraversalsteps"]
  math.randomseed(os.time())
  local max =  math.random(1, upper)
  state["maxtraversalsteps"] = max
end

function setmaxcartrepeats()
  local upper = state["maxcartrepeats"]
  math.randomseed(os.time())
  local max =  math.random(1, upper)
  state["maxcartrepeats"] = max
end

function reset()
  state["stage"] = 0
  state["sessionid"] = 0
  state["user"] = nil
  state["cartitemcount"] = 0
  state["traversalsteps"] = 0
  state["cartrepeats"] = 0
  state["cart"] = {}
end

function checkforabort()
  if state["traversalsteps"] >= state["maxtraversalsteps"] then
    reset()
  end
end

function sessionid()
  -- Generate a unique session id
  math.randomseed(os.time())
  local random = math.random
  local template ='xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx'
  return string.gsub(template, '[xy]', function (c)
    local v = (c == 'x') and random(0, 0xf) or random(8, 0xb)
    return string.format('%x', v)
  end)
end

function getitemcodechoice()

  local itemcodes = getChoice("itemcode")
  math.randomseed(os.time())
  local itemline = math.random( 1, (countlines(itemcodes) - 1))
  local item = itemcodes[itemline]
  debug("itemline "..itemline)
  debug("item "..item)
  return item

end

function randomremoval()

  math.randomseed(os.time())
  local remainder = math.fmod(math.random(1,100),10)
  return remainder == 0 

end  


if state["countdown"] == nil or state["countdown"] == 0 then 
  if randomremoval() then
    if state["cartitemcount"] > 0 then     
      debug("removal")
      debug("cart size "..countlines(state["cart"]))
      debug("cart size "..state["cartitemcount"])
      math.randomseed(os.time())
      local itemline = math.random( 0, (countlines(state["cart"]) - 1))
      debug("itemline "..itemline)
      local itemcode = table.remove(state["cart"],itemline)
      debug("itemcode "..itemcode)
      state["cartitemcount"] = state["cartitemcount"] - 1    
      setToken("itemcode", itemcode)
      sendevent(8)
      setcountdown()
      return
    end
  end
  --login
  if state["stage"] == 0 then
    debug("stage 0")
    setmaxtraversalsteps()
    setmaxcartrepeats()
    -- Pick a user
    if state["user"] == nil then
      math.randomseed(os.time())
      local userline = math.random( 0, countentries(options["users"])-1 )
      debug("userline: "..userline)
      user = getentry(options["users"], userline)
      setToken("user", user)
      debug("setToken for user: "..user)
      state["user"] = user
      state["cart"] = {}
    end
    -- Generate session id
    if state["sessionid"] == 0 then
      state["sessionid"] = sessionid()
      setToken("session", state["sessionid"])
    end
    --output event 1
    sendevent(0)
    setcountdown()    
    state["traversalsteps"] = state["traversalsteps"] + 1
    state["stage"] = state["stage"] + 1
    checkforabort()
  else if state["stage"] == 1 then
    debug("stage 1")
    sendevent(1)
    setcountdown()   
    state["traversalsteps"] = state["traversalsteps"] + 1
    state["stage"] = state["stage"] + 1
    checkforabort()
  else if state["stage"] == 2 then
    debug("stage 2")
    sendevent(2)
    setcountdown()   
    state["traversalsteps"] = state["traversalsteps"] + 1
    state["stage"] = state["stage"] + 1
    state["cartrepeats"] = state["cartrepeats"] + 1
    checkforabort()
  else if state["stage"] == 3 then
    debug("stage 3")
    sendevent(3)
    setcountdown()
    state["traversalsteps"] = state["traversalsteps"] + 1
    state["stage"] = state["stage"] + 1
    checkforabort()
  else if state["stage"] == 4 then
    debug("stage 4")
    local itemcode = getitemcodechoice()
    debug(itemcode)
    setToken("itemcode", itemcode)
    sendevent(4)
    setcountdown()
    state["cartitemcount"] = state["cartitemcount"] + 1
    table.insert(state["cart"], itemcode)
    state["traversalsteps"] = state["traversalsteps"] + 1
    if state["cartrepeats"] >= state["maxcartrepeats"] then
      -- no more cart loops
      state["stage"] = state["stage"] + 1
    else
      -- cart loop
      state["stage"] = 2
    end
    checkforabort()
  else if state["stage"] == 5 then
    debug("stage 5")
    -- skip checkout if no items in cart
    if state["itemcount"] == 0 then
      state["stage"] = 7
      setcountdown()
      checkforabort()
    else  
      setToken("itemcount", state["cartitemcount"])
      sendevent(5)
      setcountdown()    
      state["traversalsteps"] = state["traversalsteps"] + 1
      state["stage"] = state["stage"] + 1
      checkforabort()
    end
  else if state["stage"] == 6 then
    debug("stage 6")
    sendevent(6)
    setcountdown()
    state["traversalsteps"] = state["traversalsteps"] + 1
    state["stage"] = state["stage"] + 1
    checkforabort()
  else if state["stage"] == 7 then
    debug("stage 7")
    sendevent(7)
    setcountdown()
    state["traversalsteps"] = state["traversalsteps"] + 1
    reset()
  end end end end end end end end
else
  -- countdown decrementer
  state["countdown"] = state["countdown"] - 1 
end