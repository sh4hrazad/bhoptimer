static Function gH_AfterWarningMenu[MAXPLAYERS+1];

// ======[ PUBLIC EVENT ]======

bool Shavit_OnStopPre_Checkpoint(int client)
{
	if(ShouldDisplayStopWarning(client))
	{
		OpenStopWarningMenu(client, DoStopTimer);

		return false;
	}

	return true;
}


// =================

void OpenCheckpointsMenu(int client)
{
	gB_UsingOtherCheckpoint[client] = false;
	bool bSegmented = CanSegment(client);

	if(!gCV_Checkpoints.BoolValue && !bSegmented)
	{
		Shavit_PrintToChat(client, "%T", "FeatureDisabled", client);

		return;
	}

	Menu menu = new Menu(MenuHandler_Checkpoints, MENU_ACTIONS_DEFAULT|MenuAction_DisplayItem|MenuAction_Display);

	if(!bSegmented)
	{
		menu.SetTitle("%T\n%T\n ", "MiscCheckpointMenu", client, "MiscCheckpointWarning", client);
	}

	else
	{
		menu.SetTitle("%T\n ", "MiscCheckpointMenuSegmented", client);
	}

	char sDisplay[64];
	FormatEx(sDisplay, 64, "%T", "MiscCheckpointSave", client, (gA_Checkpoints[client].Length + 1));
	menu.AddItem("save", sDisplay, ITEMDRAW_DEFAULT);

	if(gA_Checkpoints[client].Length > 0)
	{
		FormatEx(sDisplay, 64, "%T", "MiscCheckpointTeleport", client, gI_CurrentCheckpoint[client]);
		menu.AddItem("tele", sDisplay, ITEMDRAW_DEFAULT);
	}
	else
	{
		FormatEx(sDisplay, 64, "%T", "MiscCheckpointTeleport", client, 1);
		menu.AddItem("tele", sDisplay, ITEMDRAW_DISABLED);
	}

	FormatEx(sDisplay, 64, "%T", "MiscCheckpointPrevious", client);
	menu.AddItem("prev", sDisplay, (gI_CurrentCheckpoint[client] > 1)? ITEMDRAW_DEFAULT:ITEMDRAW_DISABLED);

	FormatEx(sDisplay, 64, "%T\n ", "MiscCheckpointNext", client);
	menu.AddItem("next", sDisplay, (gI_CurrentCheckpoint[client] < gA_Checkpoints[client].Length)? ITEMDRAW_DEFAULT:ITEMDRAW_DISABLED);

	// apparently this is the fix
	// menu.AddItem("spacer", "", ITEMDRAW_RAWLINE);

	FormatEx(sDisplay, 64, "%T", "MiscCheckpointDeleteCurrent", client);
	menu.AddItem("del", sDisplay, (gA_Checkpoints[client].Length > 0) ? ITEMDRAW_DEFAULT:ITEMDRAW_DISABLED);

	FormatEx(sDisplay, 64, "%T", "MiscCheckpointReset", client);
	menu.AddItem("reset", sDisplay);

	menu.AddItem("useother", "使用他人存点");
	/* if(!bSegmented)
	{
		char sInfo[16];
		IntToString(CP_ANGLES, sInfo, 16);
		FormatEx(sDisplay, 64, "%T", "MiscCheckpointUseAngles", client);
		menu.AddItem(sInfo, sDisplay);

		IntToString(CP_VELOCITY, sInfo, 16);
		FormatEx(sDisplay, 64, "%T", "MiscCheckpointUseVelocity", client);
		menu.AddItem(sInfo, sDisplay);
	} */

	menu.Pagination = MENU_NO_PAGINATION;
	menu.ExitButton = true;

	Action result = Plugin_Continue;
	Call_OnCheckpointMenuMade(client, bSegmented, result);

	if(result != Plugin_Continue && result != Plugin_Changed)
	{
		return;
	}

	menu.Display(client, MENU_TIME_FOREVER);
}

