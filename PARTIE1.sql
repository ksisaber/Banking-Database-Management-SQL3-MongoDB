#B
#2
CREATE TABLESPACE SQL3_TBS
  DATAFILE 'sql3_tbs.dbf'
  SIZE 100M
  AUTOEXTEND ON
  NEXT 10M
  MAXSIZE UNLIMITED;

CREATE TEMPORARY TABLESPACE SQL3_TempTBS
  TEMPFILE 'sql3_temp_tbs.dbf'
  SIZE 50M
  AUTOEXTEND ON
  NEXT 5M
  MAXSIZE UNLIMITED;
#3
CREATE USER SQL3 IDENTIFIED BY 0666949364;

#4
GRANT ALL PRIVILEGES TO SQL3;

#C
#5 Types
CREATE OR REPLACE TYPE T_Sucursalle AS OBJECT (
  NumSucc INTEGER,
  nomSucc VARCHAR(100),
  adresseSucc VARCHAR(100),
  region VARCHAR(15)
  );
/

CREATE OR REPLACE TYPE T_Agence AS OBJECT (
  NumAgence INTEGER,
  nomAgence VARCHAR(100),
  adresseAgence VARCHAR(100),
  categorie VARCHAR(15),
  succursale REF T_Sucursalle
  );
/

CREATE OR REPLACE TYPE T_CLIENT AS OBJECT (
  NumClient INTEGER,
  NomClient VARCHAR(100),
  Typeclient VARCHAR(20),
  AdresseClient VARCHAR(100),
  NumTel INTEGER,
  Email VARCHAR(50)
  );
/


CREATE OR REPLACE TYPE T_Compte AS OBJECT (
  NumCompte INTEGER,
  dateOuverture DATE,
  etatCompte VARCHAR(10),
  Solde REAL
  client INTEGER, 
  agence INTEGER
  );
/

CREATE OR REPLACE TYPE T_Pret AS OBJECT (
  numPret INTEGER,
  montantPret REAL,
  dateEffet DATE,
  duree INTEGER,
  typePret VARCHAR(10),
  tauxInteret REAL,
  montantEcheance REAL,
  comptenum INTEGER
  );
/

CREATE OR REPLACE TYPE T_Operation AS OBJECT (
  numOperation INTEGER,
  natureOp VARCHAR(10),
  montantOp REAL,
  dateOp DATE,
  observation VARCHAR(150)
  comptenum INTEGER
  );
/

CREATE OR REPLACE TYPE T_ref_Compte_Client AS TABLE OF REF T_Compte ;
/

CREATE OR REPLACE TYPE T_ref_Pret_Compte AS TABLE OF REF T_Pret ;
/

CREATE OR REPLACE TYPE T_ref_Operation_Compte AS TABLE OF REF T_Operation;
/

CREATE OR REPLACE TYPE T_ref_Agence_Sucursalle AS TABLE OF REF T_Agence ;
/

CREATE OR REPLACE TYPE T_ref_Compte_Agence AS TABLE OF REF T_Compte ; 
/


ALTER TYPE T_Sucursalle ADD ATTRIBUTE Agences T_ref_Agence_Sucursalle CASCADE;
/

ALTER TYPE T_Agence ADD ATTRIBUTE Comptes T_ref_Compte_Agence CASCADE ;
/

ALTER TYPE T_CLIENT ADD ATTRIBUTE  CompteClient T_ref_Compte_Client CASCADE ;
/

ALTER TYPE T_Compte ADD ATTRIBUTE OperationCompte T_ref_Operation_Compte CASCADE ;
/

ALTER TYPE T_Compte ADD ATTRIBUTE PretCompte T_ref_Pret_Compte ;
/


ALTER TYPE T_Compte ADD ATTRIBUTE agence REF T_Agence CASCADE ;
/

ALTER TYPE T_Operation ADD ATTRIBUTE compte ref T_Compte CASCADE ;
/

ALTER TYPE T_Pret ADD ATTRIBUTE compte REF T_Compte CASCADE ;
/

ALTER TYPE T_Compte ADD ATTRIBUTE client REF T_Client CASCADE;
/ 


#6 méthodes
#a
CREATE OR REPLACE TYPE BODY T_Agence AS 
  MEMBER FUNCTION nombre_prets RETURN NUMBER IS
    nombre_prets NUMBER;
  BEGIN
    SELECT COUNT(*) INTO nombre_prets 
    FROM Pret
    WHERE DEREF(DEREF(compte).agence).numAgence = SELF.numAgence;
    
    RETURN nombre_prets;
  END;
END;
/


ALTER TYPE T_Sucursalle ADD MEMBER FUNCTION nombre_agences_principales RETURN NUMBER CASCADE ; 
#b
CREATE OR REPLACE TYPE BODY T_Sucursalle AS 
MEMBER FUNCTION nombre_agences_principales RETURN NUMBER IS
    nombre_agences NUMBER;
BEGIN
    SELECT COUNT(*) INTO nombre_agences 
    FROM Agence
    WHERE categorie = 'Principale' AND DEREF(succursale).numSucc = SELF.numSucc;
    
    RETURN nombre_agences;
END;
END;
/



ALTER TYPE ADD STATIC FUNCTION MONTANT_GLOBAL_PRETS_AGENCE(numAgence IN NUMBER) RETURN NUMBER CASCADE ;
#c
CREATE OR REPLACE TYPE BODY T_Agence AS
    STATIC FUNCTION MONTANT_GLOBAL_PRETS_AGENCE(numAgence IN NUMBER) RETURN NUMBER IS
        montant_total NUMBER;
    BEGIN
        SELECT SUM(montantPret)
        INTO montant_total
        FROM Pret p
        WHERE DEREF(p.compte).agence.numAgence = numAgence
        AND p.dateEffet BETWEEN TO_DATE('01-01-2020', 'DD-MM-YYYY') AND TO_DATE('01-01-2024', 'DD-MM-YYYY');

        RETURN montant_total;
    END;
END;
/


#d
CREATE OR REPLACE TYPE BODY T_Agence AS
    STATIC FUNCTION agences_secondaires_avec_ANSEJ RETURN SYS_REFCURSOR IS
        agences_cursor SYS_REFCURSOR;
    BEGIN
        OPEN agences_cursor FOR
            SELECT DEREF(A.succursale).numSucc AS numSuccursale, A.numAgence AS numAgenceSec
            FROM Agence A
            WHERE DEREF(A.succursale).typeSuccursale = 'Secondaire'
            AND EXISTS (
                SELECT 1
                FROM Pret p
                WHERE DEREF(DEREF(p.compte).agence).numAgence = a.numAgence
                AND p.typePret = 'ANSEJ'
            );
        RETURN agences_cursor;
    END agences_secondaires_avec_ANSEJ;
END;
/

--7 Création des tables

CREATE TABLE Succursale OF T_Sucursalle (
    PRIMARY KEY (NumSucc),
    CONSTRAINT CHK_Region CHECK (region IN ('Nord', 'Sud', 'Est', 'Ouest')))
    NESTED TABLE Agence Store AS SuccursaleAgence;


CREATE TABLE Agence OF T_Agence (
    PRIMARY KEY (NumAgence),
    CONSTRAINT CHK_Categorie CHECK (categorie IN ('Principale', 'Secondaire')),
    FOREIGN KEY (succursale) REFERENCES Succursale)
    NESTED TABLE Compte STORE AS AgenceCompte;


CREATE TABLE Client OF T_CLIENT (
    PRIMARY KEY (NumClient),
    CHECK (TypeClient IN ('Particulier', 'Entreprise')))
    NESTED TABLE CompteClient STORE AS ClientCompte ;


CREATE TABLE Compte OF T_Compte (
    PRIMARY KEY (NumCompte),
    CONSTRAINT CHK_EtatCompte CHECK (etatCompte IN ('Actif', 'Bloqué')),
    FOREIGN KEY (client) REFERENCES Client ,
    FOREIGN KEY (agence) REFERENCES Agence )
    NESTED TABLE OperationCompte store AS CompteOper,
    NESTED TABLE PretCompte store AS ComptePret;


CREATE TABLE Pret OF T_Pret (
    PRIMARY KEY (numPret),
    CONSTRAINT CHK_TypePret CHECK (typePret IN ('Véhicule', 'Immobilier', 'ANSEJ', 'ANJEM')),
    FOREIGN KEY (compte) REFERENCES Compte 
);

CREATE TABLE Operation OF T_Operation (
    PRIMARY KEY (numOperation),
    FOREIGN KEY (compte) REFERENCES Compte
);




D#Insertion
#succursale
-- Insérer 6 tuples dans la table Succursale
INSERT INTO Succursale VALUES (001, 'Succursale 1', 'Adresse 1', 'Nord', NULL);
INSERT INTO Succursale VALUES (002, 'Succursale 2', 'Adresse 2', 'Sud', NULL);
INSERT INTO Succursale VALUES (003, 'Succursale 3', 'Adresse 3', 'Est', NULL);
INSERT INTO Succursale VALUES (004, 'Succursale 4', 'Adresse 4', 'Ouest', NULL);
INSERT INTO Succursale VALUES (005, 'Succursale 5', 'Adresse 5', 'Sud', NULL);
INSERT INTO Succursale VALUES (006, 'Succursale 6', 'Adresse 6', 'Est', NULL);


