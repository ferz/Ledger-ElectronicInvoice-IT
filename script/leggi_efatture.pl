#!/usr/bin/env perl
use strict;
use warnings;
use feature 'say';
use utf8;
use open qw(:std :utf8);
use XML::LibXML;
use Config::ZOMG;
use JSON::PP;
use File::Basename;
use File::Path qw(make_path);
use File::Spec;
use Getopt::Long;

=encoding UTF-8

=head1 DESCRIZIONE

Questo script elabora file XML di fatture elettroniche italiane, estrae i dati rilevanti
e li salva in file JSON associati.
In modalità --dry-run verrà mostrato il path e nome di salvataggio dei file, in realtà il nome
parlante è solo un link al file relativo.
Specificando un file, esso verrà lavorato nella directory dove si trova già il file.
Specificando una directory, i file verrano lavorati in quella e in quella stessa salvati.
Se invece si fornisce anno e mese (numerico) userà i percorsi specificati dal file di configurazione
per trovarli e per salvare i file .json e relativo link alla fattura originale.
I file XML originali vengono linkati in una directory di destinazione con nomi normalizzati.

=head2 Perché?

I file delle fatture elettroniche sono in formato XML che è comodo per le elaborazioni,
ma non altrettanto per gli umani.

=cut

if (0 == scalar @ARGV ) {
    die("Uso: $0 [--dry-run] [--file FILE] [--dir FILE] ANNO MESE\n");
}

my $cfg = Config::ZOMG->new(name => substr("$0", 0 ,-3) . "_config");
my $config = $cfg->load;

# ==== CONFIGURAZIONE ====
my $BASE_EFATTURE = $config->{dir_destinazione_fatture};
my $BASE_PARLANTI = $config->{dir_destinazione_fatture_parlanti};

# ==== OPZIONI CLI ====
my $dry_run = 0;

my $src_dir;
my $dest_dir;
my @files;

my ($anno, $mese, $single_file, $single_dir);
GetOptions(
    "dry-run"     => \$dry_run,
    "file=s"      => \$single_file,
    "dir=s"      => \$single_dir,
) or die "Uso: $0 [--dry-run] [--file FILE] [--dir FILE] ANNO MESE\n";

if ($single_file) {
    my ($file);
    ($file, $src_dir) = File::Basename::fileparse($single_file);
    $dest_dir = File::Basename::dirname($single_file);
    @files = ($file);
} elsif ($single_dir) {
    $src_dir=$single_dir;
    $dest_dir=$single_dir;
    opendir my $dh, $src_dir or die "Impossibile aprire $src_dir: $!";
    @files = grep { /^IT.*\.xml$/i && -f "$src_dir/$_" } readdir $dh;
    closedir $dh;
} else {
    ($anno, $mese) = @ARGV;
    $mese = sprintf "%02d", $mese;

    # ==== PERCORSI ====
    $src_dir  = File::Spec->catdir($BASE_EFATTURE, $anno, $mese);
    $dest_dir = File::Spec->catdir($BASE_PARLANTI, $anno, $mese);
    make_path($dest_dir) unless -d $dest_dir;
    
    opendir my $dh, $src_dir or die "Impossibile aprire $src_dir: $!";
    @files = grep { /^IT.*\.xml$/i && -f "$src_dir/$_" } readdir $dh;
    closedir $dh;
}

# ==== PARSER XML ====
my $parser = XML::LibXML->new();

