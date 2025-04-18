local songs = {"Aquatic", "Cosmic Cat", "feel", "halcyon farms", "in_two", "Whispers Under Ground"}

-- take a random song from the list instead of relying on styles that no longer exist
-- using a random number from ScreenTitleMenu now, make sure to update the number there if you change the amount of songs
local file = songs[songsRandNum]

return THEME:GetPathS("", "_common menu music/" .. file)