#Agence
INSERT INTO Agence VALUES (101, 'Agence 1', 'Adresse 1', 'Principale', (SELECT REF(S) FROM Succursale S WHERE S.NumSucc = 001), NULL);
INSERT INTO Agence VALUES (102, 'Agence 2', 'Adresse 2', 'Secondaire', (SELECT REF(S) FROM Succursale S WHERE S.NumSucc = 001), NULL);
INSERT INTO Agence VALUES (103, 'Agence 3', 'Adresse 3', 'Principale', (SELECT REF(S) FROM Succursale S WHERE S.NumSucc = 001), NULL);
INSERT INTO Agence VALUES (104, 'Agence 4', 'Adresse 4', 'Principale', (SELECT REF(S) FROM Succursale S WHERE S.NumSucc = 001), NULL);
INSERT INTO Agence VALUES (105, 'Agence 5', 'Adresse 5', 'Secondaire', (SELECT REF(S) FROM Succursale S WHERE S.NumSucc = 001), NULL);
INSERT INTO Agence VALUES (106, 'Agence 6', 'Adresse 6', 'Principale', (SELECT REF(S) FROM Succursale S WHERE S.NumSucc = 002), NULL);
INSERT INTO Agence VALUES (107, 'Agence 7', 'Adresse 7', 'Secondaire', (SELECT REF(S) FROM Succursale S WHERE S.NumSucc = 002), NULL);
INSERT INTO Agence VALUES (108, 'Agence 8', 'Adresse 8', 'Secondaire', (SELECT REF(S) FROM Succursale S WHERE S.NumSucc = 002), NULL);
INSERT INTO Agence VALUES (109, 'Agence 9', 'Adresse 9', 'Principale', (SELECT REF(S) FROM Succursale S WHERE S.NumSucc = 002), NULL);
INSERT INTO Agence VALUES (110, 'Agence 10', 'Adresse 10', 'Secondaire', (SELECT REF(S) FROM Succursale S WHERE S.NumSucc = 003), NULL);
INSERT INTO Agence VALUES (111, 'Agence 11', 'Adresse 11', 'Principale', (SELECT REF(S) FROM Succursale S WHERE S.NumSucc = 003), NULL);
INSERT INTO Agence VALUES (112, 'Agence 12', 'Adresse 12', 'Secondaire', (SELECT REF(S) FROM Succursale S WHERE S.NumSucc = 003), NULL);
INSERT INTO Agence VALUES (113, 'Agence 13', 'Adresse 13', 'Principale', (SELECT REF(S) FROM Succursale S WHERE S.NumSucc = 003), NULL);
INSERT INTO Agence VALUES (114, 'Agence 14', 'Adresse 14', 'Secondaire', (SELECT REF(S) FROM Succursale S WHERE S.NumSucc = 004), NULL);
INSERT INTO Agence VALUES (115, 'Agence 15', 'Adresse 15', 'Secondaire', (SELECT REF(S) FROM Succursale S WHERE S.NumSucc = 004), NULL);
INSERT INTO Agence VALUES (116, 'Agence 16', 'Adresse 16', 'Principale', (SELECT REF(S) FROM Succursale S WHERE S.NumSucc = 004), NULL);
INSERT INTO Agence VALUES (117, 'Agence 17', 'Adresse 17', 'Secondaire', (SELECT REF(S) FROM Succursale S WHERE S.NumSucc = 004), NULL);
INSERT INTO Agence VALUES (118, 'Agence 18', 'Adresse 18', 'Principale', (SELECT REF(S) FROM Succursale S WHERE S.NumSucc = 005), NULL);
INSERT INTO Agence VALUES (119, 'Agence 19', 'Adresse 18', 'Principale', (SELECT REF(S) FROM Succursale S WHERE S.NumSucc = 005), NULL);
INSERT INTO Agence VALUES (120, 'Agence 20', 'Adresse 18', 'Principale', (SELECT REF(S) FROM Succursale S WHERE S.NumSucc = 005), NULL);
INSERT INTO Agence VALUES (121, 'Agence 21', 'Adresse 18', 'Secondaire', (SELECT REF(S) FROM Succursale S WHERE S.NumSucc = 005), NULL);
INSERT INTO Agence VALUES (122, 'Agence 22', 'Adresse 18', 'Secondaire', (SELECT REF(S) FROM Succursale S WHERE S.NumSucc = 006), NULL);
INSERT INTO Agence VALUES (123, 'Agence 23', 'Adresse 18', 'Secondaire', (SELECT REF(S) FROM Succursale S WHERE S.NumSucc = 006), NULL);
INSERT INTO Agence VALUES (124, 'Agence 24', 'Adresse 18', 'Principale', (SELECT REF(S) FROM Succursale S WHERE S.NumSucc = 006), NULL);
INSERT INTO Agence VALUES (125, 'Agence 25', 'Adresse 18', 'Principale', (SELECT REF(S) FROM Succursale S WHERE S.NumSucc = 006), NULL);


--Tableau Agence

UPDATE Succursale 
SET Agence = (CAST(MULTISET (SELECT REF(a) FROM Agence a WHERE DEREF(a.succursale).numSucc = '001') 
  AS T_ref_Agence_Sucursalle)) 
WHERE NumSucc = '001';

UPDATE Succursale 
SET Agence = (CAST(MULTISET (SELECT REF(a) FROM Agence a WHERE DEREF(a.succursale).numSucc = '002') 
  AS T_ref_Agence_Sucursalle)) 
WHERE NumSucc = '002';

UPDATE Succursale 
SET Agence = (CAST(MULTISET (SELECT REF(a) FROM Agence a WHERE DEREF(a.succursale).numSucc = '003') 
  AS T_ref_Agence_Sucursalle)) 
WHERE NumSucc = '003';

UPDATE Succursale 
SET Agence = (CAST(MULTISET (SELECT REF(a) FROM Agence a WHERE DEREF(a.succursale).numSucc = '004') 
  AS T_ref_Agence_Sucursalle)) 
WHERE NumSucc = '004';


UPDATE Succursale 
SET Agence = (CAST(MULTISET (SELECT REF(a) FROM Agence a WHERE DEREF(a.succursale).numSucc = '005') 
  AS T_ref_Agence_Sucursalle)) 
WHERE NumSucc = '005';

UPDATE Succursale 
SET Agence = (CAST(MULTISET (SELECT REF(a) FROM Agence a WHERE DEREF(a.succursale).numSucc = '006') 
  AS T_ref_Agence_Sucursalle)) 
WHERE NumSucc = '006';

