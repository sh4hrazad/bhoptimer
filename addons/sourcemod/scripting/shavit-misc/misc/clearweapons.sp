// ======[ EVENTS ]======

void Timer_ClearWeapons()
{
	if (gCV_NoWeaponDrops.BoolValue)
	{
		int ent = -1;

		while ((ent = FindEntityByClassname(ent, "weapon_*")) != -1)
		{
			if (GetEntPropEnt(ent, Prop_Send, "m_hOwnerEntity") == -1)
			{
				AcceptEntityInput(ent, "Kill");
			}
		}
	}
}

void OnClientPutInServer_HookWeaponDrop(int client)
{
	SDKHook(client, SDKHook_WeaponDrop, OnWeaponDrop);
}

public void OnWeaponDrop(int client, int entity)
{
	ClearWeapon(entity);
}

void OnClientDisconnect_ClearWeapons(int client)
{
	if(gCV_NoWeaponDrops.BoolValue)
	{
		if (IsClientInGame(client))
		{
			RemoveClientAllWeapons(client);
		}
	}
}



// ======[ PUBLIC ]======

void RemoveClientAllWeapons(int client)
{
	int weapon = -1;
	int max = GetEntPropArraySize(client, Prop_Send, "m_hMyWeapons");
	for (int i = 0; i < max; i++)
	{
		if ((weapon = GetEntPropEnt(client, Prop_Send, "m_hMyWeapons", i)) == -1)
		{
			continue;
		}

		if (RemovePlayerItem(client, weapon))
		{
			AcceptEntityInput(weapon, "Kill");
		}
	}
}


// ======[ PRIVATE ]======

static void ClearWeapon(int entity)
{
	if(gCV_NoWeaponDrops.BoolValue && IsValidEntity(entity))
	{
		AcceptEntityInput(entity, "Kill");
	}
}