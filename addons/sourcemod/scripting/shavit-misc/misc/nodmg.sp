// ======[ EVENTS ]======

void OnClientPutInServer_HookDamage(int client)
{
	SDKHook(client, SDKHook_OnTakeDamage, OnTakeDamage);
}

public Action OnTakeDamage(int victim, int& attacker)
{
	bool bBlockDamage;

	switch(gCV_GodMode.IntValue)
	{
		case 0:
		{
			bBlockDamage = false;
		}
		case 1:
		{
			// 0 - world/fall damage
			if(attacker == 0)
			{
				bBlockDamage = true;
			}
		}
		case 2:
		{
			if(IsValidClient(attacker))
			{
				bBlockDamage = true;
			}
		}
		default:
		{
			bBlockDamage = true;
		}
	}

	if (gB_Hide[victim] || bBlockDamage || IsFakeClient(victim))
	{
		ClearViewPunch(victim);

		for (int i = 1; i <= MaxClients; i++)
		{
			if (i != victim && IsValidClient(i) && GetSpectatorTarget(i) == victim)
			{
				ClearViewPunch(i);
			}
		}
	}

	return bBlockDamage ? Plugin_Handled : Plugin_Continue;
}



// ======[ PRIVATE ]======

void ClearViewPunch(int victim)
{
	if (1 <= victim <= MaxClients)
	{
		SetEntPropVector(victim, Prop_Send, "m_vecPunchAngle", NULL_VECTOR);
		SetEntPropVector(victim, Prop_Send, "m_vecPunchAngleVel", NULL_VECTOR);
	}
}