# ==== PROCESSA FILE XML ====
foreach my $file (@files) {
    my $fullpath = File::Spec->catfile($src_dir , $file);
    my $doc;
    eval { $doc = $parser->parse_file($fullpath); };
    if ($@) {
	warn "Errore nel parsing del file '$file': $@\n";
        next;
    }

    # Estrazione metadati
    my $data = extract_data($doc, '//DatiGeneraliDocumento/Data', '');
    my $numero = extract_data($doc, '//DatiGeneraliDocumento/Numero', '');

    # Estrai anche il cessionario (cioè noi, se autofattura)
    my $cedente_den = extract_data($doc, '//CedentePrestatore/DatiAnagrafici/Anagrafica/Denominazione');
    my $cedente_nazione = extract_data($doc, '//CedentePrestatore/DatiAnagrafici/IdFiscaleIVA/IdPaese');
    
    my $comm     = extract_data($doc, '//CessionarioCommittente/DatiAnagrafici/Anagrafica/Denominazione');
    my $piva     = extract_data($doc, '//CessionarioCommittente/DatiAnagrafici/IdFiscaleIVA/IdCodice');
    my $progr    = extract_data($doc, '//ProgressivoInvio');

    #Estrazione dati aggiuntivi
    my $importo   = extract_data($doc, '//DatiGeneraliDocumento/ImportoTotaleDocumento');
    my $pagamento = extract_data($doc, '//DatiPagamento/DettaglioPagamento/ModalitaPagamento');
    my $iban      = extract_data($doc, '//DatiPagamento/IBAN');

    my $tipodoc    = extract_data($doc, '//DatiGeneraliDocumento/TipoDocumento');
    my $causale    = extract_data($doc, '//DatiGeneraliDocumento/Causale');
    my $bollo      = extract_data($doc, '//DatiBollo/BolloVirtuale');
    my $importoBollo = extract_data($doc, '//DatiBollo/ImportoBollo');

    my $importo_pagato = extract_data($doc, '//DatiPagamento/DettaglioPagamento/ImportoPagamento');
    
    # Estrai le linee di dettaglio
    my ($linee, $iva_raggruppata) = estrai_linee_e_iva($doc);
    
    # Normalizzazione nomi per filesystem
    my $numero_fs = $numero; $numero_fs =~ s{[^\w\-]}{}g;
    my $comm_fs   = $comm;   $comm_fs   =~ s{[^[:alnum:]]}{}g;
    $comm_fs = camel_case($comm_fs);

    my $nome_link = sprintf(
			    "%s_%s_%s_%s.xml",
			    $data,
			    normalize_filename($numero_fs, 50),
			    normalize_filename($comm_fs, 50),
			    $progr
			   );
    
    my $link_path = File::Spec->catfile($dest_dir, $nome_link);

    my $json_path = $link_path;
    $json_path =~ s/\.xml$/.meta.json/;

    my %metadati =
	(
	 file_originale => $file,
	 percorso_originale => $fullpath,
	 dataFattura => $data,
	 numero => $numero,
	 committente => {
			 denominazione => $comm,
			 piva => $piva,
			},
	 progressivoInvio => $progr,
	 tipoDocumento => $tipodoc,
	 causale => $causale || undef,
	 bollo => $bollo eq 'SI' ? {
				    virtuale => 1,
				    importo  => format_number($importoBollo,2),
				   } : undef,
	 importoTotaleDocumento => format_number($importo,2),
	 modalitaPagamento => $pagamento,
	 iban => $iban,
	 linee => $linee,
	 aliquoteIVA => $iva_raggruppata,
	 importoPagato => format_number($importo_pagato, 2),
	);

    if ($tipodoc =~ /^TD1[789]/) {
	$metadati{cedente} = {
		     denominazione => $cedente_den,
		     nazione => $cedente_nazione,
		     };
    }

    
    if ($dry_run) {
        say "[DRY] Link: $link_path";
        say "[DRY] JSON: $json_path";
	say JSON::PP->new->utf8->pretty->encode(\%metadati);
        next;
    }

    if (-e $link_path) {
	warn "Attenzione: il file '$link_path' esiste già. Saltato.\n";
	next;
    }

    symlink $fullpath, $link_path or warn "Impossibile creare link: $!";


    save_json($json_path, \%metadati);
}


# ==== UTILITIES ====

sub save_json {
    my ($path, $data) = @_;
    open my $fh, '>:encoding(UTF-8)', $path or die "Impossibile aprire '$path': $!";
    print $fh JSON::PP->new->utf8->pretty->encode($data);  # Formattazione leggibile
    close $fh or warn "Errore durante la chiusura del file '$path': $!";
}

sub text_or_empty {
    my ($doc, $xpath) = @_;
    my ($node) = $doc->findnodes($xpath);
    return $node ? $node->textContent : '';
}

sub trim {
    my $s = shift // '';
    $s =~ s/^\s+|\s+$//g;
    return $s;
}

sub camel_case {
    my $s = shift // '';
    # $s = lc($s);
    $s =~ s/\b(\w)/\U$1/g;
    return $s;
}

sub text_or_empty_node {
    my ($node, $xpath) = @_;
    my ($found) = $node->findnodes($xpath);
    return $found ? $found->textContent : '';
}


sub normalize_filename {
    my ($name, $max_length) = @_;
    $name = camel_case($name);
    $name =~ s/[^\w\s\-.]/_/g;  # Mantieni lettere, numeri, spazi, punti e trattini
    $name =~ s/\s+/_/g;         # Sostituisci spazi multipli con un singolo underscore
    $name =~ s/^_+|_+$//g;      # Rimuovi eventuali underscore all'inizio o alla fine
    $name = substr($name, 0, $max_length) if defined $max_length && length($name) > $max_length;
    return $name;
}

sub format_number {
    my ($value, $precision) = @_;
    return sprintf("%.${precision}f", $value + 0);
}

sub extract_data {
    my ($doc, $xpath, $default) = @_;
    my ($node) = $doc->findnodes($xpath);
    return defined $node ? trim($node->textContent) : $default // '';
}

sub aggregate_iva {
    my ($linee) = @_;
    my %iva_raggruppata;
    for my $linea (@$linee) {
        my $aliqiva = $linea->{aliquotaIVA};
        $iva_raggruppata{$aliqiva}{righe}++;
        $iva_raggruppata{$aliqiva}{imponibile} += $linea->{imponibile};
        $iva_raggruppata{$aliqiva}{iva} += $linea->{iva};
    }
    return \%iva_raggruppata;
}

sub estrai_linee_e_iva {
    my ($doc) = @_;
    my @linee;

    for my $dettaglio ($doc->findnodes('//DettaglioLinee')) {
        my $descr   = extract_data($dettaglio, './Descrizione');
        my $qta     = format_number(extract_data($dettaglio, './Quantita'), 2);
        my $prezzo  = format_number(extract_data($dettaglio, './PrezzoUnitario'), 2);
        my $aliqiva = format_number(extract_data($dettaglio, './AliquotaIVA'), 0);
        my $imponibile = format_number($qta * $prezzo, 2);
        my $iva = format_number($imponibile * $aliqiva / 100, 2);

        push @linee, {
            descrizione    => $descr,
            quantita       => $qta,
            prezzoUnitario => $prezzo,
            aliquotaIVA    => $aliqiva,
            imponibile     => $imponibile,
            iva            => $iva,
        };
    }

    my $iva_raggruppata = aggregate_iva(\@linee);
    
    return (\@linee, $iva_raggruppata);
}
