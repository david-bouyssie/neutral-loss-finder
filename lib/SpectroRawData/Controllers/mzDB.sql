CREATE TABLE "scan"
(
 id INTEGER PRIMARY KEY AUTOINCREMENT ,
 number INTEGER ,
 cycle INTEGER ,
 time FLOAT ,
 msLevel INTEGER ,
 TIC FLOAT ,
 basePeak INTEGER ,
 precursor INTEGER
);

CREATE TABLE "peak"
(
 id INTEGER PRIMARY KEY AUTOINCREMENT ,
 moz FLOAT NOT NULL ,
 intensity FLOAT NOT NULL ,
 FWHM FLOAT ,
 SNR FLOAT ,
 isotopicPattern INTEGER ,
 scan INTEGER NOT NULL
);

CREATE TABLE "isotopic_pattern"
(
 id INTEGER PRIMARY KEY AUTOINCREMENT ,
 moz FLOAT NOT NULL ,
 intensity FLOAT NOT NULL ,
 charge INTEGER NOT NULL ,
 fit FLOAT ,
 bestPeak INTEGER NOT NULL ,
 scan INTEGER NOT NULL ,
 feature INTEGER
);

CREATE TABLE "feature"
(
 id INTEGER PRIMARY KEY AUTOINCREMENT ,
 area FLOAT NOT NULL ,
 firstScan INTEGER NOT NULL ,
 lastScan INTEGER NOT NULL ,
 apex INTEGER NOT NULL ,
 compound INTEGER
);

CREATE TABLE "compound"
(
 id INTEGER PRIMARY KEY AUTOINCREMENT ,
 mass FLOAT NOT NULL ,
 name VARCHAR ,
 formula VARCHAR ,
 comment VARCHAR
);