--CLients
INSERT INTO Client VALUES (00001, 'Client 1', 'Entreprise', 'Adresse 1', 5678901234, 'client1@gmail.com', NULL);
INSERT INTO Client VALUES (00002, 'Client 2', 'Entreprise', 'Adresse 2', 2345678901, 'client2@gmail.com', NULL);
INSERT INTO Client VALUES (00003, 'Client 3', 'Particulier', 'Adresse 3', 3456789012, 'client3@gmail.com', NULL);
INSERT INTO Client VALUES (00004, 'Client 4', 'Particulier', 'Adresse 4', 4567890123, 'client4@gmail.com', NULL);
INSERT INTO Client VALUES (00005, 'Client 5', 'Entreprise', 'Adresse 5', 5678901234, 'client5@gmail.com', NULL);
INSERT INTO Client VALUES (00006, 'Client 6', 'Particulier', 'Adresse 6', 6789012345, 'client6@gmail.com', NULL);
INSERT INTO Client VALUES (00007, 'Client 7', 'Particulier', 'Adresse 7', 7890123456, 'client7@gmail.com', NULL);
INSERT INTO Client VALUES (00008, 'Client 8', 'Entreprise', 'Adresse 8', 8901234567, 'client8@gmail.com', NULL);
INSERT INTO Client VALUES (00009, 'Client 9', 'Particulier', 'Adresse 9', 9012345678, 'client9@gmail.com', NULL);
INSERT INTO Client VALUES (00010, 'Client 10', 'Entreprise', 'Adresse 10', 0123456789, 'client10@gmail.com', NULL);
INSERT INTO Client VALUES (00011, 'Client 11', 'Entreprise', 'Adresse 11', 1234567890, 'client11@gmail.com', NULL);
INSERT INTO Client VALUES (00012, 'Client 12', 'Particulier', 'Adresse 12', 2345678901, 'client12@gmail.com', NULL);
INSERT INTO Client VALUES (00013, 'Client 13', 'Particulier', 'Adresse 13', 3456789012, 'client13@gmail.com', NULL);
INSERT INTO Client VALUES (00014, 'Client 14', 'Entreprise', 'Adresse 14', 4567890123, 'client14@gmail.com', NULL);
INSERT INTO Client VALUES (00015, 'Client 15', 'Particulier', 'Adresse 15', 5678901234, 'client15@gmail.com', NULL);
INSERT INTO Client VALUES (00016, 'Client 16', 'Particulier', 'Adresse 16', 6789012345, 'client16@gmail.com', NULL);
INSERT INTO Client VALUES (00017, 'Client 17', 'Entreprise', 'Adresse 17', 7890123456, 'client17@gmail.com', NULL);
INSERT INTO Client VALUES (00018, 'Client 18', 'Particulier', 'Adresse 18', 8901234567, 'client18@gmail.com', NULL);
INSERT INTO Client VALUES (00019, 'Client 19', 'Entreprise', 'Adresse 19', 9012345678, 'client19@gmail.com', NULL);
INSERT INTO Client VALUES (00020, 'Client 20', 'Particulier', 'Adresse 20', 0123456789, 'client20@gmail.com', NULL);
INSERT INTO Client VALUES (00021, 'Client 21', 'Particulier', 'Adresse 21', 1234567890, 'client21@gmail.com', NULL);
INSERT INTO Client VALUES (00022, 'Client 22', 'Entreprise', 'Adresse 22', 2345678901, 'client22@gmail.com', NULL);
INSERT INTO Client VALUES (00023, 'Client 23', 'Particulier', 'Adresse 23', 3456789012, 'client23@gmail.com', NULL);
INSERT INTO Client VALUES (00024, 'Client 24', 'Entreprise', 'Adresse 24', 4567890123, 'client24@gmail.com', NULL);
INSERT INTO Client VALUES (00025, 'Client 25', 'Particulier', 'Adresse 25', 5678901234, 'client25@gmail.com', NULL);
INSERT INTO Client VALUES (00026, 'Client 26', 'Entreprise', 'Adresse 26', 6789012345, 'client26@gmail.com', NULL);
INSERT INTO Client VALUES (00027, 'Client 27', 'Particulier', 'Adresse 27', 7890123456, 'client27@gmail.com', NULL);
INSERT INTO Client VALUES (00028, 'Client 28', 'Entreprise', 'Adresse 28', 8901234567, 'client28@gmail.com', NULL);
INSERT INTO Client VALUES (00029, 'Client 29', 'Particulier', 'Adresse 29', 9012345678, 'client29@gmail.com', NULL);
INSERT INTO Client VALUES (00030, 'Client 30', 'Entreprise', 'Adresse 30', 0123456789, 'client30@gmail.com', NULL);
INSERT INTO Client VALUES (00031, 'Client 31', 'Particulier', 'Adresse 31', 1234567890, 'client31@gmail.com', NULL);
INSERT INTO Client VALUES (00032, 'Client 32', 'Entreprise', 'Adresse 32', 2345678901, 'client32@gmail.com', NULL);
INSERT INTO Client VALUES (00033, 'Client 33', 'Particulier', 'Adresse 33', 3456789012, 'client33@gmail.com', NULL);
INSERT INTO Client VALUES (00034, 'Client 34', 'Entreprise', 'Adresse 34', 4567890123, 'client34@gmail.com', NULL);
INSERT INTO Client VALUES (00035, 'Client 35', 'Particulier', 'Adresse 35', 5678901234, 'client35@gmail.com', NULL);
INSERT INTO Client VALUES (00036, 'Client 36', 'Entreprise', 'Adresse 36', 6789012345, 'client36@gmail.com', NULL);
INSERT INTO Client VALUES (00037, 'Client 37', 'Particulier', 'Adresse 37', 7890123456, 'client37@gmail.com', NULL);
INSERT INTO Client VALUES (00038, 'Client 38', 'Entreprise', 'Adresse 38', 8901234567, 'client38@gmail.com', NULL);
INSERT INTO Client VALUES (00039, 'Client 39', 'Particulier', 'Adresse 39', 9012345678, 'client39@gmail.com', NULL);
INSERT INTO Client VALUES (00040, 'Client 40', 'Entreprise', 'Adresse 40', 0123456789, 'client40@gmail.com', NULL);
INSERT INTO Client VALUES (00041, 'Client 41', 'Particulier', 'Adresse 41', 1234567890, 'client41@gmail.com', NULL);
INSERT INTO Client VALUES (00042, 'Client 42', 'Entreprise', 'Adresse 42', 2345678901, 'client42@gmail.com', NULL);
INSERT INTO Client VALUES (00043, 'Client 43', 'Particulier', 'Adresse 43', 3456789012, 'client43@gmail.com', NULL);
INSERT INTO Client VALUES (00044, 'Client 44', 'Entreprise', 'Adresse 44', 4567890123, 'client44@gmail.com', NULL);
INSERT INTO Client VALUES (00045, 'Client 45', 'Particulier', 'Adresse 45', 5678901234, 'client45@gmail.com', NULL);
INSERT INTO Client VALUES (00046, 'Client 46', 'Entreprise', 'Adresse 46', 6789012345, 'client46@gmail.com', NULL);
INSERT INTO Client VALUES (00047, 'Client 47', 'Particulier', 'Adresse 47', 7890123456, 'client47@gmail.com', NULL);
INSERT INTO Client VALUES (00048, 'Client 48', 'Entreprise', 'Adresse 48', 8901234567, 'client48@gmail.com', NULL);
INSERT INTO Client VALUES (00049, 'Client 49', 'Particulier', 'Adresse 49', 9012345678, 'client49@gmail.com', NULL);
INSERT INTO Client VALUES (00050, 'Client 50', 'Entreprise', 'Adresse 50', 0123456789, 'client50@gmail.com', NULL);
INSERT INTO Client VALUES (00051, 'Client 51', 'Particulier', 'Adresse 51', 1234567890, 'client51@gmail.com', NULL);
INSERT INTO Client VALUES (00052, 'Client 52', 'Entreprise', 'Adresse 52', 2345678901, 'client52@gmail.com', NULL);
INSERT INTO Client VALUES (00053, 'Client 53', 'Particulier', 'Adresse 53', 3456789012, 'client53@gmail.com', NULL);
INSERT INTO Client VALUES (00054, 'Client 54', 'Entreprise', 'Adresse 54', 4567890123, 'client54@gmail.com', NULL);
INSERT INTO Client VALUES (00055, 'Client 55', 'Particulier', 'Adresse 55', 5678901234, 'client55@gmail.com', NULL);
INSERT INTO Client VALUES (00056, 'Client 56', 'Entreprise', 'Adresse 56', 6789012345, 'client56@gmail.com', NULL);
INSERT INTO Client VALUES (00057, 'Client 57', 'Particulier', 'Adresse 57', 7890123456, 'client57@gmail.com', NULL);
INSERT INTO Client VALUES (00058, 'Client 58', 'Entreprise', 'Adresse 58', 8901234567, 'client58@gmail.com', NULL);
INSERT INTO Client VALUES (00059, 'Client 59', 'Particulier', 'Adresse 59', 9012345678, 'client59@gmail.com', NULL);
INSERT INTO Client VALUES (00060, 'Client 60', 'Entreprise', 'Adresse 60', 0123456789, 'client60@gmail.com', NULL);
INSERT INTO Client VALUES (00061, 'Client 61', 'Particulier', 'Adresse 61', 1234567890, 'client61@gmail.com', NULL);
INSERT INTO Client VALUES (00062, 'Client 62', 'Entreprise', 'Adresse 62', 2345678901, 'client62@gmail.com', NULL);
INSERT INTO Client VALUES (00063, 'Client 63', 'Particulier', 'Adresse 63', 3456789012, 'client63@gmail.com', NULL);
INSERT INTO Client VALUES (00064, 'Client 64', 'Entreprise', 'Adresse 64', 4567890123, 'client64@gmail.com', NULL);
INSERT INTO Client VALUES (00065, 'Client 65', 'Particulier', 'Adresse 65', 5678901234, 'client65@gmail.com', NULL);
INSERT INTO Client VALUES (00066, 'Client 66', 'Entreprise', 'Adresse 66', 6789012345, 'client66@gmail.com', NULL);
INSERT INTO Client VALUES (00067, 'Client 67', 'Particulier', 'Adresse 67', 7890123456, 'client67@gmail.com', NULL);
INSERT INTO Client VALUES (00068, 'Client 68', 'Entreprise', 'Adresse 68', 8901234567, 'client68@gmail.com', NULL);
INSERT INTO Client VALUES (00069, 'Client 69', 'Particulier', 'Adresse 69', 9012345678, 'client69@gmail.com', NULL);
INSERT INTO Client VALUES (00070, 'Client 70', 'Entreprise', 'Adresse 70', 0123456789, 'client70@gmail.com', NULL);
INSERT INTO Client VALUES (00071, 'Client 71', 'Particulier', 'Adresse 71', 1234567890, 'client71@gmail.com', NULL);
INSERT INTO Client VALUES (00072, 'Client 72', 'Entreprise', 'Adresse 72', 2345678901, 'client72@gmail.com', NULL);
INSERT INTO Client VALUES (00073, 'Client 73', 'Particulier', 'Adresse 73', 3456789012, 'client73@gmail.com', NULL);
INSERT INTO Client VALUES (00074, 'Client 74', 'Entreprise', 'Adresse 74', 4567890123, 'client74@gmail.com', NULL);
INSERT INTO Client VALUES (00075, 'Client 75', 'Particulier', 'Adresse 75', 5678901234, 'client75@gmail.com', NULL);
INSERT INTO Client VALUES (00076, 'Client 76', 'Entreprise', 'Adresse 76', 6789012345, 'client76@gmail.com', NULL);
INSERT INTO Client VALUES (00077, 'Client 77', 'Particulier', 'Adresse 77', 7890123456, 'client77@gmail.com', NULL);
INSERT INTO Client VALUES (00078, 'Client 78', 'Entreprise', 'Adresse 78', 8901234567, 'client78@gmail.com', NULL);
INSERT INTO Client VALUES (00079, 'Client 79', 'Particulier', 'Adresse 79', 9012345678, 'client79@gmail.com', NULL);
INSERT INTO Client VALUES (00080, 'Client 80', 'Entreprise', 'Adresse 80', 0123456789, 'client80@gmail.com', NULL);
INSERT INTO Client VALUES (00081, 'Client 81', 'Particulier', 'Adresse 81', 1234567890, 'client81@gmail.com', NULL);
INSERT INTO Client VALUES (00082, 'Client 82', 'Entreprise', 'Adresse 82', 2345678901, 'client82@gmail.com', NULL);
INSERT INTO Client VALUES (00083, 'Client 83', 'Particulier', 'Adresse 83', 3456789012, 'client83@gmail.com', NULL);
INSERT INTO Client VALUES (00084, 'Client 84', 'Entreprise', 'Adresse 84', 4567890123, 'client84@gmail.com', NULL);
INSERT INTO Client VALUES (00085, 'Client 85', 'Particulier', 'Adresse 85', 5678901234, 'client85@gmail.com', NULL);
INSERT INTO Client VALUES (00086, 'Client 86', 'Entreprise', 'Adresse 86', 6789012345, 'client86@gmail.com', NULL);
INSERT INTO Client VALUES (00087, 'Client 87', 'Particulier', 'Adresse 87', 7890123456, 'client87@gmail.com', NULL);
INSERT INTO Client VALUES (00088, 'Client 88', 'Entreprise', 'Adresse 88', 8901234567, 'client88@gmail.com', NULL);
INSERT INTO Client VALUES (00089, 'Client 89', 'Particulier', 'Adresse 89', 9012345678, 'client89@gmail.com', NULL);
INSERT INTO Client VALUES (00090, 'Client 90', 'Entreprise', 'Adresse 90', 0123456789, 'client90@gmail.com', NULL);
INSERT INTO Client VALUES (00091, 'Client 91', 'Particulier', 'Adresse 91', 1234567890, 'client91@gmail.com', NULL);
INSERT INTO Client VALUES (00092, 'Client 92', 'Entreprise', 'Adresse 92', 2345678901, 'client92@gmail.com', NULL);
INSERT INTO Client VALUES (00093, 'Client 93', 'Particulier', 'Adresse 93', 3456789012, 'client93@gmail.com', NULL);
INSERT INTO Client VALUES (00094, 'Client 94', 'Entreprise', 'Adresse 94', 4567890123, 'client94@gmail.com', NULL);
INSERT INTO Client VALUES (00095, 'Client 95', 'Particulier', 'Adresse 95', 5678901234, 'client95@gmail.com', NULL);
INSERT INTO Client VALUES (00096, 'Client 96', 'Entreprise', 'Adresse 96', 6789012345, 'client96@gmail.com', NULL);
INSERT INTO Client VALUES (00097, 'Client 97', 'Particulier', 'Adresse 97', 7890123456, 'client97@gmail.com', NULL);
INSERT INTO Client VALUES (00098, 'Client 98', 'Entreprise', 'Adresse 98', 8901234567, 'client98@gmail.com', NULL);
INSERT INTO Client VALUES (00099, 'Client 99', 'Particulier', 'Adresse 99', 9012345678, 'client99@gmail.com', NULL);
INSERT INTO Client VALUES (00100, 'Client 100', 'Entreprise', 'Adresse 100', 0123456789, 'client100@gmail.com', NULL);



