local songs = {"Aquatic", "Beanmania IIDX", "feel", "halcyon farms", "in_two", "Whispers Under Ground"}

-- take a random song from the list instead of relying on styles that no longer exist
local randNum = math.random(#songs)
local file = songs[randNum]

return THEME:GetPathS("", "_common menu music/" .. file)
