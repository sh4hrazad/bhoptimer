static Handle gH_Forwards_Start = null;
static Handle gH_Forwards_StartPre = null;
static Handle gH_Forwards_Stop = null;
static Handle gH_Forwards_StopPre = null;
static Handle gH_Forwards_FinishPre = null;
static Handle gH_Forwards_Finish = null;
static Handle gH_Forwards_OnRestartPre = null;
static Handle gH_Forwards_OnRestart = null;
static Handle gH_Forwards_OnEnd = null;
static Handle gH_Forwards_OnPause = null;
static Handle gH_Forwards_OnResume = null;
static Handle gH_Forwards_OnStyleChanged = null;
static Handle gH_Forwards_OnTrackChanged = null;
static Handle gH_Forwards_OnStyleConfigLoaded = null;
static Handle gH_Forwards_OnDatabaseLoaded = null;
static Handle gH_Forwards_OnChatConfigLoaded = null;
static Handle gH_Forwards_OnUserCmdPre = null;
static Handle gH_Forwards_OnTimerIncrement = null;
static Handle gH_Forwards_OnTimerIncrementPost = null;
static Handle gH_Forwards_OnTimescaleChanged = null;
static Handle gH_Forwards_OnTimeOffsetCalculated = null;
static Handle gH_Forwards_OnProcessMovement = null;
static Handle gH_Forwards_OnProcessMovementPost = null;
static Handle gH_Forwards_OnDeleteMapData = null;
static Handle gH_Forwards_OnCommandStyle = null;
static Handle gH_Forwards_OnUserDeleteData = null;
static Handle gH_Forwards_OnDeleteRestOfUserSuccess = null;
static Handle gH_Forwards_OnStageChanged = null;

