static DynamicHook gH_AcceptInput; // used for hooking player_speedmod's AcceptInput
static DynamicHook gH_HookTeleport; // used for hooking native game teleport function
static Handle gH_PhysicsCheckForEntityUntouch;

enum struct PlayerHook
{
	int iHookedIndex;
	int iPlayerFlags;
	bool bHooked;

	void Add(int client)
	{
		gH_HookTeleport.HookEntity(Hook_Pre, client, Detour_OnTeleport);
		gH_HookTeleport.HookEntity(Hook_Post, client, Detour_OnTeleport_Post);

		this.bHooked = true;
		this.iHookedIndex = client;
	}

	void Remove()
	{
		this.bHooked = false;
		this.iHookedIndex = 0;
	}

	void AddFlag(int flags)
	{
		CHANGE_FLAGS(this.iPlayerFlags, this.iPlayerFlags | flags);
	}

	// Delay two frames to remove a flag, this is usually used in fastcall
	void RemoveFlag(int flagsToRemove)
	{
		DataPack dp = new DataPack();
		dp.WriteCell(flagsToRemove);
		dp.WriteCell(this.iHookedIndex);

		RequestFrame(Frame_RemoveFlag, dp);
	}

	// No delay, no handle create and delete, more save and faster
	void RemoveFlagEx(int flagsToRemove)
	{
		CHANGE_FLAGS(this.iPlayerFlags, this.iPlayerFlags & ~flagsToRemove);
	}

	int GetFlags()
	{
		return this.iPlayerFlags;
	}
}

PlayerHook gA_HookedPlayer[MAXPLAYERS+1];

void LoadDHooks()
{
	GameData gamedataConf = new GameData("shavit.games");

	if(gamedataConf == null)
	{
		SetFailState("Failed to load shavit gamedata");
		delete gamedataConf;
	}

	StartPrepSDKCall(SDKCall_Static);
	if(!PrepSDKCall_SetFromConf(gamedataConf, SDKConf_Signature, "CreateInterface"))
	{
		SetFailState("Failed to get CreateInterface");
	}
	PrepSDKCall_AddParameter(SDKType_String, SDKPass_Pointer);
	PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Pointer, VDECODE_FLAG_ALLOWNULL);
	PrepSDKCall_SetReturnInfo(SDKType_PlainOldData, SDKPass_Plain);
	Handle CreateInterface = EndPrepSDKCall();

	if(CreateInterface == null)
	{
		SetFailState("Unable to prepare SDKCall for CreateInterface");
	}

	char interfaceName[64];

	// ProcessMovement
	if(!GameConfGetKeyValue(gamedataConf, "IGameMovement", interfaceName, sizeof(interfaceName)))
	{
		SetFailState("Failed to get IGameMovement interface name");
		delete gamedataConf;
	}

	Address IGameMovement = SDKCall(CreateInterface, interfaceName, 0);

	if(!IGameMovement)
	{
		SetFailState("Failed to get IGameMovement pointer");
	}

	int offset = GameConfGetOffset(gamedataConf, "ProcessMovement");
	if(offset == -1)
	{
		SetFailState("Failed to get ProcessMovement offset");
	}

	Handle processMovement = DHookCreate(offset, HookType_Raw, ReturnType_Void, ThisPointer_Ignore, DHook_ProcessMovement);
	DHookAddParam(processMovement, HookParamType_CBaseEntity);
	DHookAddParam(processMovement, HookParamType_ObjectPtr);
	DHookRaw(processMovement, false, IGameMovement);

	Handle processMovementPost = DHookCreate(offset, HookType_Raw, ReturnType_Void, ThisPointer_Ignore, DHook_ProcessMovementPost);
	DHookAddParam(processMovementPost, HookParamType_CBaseEntity);
	DHookAddParam(processMovementPost, HookParamType_ObjectPtr);
	DHookRaw(processMovementPost, true, IGameMovement);

	StartPrepSDKCall(SDKCall_Entity);
	if(!PrepSDKCall_SetFromConf(gamedataConf, SDKConf_Signature, "PhysicsCheckForEntityUntouch"))
	{
		SetFailState("Failed to get PhysicsCheckForEntityUntouch");
	}
	gH_PhysicsCheckForEntityUntouch = EndPrepSDKCall();

	delete CreateInterface;
	delete gamedataConf;

	GameData AcceptInputGameData = new GameData("sdktools.games/game.cstrike");

	// Stolen from dhooks-test.sp
	offset = AcceptInputGameData.GetOffset("AcceptInput");
	delete AcceptInputGameData;

	if(offset != -1)
	{
		gH_AcceptInput = new DynamicHook(offset, HookType_Entity, ReturnType_Bool, ThisPointer_CBaseEntity);
		gH_AcceptInput.AddParam(HookParamType_CharPtr);
		gH_AcceptInput.AddParam(HookParamType_CBaseEntity);
		gH_AcceptInput.AddParam(HookParamType_CBaseEntity);
		gH_AcceptInput.AddParam(HookParamType_Object, 20, DHookPass_ByVal|DHookPass_ODTOR|DHookPass_OCTOR|DHookPass_OASSIGNOP); //variant_t is a union of 12 (float[3]) plus two int type params 12 + 8 = 20
		gH_AcceptInput.AddParam(HookParamType_Int);
	}
	else
	{
		SetFailState("Couldn't get the offset for \"AcceptInput\" - make sure your gamedata is updated!");
	}


	GameData TeleportGameData = new GameData("sdktools.games");

	offset = TeleportGameData.GetOffset("Teleport");
	delete TeleportGameData;

	if(offset != -1)
	{
		gH_HookTeleport = new DynamicHook(offset, HookType_Entity, ReturnType_Void, ThisPointer_CBaseEntity);
		gH_HookTeleport.AddParam(HookParamType_VectorPtr);
		gH_HookTeleport.AddParam(HookParamType_ObjectPtr);
		gH_HookTeleport.AddParam(HookParamType_VectorPtr);
	}
	else
	{
		SetFailState("Couldn't get the offset for \"Teleport\" - make sure your gamedata is updated!");
	}
}

