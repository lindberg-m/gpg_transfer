#!/usr/bin/env perl

use strict;
use warnings;

use File::Basename qw(basename dirname);

my $usage = << "EOF";

 usage: $0 [params] gpg-id [files]

 Decrypt and re-encrypt files with a specified GPG key.
 Either specify a directory to walk, checking for files ending with
 .gpg, and/or specify files as positional arguments on the command
 line

   Positional arguments:
     gpg-id            Hexadecimal GPG id to use for encryption
     files             Files to re-encrypt with new key, optional. 

   Optional params:
     -h, --help        Show this help and exit
     -d, --dest-dir    Directory to put newly encrypted .gpg files in
                       Default: current directory
     -s, --source-dir  Directory search for .gpg files
     -m, --max-depth   Maximum direcotory depth to search for .gpg files,
                       implies --source-dir. Default: 6
     -n, --no-decrypt  Don't decrypt anything, just encrypt
     -e, --no-encrypt  Don't encrypt anything, just decrypt
     --dry-run         Only print commands, don't run
     --force           Transfer file even if target already exist
     --verbose         Print commands to console before execution

EOF

my $GPG='/usr/bin/gpg';
my %PARAMS = ( gpg_id     => '',
               dest_dir   => '.',
               source_dir => '',
               no_decrypt => 0,
               no_encrypt => 0,
               dry_run    => 0,
               force      => 0,
               maxdepth   => 6
);


sub parse_args {
  my @posargs = ();
  my $arg;
  for (my $i = 0; $i < scalar @ARGV; $i++){
    $arg = $ARGV[$i];
    if ($arg =~ /^-/) {

      if    ($arg eq '-h' || $arg eq '--help')          { die $usage }
      elsif ($arg eq '-s' || $arg eq '--source-dir')    { $PARAMS{source_dir} = $ARGV[++$i] }
      elsif ($arg eq '-d' || $arg eq '--dest-dir')      { $PARAMS{dest_dir}   = $ARGV[++$i] }
      elsif ($arg eq '-m' || $arg eq '--max-depth')     { $PARAMS{maxdepth}   = $ARGV[++$i] }
      elsif ($arg eq '-n' || $arg eq '--no-decrypt')    { $PARAMS{no_decrypt} = 1 }
      elsif ($arg eq '-e' || $arg eq '--no-encrypt')    { $PARAMS{no_encrypt} = 1 }
      elsif ($arg eq '--dry-run')                       { $PARAMS{dry_run}    = 1 }
      elsif ($arg eq '--force')                         { $PARAMS{force}      = 1 }
      elsif ($arg eq '--verbose')                       { $PARAMS{verbose}    = 1 }
      else { die "${usage}Unregocnized argument: $arg\n" }

    } else {
      if ($PARAMS{gpg_id}) { push @posargs, $arg } else { $PARAMS{gpg_id}       = $arg      }
    }
  }
  return \@posargs;
}

# Check args:
my $files = parse_args();
die "${usage}No key specified\n"                                             unless $PARAMS{gpg_id};
die "${usage}Not a valid gpg id: $PARAMS{gpg_id}\n"                          unless $PARAMS{gpg_id} =~ /^[\da-f]+$/i;  # Only allow hexadecimal characters
die "${usage}Key not found: $PARAMS{gpg_id}\n"                               unless gpg_key_exist($PARAMS{gpg_id});
die "${usage}Max depth need to be an integer, not this: $PARAMS{maxdepth}\n" unless $PARAMS{maxdepth} =~ /^\d+$/;
die "${usage}Max depth implies --source-dir\n"                               if     (! $PARAMS{source_dir} && (grep /^-(m|-max-depth)$/, @ARGV));
die "${usage}Source directory not found\n"                                   if     ($PARAMS{source_dir}   && ! -d $PARAMS{source_dir});
die "${usage}Need to specify files and/or a source directory\n"              if     (scalar @$files == 0   && ! $PARAMS{source_dir});

# Program:
find_gpg_files($PARAMS{source_dir}, $files, $PARAMS{maxdepth}) if ($PARAMS{source_dir});
my $source_dir_nchar = length($PARAMS{source_dir});
foreach my $infile (@{$files}) {
  die "${usage}File does not exist\n" unless (-f $infile);
  my $outfile = "$PARAMS{dest_dir}/" . substr($infile, $source_dir_nchar); $outfile =~ s://+:/:g;

  print "Transfer $infile to $outfile\n" if $PARAMS{verbose};
  unless ($PARAMS{dry_run}) {

    if (! -d dirname($outfile)) { mkdir dirname($outfile) }
    if (-f $outfile && $PARAMS{force} == 0) {
      print STDERR "$outfile already exist, will not transfer $infile to $outfile (use --force to override)\n";
      next;
    }

    my ($DEC_FH, $ENC_FH, $buffer, $retcode) ;
    $PARAMS{no_decrypt} ? open($DEC_FH, '<', "$infile")  : open($DEC_FH, '-|', "$GPG --decrypt $infile");
    $PARAMS{no_encrypt} ? open($ENC_FH, '>', "$outfile") : open($ENC_FH, '|-', "$GPG --encrypt --recipient $PARAMS{gpg_id} > $outfile");

    while ($retcode = read($DEC_FH, $buffer, 1024)) { print $ENC_FH $buffer }
    print STDERR "Couldn't transfer $infile to $outfile: $!\n" unless defined $retcode;
    close($DEC_FH);
    close($ENC_FH);
  }
}

#### SUBROUTINES #####

sub gpg_key_exist {
  my $k = shift;
  `$GPG --list-keys $k`;
  return ($? == 0) ? 1 : 0;
}

sub find_gpg_files {
  my $dir     = shift;
  my $matches = shift;
  my $depth   = shift;

  if ($depth <= 0) { return -1 }
  unless (-d $dir) { return 0  }
  
  opendir(DFH, $dir);
  my @files = readdir(DFH);
  closedir(DFH);
  foreach my $file (@files) {
    my $fpath = "$dir/$file";
    if (-f $fpath && $file =~ /\.gpg$/) { push @{$matches}, $fpath }
    if ($file eq '.' || $file eq '..')  { next }
    if (-d $fpath )                     { find_gpg_files($fpath, $matches, $depth -1) }
  }
  return 1;
}

