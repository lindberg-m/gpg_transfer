#!/usr/bin/env perl

use strict;
use warnings;
use v5.10;
use Data::Dumper;

use File::Basename qw(basename dirname);
use File::Find     qw(find);

my $usage = << "EOF";

 usage: $0 [params] [file]

   Optional params:
     -h, --help        Show this help and exit
     -f, --to-key      GPG key to encrypt to
     -d, --dest-dir    Directory to put newly encrypted .gpg files in
     -s, --source-dir  Directory search for .gpg files
     --dry-run         Only print commands, don't run
     --force           Transfer file even if target already exist

EOF

my $GPG='/usr/bin/gpg';
my %PARAMS = ( to_key   => '', to_dir   => '.', from_dir => '',
               dry_run => 0, force => 0);

main();

#### SUBROUTINES #####

sub main {
  my $files = parse_args();
  my $infile;
  my $encrypt_cmd = gpg_encrypt($PARAMS{to_key});
  find_gpg_files($PARAMS{from_dir}, $files) if ($PARAMS{from_dir});
  my $from_dir_nchar = length($PARAMS{from_dir});
  foreach $infile (@{$files}) {
    my $decrypt_cmd = gpg_decrypt($infile);
    my $outfile = "$PARAMS{to_dir}/" . substr($infile, $from_dir_nchar); $outfile =~ s://+:/:g;
    if (outfile_is_ok($outfile)) {
      my $cmd =  "$decrypt_cmd | $encrypt_cmd > $outfile";
      say $cmd;
      #`$cmd`;
    } else {
      say STDERR "File $outfile already exist, will not transfer $infile to $outfile (use --force to override)";
    }
  }
}

sub outfile_is_ok {
  my $fpath = shift;
  my $force = shift || 0;
  
  if (-f $fpath) { return $force ? 1 : 0; }

  my $dname = dirname($fpath);
  mkdir $dname unless (-d $dname);
  return 1;
}

sub find_gpg_files {
  my $dir     = shift;
  my $matches = shift;
  my $depth   = shift || 5;

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

sub gpg_decrypt {
  my $infile = shift;
  if (! -f $infile) { die "$usage\n\nFile does not exist: $infile" }
  return "$GPG --decrypt $infile";
}

sub gpg_encrypt {
  my $gpg_id = shift;
  if     ($gpg_id =~ /![\da-f]/i) { die "${usage}Not a valid gpg id: $gpg_id" }
  unless ($gpg_id =~ /[\da-f]/i ) { die "${usage}Not a valid gpg id: $gpg_id" }
  return "$GPG --encrypt --recipient $gpg_id"
}

sub parse_args {
  my @posargs;
  my $arg;
  for (my $i = 0; $i < scalar @ARGV; $i++){
    $arg = $ARGV[$i];
    if ($arg =~ /^-/) {
      if ($arg eq '-h' || $arg eq '--help')       { die $usage }
      if ($arg eq '-t' || $arg eq '--to-key')     { $PARAMS{to_key}   = $ARGV[++$i] }
      if ($arg eq '-s' || $arg eq '--source-dir') { $PARAMS{from_dir} = $ARGV[++$i] }
      if ($arg eq '-d' || $arg eq '--dest-dir')   { $PARAMS{to_dir}   = $ARGV[++$i] }
      if ($arg eq '--dry-run')                    { $PARAMS{dry_run}  = $ARGV[++$i] }
      if ($arg eq '--force')                      { $PARAMS{force}  = $ARGV[++$i] }
    } else {
      push @posargs, $arg;
    }
  }
  return \@posargs;
}
