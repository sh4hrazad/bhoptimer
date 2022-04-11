void KickReplay(bot_info_t info)
{
	if (info.iEnt <= 0)
	{
		return;
	}

	if (info.iType == Replay_Dynamic && !info.bIgnoreLimit)
	{
		--gI_DynamicBots;
	}

	if (1 <= info.iEnt <= MaxClients)
	{
		KickClient(info.iEnt, "you just lost The Game");
	}

	CancelReplay(info, false);

	info.iEnt = -1;
	info.iType = -1;
}

void KickAllReplays()
{
	for (int i = 1; i <= MaxClients; i++)
	{
		if (gA_BotInfo[i].iEnt > 0)
		{
			KickReplay(gA_BotInfo[i]);
		}
	}

	gI_TrackBot = -1;
	gI_StageBot = -1;
}