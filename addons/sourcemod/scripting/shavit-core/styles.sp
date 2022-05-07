StringMap gSM_StyleCommands = null;

// flags
int gI_StyleFlag[STYLE_LIMIT];
char gS_StyleOverride[STYLE_LIMIT][32];

void CallOnStyleChanged(int client, int oldstyle, int newstyle, bool manual, bool nofoward=false)
{
	gA_Timers[client].bsStyle = newstyle;

	if (!nofoward)
	{
		Call_OnStyleChanged(client, oldstyle, newstyle, gA_Timers[client].iTimerTrack, manual);
	}

	float fNewTimescale = GetStyleSettingFloat(newstyle, "timescale");

	if (gA_Timers[client].fTimescale != fNewTimescale && fNewTimescale > 0.0)
	{
		Call_OnTimescaleChanged(client, gA_Timers[client].fTimescale, fNewTimescale);
		gA_Timers[client].fTimescale = fNewTimescale;
	}

	UpdateLaggedMovement(client, true);

	UpdateStyleSettings(client);

	SetEntityGravity(client, GetStyleSettingFloat(newstyle, "gravity"));
}

void ChangeClientStyle(int client, int style, bool manual)
{
	if(!IsValidClient(client))
	{
		return;
	}

	if(!Shavit_HasStyleAccess(client, style))
	{
		if(manual)
		{
			Shavit_PrintToChat(client, "%T", "StyleNoAccess", client);
		}

		return;
	}

	if(manual)
	{
		if(!Shavit_StopTimer(client, false))
		{
			return;
		}

		char sName[64];
		gSM_StyleKeys[style].GetString("name", sName, 64);

		Shavit_PrintToChat(client, "%T", "StyleSelection", client, sName);
	}

	if(GetStyleSettingBool(style, "unranked"))
	{
		Shavit_PrintToChat(client, "%T", "UnrankedWarning", client);
	}

	CallOnStyleChanged(client, gA_Timers[client].bsStyle, style, manual);
	Shavit_StopTimer(client, true);

	Call_OnRestart(client, gA_Timers[client].iTimerTrack);

	char sStyle[4];
	IntToString(style, sStyle, 4);

	SetClientCookie(client, gH_StyleCookie, sStyle);
}

int GetStyleSettingInt(int style, char[] key)
{
	char sValue[16];
	gSM_StyleKeys[style].GetString(key, sValue, 16);
	return StringToInt(sValue);
}

bool GetStyleSettingBool(int style, char[] key)
{
	return GetStyleSettingInt(style, key) != 0;
}

float GetStyleSettingFloat(int style, char[] key)
{
	char sValue[16];
	gSM_StyleKeys[style].GetString(key, sValue, 16);
	return StringToFloat(sValue);
}

bool HasStyleSetting(int style, char[] key)
{
	char sValue[1];
	return gSM_StyleKeys[style].GetString(key, sValue, 1);
}

bool LoadStyles()
{
	for(int i = 0; i < STYLE_LIMIT; i++)
	{
		delete gSM_StyleKeys[i];
	}

	char sPath[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, sPath, PLATFORM_MAX_PATH, "configs/shavit-styles.cfg");

	SMCParser parser = new SMCParser();
	parser.OnEnterSection = OnStyleEnterSection;
	parser.OnLeaveSection = OnStyleLeaveSection;
	parser.OnKeyValue = OnStyleKeyValue;
	parser.ParseFile(sPath);
	delete parser;

	for (int i = 0; i < gI_Styles; i++)
	{
		if (gSM_StyleKeys[i] == null)
		{
			SetFailState("Missing style index %d. Highest index is %d. Fix addons/sourcemod/configs/shavit-styles.cfg", i, gI_Styles-1);
		}
	}

	gB_Registered = true;

	SortCustom1D(gI_OrderedStyles, gI_Styles, SortAscending_StyleOrder);

	Call_OnStyleConfigLoaded(gI_Styles);

	return true;
}

