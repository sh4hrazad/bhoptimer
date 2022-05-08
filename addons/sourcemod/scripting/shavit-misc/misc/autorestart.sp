static bool gB_AutoRestart[MAXPLAYERS + 1];
static Cookie gH_AutoRestartCookie = null;

/* -- Commands -- */

void RegisterCommands_AutoRestart()
{
	RegConsoleCmd("sm_autorestart", Command_AutoRestart, "Toggles auto restart if time is longer than PB");
}

public Action Command_AutoRestart(int client, int args)
{
	if(!IsValidClient(client))
	{
		return;
	}

	gB_AutoRestart[client] = !gB_AutoRestart[client];
	gH_AutoRestartCookie.Set(client, gB_AutoRestart[client] ? "1" : "0");

	Shavit_PrintToChat(client, "自动重开已%s{white}.", gB_AutoRestart[client] ? "{lightgreen}开启" : "{red}关闭");
}

/* -- Cookies -- */

void RegisterCookie_AutoRestart()
{
	gH_AutoRestartCookie = new Cookie("shavit_autorestart", "Auto restart settings", CookieAccess_Protected);
}

void OnClientCookiesCached_AutoRestart(int client)
{
	char sSetting[8];
	gH_AutoRestartCookie.Get(client, sSetting, 8);

	if(strlen(sSetting) == 0)
	{
		gH_AutoRestartCookie.Set(client, "0");
		gB_AutoRestart[client] = false;
	}
	else
	{
		gB_AutoRestart[client] = view_as<bool>(StringToInt(sSetting));
	}
}

/* -- Functions -- */

void OnUserCmdPre_AutoRestart(int client, int track, int style)
{
	if(!gB_AutoRestart[client])
	{
		return;
	}

	int stage = Shavit_GetCurrentStage(client);
	// 第一关既是tracktimer又是stagetimer
	bool bTrackTimer = !Shavit_IsStageTimer(client);

	stage_t stagePB;
	Shavit_GetStagePB(client, style, stage, stagePB);

	float trackPB = Shavit_GetClientPB(client, style, track);

	if(bTrackTimer ? trackPB == 0.0 : stagePB.fTime == 0.0)
	{
		return;
	}

	if(Shavit_GetClientTime(client) > (bTrackTimer ? trackPB : stagePB.fTime))
	{
		if(bTrackTimer)
		{
			if (track == Track_Main)
			{
				FakeClientCommand(client, "sm_r");
			}
			else
			{
				FakeClientCommand(client, "sm_b %d", track);
			}
		}
		else
		{
			FakeClientCommand(client, "sm_s %d", stage);
		}

		Shavit_PrintToChat(client, "你的时间已超过个人最佳, 已自动将你传送回起点. (输入 {lightgreen}!autorestart{white} 关闭该功能)");
	}
}

// 完成关卡自动回到原关卡起点
public void Shavit_OnFinishStage_Post(int client, int stage, int style, float time, float diff, int overwrite, int records, int rank, bool wrcp, float leavespeed)
{
	if(!gB_AutoRestart[client] || !Shavit_IsStageTimer(client))
	{
		return;
	}

	FakeClientCommand(client, "sm_s %d", stage);
}

// 失误自动回到 /setstart 设置的位置