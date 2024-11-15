//Modélisation orienté document
"Pret":
{
    "NumPret": 1,
    "montantPret": 5000,
    "dateEffet": new Date("2023-03-24"),
    "duree": 3,
    "typePret": "ANJEM",
    "tauxInteret": 1.50,
    "montantEcheance": 500.50,
    "Compte": {
        "NumCompte": 1,
        "dateOuverture": new Date("2023-02-24"),
        "etatCompte": "Actif",
        "Solde": 100.00,
        "Client": {
            "NumClient": 00001,
            "NomClient": "Karim",
            "TypeClient": "Entreprise",
            "AdresseClient": "Adresse1",
            "NumTel": 0666949364,
            "Email": "ksisaber@gmail.com"
        },
        "Operations": [{
            "NumOperation": 1,
            "NatureOp": "Crédit",
            "montantOp": 8000.00,
            "DateOp": new Date("2023-08-15"),
            "Observation": "RAS"
        }]
    },
    "Agence": {
        "NumAgence": 1,
        "nomAgence": "Agence 1",
        "adresseAgence": "Adresse 1",
        "categorie": "Principale",
        "Succursale": {
            "NumSucc": 1,
            "nomSucc": "Sony",
            "adresseSucc": "Adresse1",
            "region": "Alger"
        }
    }
}

//Requete 1
db.Pret.find({ "Compte.Agence.NumAgence": 102 });


//Requete 2
db.Pret.find({ "Compte.Agence.Succursale.region" : "Nord" }, { NumPret: 1, "Compte.Agence.NumAgence": 1, "Compte.NumCompte": 1, "Compte.Client.NumClient": 1, montantPret: 1 });


//Requete 3
db.Pret.aggregate([
    { $group: { _id: "$Compte.Agence.NumAgence", totalPrets: { $sum: 1 } } },
    { $sort: { totalPrêts: -1 } },
    { $out: "Agence-NbPrêts" }
])


//Requete 4
db.Pret.find({ typePrêt: "ANSEJ" }, { NumPrêt: 1, "Compte.Client.NumClient": 1, montantPrêt: 1, dateEffet: 1 }).forEach(function(prêt) {
    db.Pret_ANSEJ.insertOne(prêt);
});


//Requete 5
db.Pret.find({"Compte.Client.TypeClient" : "Particulier"}, { NumPret: 1, "Compte.Client.NumClient": 1, montantPret: 1, "Compte.Client.NomClient": 1 })


//Requete 6
db.Pret.updateMany(
  { 
    montantEcheance: { $ne: 0 }, // Echeance !=0
    $expr: { $lt: [{ $year: "$dateEffet" }, 2021] }
  },
  { $inc: { montantEcheance: 2000 } } 
)


//Requete 7
// Fonction de map 
var mapFunction = function() {
    emit(this.Agence.NumAgence, 1);
};

// Fonction de réduction :
var reduceFunction = function(key, values) {
    return Array.sum(values);
};

// Fonction finale 
var finalizeFunction = function(key, reducedValue) {
    return reducedValue;
};

// Options pour la phase de Map-Reduce :
var options = {
    out: "Agence-NbPrêts",
    finalize: finalizeFunction
};

// Exécuter la phase de Map-Reduce avec les fonctions de map, de réduction et les options spécifiées.
db.Pret.mapReduce(
    mapFunction,
    reduceFunction,
    options
);

// Interroge la collection et trie les résultats par ordre décroissant :
db["Agence-NbPrêts"].find().sort({value: -1});