public SMCResult OnStyleEnterSection(SMCParser smc, const char[] name, bool opt_quotes)
{
	// styles key
	if(!IsCharNumeric(name[0]))
	{
		return SMCParse_Continue;
	}

	gI_CurrentParserIndex = StringToInt(name);

	if (gSM_StyleKeys[gI_CurrentParserIndex] != null)
	{
		SetFailState("Style index %d (%s) already parsed. Stop using the same index for multiple styles. Fix addons/sourcemod/configs/shavit-styles.cfg", gI_CurrentParserIndex, name);
	}

	if (gI_CurrentParserIndex >= STYLE_LIMIT)
	{
		SetFailState("Style index %d (%s) too high (limit %d). Fix addons/sourcemod/configs/shavit-styles.cfg", gI_CurrentParserIndex, name, STYLE_LIMIT);
	}

	if(gI_Styles <= gI_CurrentParserIndex)
	{
		gI_Styles = gI_CurrentParserIndex + 1;
	}

	gSM_StyleKeys[gI_CurrentParserIndex] = new StringMap();

	gSM_StyleKeys[gI_CurrentParserIndex].SetString("name", "<MISSING STYLE NAME>");
	gSM_StyleKeys[gI_CurrentParserIndex].SetString("shortname", "<MISSING SHORT STYLE NAME>");
	gSM_StyleKeys[gI_CurrentParserIndex].SetString("htmlcolor", "<MISSING STYLE HTML COLOR>");
	gSM_StyleKeys[gI_CurrentParserIndex].SetString("command", "");
	gSM_StyleKeys[gI_CurrentParserIndex].SetString("clantag", "<MISSING STYLE CLAN TAG>");
	gSM_StyleKeys[gI_CurrentParserIndex].SetString("specialstring", "");
	gSM_StyleKeys[gI_CurrentParserIndex].SetString("permission", "");

	gSM_StyleKeys[gI_CurrentParserIndex].SetString("runspeed", "260.00");
	gSM_StyleKeys[gI_CurrentParserIndex].SetString("gravity", "1.0");
	gSM_StyleKeys[gI_CurrentParserIndex].SetString("speed", "1.0");
	gSM_StyleKeys[gI_CurrentParserIndex].SetString("halftime", "0");
	gSM_StyleKeys[gI_CurrentParserIndex].SetString("timescale", "1.0");
	gSM_StyleKeys[gI_CurrentParserIndex].SetString("velocity", "1.0");
	gSM_StyleKeys[gI_CurrentParserIndex].SetString("bonus_velocity", "0.0");
	gSM_StyleKeys[gI_CurrentParserIndex].SetString("min_velocity", "0.0");
	gSM_StyleKeys[gI_CurrentParserIndex].SetString("jump_multiplier", "0.0");
	gSM_StyleKeys[gI_CurrentParserIndex].SetString("jump_bonus", "0.0");
	gSM_StyleKeys[gI_CurrentParserIndex].SetString("block_w", "0");
	gSM_StyleKeys[gI_CurrentParserIndex].SetString("block_a", "0");
	gSM_StyleKeys[gI_CurrentParserIndex].SetString("block_s", "0");
	gSM_StyleKeys[gI_CurrentParserIndex].SetString("block_d", "0");
	gSM_StyleKeys[gI_CurrentParserIndex].SetString("block_use", "0");
	gSM_StyleKeys[gI_CurrentParserIndex].SetString("force_hsw", "0");
	gSM_StyleKeys[gI_CurrentParserIndex].SetString("block_pleft", "0");
	gSM_StyleKeys[gI_CurrentParserIndex].SetString("block_pright", "0");
	gSM_StyleKeys[gI_CurrentParserIndex].SetString("block_pstrafe", "0");
	gSM_StyleKeys[gI_CurrentParserIndex].SetString("unranked", "0");
	gSM_StyleKeys[gI_CurrentParserIndex].SetString("noreplay", "0");
	gSM_StyleKeys[gI_CurrentParserIndex].SetString("sync", "1");
	gSM_StyleKeys[gI_CurrentParserIndex].SetString("strafe_count_w", "0");
	gSM_StyleKeys[gI_CurrentParserIndex].SetString("strafe_count_a", "1");
	gSM_StyleKeys[gI_CurrentParserIndex].SetString("strafe_count_s", "0");
	gSM_StyleKeys[gI_CurrentParserIndex].SetString("strafe_count_d", "1");
	gSM_StyleKeys[gI_CurrentParserIndex].SetString("rankingmultiplier", "1.00");
	gSM_StyleKeys[gI_CurrentParserIndex].SetString("special", "0");

	char sOrder[4];
	IntToString(gI_CurrentParserIndex, sOrder, 4);
	gSM_StyleKeys[gI_CurrentParserIndex].SetString("ordering", sOrder);

	gSM_StyleKeys[gI_CurrentParserIndex].SetString("inaccessible", "0");
	gSM_StyleKeys[gI_CurrentParserIndex].SetString("enabled", "1");
	gSM_StyleKeys[gI_CurrentParserIndex].SetString("force_groundkeys", "0");

	gI_OrderedStyles[gI_CurrentParserIndex] = gI_CurrentParserIndex;

	return SMCParse_Continue;
}