--Insertion Comptes
INSERT INTO COMPTE(NumCompte, dateOuverture, etatCompte, solde, client, agence) VALUES
(1130005564, TO_DATE('2024-02-24','YYYY-MM-DD'),'Actif',50.00,
(SELECT REF(c) FROM Client c WHERE c.numClient = 35),
(SELECT REF(a) FROM Agence a WHERE a.numAgence = '113'));

INSERT INTO Compte(NumCompte, dateOuverture, etatCompte, Solde, client, agence) 
VALUES 
(1030005566, TO_DATE('2024-02-26','YYYY-MM-DD'), 'Actif', 150.00, (SELECT REF(c) FROM Client c WHERE c.NumClient = 37), (SELECT REF(a) FROM Agence a WHERE a.NumAgence = '103'));

INSERT INTO Compte(NumCompte, dateOuverture, etatCompte, Solde, client, agence) 
VALUES 
(1040005567, TO_DATE('2024-02-27','YYYY-MM-DD'), 'Actif', 200.00, (SELECT REF(c) FROM Client c WHERE c.NumClient = 38), (SELECT REF(a) FROM Agence a WHERE a.NumAgence = '104'));

INSERT INTO Compte(NumCompte, dateOuverture, etatCompte, Solde, client, agence) 
VALUES 
(1050005568, TO_DATE('2024-02-28','YYYY-MM-DD'), 'Actif', 250.00, (SELECT REF(c) FROM Client c WHERE c.NumClient = 39), (SELECT REF(a) FROM Agence a WHERE a.NumAgence = '105'));

INSERT INTO Compte(NumCompte, dateOuverture, etatCompte, Solde, client, agence) 
VALUES 
(1060005569, TO_DATE('2024-02-29','YYYY-MM-DD'), 'Actif', 300.00, (SELECT REF(c) FROM Client c WHERE c.NumClient = 40), (SELECT REF(a) FROM Agence a WHERE a.NumAgence = '106'));

INSERT INTO Compte(NumCompte, dateOuverture, etatCompte, Solde, client, agence) 
VALUES 
(1070005570, TO_DATE('2024-03-01','YYYY-MM-DD'), 'Actif', 350.00, (SELECT REF(c) FROM Client c WHERE c.NumClient = 41), (SELECT REF(a) FROM Agence a WHERE a.NumAgence = '107'));

INSERT INTO Compte(NumCompte, dateOuverture, etatCompte, Solde, client, agence) 
VALUES 
(1080005571, TO_DATE('2024-03-02','YYYY-MM-DD'), 'Actif', 400.00, (SELECT REF(c) FROM Client c WHERE c.NumClient = 42), (SELECT REF(a) FROM Agence a WHERE a.NumAgence = '108'));

INSERT INTO Compte(NumCompte, dateOuverture, etatCompte, Solde, client, agence) 
VALUES 
(1090005572, TO_DATE('2024-03-03','YYYY-MM-DD'), 'Actif', 450.00, (SELECT REF(c) FROM Client c WHERE c.NumClient = 43), (SELECT REF(a) FROM Agence a WHERE a.NumAgence = '109'));

INSERT INTO Compte(NumCompte, dateOuverture, etatCompte, Solde, client, agence) 
VALUES 
(1100005573, TO_DATE('2024-03-04','YYYY-MM-DD'), 'Actif', 500.00, (SELECT REF(c) FROM Client c WHERE c.NumClient = 44), (SELECT REF(a) FROM Agence a WHERE a.NumAgence = '110'));

INSERT INTO Compte(NumCompte, dateOuverture, etatCompte, Solde, client, agence) 
VALUES 
(1110005574, TO_DATE('2024-03-05','YYYY-MM-DD'), 'Actif', 550.00, (SELECT REF(c) FROM Client c WHERE c.NumClient = 45), (SELECT REF(a) FROM Agence a WHERE a.NumAgence = '111'));

INSERT INTO Compte(NumCompte, dateOuverture, etatCompte, Solde, client, agence) 
VALUES 
(1120005575, TO_DATE('2024-03-06','YYYY-MM-DD'), 'Actif', 600.00, (SELECT REF(c) FROM Client c WHERE c.NumClient = 46), (SELECT REF(a) FROM Agence a WHERE a.NumAgence = '112'));

INSERT INTO Compte(NumCompte, dateOuverture, etatCompte, Solde, client, agence) 
VALUES 
(1130005576, TO_DATE('2024-03-07','YYYY-MM-DD'), 'Actif', 650.00, (SELECT REF(c) FROM Client c WHERE c.NumClient = 47), (SELECT REF(a) FROM Agence a WHERE a.NumAgence = '113'));

INSERT INTO Compte(NumCompte, dateOuverture, etatCompte, Solde, client, agence) 
VALUES 
(1140005577, TO_DATE('2024-03-08','YYYY-MM-DD'), 'Actif', 700.00, (SELECT REF(c) FROM Client c WHERE c.NumClient = 48), (SELECT REF(a) FROM Agence a WHERE a.NumAgence = '114'));

INSERT INTO Compte(NumCompte, dateOuverture, etatCompte, Solde, client, agence) 
VALUES 
(1150005578, TO_DATE('2024-03-09','YYYY-MM-DD'), 'Actif', 750.00, (SELECT REF(c) FROM Client c WHERE c.NumClient = 49), (SELECT REF(a) FROM Agence a WHERE a.NumAgence = '115'));

INSERT INTO Compte(NumCompte, dateOuverture, etatCompte, Solde, client, agence) 
VALUES 
(1160005579, TO_DATE('2024-03-10','YYYY-MM-DD'), 'Actif', 800.00, (SELECT REF(c) FROM Client c WHERE c.NumClient = 50), (SELECT REF(a) FROM Agence a WHERE a.NumAgence = '116'));

INSERT INTO Compte(NumCompte, dateOuverture, etatCompte, Solde, client, agence) 
VALUES 
(1170005580, TO_DATE('2024-03-11','YYYY-MM-DD'), 'Actif', 850.00, (SELECT REF(c) FROM Client c WHERE c.NumClient = 51), (SELECT REF(a) FROM Agence a WHERE a.NumAgence = '117'));