void CreateForwards()
{
	gH_Forwards_Start = CreateGlobalForward("Shavit_OnStart", ET_Ignore, Param_Cell, Param_Cell);
	gH_Forwards_StartPre = CreateGlobalForward("Shavit_OnStartPre", ET_Event, Param_Cell, Param_Cell);
	gH_Forwards_Stop = CreateGlobalForward("Shavit_OnStop", ET_Event, Param_Cell, Param_Cell);
	gH_Forwards_StopPre = CreateGlobalForward("Shavit_OnStopPre", ET_Event, Param_Cell, Param_Cell);
	gH_Forwards_FinishPre = CreateGlobalForward("Shavit_OnFinishPre", ET_Hook, Param_Cell, Param_Array);
	gH_Forwards_Finish = CreateGlobalForward("Shavit_OnFinish", ET_Event, Param_Cell, Param_Cell, Param_Float, Param_Cell, Param_Cell, Param_Float, Param_Cell, Param_FloatByRef, Param_Float, Param_Float, Param_Cell);
	gH_Forwards_OnRestartPre = CreateGlobalForward("Shavit_OnRestartPre", ET_Event, Param_Cell, Param_Cell);
	gH_Forwards_OnRestart = CreateGlobalForward("Shavit_OnRestart", ET_Ignore, Param_Cell, Param_Cell);
	gH_Forwards_OnEnd = CreateGlobalForward("Shavit_OnEnd", ET_Event, Param_Cell, Param_Cell);
	gH_Forwards_OnPause = CreateGlobalForward("Shavit_OnPause", ET_Event, Param_Cell, Param_Cell);
	gH_Forwards_OnResume = CreateGlobalForward("Shavit_OnResume", ET_Event, Param_Cell, Param_Cell);
	gH_Forwards_OnStyleChanged = CreateGlobalForward("Shavit_OnStyleChanged", ET_Event, Param_Cell, Param_Cell, Param_Cell, Param_Cell, Param_Cell);
	gH_Forwards_OnTrackChanged = CreateGlobalForward("Shavit_OnTrackChanged", ET_Event, Param_Cell, Param_Cell, Param_Cell);
	gH_Forwards_OnStyleConfigLoaded = CreateGlobalForward("Shavit_OnStyleConfigLoaded", ET_Event, Param_Cell);
	gH_Forwards_OnDatabaseLoaded = CreateGlobalForward("Shavit_OnDatabaseLoaded", ET_Event);
	gH_Forwards_OnChatConfigLoaded = CreateGlobalForward("Shavit_OnChatConfigLoaded", ET_Event);
	gH_Forwards_OnUserCmdPre = CreateGlobalForward("Shavit_OnUserCmdPre", ET_Event, Param_Cell, Param_CellByRef, Param_CellByRef, Param_Array, Param_Array, Param_Cell, Param_Cell, Param_Cell, Param_Array, Param_Array);
	gH_Forwards_OnTimerIncrement = CreateGlobalForward("Shavit_OnTimeIncrement", ET_Event, Param_Cell, Param_Array, Param_CellByRef, Param_Array);
	gH_Forwards_OnTimerIncrementPost = CreateGlobalForward("Shavit_OnTimeIncrementPost", ET_Event, Param_Cell, Param_Cell, Param_Array);
	gH_Forwards_OnTimescaleChanged = CreateGlobalForward("Shavit_OnTimescaleChanged", ET_Event, Param_Cell, Param_Cell, Param_Cell);
	gH_Forwards_OnTimeOffsetCalculated = CreateGlobalForward("Shavit_OnTimeOffsetCalculated", ET_Event, Param_Cell, Param_Cell, Param_Cell, Param_Cell);
	gH_Forwards_OnProcessMovement = CreateGlobalForward("Shavit_OnProcessMovement", ET_Event, Param_Cell);
	gH_Forwards_OnProcessMovementPost = CreateGlobalForward("Shavit_OnProcessMovementPost", ET_Event, Param_Cell);
	gH_Forwards_OnDeleteMapData = CreateGlobalForward("Shavit_OnDeleteMapData", ET_Event, Param_Cell, Param_String);
	gH_Forwards_OnCommandStyle = CreateGlobalForward("Shavit_OnCommandStyle", ET_Event, Param_Cell, Param_Cell, Param_FloatByRef);
	gH_Forwards_OnUserDeleteData = CreateGlobalForward("Shavit_OnUserDeleteData", ET_Event, Param_Cell, Param_Cell);
	gH_Forwards_OnDeleteRestOfUserSuccess = CreateGlobalForward("Shavit_OnDeleteRestOfUserSuccess", ET_Event, Param_Cell, Param_Cell);
	gH_Forwards_OnStageChanged = CreateGlobalForward("Shavit_OnStageChanged", ET_Event, Param_Cell, Param_Cell, Param_Cell);
}

void Call_OnStart(int client, int track, Action &result)
{
	Call_StartForward(gH_Forwards_Start);
	Call_PushCell(client);
	Call_PushCell(track);
	Call_Finish(result);
}

void Call_OnStartPre(int client, int track, Action &result)
{
	Call_StartForward(gH_Forwards_StartPre);
	Call_PushCell(client);
	Call_PushCell(track);
	Call_Finish(result);
}

void Call_OnStop(int client, int track, bool &result)
{
	Call_StartForward(gH_Forwards_Stop);
	Call_PushCell(client);
	Call_PushCell(track);
	Call_Finish(result);
}

void Call_OnStopPre(int client, int track, bool &result)
{
	Call_StartForward(gH_Forwards_StopPre);
	Call_PushCell(client);
	Call_PushCell(track);
	Call_Finish(result);
}

void Call_OnFinishPre(int client, timer_snapshot_t snapshot, int snapshotSize, Action &result)
{
	Call_StartForward(gH_Forwards_FinishPre);
	Call_PushCell(client);
	Call_PushArrayEx(snapshot, snapshotSize, SM_PARAM_COPYBACK);
	Call_Finish(result);
}

