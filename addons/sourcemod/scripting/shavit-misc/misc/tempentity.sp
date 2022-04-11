static int gI_LastShot[MAXPLAYERS+1];


// ======[ EVENTS ]======

void HookTEs()
{
	AddTempEntHook("EffectDispatch", EffectDispatch);
	AddTempEntHook("World Decal", WorldDecal);
	AddTempEntHook("Shotgun Shot", Shotgun_Shot);
}

public Action Shotgun_Shot(const char[] te_name, const int[] Players, int numClients, float delay)
{
	int client = (TE_ReadNum("m_iPlayer") + 1);

	if(!(1 <= client <= MaxClients) || !IsClientInGame(client))
	{
		return Plugin_Continue;
	}

	int ticks = GetGameTickCount();

	if(gI_LastShot[client] == ticks)
	{
		return Plugin_Continue;
	}

	gI_LastShot[client] = ticks;

	int clients[MAXPLAYERS+1];
	int count = 0;

	for(int i = 0; i < numClients; i++)
	{
		int x = Players[i];

		if (!IsClientInGame(x) || x == client)
		{
			continue;
		}

		if (!gB_Hide[x] || GetSpectatorTarget(x) == client)
		{
			clients[count++] = x;
		}
	}

	if(numClients == count)
	{
		return Plugin_Continue;
	}

	TE_Start(te_name);

	float temp[3];
	TE_ReadVector("m_vecOrigin", temp);
	TE_WriteVector("m_vecOrigin", temp);

	TE_WriteFloat("m_vecAngles[0]", TE_ReadFloat("m_vecAngles[0]"));
	TE_WriteFloat("m_vecAngles[1]", TE_ReadFloat("m_vecAngles[1]"));
	TE_WriteNum("m_iMode", TE_ReadNum("m_iMode"));
	TE_WriteNum("m_iSeed", TE_ReadNum("m_iSeed"));
	TE_WriteNum("m_iPlayer", (client - 1));

	TE_WriteNum("m_iWeaponID", TE_ReadNum("m_iWeaponID"));
	TE_WriteFloat("m_fInaccuracy", TE_ReadFloat("m_fInaccuracy"));
	TE_WriteFloat("m_fSpread", TE_ReadFloat("m_fSpread"));

	TE_Send(clients, count, delay);

	return Plugin_Stop;
}

public Action EffectDispatch(const char[] te_name, const int[] Players, int numClients, float delay)
{
	if(!gCV_NoBlood.BoolValue)
	{
		return Plugin_Continue;
	}

	int iEffectIndex = TE_ReadNum("m_iEffectName");
	int nHitBox = TE_ReadNum("m_nHitBox");

	char sEffectName[32];
	GetEffectName(iEffectIndex, sEffectName, 32);

	if(StrEqual(sEffectName, "csblood"))
	{
		return Plugin_Handled;
	}

	if(StrEqual(sEffectName, "ParticleEffect"))
	{
		char sParticleEffectName[32];
		GetParticleEffectName(nHitBox, sParticleEffectName, 32);

		if(StrEqual(sParticleEffectName, "impact_helmet_headshot") || StrEqual(sParticleEffectName, "impact_physics_dust"))
		{
			return Plugin_Handled;
		}
	}

	return Plugin_Continue;
}

public Action WorldDecal(const char[] te_name, const int[] Players, int numClients, float delay)
{
	if(!gCV_NoBlood.BoolValue)
	{
		return Plugin_Continue;
	}

	float vecOrigin[3];
	TE_ReadVector("m_vecOrigin", vecOrigin);

	int nIndex = TE_ReadNum("m_nIndex");

	char sDecalName[32];
	GetDecalName(nIndex, sDecalName, 32);

	if(StrContains(sDecalName, "decals/blood") == 0 && StrContains(sDecalName, "_subrect") != -1)
	{
		return Plugin_Handled;
	}

	return Plugin_Continue;
}



// ======[ PRIVATE ]======

static int GetParticleEffectName(int index, char[] sEffectName, int maxlen)
{
	static int table = INVALID_STRING_TABLE;

	if(table == INVALID_STRING_TABLE)
	{
		table = FindStringTable("ParticleEffectNames");
	}

	return ReadStringTable(table, index, sEffectName, maxlen);
}

static int GetEffectName(int index, char[] sEffectName, int maxlen)
{
	static int table = INVALID_STRING_TABLE;

	if(table == INVALID_STRING_TABLE)
	{
		table = FindStringTable("EffectDispatch");
	}

	return ReadStringTable(table, index, sEffectName, maxlen);
}

static int GetDecalName(int index, char[] sDecalName, int maxlen)
{
	static int table = INVALID_STRING_TABLE;

	if(table == INVALID_STRING_TABLE)
	{
		table = FindStringTable("decalprecache");
	}

	return ReadStringTable(table, index, sDecalName, maxlen);
}