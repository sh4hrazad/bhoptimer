// ======[ NATIVE ]=====

void CreateNatives()
{
	CreateNative("Shavit_GetPlainChatrank", Native_GetPlainChatrank);
}

public int Native_GetPlainChatrank(Handle handler, int numParams)
{
	char buf[MAXLENGTH_NAME];
	int client = GetNativeCell(1);
	bool includename = !(GetNativeCell(4) == 0);
	int iChatrank = gI_ChatSelection[client];

	if (HasCustomChat(client) && iChatrank == -1 && gB_NameEnabled[client])
	{
		strcopy(buf, sizeof(buf), gS_CustomName[client]);
	}
	else
	{
		if (iChatrank < 0)
		{
			for(int i = 0; i < gA_ChatRanks.Length; i++)
			{
				if(HasRankAccess(client, i))
				{
					iChatrank = i;

					break;
				}
			}
		}

		if (0 <= iChatrank <= (gA_ChatRanks.Length - 1))
		{
			chatranks_cache_t cache;
			gA_ChatRanks.GetArray(iChatrank, cache, sizeof(chatranks_cache_t));

			strcopy(buf, sizeof(buf), cache.sName);
		}
	}

	for (int i = 0; i < sizeof(gS_GlobalColorNames); i++)
	{
		ReplaceString(buf, sizeof(buf), gS_GlobalColorNames[i], "");
	}

	RemoveFromString(buf, "^", 6);
	RemoveFromString(buf, "{RGB}", 6);
	RemoveFromString(buf, "&", 8);
	RemoveFromString(buf, "{RGBA}", 8);

	char sName[MAX_NAME_LENGTH];
	if (includename /* || iChatRank == -1*/)
	{
		GetClientName(client, sName, MAX_NAME_LENGTH);
	}

	ReplaceString(buf, sizeof(buf), "{name}", sName);
	ReplaceString(buf, sizeof(buf), "{rand}", "");

	char sTag[32];
	CS_GetClientClanTag(client, sTag, 32);
	ReplaceString(buf, sizeof(buf), "{clan}", sTag);

	if (gB_Rankings)
	{
		int iRank = Shavit_GetRank(client);
		char sRank[16];
		IntToString(iRank, sRank, 16);
		ReplaceString(buf, sizeof(buf), "{rank}", sRank);

		int iRanked = Shavit_GetRankedPlayers();

		if (iRanked == 0)
		{
			iRanked = 1;
		}

		float fPercentile = (float(iRank) / iRanked) * 100.0;
		FormatEx(sRank, 16, "%.01f", fPercentile);
		ReplaceString(buf, sizeof(buf), "{rank1}", sRank);

		FormatEx(sRank, 16, "%.02f", fPercentile);
		ReplaceString(buf, sizeof(buf), "{rank2}", sRank);

		FormatEx(sRank, 16, "%.03f", fPercentile);
		ReplaceString(buf, sizeof(buf), "{rank3}", sRank);

		FormatEx(sRank, 16, "%d", Shavit_GetWRHolderRank(client));
		ReplaceString(buf, sizeof(buf), "{wrrank}", sRank);

		FormatEx(sRank, 16, "%d", Shavit_GetWRCount(client));
		ReplaceString(buf, sizeof(buf), "{wrs}", sRank);
	}

	TrimString(buf);
	SetNativeString(2, buf, GetNativeCell(3), true);
	return 0;
}