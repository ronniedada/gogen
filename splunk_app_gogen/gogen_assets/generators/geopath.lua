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

function radianstodecimaldegrees(radians)

  return radians * (180 / math.pi)

end

function decimaldegreestoradians(degrees)

  return (math.pi / 180) * degrees

end

function nextlatlong(lat_decimal,long_decimal,bearing_decimal,distance_metres)
  local lat_radians = decimaldegreestoradians(lat_decimal)
  local long_radians = decimaldegreestoradians(long_decimal)
  local bearing_radians = decimaldegreestoradians(bearing_decimal)
  local earths_radius_metres = 6378137
  local lat_radians_next = math.asin(math.sin(lat_radians)*math.cos(distance_metres/earths_radius_metres) + math.cos(lat_radians)*math.sin(distance_metres/earths_radius_metres)*math.cos(bearing_radians))
  local long_radians_next =  long_radians + math.atan(math.sin(bearing_radians)*math.sin(distance_metres/earths_radius_metres)*math.cos(lat_radians),math.cos(distance_metres/earths_radius_metres)-math.sin(lat_radians)*math.sin(lat_radians_next))
  
  return radianstodecimaldegrees(lat_radians_next),radianstodecimaldegrees(long_radians_next),distance_metres

end

--init
if state["userid"] == nil or state["userid"] == 0 then
  state["userid"] = sessionid()
  setToken("userid", state["userid"])
  state["lat"] = state["start_lat_decimal"]
  state["long"] = state["start_long_decimal"]
  state["bearing"] = state["initial_bearing_degrees"]
  state["speed"] = state["initial_speed_metres_per_sec"]
end
if state["distance"] == nil then
  state["distance"] = 0
end
setToken("lat", state["lat"])
setToken("long", state["long"])
setToken("distancetravelled", state["distance"])
setToken("bearing", state["bearing"])
setToken("speed", state["speed"])

--output event
sendevent(0)

-- get next co-ordinates
state["lat"],state["long"],state["distance"] = nextlatlong(state["lat"],state["long"],state["bearing"],state["speed"]*5)

-- randomly change the bearing for some variability in the path
if state["bearing_mode"] == "random" then

  -- check if we need to apply containment logic
  if(state["box_containment_top_lat"] ~= nil and state["box_containment_bottom_lat"] ~= nil and state["box_containment_left_long"] ~= nil and state["box_containment_right_long"] ~= nil) then
    -- are we still in the containment box

    if(state["lat"] < state["box_containment_top_lat"] and state["lat"] > state["box_containment_bottom_lat"] and state["long"] < state["box_containment_left_long"] and state["long"] > state["box_containment_right_long"]) then
      state["bearing"] = math.random(0, 360)
      debug("contained")
    else
      -- dog left the yard , relect the path to the back bearing
      if(state["bearing"] >= 180) then
        state["bearing"] = state["bearing"] - 180
      else
        state["bearing"] = state["bearing"] + 180
      end
      -- get next co-ordinates
      state["lat"],state["long"],state["distance"] = nextlatlong(state["lat"],state["long"],state["bearing"],state["speed"]*5)
      debug("dog left the yard")
      state["bearing"] = math.random(0, 360)
    end  
  else
    debug("no containment logic")
    state["bearing"] = math.random(0, 360) 
  end  
end
if state["bearing_mode"] == "straight" then
  -- no need to do anything
end