INSERT INTO Compte(NumCompte, dateOuverture, etatCompte, Solde, client, agence) 
VALUES 
(1180005581, TO_DATE('2024-03-12','YYYY-MM-DD'), 'Actif', 900.00, (SELECT REF(c) FROM Client c WHERE c.NumClient = 52), (SELECT REF(a) FROM Agence a WHERE a.NumAgence = '118'));

INSERT INTO Compte(NumCompte, dateOuverture, etatCompte, Solde, client, agence) 
VALUES 
(1190005582, TO_DATE('2024-03-13','YYYY-MM-DD'), 'Actif', 950.00, (SELECT REF(c) FROM Client c WHERE c.NumClient = 53), (SELECT REF(a) FROM Agence a WHERE a.NumAgence = '119'));

INSERT INTO Compte(NumCompte, dateOuverture, etatCompte, Solde, client, agence) 
VALUES 
(1200005583, TO_DATE('2024-03-14','YYYY-MM-DD'), 'Actif', 1000.00, (SELECT REF(c) FROM Client c WHERE c.NumClient = 54), (SELECT REF(a) FROM Agence a WHERE a.NumAgence = '120'));

INSERT INTO Compte(NumCompte, dateOuverture, etatCompte, Solde, client, agence) 
VALUES 
(1210005584, TO_DATE('2024-03-15','YYYY-MM-DD'), 'Actif', 1050.00, (SELECT REF(c) FROM Client c WHERE c.NumClient = 55), (SELECT REF(a) FROM Agence a WHERE a.NumAgence = '121'));

INSERT INTO Compte(NumCompte, dateOuverture, etatCompte, Solde, client, agence) 
VALUES 
(1220005585, TO_DATE('2024-03-16','YYYY-MM-DD'), 'Actif', 1100.00, (SELECT REF(c) FROM Client c WHERE c.NumClient = 56), (SELECT REF(a) FROM Agence a WHERE a.NumAgence = '122'));

INSERT INTO Compte(NumCompte, dateOuverture, etatCompte, Solde, client, agence) 
VALUES 
(1230005586, TO_DATE('2024-03-17','YYYY-MM-DD'), 'Actif', 1150.00, (SELECT REF(c) FROM Client c WHERE c.NumClient = 57), (SELECT REF(a) FROM Agence a WHERE a.NumAgence = '123'));

INSERT INTO Compte(NumCompte, dateOuverture, etatCompte, Solde, client, agence) 
VALUES 
(1240005587, TO_DATE('2024-03-18','YYYY-MM-DD'), 'Actif', 1200.00, (SELECT REF(c) FROM Client c WHERE c.NumClient = 58), (SELECT REF(a) FROM Agence a WHERE a.NumAgence = '124'));

INSERT INTO Compte(NumCompte, dateOuverture, etatCompte, Solde, client, agence) 
VALUES 
(1250005588, TO_DATE('2024-03-19','YYYY-MM-DD'), 'Actif', 1250.00, (SELECT REF(c) FROM Client c WHERE c.NumClient = 59), (SELECT REF(a) FROM Agence a WHERE a.NumAgence = '125'));

INSERT INTO Compte(NumCompte, dateOuverture, etatCompte, Solde, client, agence) 
VALUES 
(1260005589, TO_DATE('2024-03-20','YYYY-MM-DD'), 'Actif', 1300.00, (SELECT REF(c) FROM Client c WHERE c.NumClient = 60), (SELECT REF(a) FROM Agence a WHERE a.NumAgence = '126'));

INSERT INTO Compte(NumCompte, dateOuverture, etatCompte, Solde, client, agence) 
VALUES 
(1270005590, TO_DATE('2024-03-21','YYYY-MM-DD'), 'Actif', 1350.00, (SELECT REF(c) FROM Client c WHERE c.NumClient = 61), (SELECT REF(a) FROM Agence a WHERE a.NumAgence = '127'));

INSERT INTO Compte(NumCompte, dateOuverture, etatCompte, Solde, client, agence) 
VALUES 
(1280005591, TO_DATE('2024-03-22','YYYY-MM-DD'), 'Actif', 1400.00, (SELECT REF(c) FROM Client c WHERE c.NumClient = 62), (SELECT REF(a) FROM Agence a WHERE a.NumAgence = '128'));

INSERT INTO Compte(NumCompte, dateOuverture, etatCompte, Solde, client, agence) 
VALUES 
(1290005592, TO_DATE('2024-03-23','YYYY-MM-DD'), 'Actif', 1450.00, (SELECT REF(c) FROM Client c WHERE c.NumClient = 63), (SELECT REF(a) FROM Agence a WHERE a.NumAgence = '129'));

INSERT INTO Compte(NumCompte, dateOuverture, etatCompte, Solde, client, agence) 
VALUES 
(1300005593, TO_DATE('2024-03-24','YYYY-MM-DD'), 'Actif', 1500.00, (SELECT REF(c) FROM Client c WHERE c.NumClient = 64), (SELECT REF(a) FROM Agence a WHERE a.NumAgence = '130'));

INSERT INTO Compte(NumCompte, dateOuverture, etatCompte, Solde, client, agence) 
VALUES 
(1310005594, TO_DATE('2024-03-25','YYYY-MM-DD'), 'Actif', 1550.00, (SELECT REF(c) FROM Client c WHERE c.NumClient = 65), (SELECT REF(a) FROM Agence a WHERE a.NumAgence = '131'));

INSERT INTO Compte(NumCompte, dateOuverture, etatCompte, Solde, client, agence) 
VALUES 
(1320005595, TO_DATE('2024-03-26','YYYY-MM-DD'), 'Actif', 1600.00, (SELECT REF(c) FROM Client c WHERE c.NumClient = 66), (SELECT REF(a) FROM Agence a WHERE a.NumAgence = '132'));

INSERT INTO Compte(NumCompte, dateOuverture, etatCompte, Solde, client, agence) 
VALUES 
(1330005596, TO_DATE('2024-03-27','YYYY-MM-DD'), 'Actif', 1650.00, (SELECT REF(c) FROM Client c WHERE c.NumClient = 67), (SELECT REF(a) FROM Agence a WHERE a.NumAgence = '133'));

INSERT INTO Compte(NumCompte, dateOuverture, etatCompte, Solde, client, agence) 
VALUES 
(1340005597, TO_DATE('2024-03-28','YYYY-MM-DD'), 'Actif', 1700.00, (SELECT REF(c) FROM Client c WHERE c.NumClient = 68), (SELECT REF(a) FROM Agence a WHERE a.NumAgence = '134'));

INSERT INTO Compte(NumCompte, dateOuverture, etatCompte, Solde, client, agence) 
VALUES 
(1350005598, TO_DATE('2024-03-29','YYYY-MM-DD'), 'Actif', 1750.00, (SELECT REF(c) FROM Client c WHERE c.NumClient = 69), (SELECT REF(a) FROM Agence a WHERE a.NumAgence = '135'));

INSERT INTO Compte(NumCompte, dateOuverture, etatCompte, Solde, client, agence) 
VALUES 
(1360005599, TO_DATE('2024-03-30','YYYY-MM-DD'), 'Actif', 1800.00, (SELECT REF(c) FROM Client c WHERE c.NumClient = 70), (SELECT REF(a) FROM Agence a WHERE a.NumAgence = '136'));

INSERT INTO Compte(NumCompte, dateOuverture, etatCompte, Solde, client, agence) 
VALUES 
(1370005600, TO_DATE('2024-03-31','YYYY-MM-DD'), 'Actif', 1850.00, (SELECT REF(c) FROM Client c WHERE c.NumClient = 71), (SELECT REF(a) FROM Agence a WHERE a.NumAgence = '137'));

INSERT INTO Compte(NumCompte, dateOuverture, etatCompte, Solde, client, agence) 
VALUES 
(1380005601, TO_DATE('2024-04-01','YYYY-MM-DD'), 'Actif', 1900.00, (SELECT REF(c) FROM Client c WHERE c.NumClient = 72), (SELECT REF(a) FROM Agence a WHERE a.NumAgence = '138'));

INSERT INTO Compte(NumCompte, dateOuverture, etatCompte, Solde, client, agence) 
VALUES 
(1390005602, TO_DATE('2024-04-02','YYYY-MM-DD'), 'Actif', 1950.00, (SELECT REF(c) FROM Client c WHERE c.NumClient = 73), (SELECT REF(a) FROM Agence a WHERE a.NumAgence = '139'));

INSERT INTO Compte(NumCompte, dateOuverture, etatCompte, Solde, client, agence) 
VALUES 
(1400005603, TO_DATE('2024-04-03','YYYY-MM-DD'), 'Actif', 2000.00, (SELECT REF(c) FROM Client c WHERE c.NumClient = 74), (SELECT REF(a) FROM Agence a WHERE a.NumAgence = '140'));

INSERT INTO Compte(NumCompte, dateOuverture, etatCompte, Solde, client, agence) 
VALUES 
(1410005604, TO_DATE('2024-04-04','YYYY-MM-DD'), 'Actif', 2050.00, (SELECT REF(c) FROM Client c WHERE c.NumClient = 75), (SELECT REF(a) FROM Agence a WHERE a.NumAgence = '141'));

