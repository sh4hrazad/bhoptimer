void UpdateSyncTextHud(int client)
{
	int target = GetSpectatorTarget(client, client);

	if(target < 1 || target > MaxClients ||
		(gI_HUDSettings[client] & HUD_CENTER) == 0 ||
		((gI_HUDSettings[client] & HUD_OBSERVE) == 0 && client != target))
	{
		return;
	}

	if(!gB_Zones || !Shavit_InsideZone(target, Zone_Start, -1))
	{
		return;
	}

	huddata_t huddata;

	huddata.iTarget = target;
	huddata.iStyle = Shavit_GetBhopStyle(target);
	huddata.iTrack = Shavit_GetClientTrack(target);
	huddata.fPB = Shavit_GetClientPB(target, huddata.iStyle, huddata.iTrack);
	huddata.fWR = Shavit_GetWorldRecord(huddata.iStyle, huddata.iTrack);
	huddata.iFinishNum = (huddata.iStyle == -1 || huddata.iTrack == -1) ? Shavit_GetRecordAmount(0, 0) : Shavit_GetRecordAmount(huddata.iStyle, huddata.iTrack);
	huddata.iRank = (huddata.iFinishNum == 0) ? 0 : Shavit_GetRankForTime(huddata.iStyle, huddata.fPB, huddata.iTrack);

	char sText[256];
	AddTextToBuffer(client, huddata, sText, sizeof(sText));

	int colors[4];
	colors[0] = 100;
	colors[1] = 150;
	colors[2] = 255;
	colors[3] = 255;

	SetHudTextParamsEx(-1.0, 1.0, 1.0, colors, _, 1, 1.0, 0.0, 0.0);
	ShowSyncHudText(client, gH_SyncTextHud, sText);
}

stock void AddTextToBuffer(int client, huddata_t data, char[] buffer, int maxlen)
{
	char sWRTime[32];
	char sPBTime[32];
	FormatHUDSeconds(data.fWR, sWRTime, sizeof(sWRTime));
	FormatHUDSeconds(data.fPB, sPBTime, sizeof(sPBTime));

	if((gI_HUD2Settings[client] & HUD2_WRPB) == 0)
	{
		FormatEx(buffer, maxlen, "PB: %s \t\t Rank: %d/%d", sPBTime, data.iRank, data.iFinishNum);
	}
	else
	{
		FormatEx(buffer, maxlen, "SR: %s \t\t Rank: %d/%d", sPBTime, data.iRank, data.iFinishNum);
	}
}