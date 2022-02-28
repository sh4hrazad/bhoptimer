void InitCaches()
{
	gSM_Messages = new StringMap();
	gA_ChatRanks = new ArrayList(sizeof(chatranks_cache_t));
}

bool HasCustomChat(int client)
{
	return (gCV_CustomChat.IntValue > 0 && (CheckCommandAccess(client, "shavit_chat", ADMFLAG_CHAT) || gCV_CustomChat.IntValue == 2 || gB_CCAccess[client]));
}

bool HasRankAccess(int client, int rank)
{
	if(rank == -2 ||
		(rank == -1 && HasCustomChat(client)))
	{
		return true;
	}

	else if(!(0 <= rank <= (gA_ChatRanks.Length - 1)))
	{
		return false;
	}

	chatranks_cache_t cache;
	gA_ChatRanks.GetArray(rank, cache, sizeof(chatranks_cache_t));

	char sFlag[32];
	strcopy(sFlag, 32, cache.sAdminFlag);

	bool bFlagAccess = false;
	int iSize = strlen(sFlag);

	if(iSize == 0)
	{
		bFlagAccess = true;
	}

	else if(iSize == 1)
	{
		AdminFlag afFlag = view_as<AdminFlag>(0);

		if(FindFlagByChar(sFlag[0], afFlag))
		{
			bFlagAccess = GetAdminFlag(GetUserAdmin(client), afFlag);
		}
	}

	else
	{
		bFlagAccess = CheckCommandAccess(client, sFlag, 0, true);
	}

	if(!bFlagAccess)
	{
		return false;
	}

	if(cache.bFree)
	{
		return true;
	}

	if(/*!gB_Rankings ||*/ !gCV_RankingsIntegration.BoolValue)
	{
		return false;
	}

	if ((!gB_Rankings && (cache.iRequire == Require_Rank || cache.iRequire == Require_Points))
	|| (!gB_Stats && (cache.iRequire == Require_WR_Count || cache.iRequire == Require_WR_Rank)))
	{
		return false;
	}

	float fVal, fTotal;

	switch (cache.iRequire)
	{
		case Require_Rank:
		{
			fVal = float(Shavit_GetRank(client));
			fTotal = float(Shavit_GetRankedPlayers());
		}
		case Require_Points:
		{
			fVal = Shavit_GetPoints(client);
		}
		case Require_WR_Count:
		{
			fVal = float(Shavit_GetWRCount(client));
		}
		case Require_WR_Rank:
		{
			fVal = float(Shavit_GetWRHolderRank(client));
			fTotal = float(Shavit_GetWRHolders());
		}
	}

	if(!cache.bPercent)
	{
		if(cache.fFrom <= fVal <= cache.fTo)
		{
			return true;
		}
	}
	else
	{
		if(fTotal == 0.0)
		{
			fTotal = 1.0;
		}

		if(fVal == 1.0 && (fTotal == 1.0 || cache.fFrom == cache.fTo))
		{
			return true;
		}

		float fPercentile = (fVal / fTotal) * 100.0;

		if(cache.fFrom <= fPercentile <= cache.fTo)
		{
			return true;
		}
	}

	return false;
}

void GetPlayerChatSettings(int client, char[] name, char[] message)
{
	int iRank = gI_ChatSelection[client];

	if(!HasRankAccess(client, iRank))
	{
		iRank = -2;
	}

	int iLength = gA_ChatRanks.Length;

	// if we auto-assign, start looking for an available rank starting from index 0
	if(iRank == -2)
	{
		for(int i = 0; i < iLength; i++)
		{
			if(HasRankAccess(client, i))
			{
				iRank = i;

				break;
			}
		}
	}

	if(0 <= iRank <= (iLength - 1))
	{
		chatranks_cache_t cache;
		gA_ChatRanks.GetArray(iRank, cache, sizeof(chatranks_cache_t));

		strcopy(name, MAXLENGTH_NAME, cache.sName);
		strcopy(message, MAXLENGTH_NAME, cache.sMessage);
	}
}

