#!/usr/bin/env perl

use strict;

use File::Basename;
use Cwd qw(realpath cwd);
use Data::Dumper;

# the global vars
my %cfg;
$cfg{'color'}{''} = '';
$cfg{'color'}{'err'} = '';
$cfg{'color'}{'warn'} = '';
$cfg{'color'}{'hl'} = '';
$cfg{'color'}{'Rhl'} = '';
$cfg{'color'}{'ita'} = '';
$cfg{'color'}{'Rita'} = '';
$cfg{'source'}{'original'} = 0;
$cfg{'source'}{'preproc'} = 0;
$cfg{'list'}{'files'} = 0;
$cfg{'list'}{'incdirs'} = 0;

my %files;
my %incdirs;
my $incdirorder=0;
my %includes;

# returns ANSI color sequence
sub color($)
{ my $c;
  return '' if $cfg{'color'}{''} eq ''; # colors not enabled
  if ($_[0] =~ /^\d+(;\d+)*$/)
  { $c = $_[0];
  }
  else
  { $c = $cfg{'color'}{$_[0]};
  }
  return '' if $c eq '';
  return "\e[${c}m";
}

# first process input args
while (my $a = shift)
{ if ($a eq '-c') # output in colors
  { $cfg{'color'}{''} = '0';
    $cfg{'color'}{'err'} = '31';
    $cfg{'color'}{'warn'} = '33';
    $cfg{'color'}{'hl'} = '1';
    $cfg{'color'}{'Rhl'} = '22';
    $cfg{'color'}{'ita'} = '3';
    $cfg{'color'}{'Rita'} = '23';
    $cfg{'color'}{'dbg'} = '34';
  }
  elsif ($a eq '--output-source')
  { $cfg{'source'}{'original'} = 1;
  }
  elsif ($a eq '--output-preprocessed-source')
  { $cfg{'source'}{'preproc'} = 1;
  }
  elsif ($a eq '--debug-files')
  { $cfg{'filedebug'} = 1;
  }
  elsif ($a eq '--list-files')
  { $cfg{'list'}{'files'} = 1;
  }
  elsif ($a eq '--list-incdirs')
  { $cfg{'list'}{'incdirs'} = 1;
  }
  elsif ($a eq '-h' or $a eq '--help')
  { print "Reads source files, analyses includes in them and prints that analysis to output.\n";
    print "Takes options but also expects definitions for files on standard input.\n\n";
    print "INPUT\n";
    print "Comprises of sections - each section starts with a line containing a name with a colon ':' after it,\n";
    print "each section ends with the special line containing only :END:\n";
    print "Available sections:\n";
    print "A) files\n";
    print "each line is a wildcard (with possible '*' and '?' characters) that specifies files to process\n";
    print "Example:\nfiles:\n  mydir/*.cpp\n  mydir/*.cc\n:END:\n";
    print "B) incdirs\n";
    print "each line is a directory where to search for the includes, the actual path can be prepended by\n";
    print "the keyword SYSTEM meaning it's a system include path instead of user include path.\n";
    print "The include dirs are processed in the order in which they are given (user path to come before system paths).\n";
    print "Example:\nincdirs:\n  mydir\n  SYSTEM /usr/include\n:END:\n";
    print "OPTIONS\n";
    print "-h or --help ... prints this help and exits\n";
    print "-c ... print output (and progress) in color\n";
    print "--list-files ... prints the files that matched given patterns and exits\n";
    print "--list-incdirs ... prints the read include directories and exits\n";
    print "Few other debugging options:\n";
    print "--output-source ... output the source files as they are read\n";
    print "--output-preprocessed-source ... output the source files after comments are stripped\n";
    print "--debug-files ... prints debug messages as sources are read/closed\n";
    exit 0;
  }
  else
  { print STDERR color('err')."Invalid argument '".color('ita').$a.color('Rita')."'.\n".color('');
    exit 1
  }
}

# process the input - definition where to search and what
my $state = '';
while (<STDIN>)
{ chomp;
  s/#.*$//;
  s/^\s+//;
  s/\s+$//;
  next if /^$/;

  if ($state eq '')
  { if (/^(files|incdirs):$/)
    { $state = $1;
    }
    else
    { print STDERR color('err')."Invalid input.\n".color('ita')."$_\n".color('');
      exit 1;
    }
  }
  elsif ($_ =~ /^:END:$/)
  { $state = '';
  }
  elsif ($state eq 'files')
  { my @f = glob($_);
    my $fc = @f;
    if ($fc == 0)
    { print STDERR color('warn')."The pattern '$_' did not match any files.\n".color('');
      next;
    }
    for my $fi (@f)
    { next if -d $fi;
      my $ff = realpath($fi);
      $files{$ff}{''} = 1;
    }
  }
  elsif ($state eq 'incdirs')
  { my $d;
    my $s;
    if (/^SYSTEM\s+(.*)/)
    { $d = $1;
      $s = 1;
    }
    else
    { $d = $_;
      $s = 0;
    }
    if (! -d $d)
    { print STDERR color('warn')."No such directory '$_'.\n".color('');
      next;
    }
    $incdirs{$d}{''} = $incdirorder++;
    $incdirs{$d}{'system'} = $s;
  }
}
if ($state ne '')
{ print STDERR color('warn')."Missing ':END:' line.\n".color('');
}

