void RegisterCommands()
{
	RegConsoleCmd("sm_p", Command_Profile, "Show the player's profile. Usage: sm_profile [target]");
	RegConsoleCmd("sm_profile", Command_Profile, "Show the player's profile. Usage: sm_profile [target]");
	RegConsoleCmd("sm_stats", Command_Profile, "Show the player's profile. Usage: sm_profile [target]");
	RegConsoleCmd("sm_mapsdone", Command_MapsDoneLeft, "Show maps that the player has finished. Usage: sm_mapsdone [target]");
	RegConsoleCmd("sm_mapsleft", Command_MapsDoneLeft, "Show maps that the player has not finished yet. Usage: sm_mapsleft [target]");
	RegConsoleCmd("sm_playtime", Command_Playtime, "Show the top playtime list.");
}