INSERT INTO Compte(NumCompte, dateOuverture, etatCompte, Solde, client, agence) 
VALUES 
(1420005605, TO_DATE('2024-04-05','YYYY-MM-DD'), 'Actif', 2100.00, (SELECT REF(c) FROM Client c WHERE c.NumClient = 76), (SELECT REF(a) FROM Agence a WHERE a.NumAgence = '142'));

INSERT INTO Compte(NumCompte, dateOuverture, etatCompte, Solde, client, agence) 
VALUES 
(1430005606, TO_DATE('2024-04-06','YYYY-MM-DD'), 'Actif', 2150.00, (SELECT REF(c) FROM Client c WHERE c.NumClient = 77), (SELECT REF(a) FROM Agence a WHERE a.NumAgence = '143'));

INSERT INTO Compte(NumCompte, dateOuverture, etatCompte, Solde, client, agence) 
VALUES 
(1440005607, TO_DATE('2024-04-07','YYYY-MM-DD'), 'Actif', 2200.00, (SELECT REF(c) FROM Client c WHERE c.NumClient = 78), (SELECT REF(a) FROM Agence a WHERE a.NumAgence = '144'));

INSERT INTO Compte(NumCompte, dateOuverture, etatCompte, Solde, client, agence) 
VALUES 
(1180005564, TO_DATE('2023-04-07','YYYY-MM-DD'), 'Actif', 15000.00, (SELECT REF(c) FROM Client c WHERE c.NumClient = 79), (SELECT REF(a) FROM Agence a WHERE a.NumAgence = '144'));


--MAJ des Comptes pour chaque client 
UPDATE CLIENT c SET CompteClient = (CAST(MULTISET(SELECT REF(cpt) FROM Compte cpt WHERE DEREF(cpt.client).numClient = c.numClient) AS t_ref_Compte_Client));

--MAJ des Comptes pour chaque Agence
UPDATE Agence A SET Compte = (CAST(MULTISET(SELECT REF(cpt) FROM Compte cpt WHERE DEREF(cpt.Agence).numAgence = A.numAgence) AS t_ref_Compte_Agence));



--Insertion d'opérations
INSERT INTO Operation (numOperation, dateOp, montantop, natureop, compte)
VALUES (105, TO_DATE('2024-11-05', 'YYYY-MM-DD'), 5300.00, 'Crédit', (SELECT REF (c) FROM Compte c WHERE c.numCompte = 1200005583));
INSERT INTO Operation (numOperation, dateOp, montantop, natureop, compte)
VALUES (106, TO_DATE('2024-11-06', 'YYYY-MM-DD'), 5400.00, 'Débit', (SELECT REF (c) FROM Compte c WHERE c.numCompte = 1200005583));
INSERT INTO Operation (numOperation, dateOp, montantop, natureop, compte)
VALUES (107, TO_DATE('2024-11-07', 'YYYY-MM-DD'), 5500.00, 'Crédit', (SELECT REF (c) FROM Compte c WHERE c.numCompte = 1200005583));
INSERT INTO Operation (numOperation, dateOp, montantop, natureop, compte)
VALUES (108, TO_DATE('2024-11-08', 'YYYY-MM-DD'), 5600.00, 'Débit', (SELECT REF (c) FROM Compte c WHERE c.numCompte = 1200005583));
INSERT INTO Operation (numOperation, dateOp, montantop, natureop, compte)
VALUES (109, TO_DATE('2024-11-09', 'YYYY-MM-DD'), 5700.00, 'Crédit', (SELECT REF (c) FROM Compte c WHERE c.numCompte = 1200005583));
INSERT INTO Operation (numOperation, dateOp, montantop, natureop, compte)
VALUES (110, TO_DATE('2024-11-10', 'YYYY-MM-DD'), 5800.00, 'Débit', (SELECT REF (c) FROM Compte c WHERE c.numCompte = 1200005583));
INSERT INTO Operation (numOperation, dateOp, montantop, natureop, compte)
VALUES (111, TO_DATE('2024-11-11', 'YYYY-MM-DD'), 5900.00, 'Crédit', (SELECT REF (c) FROM Compte c WHERE c.numCompte = 1200005583));
INSERT INTO Operation (numOperation, dateOp, montantop, natureop, compte)
VALUES (112, TO_DATE('2024-11-12', 'YYYY-MM-DD'), 6000.00, 'Débit', (SELECT REF (c) FROM Compte c WHERE c.numCompte = 1200005583));
INSERT INTO Operation (numOperation, dateOp, montantop, natureop, compte)
VALUES (113, TO_DATE('2024-11-13', 'YYYY-MM-DD'), 6100.00, 'Crédit', (SELECT REF (c) FROM Compte c WHERE c.numCompte = 1200005583));
INSERT INTO Operation (numOperation, dateOp, montantop, natureop, compte)
VALUES (114, TO_DATE('2024-11-14', 'YYYY-MM-DD'), 6200.00, 'Débit', (SELECT REF (c) FROM Compte c WHERE c.numCompte = 1200005583));
INSERT INTO Operation (numOperation, dateOp, montantop, natureop, compte)
VALUES (115, TO_DATE('2024-11-15', 'YYYY-MM-DD'), 6300.00, 'Crédit', (SELECT REF (c) FROM Compte c WHERE c.numCompte = 1200005583));
INSERT INTO Operation (numOperation, dateOp, montantop, natureop, compte)
VALUES (116, TO_DATE('2024-11-16', 'YYYY-MM-DD'), 6400.00, 'Débit', (SELECT REF (c) FROM Compte c WHERE c.numCompte = 1200005583));
INSERT INTO Operation (numOperation, dateOp, montantop, natureop, compte)
VALUES (117, TO_DATE('2024-11-17', 'YYYY-MM-DD'), 6500.00, 'Crédit', (SELECT REF (c) FROM Compte c WHERE c.numCompte = 1200005583));
INSERT INTO Operation (numOperation, dateOp, montantop, natureop, compte)
VALUES (118, TO_DATE('2024-11-18', 'YYYY-MM-DD'), 6600.00, 'Débit', (SELECT REF (c) FROM Compte c WHERE c.numCompte = 1200005583));
INSERT INTO Operation (numOperation, dateOp, montantop, natureop, compte)
VALUES (119, TO_DATE('2024-11-19', 'YYYY-MM-DD'), 6700.00, 'Crédit', (SELECT REF (c) FROM Compte c WHERE c.numCompte = 1200005583));
INSERT INTO Operation (numOperation, dateOp, montantop, natureop, compte)
VALUES (120, TO_DATE('2024-11-20', 'YYYY-MM-DD'), 6800.00, 'Débit', (SELECT REF (c) FROM Compte c WHERE c.numCompte = 1200005583));
INSERT INTO Operation (numOperation, dateOp, montantop, natureop, compte)
VALUES (121, TO_DATE('2024-11-21', 'YYYY-MM-DD'), 6900.00, 'Crédit', (SELECT REF (c) FROM Compte c WHERE c.numCompte = 1200005583));
INSERT INTO Operation (numOperation, dateOp, montantop, natureop, compte)
VALUES (122, TO_DATE('2024-11-22', 'YYYY-MM-DD'), 7000.00, 'Débit', (SELECT REF (c) FROM Compte c WHERE c.numCompte = 1200005583));
INSERT INTO Operation (numOperation, dateOp, montantop, natureop, compte)
VALUES (123, TO_DATE('2024-11-23', 'YYYY-MM-DD'), 7100.00, 'Crédit', (SELECT REF (c) FROM Compte c WHERE c.numCompte = 1200005583));
INSERT INTO Operation (numOperation, dateOp, montantop, natureop, compte)
VALUES (124, TO_DATE('2024-11-24', 'YYYY-MM-DD'), 7200.00, 'Débit', (SELECT REF (c) FROM Compte c WHERE c.numCompte = 1200005583));
INSERT INTO Operation (numOperation, dateOp, montantop, natureop, compte)
VALUES (125, TO_DATE('2024-11-25', 'YYYY-MM-DD'), 7300.00, 'Crédit', (SELECT REF (c) FROM Compte c WHERE c.numCompte = 1200005583));
INSERT INTO Operation (numOperation, dateOp, montantop, natureop, compte)
VALUES (126, TO_DATE('2024-11-26', 'YYYY-MM-DD'), 7400.00, 'Débit', (SELECT REF (c) FROM Compte c WHERE c.numCompte = 1200005583));
INSERT INTO Operation (numOperation, dateOp, montantop, natureop, compte)
VALUES (127, TO_DATE('2024-11-27', 'YYYY-MM-DD'), 7500.00, 'Crédit', (SELECT REF (c) FROM Compte c WHERE c.numCompte = 1200005583));
INSERT INTO Operation (numOperation, dateOp, montantop, natureop, compte)
VALUES (128, TO_DATE('2024-11-28', 'YYYY-MM-DD'), 7600.00, 'Débit', (SELECT REF (c) FROM Compte c WHERE c.numCompte = 1200005583));
INSERT INTO Operation (numOperation, dateOp, montantop, natureop, compte)
VALUES (129, TO_DATE('2024-11-29', 'YYYY-MM-DD'), 7700.00, 'Crédit', (SELECT REF (c) FROM Compte c WHERE c.numCompte = 1200005583));
INSERT INTO Operation (numOperation, dateOp, montantop, natureop, compte)
VALUES (130, TO_DATE('2024-11-30', 'YYYY-MM-DD'), 7800.00, 'Débit', (SELECT REF (c) FROM Compte c WHERE c.numCompte = 1200005583));
INSERT INTO Operation (numOperation, dateOp, montantop, natureop, compte)
VALUES (131, TO_DATE('2024-12-01', 'YYYY-MM-DD'), 7900.00, 'Crédit', (SELECT REF (c) FROM Compte c WHERE c.numCompte = 1200005583));
INSERT INTO Operation (numOperation, dateOp, montantop, natureop, compte)
VALUES (132, TO_DATE('2024-12-02', 'YYYY-MM-DD'), 8000.00, 'Débit', (SELECT REF (c) FROM Compte c WHERE c.numCompte = 1200005583));
INSERT INTO Operation (numOperation, dateOp, montantop, natureop, compte)
VALUES (133, TO_DATE('2024-12-03', 'YYYY-MM-DD'), 8100.00, 'Crédit', (SELECT REF (c) FROM Compte c WHERE c.numCompte = 1200005583));
INSERT INTO Operation (numOperation, dateOp, montantop, natureop, compte)
VALUES (134, TO_DATE('2024-12-04', 'YYYY-MM-DD'), 8200.00, 'Débit', (SELECT REF (c) FROM Compte c WHERE c.numCompte = 1200005583));
INSERT INTO Operation (numOperation, dateOp, montantop, natureop, compte)
VALUES (135, TO_DATE('2024-12-05', 'YYYY-MM-DD'), 8300.00, 'Crédit', (SELECT REF (c) FROM Compte c WHERE c.numCompte = 1200005583));
INSERT INTO Operation (numOperation, dateOp, montantop, natureop, compte)
VALUES (136, TO_DATE('2024-12-06', 'YYYY-MM-DD'), 8400.00, 'Débit', (SELECT REF (c) FROM Compte c WHERE c.numCompte = 1200005583));
INSERT INTO Operation (numOperation, dateOp, montantop, natureop, compte)
VALUES (137, TO_DATE('2024-12-07', 'YYYY-MM-DD'), 8500.00, 'Crédit', (SELECT REF (c) FROM Compte c WHERE c.numCompte = 1200005583));