my $endbeforemain = 0;
if ($cfg{'list'}{'files'} > 0)
{ $endbeforemain = 1;
  for my $f (sort keys %files)
  { print "FILE: $f\n";
  }
}

if ($cfg{'list'}{'incdirs'} > 0)
{ $endbeforemain = 1;
  for my $f (sort { $incdirs{$a}{''} <=> $incdirs{$b}{''} } keys %incdirs)
  { print "INCDIR: $f\n";
  }
}

exit(0) if $endbeforemain > 0;

# tries to locate an include file (next to the source file or on defined include paths)
# 0 ... the include file to locate (name or relpath, unpredictable with abspath)
# 1 ... the directory in which the including source is located
# 2 ... whether it's a <> system (true) or "" user (false) include
sub locateinclude($$$)
{ my $inc = $_[0];
  my $locdir = $_[1];
  my $sys = $_[2];
  my $fnd = '';
  my $fnds = 0;
  # try locating on "known" paths, start with local
  if (not $sys and -e "$locdir/$inc" and not -d "$locdir/$inc")
  { $fnd = realpath("$locdir/$inc");
  }
  else
  { for my $id (sort { $incdirs{$a}{''} <=> $incdirs{$b}{''} } keys %incdirs)
    { next if $sys and $incdirs{$id}{'system'} == 0;
      if (-e "$id/$inc" and not -d "$id/$inc")
      { $fnd = realpath("$id/$inc");
        $fnds = $incdirs{$id}{'system'};
        last;
      }
    }
    return ('',1) if $fnd eq '';
  }

  if ($includes{$fnd}{'cnt'} > 0)
  { $includes{$fnd}{'cnt'} = $includes{$fnd}{'cnt'} + 1;
  }
  else
  { $includes{$fnd}{'cnt'} = 1;
  }
  return ($fnd,$fnds);
}

