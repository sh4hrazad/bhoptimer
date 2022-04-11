stock void MakeAngleDiff(int client, float newAngle)
{
	gF_PreviousAngle[client] = gF_Angle[client];
	gF_Angle[client] = newAngle;
	gF_AngleDiff[client] = GetAngleDiff(newAngle, gF_PreviousAngle[client]);
}

stock void ResetPrestrafeDiff(int client)
{
	strcopy(gS_PreStrafeDiff[client], sizeof(gS_PreStrafeDiff[]), "None");
}

stock void FormatDiffPreStrafeSpeed(char[] buffer, float originSpeed, float wrSpeed)
{
	float diff = originSpeed - wrSpeed;

	if(wrSpeed <= 0.0)
	{
		strcopy(buffer, 64, "N/A");
	}
	else
	{
		if(diff > 0.0)
		{
			FormatEx(buffer, 64, "%t", "PrestrafeIncrease", RoundToFloor(diff));
		}
		else if(diff == 0.0)
		{
			FormatEx(buffer, 64, "%t", "PrestrafeNochange", RoundToFloor(diff));
		}
		else
		{
			FormatEx(buffer, 64, "%t", "PrestrafeDecrease", RoundToFloor(diff));
		}
	}
}