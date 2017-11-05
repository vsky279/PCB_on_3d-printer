#!/usr/bin/env lua
local step = 16 -- interpolate circle to `step` segments

io.stderr:write("Prepare gcode from ThmqGCU.js (http://thmq.mysteria.cz/gcu/) for Prusa3d by vsky279\n\n")

function file_exists(file)
  local f = io.open(file, "rb")
  if f then f:close() end
  return f ~= nil
end

local file = arg[1]
if not (file and file_exists(file)) then 
  io.stderr:write(string.format("File `%s` not found!\n", file or ""))
  return 
end

local gcode = {}
local min = {}
for line in io.lines(file) do 
  gcode[#gcode + 1] = line
  string.gsub(line, "([XYZ])([\-\.0-9]+)", function (a, b)
    if tonumber(b) then
      min[a] = math.min(min[a] or tonumber(b), tonumber(b))
    end
  end)
end
io.stderr:write("Found mins: ")
for i,j in pairs(min) do 
  io.stderr:write(string.format("min(%s) = %.1f%s", i, j, (i==#min) and "" or ", "))
end
io.stderr:write("\n")

io.stderr:write("Adding initialization...\n")
-- add "G92 X0 Y0 Z0" after "G64 P0.05"
for i, line in pairs(gcode) do 
  gcode[i] = string.gsub(line, "^(G64.*)$", function (a)
    return a .. "\nG92 X0 Y0 Z0"
  end)
end

io.stderr:write("Shifting to origin...\n")
for i, line in pairs(gcode) do 
  gcode[i] = string.gsub(line, "([XYZ])([\-\.0-9]+)", function (a, b)
    return a..(tonumber(b) - min[a])
  end)
end


io.stderr:write("Interpolating arcs by lines.")
local position = {X=0, Y=0, Z=0}

function circle(rad)
  local result = ""
  for r = 0, step do
    local rl = 3/2*math.pi + 2*r/step * math.pi
    result = result .. string.format("G1 X%f Y%f\n", position.X + rad + math.sin(rl) * rad, position.Y + math.cos(rl) * rad)
  end
  io.stderr:write(".")
  return result
end

local output = arg[2]
local o = (output ~= nil) and io.open(output, "w") or io.stdout

for i, line in pairs(gcode) do 
  local out = string.gsub(line, "([XYZ])([\-\.0-9]+)", function (a, b)
    if tonumber(b) then
      position[a] = tonumber(b)
    end
  end)
  local out = string.gsub(line, "^(G3\ I)([\-\.0-9]+)", function (a, b)
    if tonumber(b) then
      return circle(tonumber(b))
    end
  end)
  o:write(out .. "\n")
end
io.stderr:write("\n")
io.stderr:write("Done\n")
