void OpenStyleMenu(int client)
{
	Menu menu = new Menu(StyleMenu_Handler);
	menu.SetTitle("%T", "StyleMenuTitle", client);

	for(int i = 0; i < gI_Styles; i++)
	{
		int iStyle = gI_OrderedStyles[i];

		// this logic will prevent the style from showing in !style menu if it's specifically inaccessible
		// or just completely disabled
		if((GetStyleSettingBool(iStyle, "inaccessible") && GetStyleSettingInt(iStyle, "enabled") == 1) ||
			GetStyleSettingInt(iStyle, "enabled") == -1)
		{
			continue;
		}

		char sInfo[8];
		IntToString(iStyle, sInfo, 8);

		char sDisplay[64];

		if(GetStyleSettingBool(iStyle, "unranked"))
		{
			char sName[64];
			gSM_StyleKeys[iStyle].GetString("name", sName, 64);
			FormatEx(sDisplay, 64, "%T %s", "StyleUnranked", client, sName);
		}

		else
		{
			float time = 0.0;

			Call_OnCommandStyle(client, iStyle, time);

			if(time > 0.0)
			{
				char sTime[32];
				FormatSeconds(time, sTime, 32, false);

				char sWR[8];
				strcopy(sWR, 8, "WR");

				if (gA_Timers[client].iTimerTrack >= Track_Bonus)
				{
					strcopy(sWR, 8, "BWR");
				}

				char sName[64];
				gSM_StyleKeys[iStyle].GetString("name", sName, 64);
				FormatEx(sDisplay, 64, "%s - %s: %s", sName, sWR, sTime);
			}

			else
			{
				gSM_StyleKeys[iStyle].GetString("name", sDisplay, 64);
			}
		}

		menu.AddItem(sInfo, sDisplay, (gA_Timers[client].bsStyle == iStyle || !Shavit_HasStyleAccess(client, iStyle))? ITEMDRAW_DISABLED:ITEMDRAW_DEFAULT);
	}

	// should NEVER happen
	if(menu.ItemCount == 0)
	{
		menu.AddItem("-1", "Nothing");
	}

	else if(menu.ItemCount <= 9)
	{
		menu.Pagination = MENU_NO_PAGINATION;
	}

	menu.ExitButton = true;
	menu.Display(client, MENU_TIME_FOREVER);
}

public int StyleMenu_Handler(Menu menu, MenuAction action, int param1, int param2)
{
	if(action == MenuAction_Select)
	{
		char info[16];
		menu.GetItem(param2, info, 16);

		int style = StringToInt(info);

		if(style == -1)
		{
			return 0;
		}

		ChangeClientStyle(param1, style, true);
	}

	else if(action == MenuAction_End)
	{
		delete menu;
	}

	return 0;
}

void OpenBonusMenu(int client)
{
	Menu menu = new Menu(OpenBonusMenu_Handler);
	menu.SetTitle("Select a bonus\n ");

	int lastbonus = Track_Bonus;

	for(int i = Track_Bonus; i <= Track_Bonus_Last; i++)
	{
		if(Shavit_ZoneExists(Zone_Start, i) && Shavit_ZoneExists(Zone_End, i))
		{
			char sItem[4];
			IntToString(i, sItem, 4);

			char sDisplay[16];
			FormatEx(sDisplay, 16, "Bonus %d", i);
			menu.AddItem(sItem, sDisplay);

			lastbonus = i;
		}
	}

	if(menu.ItemCount <= 1)
	{
		delete menu;
		RestartTimer(client, lastbonus);
	}
	else
	{
		menu.Display(client, -1);
	}
}

public int OpenBonusMenu_Handler(Menu menu, MenuAction action, int param1, int param2)
{
	if(action == MenuAction_Select)
	{
		char sInfo[4];
		menu.GetItem(param2, sInfo, 4);

		RestartTimer(param1, StringToInt(sInfo));
	}
	else if(action == MenuAction_End)
	{
		delete menu;
	}

	return 0;
}