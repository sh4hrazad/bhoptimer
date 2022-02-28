void UseOtherCheckpoints(int client)
{
	Menu menu = new Menu(OtherCheckpointMenu_handler);
	for(int i = 1; i < MaxClients + 1; i++)
	{
		if(IsValidClient(i) && !IsFakeClient(i) && i != client)
		{
			char sName[MAX_NAME_LENGTH];
			GetClientName(i, sName, sizeof(sName));

			char sItem[4];
			IntToString(i, sItem, 4);
			menu.AddItem(sItem, sName);
		}
	}

	menu.Display(client, -1);
}

public int OtherCheckpointMenu_handler(Menu menu, MenuAction action, int param1, int param2)
{
	if(action == MenuAction_Select)
	{
		char sInfo[4];
		menu.GetItem(param2, sInfo, sizeof(sInfo));

		int other = StringToInt(sInfo);

		gI_OtherClientIndex[param1] = other;
		gI_OtherCurrentCheckpoint[param1] = gI_CurrentCheckpoint[other];

		OpenOtherCPMenu(other, param1);
	}
	else if(action == MenuAction_End)
	{
		delete menu;
	}

	return 0;
}

void OpenOtherCPMenu(int other, int client)
{
	bool bSegmented = CanSegment(other);

	if(!gCV_Checkpoints.BoolValue && !bSegmented)
	{
		Shavit_PrintToChat(client, "%T", "FeatureDisabled", client);

		return;
	}

	Menu menu = new Menu(MenuHandler_OtherCheckpoints, MENU_ACTIONS_DEFAULT|MenuAction_DisplayItem);

	if(!bSegmented)
	{
		menu.SetTitle("%T\n%T\n ", "MiscCheckpointMenu", client, "MiscCheckpointWarning", client);
	}

	else
	{
		menu.SetTitle("%T\n ", "MiscCheckpointMenuSegmented", client);
	}

	char sDisplay[64];

	if(gA_Checkpoints[other].Length > 0)
	{
		FormatEx(sDisplay, 64, "%T", "MiscCheckpointTeleport", client, gI_OtherCurrentCheckpoint[client]);
		menu.AddItem("tele", sDisplay, ITEMDRAW_DEFAULT);
	}
	else
	{
		Format(sDisplay, 64, "这个B还没存点..");
		menu.AddItem("", sDisplay, ITEMDRAW_DISABLED);
	}

	FormatEx(sDisplay, 64, "%T", "MiscCheckpointPrevious", client);
	menu.AddItem("prev", sDisplay, (gI_OtherCurrentCheckpoint[client] > 1)? ITEMDRAW_DEFAULT:ITEMDRAW_DISABLED);

	FormatEx(sDisplay, 64, "%T\n ", "MiscCheckpointNext", client);
	menu.AddItem("next", sDisplay, (gI_OtherCurrentCheckpoint[client] < gA_Checkpoints[other].Length)? ITEMDRAW_DEFAULT:ITEMDRAW_DISABLED);

	menu.Pagination = MENU_NO_PAGINATION;
	menu.ExitButton = true;

	menu.Display(client, MENU_TIME_FOREVER);
}

public int MenuHandler_OtherCheckpoints(Menu menu, MenuAction action, int param1, int param2)
{
	if(action == MenuAction_Select)
	{
		char sInfo[16];
		menu.GetItem(param2, sInfo, 16);

		int other = gI_OtherClientIndex[param1];

		if(StrEqual(sInfo, "tele"))
		{
			TeleportToOtherCheckpoint(param1, other, gI_OtherCurrentCheckpoint[param1], true);
		}
		else if(StrEqual(sInfo, "prev"))
		{
			gI_OtherCurrentCheckpoint[param1]--;
		}
		else if(StrEqual(sInfo, "next"))
		{
			gI_OtherCurrentCheckpoint[param1]++;
		}

		OpenOtherCPMenu(other, param1);
	}
	else if(action == MenuAction_End)
	{
		delete menu;
	}

	return 0;
}

void TeleportToOtherCheckpoint(int client, int other, int index, bool suppressMessage)
{
	if(index < 1 || index > gCV_MaxCP.IntValue || (!gCV_Checkpoints.BoolValue && !CanSegment(other)))
	{
		return;
	}

	gB_UsingOtherCheckpoint[client] = true;

	if(index > gA_Checkpoints[other].Length)
	{
		Shavit_PrintToChat(client, "%T", "MiscCheckpointsEmpty", client, index);
		return;
	}

	cp_cache_t cpcache;
	gA_Checkpoints[other].GetArray(index - 1, cpcache, sizeof(cp_cache_t));

	if(IsNullVector(cpcache.fPosition))
	{
		return;
	}

	if(!IsPlayerAlive(client))
	{
		Shavit_PrintToChat(client, "%T", "CommandAlive", client);

		return;
	}

	gI_TimesTeleported[client]++;

	if(Shavit_InsideZone(client, Zone_Start, -1))
	{
		Shavit_StopTimer(client);
	}

	LoadCheckpointCache(client, cpcache, false);
	Shavit_ResumeTimer(client);

	if(!suppressMessage)
	{
		Shavit_PrintToChat(client, "%T", "MiscCheckpointsTeleported", client, index);
	}
}