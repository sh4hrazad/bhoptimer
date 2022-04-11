void RemoveAllWeapons(int client)
{
	int weapon = -1, max = GetEntPropArraySize(client, Prop_Send, "m_hMyWeapons");
	for (int i = 0; i < max; i++)
	{
		if ((weapon = GetEntPropEnt(client, Prop_Send, "m_hMyWeapons", i)) == -1)
			continue;

		if (RemovePlayerItem(client, weapon))
		{
			AcceptEntityInput(weapon, "Kill");
		}
	}
}

void Frame_UpdateReplayClient(int serial)
{
	int client = GetClientFromSerial(serial);

	if (client > 0)
	{
		UpdateReplayClient(client);
	}
}

void UpdateReplayClient(int client)
{
	// Only run on fakeclients
	if (!gB_CanUpdateReplayClient || !gCV_Enabled.BoolValue || !IsValidClient(client) || !IsFakeClient(client))
	{
		return;
	}

	gF_Tickrate = (1.0 / GetTickInterval());

	SetEntProp(client, Prop_Data, "m_CollisionGroup", 2);
	SetEntityMoveType(client, MOVETYPE_NOCLIP);

	UpdateBotScoreboard(gA_BotInfo[client]);

	if(GetClientTeam(client) != gCV_DefaultTeam.IntValue)
	{
		CS_SwitchTeam(client, gCV_DefaultTeam.IntValue);
	}

	if(!IsPlayerAlive(client))
	{
		CS_RespawnPlayer(client);
	}

	int iFlags = GetEntityFlags(client);

	if((iFlags & FL_ATCONTROLS) == 0)
	{
		SetEntityFlags(client, (iFlags | FL_ATCONTROLS));
	}

	char sWeapon[32];
	gCV_BotWeapon.GetString(sWeapon, 32);

	if(strlen(sWeapon) > 0)
	{
		int iWeapon = GetEntPropEnt(client, Prop_Data, "m_hActiveWeapon");

		if(StrEqual(sWeapon, "none"))
		{
			RemoveAllWeapons(client);
		}
		else
		{
			char sClassname[32];

			if(iWeapon != -1 && IsValidEntity(iWeapon))
			{
				GetEntityClassname(iWeapon, sClassname, 32);

				bool same_thing = false;

				// special case for csgo stuff because the usp classname becomes weapon_hpk2000
				if (StrEqual(sWeapon, "weapon_usp_silencer"))
				{
					same_thing = (61 == GetEntProp(iWeapon, Prop_Send, "m_iItemDefinitionIndex"));
				}
				else if (StrEqual(sWeapon, "weapon_hpk2000"))
				{
					same_thing = (32 == GetEntProp(iWeapon, Prop_Send, "m_iItemDefinitionIndex"));
				}

				if (!same_thing && !StrEqual(sWeapon, sClassname))
				{
					RemoveAllWeapons(client);
					GivePlayerItem(client, sWeapon);
				}
			}
			else
			{
				GivePlayerItem(client, sWeapon);
			}
		}
	}
}