if shell.getRunningProgram() == "cc_storage/startup.lua" then
  if fs.exists("startup.lua") then
    print("Can't setup startup.lua, one already exists")
    return
  else
    fs.copy("cc_storage/startup.lua", "startup.lua")
    settings.set("motd.enable", false)
    settings.save()
    os.reboot()
  end
end

shell.run("cc_storage/debug/setupMonPrint")

if turtle then
  local label = os.getComputerLabel()
  if label == "crafter" then
    shell.run("cc_storage/crafterTurtle")
  elseif label == "burner" then
    shell.run("cc_storage/burnerTurtle")
  else
    print("No turtle type set, select from \"crafter\" or \"burner\":")
    local l = read()
    os.setComputerLabel(l)
    os.reboot()
  end
else
  shell.run("cc_storage/storage")
end