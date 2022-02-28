// percent, ranged, Require_*
static const char gA_ChatRankMenuFormatStrings[2][2][4][] = 
{
	{
		{
			"ChatRanksMenu_Flat",
			"ChatRanksMenu_Points",
			"ChatRanksMenu_WR_Count",
			"ChatRanksMenu_WR_Rank",
		},
		{
			"ChatRanksMenu_Flat_Ranged",
			"ChatRanksMenu_Points_Ranged",
			"ChatRanksMenu_WR_Count_Ranged",
			"ChatRanksMenu_WR_Rank_Ranged",
		}
	},
	{
		{
			"ChatRanksMenu_Percentage",
			"",
			"",
			"ChatRanksMenu_WR_Rank_Percentage",
		},
		{
			"ChatRanksMenu_Percentage_Ranged",
			"",
			"",
			"ChatRanksMenu_WR_Rank_Ranged",
		}
	}
};

void ShowRanksMenu(int client, int item)
{
	Menu menu = new Menu(MenuHandler_Ranks);
	menu.SetTitle("%T\n ", "ChatRanksMenu", client);

	int iLength = gA_ChatRanks.Length;

	for(int i = 0; i < iLength; i++)
	{
		chatranks_cache_t cache;
		gA_ChatRanks.GetArray(i, cache, sizeof(chatranks_cache_t));

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

		if(cache.bEasterEgg || !bFlagAccess)
		{
			continue;
		}

		char sDisplay[MAXLENGTH_DISPLAY];
		strcopy(sDisplay, MAXLENGTH_DISPLAY, cache.sDisplay);
		ReplaceString(sDisplay, MAXLENGTH_DISPLAY, "<n>", "\n");

		char sExplodedString[2][32];
		ExplodeString(sDisplay, "\n", sExplodedString, 2, 64);

		FormatEx(sDisplay, MAXLENGTH_DISPLAY, "%s\n ", sExplodedString[0]);

		char sRequirements[64];

		if(!cache.bFree)
		{
			if(cache.fFrom == 0.0 && cache.fTo == 0.0)
			{
				FormatEx(sRequirements, 64, "%T", "ChatRanksMenu_Unranked", client);
			}
			else
			{
				char sTranslation[64];
				strcopy(sTranslation, sizeof(sTranslation), gA_ChatRankMenuFormatStrings[cache.bPercent?1:0][cache.bRanged?1:0][cache.iRequire]);

				if (!cache.bRanged && !cache.bPercent && cache.fFrom == 1.0)
				{
					StrCat(sTranslation, sizeof(sTranslation), "_1");
				}

				FormatEx(sRequirements, 64, "%T", sTranslation, client, cache.fFrom, cache.fTo, '%', '%');
			}
		}

		StrCat(sDisplay, MAXLENGTH_DISPLAY, sRequirements);
		StrCat(sDisplay, MAXLENGTH_DISPLAY, "\n ");

		char sInfo[8];
		IntToString(i, sInfo, 8);

		menu.AddItem(sInfo, sDisplay);
	}

	// why even
	if(menu.ItemCount == 0)
	{
		menu.AddItem("-1", "Nothing");
	}

	menu.ExitButton = true;
	menu.DisplayAt(client, item, MENU_TIME_FOREVER);
}

public int MenuHandler_Ranks(Menu menu, MenuAction action, int param1, int param2)
{
	if(action == MenuAction_Select)
	{
		char sInfo[8];
		menu.GetItem(param2, sInfo, 8);

		PreviewChat(param1, StringToInt(sInfo));
		ShowRanksMenu(param1, GetMenuSelectionPosition());
	}

	else if(action == MenuAction_End)
	{
		delete menu;
	}

	return 0;
}