public SMCResult OnStyleLeaveSection(SMCParser smc)
{
	if (gI_CurrentParserIndex == -1)
	{
		// OnStyleLeaveSection can be called back to back.
		// And does for when hitting the last style!
		// So we set gI_CurrentParserIndex to -1 at the end of this function.
		return SMCParse_Halt;
	}

	// if this style is disabled, we will force certain settings
	if(GetStyleSettingInt(gI_CurrentParserIndex, "enabled") <= 0)
	{
		gSM_StyleKeys[gI_CurrentParserIndex].SetString("noreplay", "1");
		gSM_StyleKeys[gI_CurrentParserIndex].SetString("rankingmultiplier", "0");
		gSM_StyleKeys[gI_CurrentParserIndex].SetString("inaccessible", "1");
	}

	if(GetStyleSettingBool(gI_CurrentParserIndex, "halftime"))
	{
		gSM_StyleKeys[gI_CurrentParserIndex].SetString("timescale", "0.5");
	}

	if (GetStyleSettingFloat(gI_CurrentParserIndex, "timescale") <= 0.0)
	{
		gSM_StyleKeys[gI_CurrentParserIndex].SetString("timescale", "1.0");
	}

	// Setting it here so that we can reference the timescale setting.
	if(!HasStyleSetting(gI_CurrentParserIndex, "force_timescale"))
	{
		if(GetStyleSettingFloat(gI_CurrentParserIndex, "timescale") == 1.0)
		{
			gSM_StyleKeys[gI_CurrentParserIndex].SetString("force_timescale", "0");
		}

		else
		{
			gSM_StyleKeys[gI_CurrentParserIndex].SetString("force_timescale", "1");
		}
	}

	char sStyleCommand[128];
	gSM_StyleKeys[gI_CurrentParserIndex].GetString("command", sStyleCommand, 128);
	char sName[64];
	gSM_StyleKeys[gI_CurrentParserIndex].GetString("name", sName, 64);

	if(!gB_Registered && strlen(sStyleCommand) > 0 && !GetStyleSettingBool(gI_CurrentParserIndex, "inaccessible"))
	{
		char sStyleCommands[32][32];
		int iCommands = ExplodeString(sStyleCommand, ";", sStyleCommands, 32, 32, false);

		char sDescription[128];
		FormatEx(sDescription, 128, "Change style to %s.", sName);

		for(int x = 0; x < iCommands; x++)
		{
			TrimString(sStyleCommands[x]);
			StripQuotes(sStyleCommands[x]);

			char sCommand[32];
			FormatEx(sCommand, 32, "sm_%s", sStyleCommands[x]);

			gSM_StyleCommands.SetValue(sCommand, gI_CurrentParserIndex);

			RegConsoleCmd(sCommand, Command_StyleChange, sDescription);
		}
	}

	char sPermission[64];
	gSM_StyleKeys[gI_CurrentParserIndex].GetString("permission", sPermission, 64);

	if(StrContains(sPermission, ";") != -1)
	{
		char sText[2][32];
		int iCount = ExplodeString(sPermission, ";", sText, 2, 32);

		AdminFlag flag = Admin_Reservation;

		if(FindFlagByChar(sText[0][0], flag))
		{
			gI_StyleFlag[gI_CurrentParserIndex] = FlagToBit(flag);
		}

		strcopy(gS_StyleOverride[gI_CurrentParserIndex], 32, (iCount >= 2)? sText[1]:"");
	}

	else if(strlen(sPermission) > 0)
	{
		AdminFlag flag = Admin_Reservation;

		if(FindFlagByChar(sPermission[0], flag))
		{
			gI_StyleFlag[gI_CurrentParserIndex] = FlagToBit(flag);
		}
	}

	gI_CurrentParserIndex = -1;

	return SMCParse_Continue;
}

// should be in commands.sp but commands does not register in OnPluginStart()
public Action Command_StyleChange(int client, int args)
{
	char sCommand[128];
	GetCmdArg(0, sCommand, 128);

	int style = 0;

	if(gSM_StyleCommands.GetValue(sCommand, style))
	{
		ChangeClientStyle(client, style, true);

		return Plugin_Handled;
	}

	return Plugin_Continue;
}

public SMCResult OnStyleKeyValue(SMCParser smc, const char[] key, const char[] value, bool key_quotes, bool value_quotes)
{
	gSM_StyleKeys[gI_CurrentParserIndex].SetString(key, value);

	return SMCParse_Continue;
}

public int SortAscending_StyleOrder(int index1, int index2, const int[] array, any hndl)
{
	int iOrder1 = GetStyleSettingInt(index1, "ordering");
	int iOrder2 = GetStyleSettingInt(index2, "ordering");

	if(iOrder1 < iOrder2)
	{
		return -1;
	}

	else if(iOrder1 == iOrder2)
	{
		return 0;
	}

	else
	{
		return 1;
	}
}

void UpdateStyleSettings(int client)
{
	SetEntityGravity(client, GetStyleSettingFloat(gA_Timers[client].bsStyle, "gravity"));
}
