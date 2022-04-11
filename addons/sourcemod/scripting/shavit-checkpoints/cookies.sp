void InitCookies()
{
	gH_CheckpointsCookie = new Cookie("shavit_checkpoints", "Checkpoints settings", CookieAccess_Protected);
}

void OnClientCookiesCached_Checkpoints(int client)
{
	char sSetting[8];
	gH_CheckpointsCookie.Get(client, sSetting, sizeof(sSetting));

	if(strlen(sSetting) == 0)
	{
		IntToString(CP_DEFAULT, sSetting, sizeof(sSetting));
		gH_CheckpointsCookie.Set(client, sSetting);
		gI_CheckpointsSettings[client] = CP_DEFAULT;
	}
	else
	{
		gI_CheckpointsSettings[client] = StringToInt(sSetting);
	}
}