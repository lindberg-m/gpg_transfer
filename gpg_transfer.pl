#!/usr/bin/env perl

use strict;
use warnings;
use v5.10;
use File::Basename qw(basename dirname);

my $usage = << 'EOF';

 usage: $0 [params] file

   Optional params:
     -h, --help        Show this help and exit
     -f, --to-key      GPG key to encrypt to
     -d, --dest-dir    Directory to put newly encrypted .gpg files in

EOF

my $GPG='/usr/bin/gpg';
my %PARAMS = ( to_key   => '',
               to_dir   => '.');

test();

#### SUBROUTINES #####

sub test {
  my $posargs = parse_args();
  my $infile;
  foreach $infile (@$posargs) {
    my $decode = gpg_decode($infile);
    my $encode = gpg_encode($PARAMS{to_key});

    my $outfile = "$PARAMS{to_dir}/" . basename($infile);
    my $cmd =  "$decode | $encode > $outfile";
    say $cmd;
    `$cmd`;
  }
}

sub gpg_decode {
  my $infile = shift;
  if (! -f $infile) { die "$usage\n\nFile does not exist: $infile" }
  return "$GPG --decrypt $infile";
}

sub gpg_encode {
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
