static int gI_MenuTrack[MAXPLAYERS+1];
static int gI_MenuStyle[MAXPLAYERS+1];
static int gI_MenuStage[MAXPLAYERS+1];
static int gI_MenuType[MAXPLAYERS+1];
static bool gB_MenuBonus[MAXPLAYERS+1];
static bool gB_MenuStage[MAXPLAYERS+1];



// ======[ PUBLIC ]======

void OpenDeleteReplayMenu(int client)
{
	Menu menu = new Menu(DeleteReplay_Callback);
	menu.SetTitle("%T", "DeleteReplayMenuTitle", client);

	int[] styles = new int[gI_Styles];
	Shavit_GetOrderedStyles(styles, gI_Styles);

	for(int i = 0; i < gI_Styles; i++)
	{
		int iStyle = styles[i];

		if(!ReplayEnabled(iStyle))
		{
			continue;
		}

		for(int j = 0; j < TRACKS_SIZE; j++)
		{
			if(gA_FrameCache[iStyle][j].iFrameCount == 0)
			{
				continue;
			}

			char sInfo[8];
			FormatEx(sInfo, 8, "%d;%d", iStyle, j);

			float time = GetReplayLength(iStyle, j, gA_FrameCache[iStyle][j]);

			char sTrack[32];
			GetTrackName(client, j, sTrack, 32);

			char sDisplay[64];

			if(time > 0.0)
			{
				char sTime[32];
				FormatSeconds(time, sTime, 32, false);

				FormatEx(sDisplay, 64, "%s (%s) - %s", gS_StyleStrings[iStyle].sStyleName, sTrack, sTime);
			}

			else
			{
				FormatEx(sDisplay, 64, "%s (%s)", gS_StyleStrings[iStyle].sStyleName, sTrack);
			}

			menu.AddItem(sInfo, sDisplay);
		}
	}

	if(menu.ItemCount == 0)
	{
		char sMenuItem[64];
		FormatEx(sMenuItem, 64, "%T", "ReplaysUnavailable", client);
		menu.AddItem("-1", sMenuItem);
	}

	menu.ExitButton = true;
	menu.Display(client, MENU_TIME_FOREVER);
}

void OpenReplayMenu(int client, bool canControlReplayUiFix=false)
{
	Menu menu = new Menu(MenuHandler_Replay, MENU_ACTIONS_DEFAULT|MenuAction_DisplayItem|MenuAction_Display);
	menu.SetTitle("%T\n ", "Menu_Replay", client);

	char sDisplay[64];
	bool alreadyHaveBot = (gA_BotInfo[client].iEnt > 0);
	int index = GetControllableReplay(client);
	bool canControlReplay = canControlReplayUiFix || (index != -1);

	FormatEx(sDisplay, 64, "%T", "CentralReplayStop", client);
	menu.AddItem("stop", sDisplay, canControlReplay ? ITEMDRAW_DEFAULT:ITEMDRAW_DISABLED);

	FormatEx(sDisplay, 64, "%T", "Menu_SpawnReplay", client);
	menu.AddItem("spawn", sDisplay, !(alreadyHaveBot) ? ITEMDRAW_DEFAULT:ITEMDRAW_DISABLED);

	FormatEx(sDisplay, 64, "+1s");
	menu.AddItem("+1", sDisplay, canControlReplay ? ITEMDRAW_DEFAULT:ITEMDRAW_DISABLED);

	FormatEx(sDisplay, 64, "-1s");
	menu.AddItem("-1", sDisplay, canControlReplay ? ITEMDRAW_DEFAULT:ITEMDRAW_DISABLED);

	FormatEx(sDisplay, 64, "+10s");
	menu.AddItem("+10", sDisplay, canControlReplay ? ITEMDRAW_DEFAULT:ITEMDRAW_DISABLED);

	FormatEx(sDisplay, 64, "-10s");
	menu.AddItem("-10", sDisplay, canControlReplay ? ITEMDRAW_DEFAULT:ITEMDRAW_DISABLED);

	FormatEx(sDisplay, 64, "%T", "Menu_Replay2X", client, (index != -1 && gA_BotInfo[index].b2x) ? 2 : 1);
	menu.AddItem("2x", sDisplay, canControlReplay ? ITEMDRAW_DEFAULT:ITEMDRAW_DISABLED);

	FormatEx(sDisplay, 64, "%T", "Menu_RefreshReplay", client);
	menu.AddItem("refresh", sDisplay, ITEMDRAW_DEFAULT);

	menu.Pagination = MENU_NO_PAGINATION;
	menu.ExitButton = true;
	menu.DisplayAt(client, 0, MENU_TIME_FOREVER);
}



