// ======[ NATIVES ]======

void CreateNatives()
{
	CreateNative("Shavit_OpenStatsMenu", Native_OpenStatsMenu);
}

public int Native_OpenStatsMenu(Handle handler, int numParams)
{
	int client = GetNativeCell(1);
	gI_TargetSteamID[client] = GetNativeCell(2);
	OpenStatsMenu(client, gI_TargetSteamID[client]);

	return 0;
}