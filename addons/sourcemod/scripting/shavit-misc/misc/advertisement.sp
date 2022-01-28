static Cookie gH_BlockAdvertsCookie = null;

static ArrayList gA_Advertisements = null;
static int gI_AdvertisementsCycle = 0;



// ======[ EVENTS ]======

void OnPluginStart_InitAdvs()
{
	gA_Advertisements = new ArrayList(600);
}

void RegisterCookie_Advs()
{
	gH_BlockAdvertsCookie = new Cookie("shavit-blockadverts", "whether to block shavit-misc advertisements", CookieAccess_Private);
}

void RegisterCommands_Advs()
{
	RegConsoleCmd("sm_toggleadverts", Command_ToggleAdverts, "Toggles visibility of advertisements");
}

void Shavit_OnChatConfigLoaded_LoadAdvs()
{
	if(!LoadAdvertisementsConfig())
	{
		SetFailState("Cannot open \"configs/shavit-advertisements.cfg\". Make sure this file exists and that the server has read permissions to it.");
	}
}

void OnConfigsExecuted_ShowAdvs()
{
	if(gCV_AdvertisementInterval.FloatValue > 0.0)
	{
		CreateTimer(gCV_AdvertisementInterval.FloatValue, Timer_Advertisement, 0, TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE);
	}
}

public Action Command_ToggleAdverts(int client, int args)
{
	if (IsValidClient(client))
	{
		char sCookie[4];
		gH_BlockAdvertsCookie.Get(client, sCookie, sizeof(sCookie));
		gH_BlockAdvertsCookie.Set(client, (sCookie[0] == '1') ? "0" : "1");
		Shavit_PrintToChat(client, "%T", (sCookie[0] == '1') ? "AdvertisementsEnabled" : "AdvertisementsDisabled", client);
	}

	return Plugin_Handled;
}



// ======[ PRIVATE ]======

static bool LoadAdvertisementsConfig()
{
	gA_Advertisements.Clear();

	char sPath[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, sPath, PLATFORM_MAX_PATH, "configs/shavit-advertisements.cfg");

	KeyValues kv = new KeyValues("shavit-advertisements");
	
	if(!kv.ImportFromFile(sPath) || !kv.GotoFirstSubKey(false))
	{
		delete kv;

		return false;
	}

	do
	{
		char sTempMessage[600];
		kv.GetString(NULL_STRING, sTempMessage, 600, "<EMPTY ADVERTISEMENT>");

		gA_Advertisements.PushString(sTempMessage);
	}

	while(kv.GotoNextKey(false));

	delete kv;

	return true;
}

public Action Timer_Advertisement(Handle timer)
{
	char sHostname[128];
	hostname.GetString(sHostname, 128);

	char sTimeLeft[32];
	int iTimeLeft = 0;
	GetMapTimeLeft(iTimeLeft);
	FormatSeconds(float(iTimeLeft), sTimeLeft, 32, false, true);

	char sTimeLeftRaw[8];
	IntToString(iTimeLeft, sTimeLeftRaw, 8);

	char sIPAddress[64];

	if(GetFeatureStatus(FeatureType_Native, "SteamWorks_GetPublicIP") == FeatureStatus_Available)
	{
		int iAddress[4];
		SteamWorks_GetPublicIP(iAddress);

		FormatEx(sIPAddress, 64, "%d.%d.%d.%d:%d", iAddress[0], iAddress[1], iAddress[2], iAddress[3], hostport.IntValue);
	}

	bool bLinear = Shavit_IsLinearMap();

	char sMapType[16];
	strcopy(sMapType, 16, bLinear? "竞速图":"关卡图");

	char sMapCPType[16];
	strcopy(sMapCPType, 16, bLinear? "检查点数":"关卡数");

	char sMapCPs[4];
	IntToString(bLinear? Shavit_GetMapCheckpoints():Shavit_GetMapStages(), sMapCPs, 4);

	char sMapTier[4];
	IntToString(Shavit_GetMapTier(gS_Map), sMapTier, 4);

	char sMapBonuses[4];
	IntToString(Shavit_GetMapBonuses(), sMapBonuses, 4);

	for(int i = 1; i <= MaxClients; i++)
	{
		if(IsClientConnected(i) && IsClientInGame(i))
		{
			if(AreClientCookiesCached(i))
			{
				char sCookie[2];
				gH_BlockAdvertsCookie.Get(i, sCookie, sizeof(sCookie));

				if (sCookie[0] == '1')
				{
					continue;
				}
			}

			char sTempMessage[600];
			gA_Advertisements.GetString(gI_AdvertisementsCycle, sTempMessage, 600);

			char sName[MAX_NAME_LENGTH];
			GetClientName(i, sName, MAX_NAME_LENGTH);
			ReplaceString(sTempMessage, 600, "{name}", sName);
			ReplaceString(sTempMessage, 600, "{timeleft}", sTimeLeft);
			ReplaceString(sTempMessage, 600, "{timeleftraw}", sTimeLeftRaw);
			ReplaceString(sTempMessage, 600, "{hostname}", sHostname);
			ReplaceString(sTempMessage, 600, "{serverip}", sIPAddress);
			ReplaceString(sTempMessage, 600, "{map}", gS_Map);
			ReplaceString(sTempMessage, 600, "{maptype}", sMapType);
			ReplaceString(sTempMessage, 600, "{mapcptype}", sMapCPType);
			ReplaceString(sTempMessage, 600, "{mapcps}", sMapCPs);
			ReplaceString(sTempMessage, 600, "{maptier}", sMapTier);
			ReplaceString(sTempMessage, 600, "{mapbonuses}", sMapBonuses);

			Shavit_PrintToChat(i, "%s", sTempMessage);
		}
	}

	if(++gI_AdvertisementsCycle >= gA_Advertisements.Length)
	{
		gI_AdvertisementsCycle = 0;
	}

	return Plugin_Continue;
}