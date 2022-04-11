



// ======[ EVENTS ]======

void OnConfigsExecuted_Timelimit()
{
	if(!gCV_Enabled.BoolValue)
	{
		return;
	}

	if(gCV_Config.BoolValue)
	{
		if(mp_do_warmup_period != null)
		{
			mp_do_warmup_period.BoolValue = false;
		}

		if(mp_freezetime != null)
		{
			mp_freezetime.IntValue = 0;
		}

		if(mp_ignore_round_win_conditions != null)
		{
			mp_ignore_round_win_conditions.BoolValue = true;
		}
	}

	if(gCV_DynamicTimelimits.BoolValue)
	{
		StartCalculating();
	}
	
	else
	{
		SetLimit(RoundToNearest(gCV_DefaultLimit.FloatValue));
	}

	if(gCV_ForceMapEnd.BoolValue && gH_Timer == null)
	{
		gH_Timer = CreateTimer(1.0, Timer_PrintToChat, 0, TIMER_REPEAT);
	}
}

Action Timer_PrintToChat_Timelimit()
{
	if(!gCV_Enabled.BoolValue)
	{
		return Plugin_Continue;
	}

	int timelimit = 0;

	if(!GetMapTimeLimit(timelimit) || timelimit == 0)
	{
		return Plugin_Continue;
	}

	int timeleft = 0;
	GetMapTimeLeft(timeleft);

	if(timeleft <= -1 && timeleft >= -3)
	{
		Shavit_StopChatSound();
	}

	if (gCV_InstantMapChange.BoolValue && timeleft <= 5)
	{
		if (timeleft)
		{
			if (timeleft == 5)
			{
				Call_OnCountdownStart();
			}

			if (1 <= timeleft <= 3 && !gCV_Hide321CountDown.BoolValue)
			{
				Shavit_StopChatSound();
				Shavit_PrintToChatAll("%d..", timeleft);
			}

			if (timeleft == 1)
			{
				CreateTimer(0.9001, Timer_ChangeMap, 0, TIMER_FLAG_NO_MAPCHANGE);
			}
		}

		return Plugin_Continue;
	}

	switch(timeleft)
	{
		case 3600: Shavit_PrintToChatAll("%T", "Minutes", LANG_SERVER, "60");
		case 1800: Shavit_PrintToChatAll("%T", "Minutes", LANG_SERVER, "30");
		case 1200: Shavit_PrintToChatAll("%T", "Minutes", LANG_SERVER, "20");
		case 600: Shavit_PrintToChatAll("%T", "Minutes", LANG_SERVER, "10");
		case 300: Shavit_PrintToChatAll("%T", "Minutes", LANG_SERVER, "5");
		case 120: Shavit_PrintToChatAll("%T", "Minutes", LANG_SERVER, "2");
		case 60: Shavit_PrintToChatAll("%T", "Seconds", LANG_SERVER, "60");
		case 30: Shavit_PrintToChatAll("%T", "Seconds", LANG_SERVER, "30");
		case 15: Shavit_PrintToChatAll("%T", "Seconds", LANG_SERVER, "15");

		case 0: // case 0 is hit twice....
		{
			if (!gB_AlternateZeroPrint)
			{
				Call_OnCountdownStart();
			}

			Shavit_StopChatSound();
			Shavit_PrintToChatAll("%d..", gB_AlternateZeroPrint ? 4 : 5);
			gB_AlternateZeroPrint = !gB_AlternateZeroPrint;
		}
		case -1:
		{
			Shavit_PrintToChatAll("3..");
		}
		case -2:
		{
			Shavit_PrintToChatAll("2..");
			
			gB_BlockRoundEndEvent = true;
			// needs to be when timeleft is under 0 otherwise the round will restart and the map won't change
			CS_TerminateRound(0.0, CSRoundEnd_Draw, true);
		}
		case -3:
		{
			Shavit_PrintToChatAll("1..");
		}
	}

	return Plugin_Continue;
}