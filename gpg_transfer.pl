#!/usr/bin/env perl

use strict;
use warnings;
use v5.10;
use Data::Dumper;

use File::Basename qw(basename dirname);
use File::Find     qw(find);

my $usage = << 'EOF';

 usage: $0 [params] file

   Optional params:
     -h, --help        Show this help and exit
     -f, --to-key      GPG key to encrypt to
     -d, --dest-dir    Directory to put newly encrypted .gpg files in
     -s, --source-dir  Directory search for .gpg files

EOF

my $GPG='/usr/bin/gpg';
my %PARAMS = ( to_key   => '', to_dir   => '.', from_dir => '');

main();

#### SUBROUTINES #####

sub main {
  my $files = parse_args();
  my $infile;
  my $encrypt = gpg_encrypt($PARAMS{to_key});
  find_gpg_files($PARAMS{from_dir}, $files) if ($PARAMS{from_dir});
  foreach $infile (@{$files}) {
    my $decrypt = gpg_decrypt($infile);
    my $outfile = "$PARAMS{to_dir}/" . basename($infile);
    my $cmd =  "$decrypt | $encrypt > $outfile";
    say $cmd;
    #`$cmd`;
  }
}

sub find_gpg_files {
  my $dir     = shift;
  my $matches = shift;
  my $depth   = shift || 5;

  if ($depth <= 0) { return -1 }
  unless (-d $dir) { return 0 }
  
  opendir(DFH, $dir);
  my @files = readdir(DFH);
  closedir(DFH);
  foreach my $file (@files) {
    my $fpath = "$dir/$file";
    if (-f $fpath && $file =~ /gpg$/)   { push @{$matches}, $fpath }
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
    } else {
      push @posargs, $arg;
    }
  }
  return \@posargs;
}
