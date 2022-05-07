/**
 * Include file for maps folder stocks
 *
 * Original plugin website: https://github.com/Ciallo-Ani/mytimer/tree/gokz-framework
 */

#if defined _shavit_mapsfolderstocks_included
	#endinput
#endif
#define _shavit_mapsfolderstocks_included

stock bool ReadMapsFolderHandler(const char path[PLATFORM_MAX_PATH], bool is_stringmap, Handle data, bool lowercase, bool display, bool iter_subfolders, bool use_valve_fs, char[][] exclude_prefixes, int exclude_count)
{
	bool first_iteration = StrEqual(path, "maps");
	DirectoryListing dir = OpenDirectory(path, use_valve_fs);

	if (dir == null)
	{
		return false;
	}

	char buffer[PLATFORM_MAX_PATH];
	FileType type;

	while (dir.GetNext(buffer, sizeof(buffer), type))
	{
		if (type == FileType_Directory)
		{
			if (buffer[0] == '.' && (buffer[1] == 0 || (buffer[1] == '.' && buffer[2] == 0)))
			{
				continue;
			}

			if (iter_subfolders)
			{
				char subfolder[PLATFORM_MAX_PATH];
				FormatEx(subfolder, sizeof(subfolder), "%s/%s", path, buffer);
				ReadMapsFolderHandler(subfolder, is_stringmap, data, lowercase, display, iter_subfolders, use_valve_fs, exclude_prefixes, exclude_count);
			}
		}
		else if (type == FileType_File)
		{
			int length = strlen(buffer);

			if (length < 5 || buffer[length-4] != '.') // a.bsp
			{
				continue;
			}

			if ((buffer[length-3] == 'b' && buffer[length-2] == 's' && buffer[length-1] == 'p') ||
			    (buffer[length-3] == 'u' && buffer[length-2] == 'g' && buffer[length-1] == 'c'))
			{
				buffer[length-4] = 0;

				if (lowercase)
				{
					LowercaseString(buffer);
				}

				bool skip = false;

				for (int i = 0; i < exclude_count; i++)
				{
					if (strncmp(buffer, exclude_prefixes[i], strlen(exclude_prefixes[i]), lowercase) == 0)
					{
						skip = true;
						break;
					}
				}

				if (skip)
				{
					continue;
				}

				if (!display && !first_iteration)
				{
					char temp[PLATFORM_MAX_PATH];
					int skip_this = 5; // strlen("maps/")
					FormatEx(temp, sizeof(temp), "%s/%s", path[skip_this], buffer);
					buffer = temp;
				}

				if (is_stringmap)
				{
					view_as<StringMap>(data).SetValue(buffer, false, false);
				}
				else
				{
					view_as<ArrayList>(data).PushString(buffer);
				}
			}
		}
	}

	delete dir;
	return true;
}

static char empty_excludes[][] = {""};

stock bool ReadMapsFolderStringMap(StringMap data, bool lowercase=true, bool display=false, bool iter_subfolders=true, bool use_valve_fs=true, char[][] exclude_prefixes=empty_excludes, int exclude_count=0)
{
	return ReadMapsFolderHandler("maps", true, data, lowercase, display, iter_subfolders, use_valve_fs, exclude_prefixes, exclude_count);
}

// don't forget to declare your ArrayList like below :)))
//// ArrayList maps = new ArrayList(ByteCountToCells(PLATFORM_MAX_PATH));
stock bool ReadMapsFolderArrayList(ArrayList data, bool lowercase=true, bool display=false, bool iter_subfolders=true, bool use_valve_fs=true, char[][] exclude_prefixes=empty_excludes, int exclude_count=0)
{
	return ReadMapsFolderHandler("maps", false, data, lowercase, display, iter_subfolders, use_valve_fs, exclude_prefixes, exclude_count);
}