// ======[ PRIVATE ]======

public int DeleteReplay_Callback(Menu menu, MenuAction action, int param1, int param2)
{
	if(action == MenuAction_Select)
	{
		char sInfo[8];
		menu.GetItem(param2, sInfo, 8);

		char sExploded[2][4];
		ExplodeString(sInfo, ";", sExploded, 2, 4);

		int style = StringToInt(sExploded[0]);

		if(style == -1)
		{
			return 0;
		}

		gI_MenuTrack[param1] = StringToInt(sExploded[1]);

		Menu submenu = new Menu(DeleteConfirmation_Callback);
		submenu.SetTitle("%T", "ReplayDeletionConfirmation", param1, gS_StyleStrings[style].sStyleName);

		char sMenuItem[64];

		for(int i = 1; i <= GetRandomInt(2, 4); i++)
		{
			FormatEx(sMenuItem, 64, "%T", "MenuResponseNo", param1);
			submenu.AddItem("-1", sMenuItem);
		}

		FormatEx(sMenuItem, 64, "%T", "MenuResponseYes", param1);
		submenu.AddItem(sInfo, sMenuItem);

		for(int i = 1; i <= GetRandomInt(2, 4); i++)
		{
			FormatEx(sMenuItem, 64, "%T", "MenuResponseNo", param1);
			submenu.AddItem("-1", sMenuItem);
		}

		submenu.ExitButton = true;
		submenu.Display(param1, MENU_TIME_FOREVER);
	}

	else if(action == MenuAction_End)
	{
		delete menu;
	}

	return 0;
}

public int DeleteConfirmation_Callback(Menu menu, MenuAction action, int param1, int param2)
{
	if(action == MenuAction_Select)
	{
		char sInfo[4];
		menu.GetItem(param2, sInfo, 4);
		int style = StringToInt(sInfo);

		if(DeleteReplay(style, gI_MenuTrack[param1], 0, gS_Map))
		{
			char sTrack[32];
			GetTrackName(param1, gI_MenuTrack[param1], sTrack, 32);

			LogAction(param1, param1, "Deleted replay for %s on map %s. (Track: %s)", gS_StyleStrings[style].sStyleName, gS_Map, sTrack);

			Shavit_PrintToChat(param1, "%T", "ReplayDeleted", param1, gS_StyleStrings[style].sStyleName, sTrack);
		}

		else
		{
			Shavit_PrintToChat(param1, "%T", "ReplayDeleteFailure", param1, gS_StyleStrings[style].sStyleName);
		}
	}

	else if(action == MenuAction_End)
	{
		delete menu;
	}

	return 0;
}

public int MenuHandler_Replay(Menu menu, MenuAction action, int param1, int param2)
{
	if(action == MenuAction_Select)
	{
		char sInfo[16];
		menu.GetItem(param2, sInfo, 16);

		if (StrEqual(sInfo, "stop"))
		{
			int index = GetControllableReplay(param1);

			if (index != -1)
			{
				Shavit_PrintToChat(param1, "%T", "CentralReplayStopped", param1);
				FinishReplay(gA_BotInfo[index]);
			}

			OpenReplayMenu(param1);
		}
		else if (StrEqual(sInfo, "spawn"))
		{
			OpenReplayTrackMenu(param1);
		}
		else if (StrEqual(sInfo, "2x"))
		{
			int index = GetControllableReplay(param1);

			if (index != -1)
			{
				gA_BotInfo[index].b2x = !gA_BotInfo[index].b2x;
			}

			OpenReplayMenu(param1);
		}
		else if (StrEqual(sInfo, "refresh"))
		{
			OpenReplayMenu(param1);
		}
		else if (sInfo[0] == '-' || sInfo[0] == '+')
		{
			int seconds = StringToInt(sInfo);

			int index = GetControllableReplay(param1);

			if (index != -1)
			{
				if(gA_BotInfo[index].iTrack == 0 && gA_BotInfo[index].iStage == 0)
				{
					Shavit_PrintToChat(param1, "{darkred}无法对主线电脑进行跳帧操作{default}");
					OpenReplayMenu(param1);
					return 0;
				}

				gA_BotInfo[index].iTick += RoundToFloor(seconds * gF_Tickrate);

				if (gA_BotInfo[index].iTick < 0)
				{
					gA_BotInfo[index].iTick = 0;
					gA_BotInfo[index].iRealTick = 0;
				}
				else
				{
					int limit = (gA_BotInfo[index].aCache.iFrameCount + gA_BotInfo[index].aCache.iPreFrames + gA_BotInfo[index].aCache.iPostFrames);

					if (gA_BotInfo[index].iTick > limit)
					{
						gA_BotInfo[index].iTick = limit;
						gA_BotInfo[index].iRealTick = limit;
					}
				}
			}

			OpenReplayMenu(param1);
		}
	}
	else if (action == MenuAction_Display)
	{
		gB_InReplayMenu[param1] = true;
	}
	else if (action == MenuAction_Cancel)
	{
		gB_InReplayMenu[param1] = false;
	}
	else if(action == MenuAction_End)
	{
		delete menu;
	}

	return 0;
}