void Call_OnFinish(Action result, int client, timer_snapshot_t snapshot, int timestamp)
{
	Call_StartForward(gH_Forwards_Finish);
	Call_PushCell(client);

	if(result == Plugin_Continue)
	{
		Call_PushCell(gA_Timers[client].bsStyle);
		Call_PushFloat(gA_Timers[client].fCurrentTime);
		Call_PushCell(gA_Timers[client].iJumps);
		Call_PushCell(gA_Timers[client].iStrafes);
		//gross
		Call_PushFloat((GetStyleSettingBool(gA_Timers[client].bsStyle, "sync"))? (gA_Timers[client].iGoodGains == 0)? 0.0:(gA_Timers[client].iGoodGains / float(gA_Timers[client].iTotalMeasures) * 100.0):-1.0);
		Call_PushCell(gA_Timers[client].iTimerTrack);
	}
	else
	{
		Call_PushCell(snapshot.bsStyle);
		Call_PushFloat(snapshot.fCurrentTime);
		Call_PushCell(snapshot.iJumps);
		Call_PushCell(snapshot.iStrafes);
		// gross
		Call_PushFloat((GetStyleSettingBool(snapshot.bsStyle, "sync"))? (snapshot.iGoodGains == 0)? 0.0:(snapshot.iGoodGains / float(snapshot.iTotalMeasures) * 100.0):-1.0);
		Call_PushCell(snapshot.iTimerTrack);
	}
	
	float oldtime = 0.0;
	Call_PushFloatRef(oldtime);

	if(result == Plugin_Continue)
	{
		Call_PushFloat(gA_Timers[client].fAvgVelocity);
		Call_PushFloat(gA_Timers[client].fMaxVelocity);
	}
	else
	{
		Call_PushFloat(snapshot.fAvgVelocity);
		Call_PushFloat(snapshot.fMaxVelocity);
	}

	Call_PushCell(timestamp);
	Call_Finish();
}

void Call_OnRestartPre(int client, int track, Action &result)
{
	Call_StartForward(gH_Forwards_OnRestartPre);
	Call_PushCell(client);
	Call_PushCell(track);
	Call_Finish(result);
}

void Call_OnRestart(int client, int track)
{
	Call_StartForward(gH_Forwards_OnRestart);
	Call_PushCell(client);
	Call_PushCell(track);
	Call_Finish();
}

void Call_OnEnd(int client, int track)
{
	Call_StartForward(gH_Forwards_OnEnd);
	Call_PushCell(client);
	Call_PushCell(track);
	Call_Finish();
}

void Call_OnPause(int client, int track)
{
	Call_StartForward(gH_Forwards_OnPause);
	Call_PushCell(client);
	Call_PushCell(track);
	Call_Finish();
}

void Call_OnResume(int client, int track)
{
	Call_StartForward(gH_Forwards_OnResume);
	Call_PushCell(client);
	Call_PushCell(track);
	Call_Finish();
}

void Call_OnStyleChanged(int client, int oldstyle, int newstyle, int track, bool manual)
{
	Call_StartForward(gH_Forwards_OnStyleChanged);
	Call_PushCell(client);
	Call_PushCell(oldstyle);
	Call_PushCell(newstyle);
	Call_PushCell(track);
	Call_PushCell(manual);
	Call_Finish();
}

void Call_OnTrackChanged(int client, int oldtrack, int newtrack)
{
	Call_StartForward(gH_Forwards_OnTrackChanged);
	Call_PushCell(client);
	Call_PushCell(oldtrack);
	Call_PushCell(newtrack);
	Call_Finish();

	if (oldtrack == Track_Main && oldtrack != newtrack)
	{
		Shavit_PrintToChat(client, "%T", "TrackChangeFromMain", client);
	}
}

void Call_OnStyleConfigLoaded(int styles)
{
	Call_StartForward(gH_Forwards_OnStyleConfigLoaded);
	Call_PushCell(styles);
	Call_Finish();
}