public void OnEntityCreated(int entity, const char[] classname)
{
	if (StrEqual(classname, "player_speedmod"))
	{
		gH_AcceptInput.HookEntity(Hook_Post, entity, DHook_AcceptInput_player_speedmod_Post);
	}
}

// bool CBaseEntity::AcceptInput(char  const*, CBaseEntity*, CBaseEntity*, variant_t, int)
public MRESReturn DHook_AcceptInput_player_speedmod_Post(int pThis, DHookReturn hReturn, DHookParam hParams)
{
	char buf[128];
	hParams.GetString(1, buf, sizeof(buf));

	if (!StrEqual(buf, "ModifySpeed") || hParams.IsNull(2))
	{
		return MRES_Ignored;
	}

	int activator = hParams.Get(2);

	if (!IsValidClient(activator, true))
	{
		return MRES_Ignored;
	}

	float speed;

	int variant_type = hParams.GetObjectVar(4, 16, ObjectValueType_Int);

	if (variant_type == 2 /* FIELD_STRING */)
	{
		hParams.GetObjectVarString(4, 0, ObjectValueType_String, buf, sizeof(buf));
		speed = StringToFloat(buf);
	}
	else // should be FIELD_FLOAT but don't check who cares
	{
		speed = hParams.GetObjectVar(4, 0, ObjectValueType_Float);
	}

	gA_Timers[activator].fplayer_speedmod = speed;
	UpdateLaggedMovement(activator, true);

	return MRES_Ignored;
}

public MRESReturn Detour_OnTeleport(int pThis, DHookReturn hReturn, DHookParam hParams)
{
	gA_HookedPlayer[pThis].AddFlag(STATUS_ONTELEPORT);

	return MRES_Ignored;
}

public MRESReturn Detour_OnTeleport_Post(int pThis, DHookReturn hReturn, DHookParam hParams)
{
	gA_HookedPlayer[pThis].RemoveFlag(STATUS_ONTELEPORT);

	return MRES_Ignored;
}

public MRESReturn DHook_ProcessMovement(Handle hParams)
{
	int client = DHookGetParam(hParams, 1);

	// Causes client to do zone touching in movement instead of server frames.
	// From https://github.com/rumourA/End-Touch-Fix
	if(GetCheckUntouch(client))
	{
		SDKCall(gH_PhysicsCheckForEntityUntouch, client);
	}

	Call_OnProcessMovement(client);

	if (IsFakeClient(client) || !IsPlayerAlive(client))
	{
		SetEntPropFloat(client, Prop_Data, "m_flLaggedMovementValue", 1.0); // otherwise you get slow spec noclip
		return MRES_Ignored;
	}

	return MRES_Ignored;
}

public MRESReturn DHook_ProcessMovementPost(Handle hParams)
{
	int client = DHookGetParam(hParams, 1);

	Call_OnProcessMovementPost(client);

	if (gA_Timers[client].bClientPaused || !gA_Timers[client].bTimerEnabled)
	{
		return MRES_Ignored;
	}

	float interval = GetTickInterval();
	float time = interval * gA_Timers[client].fTimescale;
	float timeOrig = time;

	gA_Timers[client].iZoneIncrement++;

	timer_snapshot_t snapshot;
	BuildSnapshot(client, snapshot);

	Call_OnTimerIncrement(client, snapshot, sizeof(timer_snapshot_t), time);

	if (time == timeOrig)
	{
		gA_Timers[client].fTimescaledTicks += gA_Timers[client].fTimescale;
	}
	else
	{
		gA_Timers[client].fTimescaledTicks += time / interval;
	}

	gA_Timers[client].fCurrentTime = interval * gA_Timers[client].fTimescaledTicks;

	Call_OnTimerIncrementPost(client, time);

	return MRES_Ignored;
}

static bool GetCheckUntouch(int client)
{
	int flags = GetEntProp(client, Prop_Data, "m_iEFlags");
	return (flags & EFL_CHECK_UNTOUCH) != 0;
}