static void OpenReplayTrackMenu(int client)
{
	if(gI_DynamicBots >= gCV_DynamicBotLimit.IntValue)
	{
		Shavit_PrintToChat(client, "电脑数量达到极限了");

		return;
	}

	gB_MenuBonus[client] = false;
	gB_MenuStage[client] = false;
	gI_MenuType[client] = Replay_Dynamic;

	Menu menu = new Menu(MenuHandler_ReplayTrack);
	menu.SetTitle("%T\n ", "CentralReplayTrack", client);

	char sItem[16];

	FormatEx(sItem, 16, "主线");
	menu.AddItem("", sItem);

	FormatEx(sItem, 16, "奖励关");
	menu.AddItem("", sItem);

	FormatEx(sItem, 16, "关卡");
	menu.AddItem("", sItem);

	menu.ExitBackButton = true;
	menu.Display(client, MENU_TIME_FOREVER);
}

public int MenuHandler_ReplayTrack(Menu menu, MenuAction action, int param1, int param2)
{
	if(action == MenuAction_Select)
	{
		Menu submenu = new Menu(MenuHandler_ReplayTrack2);

		switch(param2)
		{
			case 0:
			{
				delete submenu;

				gI_MenuTrack[param1] = 0;
				gI_MenuStage[param1] = 0;
				OpenReplayStyleMenu(param1, gI_MenuTrack[param1]);
			}
			case 1:
			{
				submenu.SetTitle("%T\n ", "CentralReplayTrack", param1);

				for(int i = 1; i < TRACKS_SIZE; i++)
				{
					for(int j = 0; j < gI_Styles; j++)
					{
						if(gA_FrameCache[j][i].iFrameCount > 0)
						{
							char sInfo[8];
							IntToString(i, sInfo, 8);

							char sTrack[32];
							GetTrackName(param1, i, sTrack, 32);

							submenu.AddItem(sInfo, sTrack);
							break;
						}
					}
				}

				if(submenu.ItemCount == 0)
				{
					char sItem[32];
					FormatEx(sItem, sizeof(sItem), "%T", "ReplaysUnavailable", param1);
					submenu.AddItem("-1", sItem, ITEMDRAW_DISABLED);
				}

				gB_MenuBonus[param1] = true;

				submenu.ExitBackButton = true;
				submenu.Display(param1, MENU_TIME_FOREVER);
			}
			case 2:
			{
				submenu.SetTitle("选择关卡", param1);

				for(int i = 1; i <= Shavit_GetMapStages(); i++)
				{
					for(int j = 0; j < gI_Styles; j++)
					{
						if(gA_FrameCache_Stage[j][i].iFrameCount > 0)
						{
							char sInfo[8];
							IntToString(i, sInfo, sizeof(sInfo));

							char sStage[16];
							FormatEx(sStage, sizeof(sStage), "关卡 %d", i);

							submenu.AddItem(sInfo, sStage);
							break;
						}
					}
				}

				if(submenu.ItemCount == 0)
				{
					char sItem[32];
					FormatEx(sItem, sizeof(sItem), "%T", "ReplaysUnavailable", param1);
					submenu.AddItem("-1", sItem, ITEMDRAW_DISABLED);
				}

				gB_MenuStage[param1] = true;

				submenu.ExitBackButton = true;
				submenu.Display(param1, MENU_TIME_FOREVER);
			}
		}
	}
	else if(action == MenuAction_Cancel && param2 == MenuCancel_ExitBack)
	{
		OpenReplayMenu(param1);
	}
	else if(action == MenuAction_End)
	{
		delete menu;
	}

	return 0;
}

