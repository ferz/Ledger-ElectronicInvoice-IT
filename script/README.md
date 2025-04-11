# leggi_efatture.pl

Può limitarsi alla lettura e stampa dei dati con --dry-run

Può funzionare su un singolo file:

```
   perl leggi_efatture.pl --dry-run --file IT07242536616_Qw7jt.xml
```

Senza dry-run salverà i dati in un file .json
e creerà un link symbolico con il file originale della efattura ma nel nome sarà aggiunto:

```
   ${numero_fattura}_${data_fattura}_${denominazione_cliente}_Qw7jt.xml
```
Può funzionare su una directory:

```
   perl leggi_efatture.pl --dry-run --dir efatture/
```

In questo caso mostrerà i dati di ogni file IT*.xml

Senza dry-run scriverà in quella directory con i criteri come sopra descritti per il caso del
file singolo.

```
   perl leggi_efatture.pl --dry-run ANNO MESE
```

Userà il file di configurazione nominato leggi_efattura_config.json per sapere:
1. la directory dove trovare i file delle fatture di quel anno/mese
2. la directory di scrittura dove salvare il file .json con i dati e il link simbolico.

In realtà il file di configurazione può avere altre estensioni oltre a .json relative
ad altri formati di configurazione, se installati opportunamente i driver Config::Any relativi
come ad esempio Config::Any:TOML


## installazione librerie perl necessarie

l'elenco dei moduli/librerie sono all'inizio del file preceduti dal comando "use".

In genrale basta avere installato Perl ed eseguire:

```
  cpan Modern::Perl Config::Any Config::Any::JSON  Config::ZOMG
```

Comando che può essere ripetuto con un numero variabile di moduli da installare o aggiornare.
