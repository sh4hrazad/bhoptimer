stock int GetStageRecordAmount(int style, int stage)
{
	if(gA_StageLeaderboard[style][stage] == null)
	{
		return 0;
	}

	return gA_StageLeaderboard[style][stage].Length;
}

stock int GetStageRankForTime(int style, float time, int stage)
{
	int iRecords = GetStageRecordAmount(style, stage);

	if(time <= 0.0)
	{
		return 0;
	}
	else if(time <= gA_WRStageInfo[style][stage].fTime || iRecords <= 0)
	{
		return 1;
	}

	int i = 0;

	if (iRecords > 100)
	{
		int middle = iRecords / 2;

		stage_t stagepb;
		gA_StageLeaderboard[style][stage].GetArray(middle, stagepb, sizeof(stage_t));

		if (stagepb.fTime < time)
		{
			i = middle;
		}
		else
		{
			iRecords = middle;
		}
	}

	for (; i < iRecords; i++)
	{
		stage_t stagepb;
		gA_StageLeaderboard[style][stage].GetArray(i, stagepb, sizeof(stage_t));

		if (time <= stagepb.fTime)
		{
			return i + 1;
		}
	}

	return (iRecords + 1);
}