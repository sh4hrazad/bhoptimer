static bool gB_MenuMaplimitspeed[MAXPLAYERS+1];
static int gI_MenuTier[MAXPLAYERS+1];
static float gF_MenuMaxvelocity[MAXPLAYERS+1];



void SetMapSettings(int client)
{
	gI_MenuTier[client] = gI_Tier;
	gB_MenuMaplimitspeed[client] = gB_Maplimitspeed;
	gF_MenuMaxvelocity[client] = gF_Maxvelocity;

	Menu menu = new Menu(SetMapSettings_Handler);
	menu.SetTitle("地图设置\n");

	char sItem[32];
	FormatEx(sItem, sizeof(sItem), "Tier: %d", gI_MenuTier[client]);
	menu.AddItem("Tier", sItem);

	FormatEx(sItem, sizeof(sItem), "全关卡限速: %s", (gB_MenuMaplimitspeed[client]) ? "是" : "否");
	menu.AddItem("LimitStage", sItem);

	FormatEx(sItem, sizeof(sItem), "限速: %.2f", gF_MenuMaxvelocity[client]);
	menu.AddItem("Maxvel", sItem);

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
			SetMapSettings(param1);
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
		else
		{
			DB_SaveMapSettings(param1, gI_MenuTier[param1], gB_MenuMaplimitspeed[param1], gF_MenuMaxvelocity[param1]);
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

		if(num < 3500)
		{
			gI_MenuTier[param1] = num;
		}
		else
		{
			gF_MenuMaxvelocity[param1] = num * 1.0;
		}

		SetMapSettings(param1);
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