void Call_OnDatabaseLoaded()
{
	Call_StartForward(gH_Forwards_OnDatabaseLoaded);
	Call_Finish();
}

void Call_OnChatConfigLoaded()
{
	Call_StartForward(gH_Forwards_OnChatConfigLoaded);
	Call_Finish();
}

void Call_OnUserCmdPre(int client, int &buttons, int &impulse, float vel[3], float angles[3], TimerStatus status, int track, int style, int mouse[2], Action &result)
{
	Call_StartForward(gH_Forwards_OnUserCmdPre);
	Call_PushCell(client);
	Call_PushCellRef(buttons);
	Call_PushCellRef(impulse);
	Call_PushArrayEx(vel, 3, SM_PARAM_COPYBACK);
	Call_PushArrayEx(angles, 3, SM_PARAM_COPYBACK);
	Call_PushCell(status);
	Call_PushCell(track);
	Call_PushCell(style);
	Call_PushArrayEx(mouse, 2, SM_PARAM_COPYBACK);
	Call_Finish(result);
}

void Call_OnTimerIncrement(int client, timer_snapshot_t snapshot, int size, float &time)
{
	Call_StartForward(gH_Forwards_OnTimerIncrement);
	Call_PushCell(client);
	Call_PushArray(snapshot, size);
	Call_PushCellRef(time);
	Call_Finish();
}

void Call_OnTimerIncrementPost(int client, float time)
{
	Call_StartForward(gH_Forwards_OnTimerIncrementPost);
	Call_PushCell(client);
	Call_PushCell(time);
	Call_Finish();
}

void Call_OnTimescaleChanged(int client, float oldtimescale, float newtimescale)
{
	Call_StartForward(gH_Forwards_OnTimescaleChanged);
	Call_PushCell(client);
	Call_PushCell(oldtimescale);
	Call_PushCell(newtimescale);
	Call_Finish();
}

void Call_OnTimeOffsetCalculated(int client, int zonetype, float offset, float distance)
{
	Call_StartForward(gH_Forwards_OnTimeOffsetCalculated);
	Call_PushCell(client);
	Call_PushCell(zonetype);
	Call_PushCell(offset);
	Call_PushCell(distance);
	Call_Finish();
}

void Call_OnProcessMovement(int client)
{
	Call_StartForward(gH_Forwards_OnProcessMovement);
	Call_PushCell(client);
	Call_Finish();
}

void Call_OnProcessMovementPost(int client)
{
	Call_StartForward(gH_Forwards_OnProcessMovementPost);
	Call_PushCell(client);
	Call_Finish();
}

void Call_OnDeleteMapData(int client, const char[] map)
{
	Call_StartForward(gH_Forwards_OnDeleteMapData);
	Call_PushCell(client);
	Call_PushString(map);
	Call_Finish();
}

void Call_OnCommandStyle(int client, int style, float &time)
{
	Call_StartForward(gH_Forwards_OnCommandStyle);
	Call_PushCell(client);
	Call_PushCell(style);
	Call_PushFloatRef(time);
	Call_Finish();
}

void Call_OnUserDeleteData(int client, int steamID)
{
	Call_StartForward(gH_Forwards_OnUserDeleteData);
	Call_PushCell(client);
	Call_PushCell(steamID);
	Call_Finish();
}

void Call_OnDeleteRestOfUserSuccess(int client, int steamID)
{
	Call_StartForward(gH_Forwards_OnDeleteRestOfUserSuccess);
	Call_PushCell(client);
	Call_PushCell(steamID);
	Call_Finish();
}

void Call_OnStageChanged(int client, int oldstage, int newstage)
{
	Call_StartForward(gH_Forwards_OnStageChanged);
	Call_PushCell(client);
	Call_PushCell(oldstage);
	Call_PushCell(newstage);
	Call_Finish();
}