public int MenuHandler_Checkpoints(Menu menu, MenuAction action, int param1, int param2)
{
	if(action == MenuAction_Select)
	{
		char sInfo[16];
		menu.GetItem(param2, sInfo, 16);

		int iMaxCPs = GetMaxCPs(param1);
		int iCurrent = gI_CurrentCheckpoint[param1];

		Action result = Plugin_Continue;
		Call_OnCheckpointMenuSelect(param1, param2, sInfo, sizeof(sInfo), iCurrent, iMaxCPs, result);

		if(result != Plugin_Continue)
		{
			return 0;
		}

		if(StrEqual(sInfo, "save"))
		{
			SaveCheckpoint(param1);
		}
		else if(StrEqual(sInfo, "tele"))
		{
			TeleportToCheckpoint(param1, iCurrent, true);
		}
		else if(StrEqual(sInfo, "prev"))
		{
			gI_CurrentCheckpoint[param1]--;
		}
		else if(StrEqual(sInfo, "next"))
		{
			gI_CurrentCheckpoint[param1]++;
		}
		else if(StrEqual(sInfo, "del"))
		{
			if(DeleteCheckpoint(param1, gI_CurrentCheckpoint[param1]))
			{
				if(gI_CurrentCheckpoint[param1] > gA_Checkpoints[param1].Length)
				{
					gI_CurrentCheckpoint[param1] = gA_Checkpoints[param1].Length;
				}
			}
		}
		else if(StrEqual(sInfo, "reset"))
		{
			ConfirmCheckpointsDeleteMenu(param1);
			gB_InCheckpointMenu[param1] = false;

			return 0;
		}
		else if(StrEqual(sInfo, "useother"))
		{
			UseOtherCheckpoints(param1);

			return 0;
		}
		else if(!StrEqual(sInfo, "spacer"))
		{
			char sCookie[16];
			gI_CheckpointsSettings[param1] ^= StringToInt(sInfo);
			IntToString(gI_CheckpointsSettings[param1], sCookie, StringToInt(sInfo));

			gH_CheckpointsCookie.Set(param1, sCookie);
		}

		OpenCheckpointsMenu(param1);
	}
	else if(action == MenuAction_DisplayItem)
	{
		char sInfo[16];
		char sDisplay[64];
		int style = 0;
		menu.GetItem(param2, sInfo, 16, style, sDisplay, 64);

		if(StringToInt(sInfo) == 0)
		{
			return 0;
		}

		Format(sDisplay, 64, "[%s] %s", ((gI_CheckpointsSettings[param1] & StringToInt(sInfo)) > 0)? "x":" ", sDisplay);

		return RedrawMenuItem(sDisplay);
	}
	else if (action == MenuAction_Display)
	{
		gB_InCheckpointMenu[param1] = true;
	}
	else if (action == MenuAction_Cancel)
	{
		gB_InCheckpointMenu[param1] = false;
	}
	else if(action == MenuAction_End)
	{
		delete menu;
	}

	return 0;
}

void ConfirmCheckpointsDeleteMenu(int client)
{
	Menu hMenu = new Menu(MenuHandler_CheckpointsDelete);
	hMenu.SetTitle("%T\n ", "ClearCPWarning", client);

	char sDisplay[64];
	FormatEx(sDisplay, 64, "%T", "ClearCPYes", client);
	hMenu.AddItem("yes", sDisplay);

	FormatEx(sDisplay, 64, "%T", "ClearCPNo", client);
	hMenu.AddItem("no", sDisplay);

	hMenu.ExitButton = true;
	hMenu.Display(client, MENU_TIME_FOREVER);
}

public int MenuHandler_CheckpointsDelete(Menu menu, MenuAction action, int param1, int param2)
{
	if(action == MenuAction_Select)
	{
		char sInfo[8];
		menu.GetItem(param2, sInfo, 8);

		if(StrEqual(sInfo, "yes"))
		{
			ResetCheckpoints(param1);
		}

		OpenCheckpointsMenu(param1);
	}

	else if(action == MenuAction_End)
	{
		delete menu;
	}

	return 0;
}

bool ShouldDisplayStopWarning(int client)
{
	return (gCV_StopTimerWarning.BoolValue && Shavit_GetTimerStatus(client) != Timer_Stopped && Shavit_GetClientTime(client) > gCV_StopTimerWarning.FloatValue && !CanSegment(client));
}

/* void DoNoclip(int client)
{
	Shavit_StopTimer(client);
	SetEntityMoveType(client, MOVETYPE_NOCLIP);
} */

void DoStopTimer(int client)
{
	Shavit_StopTimer(client);
}

void OpenStopWarningMenu(int client, StopTimerCallback after)
{
	gH_AfterWarningMenu[client] = after;

	Menu hMenu = new Menu(MenuHandler_StopWarning);
	hMenu.SetTitle("%T\n ", "StopTimerWarning", client);

	char sDisplay[64];
	FormatEx(sDisplay, 64, "%T", "StopTimerYes", client);
	hMenu.AddItem("yes", sDisplay);

	FormatEx(sDisplay, 64, "%T", "StopTimerNo", client);
	hMenu.AddItem("no", sDisplay);

	hMenu.ExitButton = true;
	hMenu.Display(client, MENU_TIME_FOREVER);
}

public int MenuHandler_StopWarning(Menu menu, MenuAction action, int param1, int param2)
{
	if(action == MenuAction_Select)
	{
		char sInfo[8];
		menu.GetItem(param2, sInfo, 8);

		if(StrEqual(sInfo, "yes"))
		{
			Call_StartFunction(null, gH_AfterWarningMenu[param1]);
			Call_PushCell(param1);
			Call_Finish();
		}
	}

	else if(action == MenuAction_End)
	{
		delete menu;
	}

	return 0;
}