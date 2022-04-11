// ======[ EVENTS ]======

void HookSounds()
{
	AddNormalSoundHook(NormalSound);
}



// ======[ PUBLIC ]======

public Action NormalSound(int clients[MAXPLAYERS], int &numClients, char sample[PLATFORM_MAX_PATH], int &entity, int &channel, float &volume, int &level, int &pitch, int &flags, char soundEntry[PLATFORM_MAX_PATH], int &seed)
{
	if(!gCV_BhopSounds.BoolValue)
	{
		return Plugin_Continue;
	}

	if (IsValidClient(entity) && IsFakeClient(entity) && StrContains(sample, "footsteps/") != -1)
	{
		numClients = 0;

		if (gCV_BhopSounds.IntValue < 2)
		{
			// The server removes recipients that are in the PVS because CS:S generates the footsteps clientside.
			// UpdateStepSound clientside bails because of MOVETYPE_NOCLIP though.
			// So fuck it, add all the clients xd.
			// Alternatively and preferably you'd patch out the RemoveRecipientsByPVS call in PlayStepSound.
			for (int i = 1; i <= MaxClients; i++)
			{
				if (IsValidClient(i) && (!gB_Hide[i] || GetSpectatorTarget(i) == entity))
				{
					clients[numClients++] = i;
				}
			}
		}

		return Plugin_Changed;
	}

	if(StrContains(sample, "physics/") != -1 || StrContains(sample, "weapons/") != -1 || StrContains(sample, "player/") != -1 || StrContains(sample, "items/") != -1)
	{
		if(gCV_BhopSounds.IntValue == 2)
		{
			numClients = 0;
		}
		else
		{
			for(int i = 0; i < numClients; ++i)
			{
				if(!IsValidClient(clients[i]) || (clients[i] != entity && gB_Hide[clients[i]] && GetSpectatorTarget(clients[i]) != entity))
				{
					for (int j = i; j < numClients-1; j++)
					{
						clients[j] = clients[j+1];
					}
					
					numClients--;
					i--;
				}
			}
		}

		return Plugin_Changed;
	}
	
	return Plugin_Continue;
}
