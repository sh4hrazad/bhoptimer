#define NEW_LIMIT_METHOD
#define BHOP_PUNISH_RATIO 0.4
#define BHOP_FRAMES 10

enum
{
	Invalid_Prehop,
	Invalid_Bhop,
	Invalid_Enterstart,
	Invalid_Noclip
}

static int gI_Bhop[MAXPLAYERS+1];
static int gI_TicksOnGround[MAXPLAYERS+1];

/* -- Sub functions -- */
void OnClientPutInServer_InitPrestrafe(int client)
{
	gI_Bhop[client] = 0;
	gI_TicksOnGround[client] = 0;
}

void OnUserCmdPre_PreStrafe(int client, int buttons)
{
	int flags = GetEntityFlags(client);

	// 不跳 not jumping
	if(flags & FL_ONGROUND == FL_ONGROUND)
	{
		if(gI_TicksOnGround[client]++ > BHOP_FRAMES)
		{
			gI_Bhop[client] = 0;
		}

		if ((buttons & IN_JUMP) > 0 && gI_TicksOnGround[client] == 1)
		{
			gI_TicksOnGround[client] = 0;
		}
	}
	else
	{
		gI_TicksOnGround[client] = 0;
	}

	if(Shavit_InsideZone(client, Zone_AutoBhop, -1))
	{
		gI_Bhop[client] = 0;
	}

	if(!Shavit_CanAutoBhopInTrack(client) && gCV_LimitBhop.IntValue != 0)
	{
		LimitInvalidSpeed(client, Invalid_Bhop);
	}

	if(GetEntityMoveType(client) == MOVETYPE_NOCLIP
		 && ((Shavit_GetTimerStatus(client) == Timer_Running
		 && Shavit_GetClientTime(client) != 0.0)
		 || Shavit_GetTimerStatus(client) == Timer_Stopped))
	{
		gB_NoclipOnStopped[client] = true;
	}
}

/* -- Public -- */
public void Player_Jump(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));

	gI_Bhop[client]++;
}

// limit those one that enter zone by outsiding zone
public Action Shavit_OnEnterZone(int client, int type, int track, int id, int entity, int data)
{
	if(Shavit_GetTimerStatus(client) == Timer_Running
		 && shavit_zones_entryzonespeedlimit.FloatValue > 0.0
		 && (type == Zone_Start || (Shavit_GetMapLimitspeed() && type == Zone_Stage)))
	{
		LimitInvalidSpeed(client, Invalid_Enterstart);
	}
}

public Action Shavit_OnLeaveZone(int client, int type, int track, int id, int entity, int data)
{
	if(Shavit_GetTimerStatus(client) == Timer_Running
		 && gCV_LimitPrestrafe.BoolValue
		 && (type == Zone_Start || (Shavit_GetMapLimitspeed() && type == Zone_Stage)))
	{
		LimitInvalidSpeed(client, Invalid_Noclip);
		LimitInvalidSpeed(client, Invalid_Prehop);
	}
}

/* -- Private -- */
static void LimitInvalidSpeed(int client, int type)
{
	if(GetEntityMoveType(client) == MOVETYPE_NOCLIP)
	{
		return;
	}

	float fSpeed[3];
	GetEntPropVector(client, Prop_Data, "m_vecAbsVelocity", fSpeed);
	float fSpeedXY = SquareRoot(Pow(fSpeed[0], 2.0) + Pow(fSpeed[1], 2.0));

	// they are on booster, dont limit them
	// 起点里面有加速板, 直接放个禁止起跳区域就行.

	// 全关卡限速
	// 开启: 所有关卡的限速规则都与 Track 起点相同
	// 关闭: 不限制 bhop 起步速度, 进入区域时不会限速
	
	// 起跳 starts jump
	if(type == Invalid_Prehop)
	{
		float fScale = 270.0 / fSpeedXY;

		if(fScale < 1.0 && gI_Bhop[client] >= 2)
		{
			DumbSetVelocity(client, fSpeed, fScale);

			Shavit_PrintToChat(client, "Prehop speed exceeded!");
		}

		return;
	}
	
	// 连跳 bunny hop
	if(type == Invalid_Bhop)
	{
		if(gI_Bhop[client] > gCV_LimitBhop.IntValue)
		{
			DumbSetVelocity(client, fSpeed, BHOP_PUNISH_RATIO);
			
			Shavit_PrintToChat(client, "Bhop limit exceeded! ({red}%d{white})", gCV_LimitBhop.IntValue);

			gI_Bhop[client] = 0;
		}
		
		return;
	}

	// 进起点 enter start
	if(type == Invalid_Enterstart)
	{
		if(fSpeedXY > shavit_zones_entryzonespeedlimit.FloatValue)
		{
			DumbSetVelocity(client, fSpeed, fSpeedXY <= 290 * 10 ? 0.1 : 0.0);
		}
		
		return;
	}

	// 起点开穿墙 noclip in start
	if(type == Invalid_Noclip)
	{
		if(gB_NoclipOnStopped[client])
		{
			Shavit_StopTimer(client);
			Shavit_PrintToChat(client, "你曾经使用过穿墙, 需要输入 !r 才能重启计时器.");
		}

		return;
	}
}

static void DumbSetVelocity(int client, float fSpeed[3], float scale)
{
	fSpeed[0] *= scale;
	fSpeed[1] *= scale;

#if defined NEW_LIMIT_METHOD
	TeleportEntity(client, NULL_VECTOR, NULL_VECTOR, fSpeed);
#else
	// Someone please let me know if any of these are unnecessary.
	SetEntPropVector(client, Prop_Data, "m_vecBaseVelocity", NULL_VECTOR);
	SetEntPropVector(client, Prop_Data, "m_vecVelocity", fSpeed);
	SetEntPropVector(client, Prop_Data, "m_vecAbsVelocity", fSpeed); // m_vecBaseVelocity+m_vecVelocity
#endif
}

#undef NEW_LIMIT_METHOD
#undef BHOP_PUNISH_RATIO
#undef BHOP_FRAMES