public int MenuHandler_ReplayTrack2(Menu menu, MenuAction action, int param1, int param2)
{
	if(action == MenuAction_Select)
	{
		char sInfo[8];
		menu.GetItem(param2, sInfo, 8);

		int value = StringToInt(sInfo);
		if(gB_MenuBonus[param1])
		{
			gI_MenuTrack[param1] = value;
			gI_MenuStage[param1] = 0;
		}
		else if(gB_MenuStage[param1])
		{
			gI_MenuTrack[param1] = 0;
			gI_MenuStage[param1] = value;
		}

		OpenReplayStyleMenu(param1, gI_MenuTrack[param1], gI_MenuStage[param1]);
	}
	else if(action == MenuAction_Cancel && param2 == MenuCancel_ExitBack)
	{
		OpenReplayTrackMenu(param1);
	}
	else if(action == MenuAction_End)
	{
		delete menu;
	}
	
	return 0;
}

static void OpenReplayStyleMenu(int client, int track, int stage = 0)
{
	char sTrack[32];
	GetTrackName(client, track, sTrack, 32);

	Menu menu = new Menu(MenuHandler_ReplayStyle);
	menu.SetTitle("%T (%s)\n ", "CentralReplayTitle", client, stage == 0 ? sTrack : "关卡");

	int[] styles = new int[gI_Styles];
	Shavit_GetOrderedStyles(styles, gI_Styles);

	for(int i = 0; i < gI_Styles; i++)
	{
		int iStyle = styles[i];

		if(!ReplayEnabled(iStyle))
		{
			continue;
		}

		char sInfo[8];
		IntToString(iStyle, sInfo, 8);

		float time = GetReplayLength(iStyle, track, (stage == 0)? gA_FrameCache[iStyle][track]:gA_FrameCache_Stage[iStyle][stage], stage);

		char sDisplay[64];

		if(time > 0.0)
		{
			char sTime[32];
			FormatSeconds(time, sTime, 32, false);

			FormatEx(sDisplay, 64, "%s - %s", gS_StyleStrings[iStyle].sStyleName, sTime);
		}
		else
		{
			strcopy(sDisplay, 64, gS_StyleStrings[iStyle].sStyleName);
		}

		if(stage == 0)
		{
			if(gA_FrameCache[iStyle][track].iFrameCount > 0)
			{
				menu.AddItem(sInfo, sDisplay);
			}
		}
		else
		{
			if(gA_FrameCache_Stage[iStyle][stage].iFrameCount > 0)
			{
				menu.AddItem(sInfo, sDisplay);
			}
		}
	}

	if(menu.ItemCount == 0)
	{
		char sItem[32];
		FormatEx(sItem, sizeof(sItem), "%T", "ReplaysUnavailable", client);
		menu.AddItem("-1", sItem, ITEMDRAW_DISABLED);
	}

	menu.ExitBackButton = true;
	menu.DisplayAt(client, 0, 300);
}

public int MenuHandler_ReplayStyle(Menu menu, MenuAction action, int param1, int param2)
{
	if(action == MenuAction_Select)
	{
		char sInfo[16];
		menu.GetItem(param2, sInfo, 16);

		int style = StringToInt(sInfo);

		if(style < 0 || style >= gI_Styles || !ReplayEnabled(style) || gA_BotInfo[param1].iEnt > 0 || (GetEngineTime() - gF_LastInteraction[param1] < gCV_PlaybackCooldown.FloatValue && !CheckCommandAccess(param1, "sm_deletereplay", ADMFLAG_RCON)))
		{
			return 0;
		}

		gI_MenuStyle[param1] = style;
		int type = gI_MenuType[param1];

		int bot = -1;

		if (type == Replay_Central)
		{
			if (!IsValidClient(gI_CentralBot))
			{
				return 0;
			}

			if (gA_BotInfo[gI_CentralBot].iStatus != Replay_Idle)
			{
				Shavit_PrintToChat(param1, "%T", "CentralReplayPlaying", param1);
				return 0;
			}

			bot = gI_CentralBot;
		}
		else if (type == Replay_Dynamic)
		{
			if (gI_DynamicBots >= gCV_DynamicBotLimit.IntValue)
			{
				Shavit_PrintToChat(param1, "%T", "TooManyDynamicBots", param1);
				return 0;
			}
		}

		frame_cache_t cache; // NULL cache
		bot = CreateReplayEntity(gI_MenuTrack[param1], gI_MenuStyle[param1], gCV_ReplayDelay.FloatValue, param1, bot, type, false, cache, gI_MenuStage[param1]);

		if (bot == 0)
		{
			Shavit_PrintToChat(param1, "%T", "FailedToCreateReplay", param1);
			return 0;
		}
	}
	else if(action == MenuAction_Cancel && param2 == MenuCancel_ExitBack)
	{
		OpenReplayTrackMenu(param1);
	}
	else if(action == MenuAction_End)
	{
		delete menu;
	}

	return 0;
}