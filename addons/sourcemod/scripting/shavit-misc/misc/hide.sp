static Cookie gH_HideCookie = null;


// ======[ EVENTS ]======

void RegisterCommands_Hide()
{
	RegConsoleCmd("sm_hide", Command_Hide, "Toggle players' hiding.");
	RegConsoleCmd("sm_unhide", Command_Hide, "Toggle players' hiding.");
}

void OnClientPutInServer_Hide(int client)
{
	SDKHook(client, SDKHook_SetTransmit, OnSetTransmit);

	if(!AreClientCookiesCached(client))
	{
		gB_Hide[client] = false;
	}
}

void RegisterCookie_Hide()
{
	gH_HideCookie = new Cookie("shavit_hide", "Hide settings", CookieAccess_Protected);
}

void OnClientCookiesCached_Hide(int client)
{
	char sSetting[8];
	gH_HideCookie.Get(client, sSetting, 8);

	if(strlen(sSetting) == 0)
	{
		gH_HideCookie.Set(client, "0");
		gB_Hide[client] = false;
	}
	else
	{
		gB_Hide[client] = view_as<bool>(StringToInt(sSetting));
	}
}



// ======[ PRIVATE ]======

public Action Command_Hide(int client, int args)
{
	if(!IsValidClient(client))
	{
		return Plugin_Handled;
	}

	gB_Hide[client] = !gB_Hide[client];
	gH_HideCookie.Set(client, gB_Hide[client] ? "1" : "0");

	if(gB_Hide[client])
	{
		Shavit_PrintToChat(client, "%T", "HideEnabled", client);
	}
	else
	{
		Shavit_PrintToChat(client, "%T", "HideDisabled", client);
	}

	return Plugin_Handled;
}

public Action OnSetTransmit(int entity, int client)
{
	if((gB_Hide[client] || IsFakeClient(entity) /* always hide replay bot */ ) && client != entity 
		&& (!IsClientObserver(client) || (GetEntProp(client, Prop_Send, "m_iObserverMode") != 6
		&& GetEntPropEnt(client, Prop_Send, "m_hObserverTarget") != entity)))
	{
		return Plugin_Handled;
	}

	return Plugin_Continue;
}