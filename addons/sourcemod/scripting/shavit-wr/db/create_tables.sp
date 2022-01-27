/*
	Table creation and alteration.
*/



void DB_CreateTables()
{
	Transaction2 hTransaction = new Transaction2();

	if(gB_MySQL)
	{
		hTransaction.AddQuery(mysql_playertimes_create);
		hTransaction.AddQuery(mysql_wrs_min_create);
		hTransaction.AddQuery(mysql_wrs_create);
	}
	else
	{
		SetFailState("shavit-wr only support mysql database.");
		delete hTransaction;
		return;
	}

	gH_SQL.Execute(hTransaction, Trans_CreateTable_Success, Trans_CreateTable_Error, 0, DBPrio_High);
}

public void Trans_CreateTable_Success(Database db, any data, int numQueries, DBResultSet[] results, any[] queryData)
{
	gB_Connected = true;

	OnMapStart();
}

public void Trans_CreateTable_Error(Database db, any data, int numQueries, const char[] error, int failIndex, any[] queryData)
{
	LogError("shavit-wr SQL query %d/%d failed. Reason: %s", failIndex, numQueries, error);
}



// ======[ PRIVATE ]======

stock void DB_CreateTables_Deprecated()
{
	char sQuery[1024];
	Transaction2 hTransaction = new Transaction2();

	if(gB_MySQL)
	{
		FormatEx(sQuery, sizeof(sQuery),
			"CREATE TABLE IF NOT EXISTS `%splayertimes` (`id` INT NOT NULL AUTO_INCREMENT, `auth` INT, `map` VARCHAR(128), `time` FLOAT, `jumps` INT, `style` TINYINT, `date` INT, `strafes` INT, `sync` FLOAT, `points` FLOAT NOT NULL DEFAULT 0, `track` TINYINT NOT NULL DEFAULT 0, `perfs` FLOAT DEFAULT 0, `completions` SMALLINT DEFAULT 1, `exact_time_int` INT DEFAULT 0, `prestrafe` FLOAT DEFAULT 0, PRIMARY KEY (`id`), INDEX `map` (`map`, `style`, `track`, `time`), INDEX `auth` (`auth`, `date`, `points`), INDEX `time` (`time`), CONSTRAINT `%spt_auth` FOREIGN KEY (`auth`) REFERENCES `%susers` (`auth`) ON UPDATE CASCADE ON DELETE CASCADE) ENGINE=INNODB;",
			gS_MySQLPrefix, gS_MySQLPrefix, gS_MySQLPrefix);
	}
	else
	{
		FormatEx(sQuery, sizeof(sQuery),
			"CREATE TABLE IF NOT EXISTS `%splayertimes` (`id` INTEGER PRIMARY KEY, `auth` INT, `map` VARCHAR(128), `time` FLOAT, `jumps` INT, `style` TINYINT, `date` INT, `strafes` INT, `sync` FLOAT, `points` FLOAT NOT NULL DEFAULT 0, `track` TINYINT NOT NULL DEFAULT 0, `perfs` FLOAT DEFAULT 0, `completions` SMALLINT DEFAULT 1, `exact_time_int` INT DEFAULT 0, CONSTRAINT `%spt_auth` FOREIGN KEY (`auth`) REFERENCES `%susers` (`auth`) ON UPDATE CASCADE ON DELETE CASCADE);",
			gS_MySQLPrefix, gS_MySQLPrefix, gS_MySQLPrefix);
	}

	hTransaction.AddQuery(sQuery);

	FormatEx(sQuery, sizeof(sQuery),
		"DROP VIEW IF EXISTS %swrs_min;",
		gS_MySQLPrefix);
	hTransaction.AddQuery(sQuery);

	FormatEx(sQuery, sizeof(sQuery),
		"%s %swrs AS SELECT MIN(time) time, MIN(id) id, MIN(auth) auth, MIN(exact_time_int) exact_time_int, MIN(date) date, map, track, style FROM %splayertimes GROUP BY map, track, style;",
		gB_MySQL ? "CREATE OR REPLACE VIEW" : "CREATE VIEW IF NOT EXISTS",
		gS_MySQLPrefix, gS_MySQLPrefix, gS_MySQLPrefix);
	hTransaction.AddQuery(sQuery);

	gH_SQL.Execute(hTransaction, Trans_CreateTable_Success, Trans_CreateTable_Error, 0, DBPrio_High);
}