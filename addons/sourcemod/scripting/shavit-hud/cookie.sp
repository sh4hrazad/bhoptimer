void InitCookies()
{
	gH_HUDCookie = RegClientCookie("shavit_hud_setting", "HUD settings", CookieAccess_Protected);
	gH_HUDCookieMain = RegClientCookie("shavit_hud_settingmain", "HUD settings for hint text.", CookieAccess_Protected);
}

void OnClientCookiesCached_HUDMain(int client)
{
	char sHUDSettings[8];
	gH_HUDCookieMain.Get(client, sHUDSettings, sizeof(sHUDSettings));

	if(strlen(sHUDSettings) == 0)
	{
		gCV_DefaultHUD2.GetString(sHUDSettings, sizeof(sHUDSettings));

		gH_HUDCookieMain.Set(client, sHUDSettings);
		gI_HUD2Settings[client] = gCV_DefaultHUD2.IntValue;
	}
	else
	{
		gI_HUD2Settings[client] = StringToInt(sHUDSettings);
	}
}

void OnClientCookiesCached_HUD2(int client)
{
	char sHUDSettings[8];
	gH_HUDCookie.Get(client, sHUDSettings, sizeof(sHUDSettings));

	if(strlen(sHUDSettings) == 0)
	{
		gCV_DefaultHUD.GetString(sHUDSettings, 8);

		gH_HUDCookie.Set(client, sHUDSettings);
		gI_HUDSettings[client] = gCV_DefaultHUD.IntValue;
	}
	else
	{
		gI_HUDSettings[client] = StringToInt(sHUDSettings);
	}
}