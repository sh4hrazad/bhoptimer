void ShowChatRanksMenu(int client, int item)
{
	Menu menu = new Menu(MenuHandler_ChatRanks);
	menu.SetTitle("%T\n ", "SelectChatRank", client);

	char sDisplay[MAXLENGTH_DISPLAY];
	FormatEx(sDisplay, MAXLENGTH_DISPLAY, "%T\n ", "AutoAssign", client);
	menu.AddItem("-2", sDisplay, (gI_ChatSelection[client] == -2)? ITEMDRAW_DISABLED:ITEMDRAW_DEFAULT);

	if(HasCustomChat(client))
	{
		FormatEx(sDisplay, MAXLENGTH_DISPLAY, "%T\n ", "CustomChat", client);
		menu.AddItem("-1", sDisplay, (gI_ChatSelection[client] == -1)? ITEMDRAW_DISABLED:ITEMDRAW_DEFAULT);
	}

	int iLength = gA_ChatRanks.Length;

	for(int i = 0; i < iLength; i++)
	{
		if(!HasRankAccess(client, i))
		{
			continue;
		}

		chatranks_cache_t cache;
		gA_ChatRanks.GetArray(i, cache, sizeof(chatranks_cache_t));

		char sMenuDisplay[MAXLENGTH_DISPLAY];
		strcopy(sMenuDisplay, MAXLENGTH_DISPLAY, cache.sDisplay);
		ReplaceString(sMenuDisplay, MAXLENGTH_DISPLAY, "<n>", "\n");
		StrCat(sMenuDisplay, MAXLENGTH_DISPLAY, "\n "); // to add spacing between each entry

		char sInfo[8];
		IntToString(i, sInfo, 8);

		menu.AddItem(sInfo, sMenuDisplay, (gI_ChatSelection[client] == i)? ITEMDRAW_DISABLED:ITEMDRAW_DEFAULT);
	}

	menu.ExitButton = true;
	menu.DisplayAt(client, item, MENU_TIME_FOREVER);
}

public int MenuHandler_ChatRanks(Menu menu, MenuAction action, int param1, int param2)
{
	if(action == MenuAction_Select)
	{
		char sInfo[8];
		menu.GetItem(param2, sInfo, 8);

		int iChoice = StringToInt(sInfo);

		gI_ChatSelection[param1] = iChoice;
		gH_ChatCookie.Set(param1, sInfo);

		Shavit_PrintToChat(param1, "%T", "ChatUpdated", param1);
		ShowChatRanksMenu(param1, GetMenuSelectionPosition());
	}

	else if(action == MenuAction_End)
	{
		delete menu;
	}

	return 0;
}