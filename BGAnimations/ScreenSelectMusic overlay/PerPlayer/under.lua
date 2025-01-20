local t = Def.ActorFrame{
	Name="PerPlayer"
}

for player in ivalues({PLAYER_1,PLAYER_2}) do
	-- AuthorCredit, Description, and ChartName associated with the current stepchart
	t[#t+1] = LoadActor("./StepArtist.lua", player)
    t[#t + 1] = LoadActor("./ScoreBox.lua", player)
end

return t