INSERT INTO Operation (numOperation, dateOp, montantop, natureop, compte)
VALUES (138, TO_DATE('2023-12-07', 'YYYY-MM-DD'), 8500.00, 'Crédit', (SELECT REF (c) FROM Compte c WHERE c.numCompte = 1180005564));
INSERT INTO Operation (numOperation, dateOp, montantop, natureop, compte)
VALUES (139, TO_DATE('2023-10-07', 'YYYY-MM-DD'), 10000.00, 'Crédit', (SELECT REF (c) FROM Compte c WHERE c.numCompte = 1180005564));
INSERT INTO Operation (numOperation, dateOp, montantop, natureop, compte)
VALUES (140, TO_DATE('2023-12-25', 'YYYY-MM-DD'), 15000.00, 'Crédit', (SELECT REF (c) FROM Compte c WHERE c.numCompte = 1180005564));
INSERT INTO Operation (numOperation, dateOp, montantop, natureop, compte)
VALUES (141, TO_DATE('2023-03-25', 'YYYY-MM-DD'), 1250.00, 'Crédit', (SELECT REF (c) FROM Compte c WHERE c.numCompte = 1180005564));

--Insertion dans la table Pret 
 INSERT INTO Pret(numPret, montantPret, dateEffet, duree, typePret, tauxInteret, MontantEcheance, compte) VALUES (1, 50000.00, TO_DATE('2024-05-24','YYYY-MM-DD'),24,'ANJEM',0.15,500.54,(SELECT REF(c) FROM Compte C WHERE c.numCompte = 1200005583 ));

