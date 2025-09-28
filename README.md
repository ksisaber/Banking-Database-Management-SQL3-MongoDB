# Bank Operations & Loan Management — Relational and NoSQL Project

**Project goal:**
Design and implement a bank database for branch/agency/client/account/operation/loan management. Deliver a relational-object design and implementation (SQL), populate the DB with realistic test data (inserts), then propose & implement a document-oriented (NoSQL) model and answer typical queries (including Map-Reduce).

---

## Repository contents

```
Description.txt                 -> Project report / explanations
PARTIE1.sql                     -> SQL script for Part I (DDL, types, tables, methods, inserts)
PARTIE2.js                      -> NoSQL script (MongoDB JS). NOTE: sometimes renamed to PARTIE2.js.txt
PARTIE2.js.txt                  -> Same as above (renamed .txt for email transport)
scriptinsertion.js              -> Additional insertion script for Part II (Mongo)
scriptinsertion.js.txt          -> Same as above (renamed .txt)
SI SABER Karim...               -> Project documents / report files
```

> **Note:** `.js` files may be renamed to `.txt` due to email restrictions. Rename them back before running.

---

## Problem summary & relational schema

A database for a bank handling branches, agencies, clients, accounts, operations, and loans.

**Relations:**

* **Succursale**(`NumSucc`, `nomSucc`, `adresseSucc`, `région`)
* **Agence**(`NumAgence`, `nomAgence`, `adresseAgence`, `catégorie`, `NumSucc*`)
* **Client**(`NumClient`, `NomClient`, `TypeClient`, `AdresseClient`, `NumTel`, `Email`)
* **Compte**(`NumCompte`, `dateOuverture`, `etatCompte`, `Solde`, `NumClient*`, `NumAgence*`)
* **Opération**(`NumOpération`, `NatureOp`, `montantOp`, `DateOp`, `Observation`, `NumCompte*`)
* **Prêt**(`NumPrêt`, `montantPrêt`, `dateEffet`, `durée`, `typePrêt`, `tauxIntérêt`, `montantEchéance`, `NumCompte*`)

**Constraints / values:**

* `région`: North, South, East, West
* `catégorie`: Principale, Secondaire
* `etatCompte`: Actif, Bloqué
* `typePrêt`: Véhicule, Immobilier, ANSEJ, ANJEM
* `TypeClient`: Particulier, Entreprise
* `NatureOp`: Crédit, Débit
* IDs and numbering conventions defined in the report.

---

## Part I — Relational / Object-relational tasks (`PARTIE1.sql`)

### Implemented

* UML class diagram and object model (in report).
* Create tablespaces `SQL3_TBS` and `SQL3_TempTBS`.
* Create user `SQL3` and grant privileges.
* Define abstract SQL types, associations, and methods:

  * Number of loans per agency.
  * Number of primary agencies per branch.
  * Total loan amount for an agency in a date range.
  * List secondary agencies with at least one ANSEJ loan.
* Create tables and constraints.
* Populate tables with realistic sample data.
* Example queries included.

---

## Part II — NoSQL (MongoDB, document model) (`PARTIE2.js`, `scriptinsertion.js`)

### Implemented

* Document-oriented design centered on loans.
* Data insertion scripts (`PARTIE2.js`, `scriptinsertion.js`).
* Queries:

  * Loans for agency `102`.
  * Loans for agencies in region North.
  * Aggregation: loans per agency (`Agence-NbPrêts`).
  * Loans of type ANSEJ (`Prêt-ANSEJ`).
  * Loans by Particulier clients.
  * Update unpaid loans (increase installment amount).
  * Map-Reduce version of aggregation.
* Analysis of trade-offs and design justification (in report).

---

## Example SQL queries

1. List accounts of an agency where owners are companies.
2. Loans from agencies of a given branch (`NumSucc=005`).
3. Accounts with no debit ops between 2000–2022.
4. Total credits on account `1180005564` in 2023.
5. Unpaid loans with details.
6. Most active account in 2023.

---

## Example NoSQL queries

* Loans at agency `102`.
* Loans in agencies of the North region.
* Aggregate: number of loans per agency (sorted).
* Loans of type ANSEJ.
* Loans by Particulier clients.
* Update installment amount for old unpaid loans.
* Map-Reduce: aggregation of loans per agency.

---

## Requirements

* **Relational:** Oracle (preferred for tablespaces & object-relational features) or PostgreSQL (adapt scripts).
* **NoSQL:** MongoDB (`mongosh` or `mongo` shell).
* Optional: Node.js for JS execution.

---

## How to run

### Relational

1. Connect as DBA or privileged user.
2. Run:

   ```sql
   @PARTIE1.sql
   ```

### NoSQL

1. Ensure MongoDB is running.
2. Rename `.txt` → `.js` if needed.
3. Execute:

   ```bash
   mongosh < PARTIE2.js
   mongosh < scriptinsertion.js
   ```

---

## Design justification

* **Relational model**: normalized, consistent, with enforced integrity.
* **Document model**: denormalized, optimized for loan queries (fast reads, some redundancy).

---

## Report & authorship

* Detailed report, UML, and analysis in `Description.txt` and other report files.
* Author: listed in project files.

---
