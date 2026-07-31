if fs.exists("main.lua") then
    shell.run("main.lua")
else
    print("No main.lua found on slave computer")
end