void PreviewChat(int client, int rank)
{
	char sTextFormatting[MAXLENGTH_BUFFER];
	gSM_Messages.GetString("Cstrike_Chat_All", sTextFormatting, MAXLENGTH_BUFFER);
	Format(sTextFormatting, MAXLENGTH_BUFFER, "\x01%s", sTextFormatting);

	char sOriginalName[MAXLENGTH_NAME];
	GetClientName(client, sOriginalName, MAXLENGTH_NAME);

	// remove control characters
	for(int i = 0; i < sizeof(gS_ControlCharacters); i++)
	{
		ReplaceString(sOriginalName, MAXLENGTH_NAME, gS_ControlCharacters[i], "");
	}

	chatranks_cache_t cache;
	gA_ChatRanks.GetArray(rank, cache, sizeof(chatranks_cache_t));

	char sName[MAXLENGTH_NAME];
	strcopy(sName, MAXLENGTH_NAME, cache.sName);

	char sCMessage[MAXLENGTH_CMESSAGE];
	strcopy(sCMessage, MAXLENGTH_CMESSAGE, cache.sMessage);

	FormatChat(client, sName, MAXLENGTH_NAME);
	strcopy(sOriginalName, MAXLENGTH_NAME, sName);

	FormatChat(client, sCMessage, MAXLENGTH_CMESSAGE);

	char sSampleText[MAXLENGTH_MESSAGE];
	FormatEx(sSampleText, MAXLENGTH_MESSAGE, "%s%T", sCMessage, "ChatRanksMenu_SampleText", client);

	char sColon[MAXLENGTH_CMESSAGE];
	gCV_Colon.GetString(sColon, MAXLENGTH_CMESSAGE);

	ReplaceFormats(sTextFormatting, MAXLENGTH_BUFFER, sName, sColon, sSampleText);

	Handle hSayText2 = StartMessageOne("SayText2", client, USERMSG_RELIABLE|USERMSG_BLOCKHOOKS);

	if(hSayText2 != null)
	{
		if(gB_Protobuf)
		{
			// show colors in cs:go
			Format(sTextFormatting, MAXLENGTH_BUFFER, " %s", sTextFormatting);

			Protobuf pbmsg = UserMessageToProtobuf(hSayText2);
			pbmsg.SetInt("ent_idx", client);
			pbmsg.SetBool("chat", true);
			pbmsg.SetString("msg_name", sTextFormatting);

			for(int i = 1; i <= 4; i++)
			{
				pbmsg.AddString("params", "");
			}
		}

		else
		{
			BfWrite bfmsg = UserMessageToBfWrite(hSayText2);
			bfmsg.WriteByte(client);
			bfmsg.WriteByte(true);
			bfmsg.WriteString(sTextFormatting);
		}
	}

	EndMessage();
}

void FormatColors(char[] buffer, int size, bool colors, bool escape)
{
	if(colors)
	{
		for(int i = 0; i < sizeof(gS_GlobalColorNames); i++)
		{
			ReplaceString(buffer, size, gS_GlobalColorNames[i], gS_GlobalColors[i]);
		}

		for(int i = 0; i < sizeof(gS_CSGOColorNames); i++)
		{
			ReplaceString(buffer, size, gS_CSGOColorNames[i], gS_CSGOColors[i]);
		}

		ReplaceString(buffer, size, "^", "\x07");
		ReplaceString(buffer, size, "{RGB}", "\x07");
		ReplaceString(buffer, size, "&", "\x08");
		ReplaceString(buffer, size, "{RGBA}", "\x08");
	}

	if(escape)
	{
		ReplaceString(buffer, size, "%%", "");
	}
}

void FormatRandom(char[] buffer, int size)
{
	char temp[8];

	do
	{
		strcopy(temp, 8, gS_CSGOColors[GetRandomInt(0, sizeof(gS_CSGOColors) - 1)]);
	}

	while(ReplaceStringEx(buffer, size, "{rand}", temp) > 0);
}

void FormatChat(int client, char[] buffer, int size)
{
	FormatColors(buffer, size, true, true);
	FormatRandom(buffer, size);

	char temp[32];
	CS_GetClientClanTag(client, temp, 32);
	ReplaceString(buffer, size, "{clan}", temp);

	if(gB_Rankings)
	{
		int iRank = Shavit_GetRank(client);
		IntToString(iRank, temp, 32);
		ReplaceString(buffer, size, "{rank}", temp);

		int iRanked = Shavit_GetRankedPlayers();

		if(iRanked == 0)
		{
			iRanked = 1;
		}

		float fPercentile = (float(iRank) / iRanked) * 100.0;
		FormatEx(temp, 32, "%.01f", fPercentile);
		ReplaceString(buffer, size, "{rank1}", temp);

		FormatEx(temp, 32, "%.02f", fPercentile);
		ReplaceString(buffer, size, "{rank2}", temp);

		FormatEx(temp, 32, "%.03f", fPercentile);
		ReplaceString(buffer, size, "{rank3}", temp);

		FormatEx(temp, 32, "%0.f", Shavit_GetPoints(client));
		ReplaceString(buffer, size, "{pts}", temp);

		FormatEx(temp, 32, "%d", Shavit_GetWRHolderRank(client));
		ReplaceString(buffer, size, "{wrrank}", temp);

		FormatEx(temp, 32, "%d", Shavit_GetWRCount(client));
		ReplaceString(buffer, size, "{wrs}", temp);
	}

	GetClientName(client, temp, 32);
	ReplaceString(buffer, size, "{name}", temp);
}

void RemoveFromString(char[] buf, char[] thing, int extra)
{
	int index, len = strlen(buf);
	extra += strlen(thing);

	while ((index = StrContains(buf, thing, true)) != -1)
	{
		// Search sequence is in the end of the string, so just cut it and exit
		if(index + extra >= len)
		{
			buf[index] = '\0';
			break;
		}

		while (buf[index] != 0)
		{
			buf[index] = buf[index+extra];
			++index;
		}
	}
}

void ReplaceFormats(char[] formatting, int maxlen, char[] name, char[] colon, char[] text)
{
	FormatColors(formatting, maxlen, true, false);
	FormatRandom(formatting, maxlen);
	ReplaceString(formatting, maxlen, "{name}", name);
	ReplaceString(formatting, maxlen, "{def}", "\x01");
	ReplaceString(formatting, maxlen, "{colon}", colon);
	ReplaceString(formatting, maxlen, "{msg}", text);
}