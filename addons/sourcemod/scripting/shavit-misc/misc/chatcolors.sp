// ======[ EVENTS ]======

void RegisterCommands_ChatColors()
{
	RegConsoleCmd("sm_colors", Command_ValidColors, "Show a list of avaliable colors to client's chat");
	RegConsoleCmd("sm_validcolors", Command_ValidColors, "Show a list of avaliable colors to client's chat");
}

public Action Command_ValidColors(int client, int args)
{
	if(!IsValidClient(client))
	{
		return Plugin_Handled;
	}

	static char sGlobalColorNames[][] =
	{
		"{default}", "{team}", "{green}"
	};

	static char sGlobalColorNamesDemo[][] =
	{
		"default", "team", "green"
	};

	static char sCSGOColorNames[][] =
	{
		"{blue}", "{bluegrey}", "{darkblue}", "{darkred}", "{gold}", "{grey}", "{grey2}", "{lightgreen}", "{lightred}", "{lime}", "{orchid}", "{yellow}", "{palered}"
	};

	static char sCSGOColorNamesDemo[][] =
	{
		"blue", "bluegrey", "darkblue", "darkred", "gold", "grey", "grey2", "lightgreen", "lightred", "lime", "orchid", "yellow", "palered"
	};

	for(int i = 0; i < sizeof(sGlobalColorNames); i++)
	{
		Shavit_PrintToChat(client, "%s%s", sGlobalColorNames[i], sGlobalColorNamesDemo[i]);
	}

	for(int i = 0; i < sizeof(sCSGOColorNames); i++)
	{
		Shavit_PrintToChat(client, "%s%s", sCSGOColorNames[i], sCSGOColorNamesDemo[i]);
	}

	return Plugin_Handled;
}