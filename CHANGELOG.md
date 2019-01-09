# v0.4.0
- Databases splitted into multiple instances instead of 1. This is due to problems with concurrency in SQLite databases. If you would like to preserve your current DB values, make a copy of your DB and name them as below inside the `data` folder.
1) dbAlarm.db
2) dbCron.db
3) dbFile.db
4) dbMail.db
5) dbMqtt.db
6) dbOwntracks.db
7) dbPushbullet.db
8) dbRpi.db
9) dbRss.db
10) dbXiaomi.db
11) dbWeb.db