INSERT INTO Pret(numPret, montantPret, dateEffet, duree, typePret, tauxInteret, MontantEcheance, compte)
VALUES (1, 50000.00, TO_DATE('2024-05-24','YYYY-MM-DD'),24,'ANJEM',0.15,500.54,(SELECT REF(c) FROM Compte C WHERE c.numCompte = 1200005523 ));
INSERT INTO Pret(numPret, montantPret, dateEffet, duree, typePret, tauxInteret, MontantEcheance, compte)
VALUES (2, 60000.00, TO_DATE('2024-05-25','YYYY-MM-DD'),36,'ANJEM',0.16,600.54,(SELECT REF(c) FROM Compte C WHERE c.numCompte = 1200005524 ));
INSERT INTO Pret(numPret, montantPret, dateEffet, duree, typePret, tauxInteret, MontantEcheance, compte)
VALUES (3, 70000.00, TO_DATE('2024-05-26','YYYY-MM-DD'),48,'ANJEM',0.17,700.54,(SELECT REF(c) FROM Compte C WHERE c.numCompte = 1200005525 ));
INSERT INTO Pret(numPret, montantPret, dateEffet, duree, typePret, tauxInteret, MontantEcheance, compte)
VALUES (4, 80000.00, TO_DATE('2024-05-27','YYYY-MM-DD'),60,'ANJEM',0.18,800.54,(SELECT REF(c) FROM Compte C WHERE c.numCompte = 1200005526 ));
INSERT INTO Pret(numPret, montantPret, dateEffet, duree, typePret, tauxInteret, MontantEcheance, compte)
VALUES (5, 90000.00, TO_DATE('2024-05-28','YYYY-MM-DD'),72,'ANJEM',0.19,900.54,(SELECT REF(c) FROM Compte C WHERE c.numCompte = 1200005527 ));
INSERT INTO Pret(numPret, montantPret, dateEffet, duree, typePret, tauxInteret, MontantEcheance, compte)
VALUES (6, 100000.00, TO_DATE('2024-05-29','YYYY-MM-DD'),24,'ANJEM',0.2,1000.54,(SELECT REF(c) FROM Compte C WHERE c.numCompte = 1200005528 ));
INSERT INTO Pret(numPret, montantPret, dateEffet, duree, typePret, tauxInteret, MontantEcheance, compte)
VALUES (7, 110000.00, TO_DATE('2024-05-30','YYYY-MM-DD'),36,'ANJEM',0.21,1100.54,(SELECT REF(c) FROM Compte C WHERE c.numCompte = 1200005529 ));
INSERT INTO Pret(numPret, montantPret, dateEffet, duree, typePret, tauxInteret, MontantEcheance, compte)
VALUES (8, 120000.00, TO_DATE('2024-05-31','YYYY-MM-DD'),48,'ANJEM',0.22,1200.54,(SELECT REF(c) FROM Compte C WHERE c.numCompte = 1200005530 ));
INSERT INTO Pret(numPret, montantPret, dateEffet, duree, typePret, tauxInteret, MontantEcheance, compte)
VALUES (9, 130000.00, TO_DATE('2024-06-01','YYYY-MM-DD'),60,'ANJEM',0.23,1300.54,(SELECT REF(c) FROM Compte C WHERE c.numCompte = 1200005531 ));
INSERT INTO Pret(numPret, montantPret, dateEffet, duree, typePret, tauxInteret, MontantEcheance, compte)
VALUES (10, 140000.00, TO_DATE('2024-06-02','YYYY-MM-DD'),72,'ANJEM',0.24,1400.54,(SELECT REF(c) FROM Compte C WHERE c.numCompte = 1200005532 ));
INSERT INTO Pret(numPret, montantPret, dateEffet, duree, typePret, tauxInteret, MontantEcheance, compte)
VALUES (11, 150000.00, TO_DATE('2024-06-03','YYYY-MM-DD'),24,'ANJEM',0.25,1500.54,(SELECT REF(c) FROM Compte C WHERE c.numCompte = 1200005533 ));
INSERT INTO Pret(numPret, montantPret, dateEffet, duree, typePret, tauxInteret, MontantEcheance, compte)
VALUES (12, 160000.00, TO_DATE('2024-06-04','YYYY-MM-DD'),36,'ANJEM',0.26,1600.54,(SELECT REF(c) FROM Compte C WHERE c.numCompte = 1200005534 ));
INSERT INTO Pret(numPret, montantPret, dateEffet, duree, typePret, tauxInteret, MontantEcheance, compte)
VALUES (13, 170000.00, TO_DATE('2024-06-05','YYYY-MM-DD'),48,'ANJEM',0.27,1700.54,(SELECT REF(c) FROM Compte C WHERE c.numCompte = 1200005535 ));
INSERT INTO Pret(numPret, montantPret, dateEffet, duree, typePret, tauxInteret, MontantEcheance, compte)
VALUES (14, 180000.00, TO_DATE('2024-06-06','YYYY-MM-DD'),60,'ANJEM',0.28,1800.54,(SELECT REF(c) FROM Compte C WHERE c.numCompte = 1200005536 ));
INSERT INTO Pret(numPret, montantPret, dateEffet, duree, typePret, tauxInteret, MontantEcheance, compte)
VALUES (15, 190000.00, TO_DATE('2024-06-07','YYYY-MM-DD'),72,'ANJEM',0.29,1900.54,(SELECT REF(c) FROM Compte C WHERE c.numCompte = 1200005537 ));
INSERT INTO Pret(numPret, montantPret, dateEffet, duree, typePret, tauxInteret, MontantEcheance, compte)
VALUES (16, 200000.00, TO_DATE('2024-06-08','YYYY-MM-DD'),24,'ANJEM',0.30,2000.54,(SELECT REF(c) FROM Compte C WHERE c.numCompte = 1200005538 ));
INSERT INTO Pret(numPret, montantPret, dateEffet, duree, typePret, tauxInteret, MontantEcheance, compte)
VALUES (17, 210000.00, TO_DATE('2024-06-09','YYYY-MM-DD'),36,'ANJEM',0.31,2100.54,(SELECT REF(c) FROM Compte C WHERE c.numCompte = 1200005539 ));
INSERT INTO Pret(numPret, montantPret, dateEffet, duree, typePret, tauxInteret, MontantEcheance, compte)
VALUES (18, 220000.00, TO_DATE('2024-06-10','YYYY-MM-DD'),48,'ANJEM',0.32,2200.54,(SELECT REF(c) FROM Compte C WHERE c.numCompte = 1200005540 ));
INSERT INTO Pret(numPret, montantPret, dateEffet, duree, typePret, tauxInteret, MontantEcheance, compte)
VALUES (19, 230000.00, TO_DATE('2024-06-11','YYYY-MM-DD'),60,'ANJEM',0.33,2300.54,(SELECT REF(c) FROM Compte C WHERE c.numCompte = 1200005541 ));
INSERT INTO Pret(numPret, montantPret, dateEffet, duree, typePret, tauxInteret, MontantEcheance, compte)
VALUES (20, 240000.00, TO_DATE('2024-06-12','YYYY-MM-DD'),72,'ANJEM',0.34,2400.54,(SELECT REF(c) FROM Compte C WHERE c.numCompte = 1200005542 ));
INSERT INTO Pret(numPret, montantPret, dateEffet, duree, typePret, tauxInteret, MontantEcheance, compte)
VALUES (21, 250000.00, TO_DATE('2024-06-13','YYYY-MM-DD'),24,'ANJEM',0.35,2500.54,(SELECT REF(c) FROM Compte C WHERE c.numCompte = 1200005543 ));
INSERT INTO Pret(numPret, montantPret, dateEffet, duree, typePret, tauxInteret, MontantEcheance, compte)
VALUES (22, 260000.00, TO_DATE('2024-06-14','YYYY-MM-DD'),36,'ANJEM',0.36,2600.54,(SELECT REF(c) FROM Compte C WHERE c.numCompte = 1200005544 ));
INSERT INTO Pret(numPret, montantPret, dateEffet, duree, typePret, tauxInteret, MontantEcheance, compte)
VALUES (23, 270000.00, TO_DATE('2024-06-15','YYYY-MM-DD'),48,'ANJEM',0.37,2700.54,(SELECT REF(c) FROM Compte C WHERE c.numCompte = 1200005545 ));
INSERT INTO Pret(numPret, montantPret, dateEffet, duree, typePret, tauxInteret, MontantEcheance, compte)
VALUES (24, 280000.00, TO_DATE('2024-06-16','YYYY-MM-DD'),60,'ANJEM',0.38,2800.54,(SELECT REF(c) FROM Compte C WHERE c.numCompte = 1200005546 ));
INSERT INTO Pret(numPret, montantPret, dateEffet, duree, typePret, tauxInteret, MontantEcheance, compte)
VALUES (25, 290000.00, TO_DATE('2024-06-17','YYYY-MM-DD'),72,'ANJEM',0.39,2900.54,(SELECT REF(c) FROM Compte C WHERE c.numCompte = 1200005547 ));
INSERT INTO Pret(numPret, montantPret, dateEffet, duree, typePret, tauxInteret, MontantEcheance, compte)
VALUES (26, 300000.00, TO_DATE('2024-06-18','YYYY-MM-DD'),24,'ANJEM',0.40,3000.54,(SELECT REF(c) FROM Compte C WHERE c.numCompte = 1200005548 ));
INSERT INTO Pret(numPret, montantPret, dateEffet, duree, typePret, tauxInteret, MontantEcheance, compte)
VALUES (27, 310000.00, TO_DATE('2024-06-19','YYYY-MM-DD'),36,'ANJEM',0.41,3100.54,(SELECT REF(c) FROM Compte C WHERE c.numCompte = 1200005549 ));
INSERT INTO Pret(numPret, montantPret, dateEffet, duree, typePret, tauxInteret, MontantEcheance, compte)
VALUES (28, 320000.00, TO_DATE('2024-06-20','YYYY-MM-DD'),48,'ANJEM',0.42,3200.54,(SELECT REF(c) FROM Compte C WHERE c.numCompte = 1200005550 ));
INSERT INTO Pret(numPret, montantPret, dateEffet, duree, typePret, tauxInteret, MontantEcheance, compte)
VALUES (29, 330000.00, TO_DATE('2024-06-21','YYYY-MM-DD'),60,'ANJEM',0.43,3300.54,(SELECT REF(c) FROM Compte C WHERE c.numCompte = 1200005551 ));
INSERT INTO Pret(numPret, montantPret, dateEffet, duree, typePret, tauxInteret, MontantEcheance, compte)
VALUES (30, 340000.00, TO_DATE('2024-06-22','YYYY-MM-DD'),72,'ANJEM',0.44,3400.54,(SELECT REF(c) FROM Compte C WHERE c.numCompte = 1200005552 ));
INSERT INTO Pret(numPret, montantPret, dateEffet, duree, typePret, tauxInteret, MontantEcheance, compte)
VALUES (31, 350000.00, TO_DATE('2024-06-23','YYYY-MM-DD'),24,'ANJEM',0.45,3500.54,(SELECT REF(c) FROM Compte C WHERE c.numCompte = 1200005553 ));
INSERT INTO Pret(numPret, montantPret, dateEffet, duree, typePret, tauxInteret, MontantEcheance, compte)
VALUES (32, 360000.00, TO_DATE('2024-06-24','YYYY-MM-DD'),36,'ANJEM',0.46,3600.54,(SELECT REF(c) FROM Compte C WHERE c.numCompte = 1200005554 ));
INSERT INTO Pret(numPret, montantPret, dateEffet, duree, typePret, tauxInteret, MontantEcheance, compte)
VALUES (33, 370000.00, TO_DATE('2024-06-25','YYYY-MM-DD'),48,'ANJEM',0.47,3700.54,(SELECT REF(c) FROM Compte C WHERE c.numCompte = 1200005579 ));
INSERT INTO Pret(numPret, montantPret, dateEffet, duree, typePret, tauxInteret, MontantEcheance, compte)
VALUES (34, 380000.00, TO_DATE('2024-06-26','YYYY-MM-DD'),60,'ANJEM',0.48,3800.54,(SELECT REF(c) FROM Compte C WHERE c.numCompte = 1200005580 ));
INSERT INTO Pret(numPret, montantPret, dateEffet, duree, typePret, tauxInteret, MontantEcheance, compte)
VALUES (35, 390000.00, TO_DATE('2024-06-27','YYYY-MM-DD'),72,'ANJEM',0.49,3900.54,(SELECT REF(c) FROM Compte C WHERE c.numCompte = 1200005581 ));
INSERT INTO Pret(numPret, montantPret, dateEffet, duree, typePret, tauxInteret, MontantEcheance, compte)
VALUES (36, 390000.00, TO_DATE('2024-06-27','YYYY-MM-DD'),72,'ANJEM',0.49,3900.54,(SELECT REF(c) FROM Compte C WHERE c.numCompte = 1200005583 ));

#interrogation de la BD
#1
SELECT C.numCompte FROM Compte C 
WHERE DEREF(C.Agence).numAgence = 120 
AND DEREF(C.Client).TypeClient = 'Entreprise' ;

#2
SELECT P.numPret, DEREF(DEREF(P.compte).agence).numAgence, DEREF(P.compte).numCompte, P.montantPret
  FROM pret P 
  WHERE DEREF(DEREF(DEREF(P.compte).agence).succursale).numSucc = 005 ;

#3
SELECT C.numCompte
FROM Compte C
WHERE NOT EXISTS (
    SELECT 1
    FROM Operation O
    WHERE O.compte = REF(C)
    AND O.natureOp = 'Débit'
    AND O.dateOp BETWEEN TO_DATE('2000-01-01', 'YYYY-MM-DD') 
    AND TO_DATE('2022-12-31', 'YYYY-MM-DD')
);


#4
--Notre exemple selon notre BD
SELECT SUM(O.montantOp) AS montant_total_credit
FROM Operation O
WHERE DEREF(O.compte).numCompte = 1200005583
AND O.natureOp = 'Crédit'
AND EXTRACT(YEAR FROM O.dateOp) = 2024;

--L'exemple selon l'énnoncé
SELECT SUM(O.montantOp) AS montant_total_credit
FROM Operation O
WHERE DEREF(O.compte).numCompte = 1180005564
AND O.natureOp = 'Crédit'
AND EXTRACT(YEAR FROM O.dateOp) = 2023;


#5
SELECT P.numPret, DEREF(DEREF(P.compte).agence).numAgence, 
DEREF(P.compte).numCompte ,
DEREF(DEREF(P.compte).client).numClient, P.montantPret
FROM Pret P
WHERE montantEcheance !=0 ;

#6
SELECT DEREF(o.compte).numCompte
FROM operation o
WHERE EXTRACT(YEAR FROM o.dateOp) = 2024
GROUP BY DEREF(o.compte).numCompte
ORDER BY COUNT(o.numOperation) DESC
FETCH FIRST 1 ROW ONLY;



