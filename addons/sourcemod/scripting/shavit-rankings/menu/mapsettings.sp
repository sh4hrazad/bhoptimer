static bool gB_MenuMaplimitspeed[MAXPLAYERS+1];
static int gI_MenuTier[MAXPLAYERS+1];
static float gF_MenuMaxvelocity[MAXPLAYERS+1];
static int gI_MenuAllowBhop[MAXPLAYERS+1];



void SetMapSettings(int client, bool reset = true)
{
	if(reset)
	{
		gI_MenuTier[client] = gI_Tier;
		gB_MenuMaplimitspeed[client] = gB_Maplimitspeed;
		gF_MenuMaxvelocity[client] = gF_Maxvelocity;
		gI_MenuAllowBhop[client] = gI_AllowBhop;
	}
	
	Menu menu = new Menu(SetMapSettings_Handler);
	menu.SetTitle("地图设置\n");

	char sItem[32];
	FormatEx(sItem, sizeof(sItem), "修改难度: Tier %d", gI_MenuTier[client]);
	menu.AddItem("Tier", sItem);

	FormatEx(sItem, sizeof(sItem), "全关卡限速: %s", (gB_MenuMaplimitspeed[client]) ? "是" : "否");
	menu.AddItem("LimitStage", sItem);

	FormatEx(sItem, sizeof(sItem), "修改限速: %.2f", gF_MenuMaxvelocity[client]);
	menu.AddItem("Maxvel", sItem);

	FormatEx(sItem, sizeof(sItem), "选择开启自动跳的 Track");
	menu.AddItem("AllowBhop", sItem);

	menu.AddItem("SaveSettings", "保存设置");

	menu.Display(client, -1);
}

public int SetMapSettings_Handler(Menu menu, MenuAction action, int param1, int param2)
{
	if(action == MenuAction_Select)
	{
		char sInfo[32];
		menu.GetItem(param2, sInfo, sizeof(sInfo));

		if(StrEqual(sInfo, "Tier"))
		{
			Menu submenu = new Menu(SetMapSettings2_Handler);
			submenu.SetTitle("设置地图Tier\n");
			for(int i = 1; i <= 8; i++)
			{
				char sSubInfo[4];
				IntToString(i, sSubInfo, sizeof(sSubInfo));

				char sItem[8];
				FormatEx(sItem, sizeof(sItem), "Tier: %d", i);

				submenu.AddItem(sSubInfo, sItem);
			}

			submenu.ExitBackButton = true;
			submenu.Display(param1, -1);
		}
		else if(StrEqual(sInfo, "LimitStage"))
		{
			gB_MenuMaplimitspeed[param1] = !gB_MenuMaplimitspeed[param1];
			SetMapSettings(param1, false);
		}
		else if(StrEqual(sInfo, "Maxvel"))
		{
			Menu submenu = new Menu(SetMapSettings2_Handler);
			submenu.SetTitle("设置地图限速");

			submenu.AddItem("3500", "3500.00");
			submenu.AddItem("5000", "5000.00");
			submenu.AddItem("10000", "10000.00");

			submenu.ExitBackButton = true;
			submenu.Display(param1, -1);
		}
		else if(StrEqual(sInfo, "AllowBhop"))
		{
			OpenBhopSettingsMenu(param1);
		}
		else
		{
			DB_SaveMapSettings(param1, gI_MenuTier[param1], gB_MenuMaplimitspeed[param1], gF_MenuMaxvelocity[param1], gI_MenuAllowBhop[param1]);
		}
	}

	else if(action == MenuAction_End)
	{
		delete menu;
	}

	return 0;
}

public int SetMapSettings2_Handler(Menu menu, MenuAction action, int param1, int param2)
{
	if(action == MenuAction_Select)
	{
		char sInfo[16];
		menu.GetItem(param2, sInfo, sizeof(sInfo));

		int num = StringToInt(sInfo);

		if(num < 3500) // settier
		{
			gI_MenuTier[param1] = num;
		}
		else // set maxvel
		{
			gF_MenuMaxvelocity[param1] = num * 1.0;
		}

		SetMapSettings(param1, false);
	}
	else if(action == MenuAction_Cancel)
	{
		SetMapSettings(param1);
	}
	else if(action == MenuAction_End)
	{
		delete menu;
	}

	return 0;
}

void OpenBhopSettingsMenu(int client, int item = 0)
{
	Menu menu = new Menu(SetBhopSettings_Handler);
	menu.SetTitle("请勾选允许全关自动跳的 Track:");

	char sTrackName[16];
	char sInfo[4];
	char sItem[24];

	for(int i = Track_Main; i <= Track_Bonus_Last; i++)
	{
		if(Shavit_ZoneExists(Zone_Start, i) && Shavit_ZoneExists(Zone_End, i)) // invalid track
		{
			GetTrackName(client, i, sTrackName, sizeof(sTrackName));
			IntToString(i, sInfo, sizeof(sInfo));

			FormatEx(sItem, sizeof(sItem), "[%s] %s",
				(gI_MenuAllowBhop[client] & (1 << i) == 0) ? "√" : " ", sTrackName);

			menu.AddItem(sInfo, sItem);
		}
	}

	if(menu.ItemCount == 0)
	{
		menu.AddItem("", "请先设置 Track 后再设置此项.", ITEMDRAW_DISABLED);
	}

	menu.DisplayAt(client, item, MENU_TIME_FOREVER);
	menu.ExitButton = true;
}

public int SetBhopSettings_Handler(Menu menu, MenuAction action, int param1, int param2)
{
	if(action == MenuAction_Select)
	{
		char sInfo[16];
		menu.GetItem(param2, sInfo, sizeof(sInfo));

		int iTrack = StringToInt(sInfo);
		gI_MenuAllowBhop[param1] ^= (1 << iTrack);

		OpenBhopSettingsMenu(param1, GetMenuSelectionPosition());
	}
	else if(action == MenuAction_Cancel)
	{
		SetMapSettings(param1, false);
	}
	else if(action == MenuAction_End)
	{
		delete menu;
	}

	return 0;
}