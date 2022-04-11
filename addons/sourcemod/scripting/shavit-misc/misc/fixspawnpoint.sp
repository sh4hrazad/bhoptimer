// ======[ EVENTS ]======

void OnConfigsExecuted_FixSpawnPoints()
{
	if(gCV_CreateSpawnPoints.IntValue > 0)
	{
		int info_player_terrorist        = FindEntityByClassname(-1, "info_player_terrorist");
		int info_player_counterterrorist = FindEntityByClassname(-1, "info_player_counterterrorist");
		int info_player_teamspawn        = FindEntityByClassname(-1, "info_player_teamspawn");
		int info_player_start            = FindEntityByClassname(-1, "info_player_start");

		int iEntity =
			((info_player_terrorist != -1)        ? info_player_terrorist :
			((info_player_counterterrorist != -1) ? info_player_counterterrorist :
			((info_player_teamspawn != -1)        ? info_player_teamspawn :
			((info_player_start != -1)            ? info_player_start : -1))));

		if (iEntity != -1)
		{
			float fOrigin[3], fAngles[3];
			GetEntPropVector(iEntity, Prop_Send, "m_vecOrigin", fOrigin);
			GetEntPropVector(iEntity, Prop_Data, "m_angAbsRotation", fAngles);

			if (info_player_terrorist == -1)
			{
				CreateSpawnPoint(2, fOrigin, fAngles);
			}

			if (info_player_counterterrorist == -1)
			{
				CreateSpawnPoint(3, fOrigin, fAngles);
			}
		}
	}
}


// ======[ PRIVATE ]======

static void CreateSpawnPoint(int iTeam, float fOrigin[3], float fAngles[3])
{
	int iSpawnPoint = CreateEntityByName((iTeam == 2)? "info_player_terrorist":"info_player_counterterrorist");

	if (DispatchSpawn(iSpawnPoint))
	{
		TeleportEntity(iSpawnPoint, fOrigin, fAngles, NULL_VECTOR);
	}
}