static Address gI_PatchAddress;
static int gI_PatchRestore[100];
static int gI_PatchRestoreBytes;


void UnlockMovement()
{
	if(!gCV_CSGOUnlockMovement.BoolValue)
	{
		return;
	}

	Handle hGameData = LoadGameConfigFile("shavit.games");

	if (hGameData == null)
	{
		SetFailState("Failed to load shavit gamedata");
	}

	Address iAddr = GameConfGetAddress(hGameData, "WalkMoveMaxSpeed");
	if (iAddr == Address_Null)
	{
		SetFailState("Can't find WalkMoveMaxSpeed address.");
	}

	int iOffset = GameConfGetOffset(hGameData, "CappingOffset");
	if (iOffset == -1)
	{
		SetFailState("Can't find CappingOffset in gamedata.");
	}

	iAddr += view_as<Address>(iOffset);
	gI_PatchAddress = iAddr;

	if ((gI_PatchRestoreBytes = GameConfGetOffset(hGameData, "PatchBytes")) == -1)
	{
		SetFailState("Can't find PatchBytes in gamedata.");
	}

	for (int i = 0; i < gI_PatchRestoreBytes; i++)
	{
		gI_PatchRestore[i] = LoadFromAddress(iAddr, NumberType_Int8);
		StoreToAddress(iAddr++, 0x90, NumberType_Int8);
	}

	delete hGameData;
}

void LockMovement()
{
	if(gI_PatchAddress != Address_Null)
	{
		for(int i = 0; i < gI_PatchRestoreBytes; i++)
		{
			StoreToAddress(gI_PatchAddress + view_as<Address>(i), gI_PatchRestore[i], NumberType_Int8);
		}
	}
}