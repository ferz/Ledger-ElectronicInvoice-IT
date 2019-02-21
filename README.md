# Ledger-ElectronicInvoice-IT
From Italian Electronic Invoice XML format to ledger-cli record.

I like ledger-cli for my book keeping, and I would like to use code to record incoming invoices.

Ho una directory contenente le fatture elettroniche scaricate dalla PEC e gia' separate in due file:

* Metadati
* Fattura

Ho provato a generare con XML::Pastor i file delle classi dall'XML Schema dell'agenzia delle Entrate, ma il tool ha subito riscontrato un paio di errori formali:

1) :7: namespace error : Namespace prefix xsd on import is not defined
2) http://www.w3.org/TR/2002/REC-xmldsig-core-20020212/xmldsig-core-schema.xsd a questa url non c'e' piu' lo schema, pare da tempo.


Il testo fa riferimento ad un aggiornamento alla versione 1.2.1 dell'XML Schema di ottobre 2018, vedi pagina:
https://www.fatturapa.gov.it/export/fatturazione/it/normativa/f-2.htm

ma il link porta ad una versione 1.2 non a una 1.2.1.

https://fatturapa.gov.it/export/fatturazione/sdi/fatturapa/v1.2/Schema_del_file_xml_FatturaPA_versione_1.2.xsd

    <?xml version="1.0" encoding="utf-8"?>
    <xs:schema xmlns:xs="http://www.w3.org/2001/XMLSchema"
               xmlns:ds="http://www.w3.org/2000/09/xmldsig#" 
	             xmlns="http://ivaservizi.agenziaentrate.gov.it/docs/xsd/fatture/v1.2" 
	             targetNamespace="http://ivaservizi.agenziaentrate.gov.it/docs/xsd/fatture/v1.2" 
	             version="1.2">
    <xsd:import namespace="http://www.w3.org/2000/09/xmldsig#"
                schemaLocation="http://www.w3.org/TR/2002/REC-xmldsig-core-20020212/xmldsig-core-schema.xsd"/>

La cosa carina è che perfino l'editor mi segnale di rosso "xsd" nell'elemento qui sopra.

Sono esterefatto :scream: che nonostante ci abbiano lavorato da mesi questo XML Schema contenga ancora degli errori. 