# reads a C/C++ source file and extracts #include directives, recurses into included files
sub processsrc($)
{ print color('dbg')."FILE OPEN '$_[0]'\n".color('') if $cfg{'filedebug'} > 0;
  my $af = $_[0];
  my ($fn, $dn, $suf) = fileparse($af);
  $dn = realpath($dn);
  my $f;
  unless (open($f, '<', $af))
  { $files{$af}{'status'} = 'fail';
    print color('err')."FILE FAIL '$af'\n".color('') if $cfg{'filedebug'} > 0;
    return 0;
  }
  $files{$af}{'includes'} = ();
  my $state = '';
  my $line = 0;
  while (<$f>)
  { $line++;
    print if $cfg{'source'}{'original'} > 0;
    if ($state eq '')
    { s/\/\*.*\*\///; # remove all inline /* */ comments
      s/\/\/.*//; # remove all one line // comments
      if (/\/\*/)
      { $state = 'comment';
        s/\/\*.*//; # remove beginning of multiline comment
      }
    }
    elsif ($state eq 'comment')
    { if (/\*\//)
      { s/.*?\*\///; # remove end of multiline comment
        $state = '';
      }
      else
      { $_ = ''; # in the middle of multiline comment
      }
    }
    print if $cfg{'source'}{'preproc'} > 0;

    if (/^\s*#\s*include\s*(<|")(.*?)(>|")/)
    { my $sys = $1 eq '<' or $3 eq '>';
      my ($ri, $s) = locateinclude($2, $dn, $sys); # tries to find file on filesystem and inserts to includes, returns real path of include (or empty if not found)
      my $ip = $ri;
      $ip = $2 if $ip eq '';
      print color('36')."INCLUDE: $2 = $ri\n".color('') if $cfg{'filedebug'} > 0;
      push @{$files{$af}{'includes'}}, $ip;
      $includes{$af}{'includes'} = () unless defined $includes{$af}{'includes'};
      push @{$includes{$af}{'includes'}}, $ip;
      if ($ri eq '')
      { print STDERR color('warn')."Failed to locate include '$2' at $af:$line.\n".color('');
        next;
      }
      $includes{$ri}{'files'}{"$af:$line"} = $_;
      next if $s > 0; # do not recurse into system includes
      processsrc($ri) unless $includes{$ri}{'cnt'} > 1 or $files{$ri}{'status'} ne '';
    }
  }
  $files{$af}{'status'} = 'ok';
  print color('dbg')."FILE DONE '$af'\n".color('') if $cfg{'filedebug'} > 0;
  close($f);
}

####################
# ACTUAL PROGRAM START

# process all matched files first (will recurse into any other non-system includes)
for my $x (keys %files)
{ processsrc($x) unless $includes{$x}{'cnt'} > 1 or $files{$x}{'status'} ne '';
}

# for all matched files calculate the indirect includes
my @visited;
my @gather;
sub gatherindirectincludes($)
{ my $inc = $_[0];

  return if grep { $_ eq $inc } @visited;
  push @visited, $inc;
  return unless defined($includes{$inc}{'includes'}) and scalar(@{$includes{$inc}{'includes'}})>0;;
  for my $fi (@{$includes{$inc}{'includes'}})
  { push @gather, $fi unless grep { $_ eq $fi } @gather;
    gatherindirectincludes($fi);
  }
}
for my $f (keys %files)
{ @visited=();
  @gather=();
  gatherindirectincludes($f);
  $files{$f}{'indirect'} = ();
  for my $x (@gather)
  { push @{$files{$f}{'indirect'}}, $x;
  }
}

my $cd = cwd();
$cd = "$cd/" unless $cd =~ /\/$/;

# print the list of files (with their direct and includes)
print color('ita').color('33')."DIRECT INCLUSIONS:\n".color('');
print color('ita').color('33')."==================\n".color('');
for my $x (sort keys %files)
{ my $rp = $x;
  $rp =~ s/^$cd//;
  print color('hl')."$rp (";
  if (defined($files{$x}{'includes'}) and scalar(@{$files{$x}{'includes'}})>0)
  { my @a = @{$files{$x}{'includes'}};
    print scalar(@a)."): ".color('');
    for my $i (@a)
    { $i =~ s/^$cd//;
    }
    print join(', ', sort @a) 
  }
  else
  { print "0):".color('');
  }
  print "\n";
}

# print the list of files (with their direct and indirect includes)
print color('ita').color('33')."ALL INCLUSIONS:\n".color('');
print color('ita').color('33')."===============\n".color('');
for my $x (sort keys %files)
{ my $rp = $x;
  $rp =~ s/^$cd//;
  print color('hl')."$rp (";
  if (defined($files{$x}{'indirect'}) and scalar(@{$files{$x}{'indirect'}})>0)
  { my @a = @{$files{$x}{'indirect'}};
    print scalar(@a),"): ".color('');
    for my $i (@a)
    { $i =~ s/^$cd//;
    }
    print join(', ', sort @a) 
  }
  else
  { print "0):".color('');
  }
  print "\n";
}

# print the individual found includes (in increasing order of inclusions)
print color('ita').color('33')."INCLUSION COUNTS:\n".color('');
print color('ita').color('33')."=================\n".color('');
for my $inc (sort { $includes{$a}{'cnt'} <=> $includes{$b}{'cnt'} } keys %includes)
{ my $tmp = $inc;
  $tmp =~ s/^$cd//;
  next unless $includes{$inc}{'cnt'} > 0 or (defined($includes{$inc}{'files'}) and scalar(keys %{$includes{$inc}{'files'}})>0);
  print color('36')."INCLUDE: $includes{$inc}{'cnt'} - ".color('hl')."$tmp\n".color('');
  if (defined($includes{$inc}{'files'}) and scalar(keys %{$includes{$inc}{'files'}})>0)
  { for my $iloc (sort keys %{$includes{$inc}{'files'}})
    { my $tmp = $iloc;
      $tmp =~ s/^$cd//;
      print color('hl')."\t$tmp: ".color('Rhl').$includes{$inc}{'files'}{$iloc};
    }
  }
}

# print the individual includes and all their inclusion (in increasing order of inclusions)
print color('ita').color('33')."ALL INCLUSION COUNTS:\n".color('');
print color('ita').color('33')."=====================\n".color('');
my %all;
for my $inc (keys %includes)
{ $all{$inc}{'cnt'} = 0;
  @{$all{$inc}{'files'}} = ();
  for my $f (keys %files)
  { next unless grep { $_ eq $inc } @{$files{$f}{'indirect'}};
    $all{$inc}{'cnt'}++;
    push @{$all{$inc}{'files'}}, $f;
  }
}
for my $inc (sort { $all{$a}{'cnt'} <=> $all{$b}{'cnt'} } keys %all)
{ my $tmp = $inc;
  $tmp =~ s/^$cd//;
  next unless $all{$inc}{'cnt'} > 0 or (defined($all{$inc}{'files'}) and scalar(@{$all{$inc}{'files'}})>0);
  print color('36')."INCLUDE: $all{$inc}{'cnt'} - ".color('hl')."$tmp\n".color('');
  for my $iloc (sort @{$all{$inc}{'files'}})
  { my $tmp = $iloc;
    $tmp =~ s/^$cd//;
    print color('hl')."\t$tmp\n".color('');
  }
}
