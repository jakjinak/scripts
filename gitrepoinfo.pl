#!/usr/bin/env perl

use strict;
my $p;
my $gitdir;
open($p, "-|", "git rev-parse --git-dir 2> /dev/null") or exit(1);
while(<$p>)
{ chomp;
  $gitdir = $_;
}
close($p);
exit(1) if "$gitdir" eq ''; # not within git repo
# now sure that inside of git repo

# check the current branch first
my $branch;
open($p, "-|", "git rev-parse --symbolic-full-name HEAD 2> /dev/null") or exit(0);
while(<$p>)
{ chomp;
  $branch=$_;
}
close($p);
exit(0) if $branch eq '';
my $rbranch;
open($p, "-|", "git rev-parse --abbrev-ref --symbolic-full-name '\@{u}' 2> /dev/null") or exit(0);
while(<$p>)
{ chomp;
  $rbranch=$_;
}
close($p);
$rbranch='' if $rbranch eq '@{u}';
$branch =~ s/^refs\/heads\///;
print "\033[1;37m";
print "\033[101mMERGE\033[49m " if -e $gitdir."/MERGE_HEAD";
print "$branch";
if ($rbranch eq '')
{ print "\033[1;36m>\033[22;35m<no-remote>\033[33m" ;
}
elsif ($rbranch ne "origin/$branch")
{ print "\033[1;36m>\033[22;33m$rbranch\033[1m";
}

my @r; # this contains the individual '|' separated fields

# check the status against know remotes
sub remotestatus
{ my $remote = $_[0];
  my $branch = $_[1];
  my $branchd = $_[2];
  open(my $p, "-|", "git rev-list --left-right --count \"$branch...$remote/$branch\" 2> /dev/null") or return 1;
  while(<$p>)
  { if (/\s*(\d+)\s+(\d+)\s*/)
    { my $ahead = $1;
      my $behind = $2;
      next unless $ahead>0 or $behind>0;
      my $txt="";
      $txt.="\033[32m+$ahead" if $ahead>0;
      $txt.="\033[33m-$behind" if $behind>0;
      $txt.="\033[22;37m vs $remote/$branchd\033[1;36m";
      push @r, "$txt";
    }
  }
  close($p);
}

if (open($p, "-|", "git remote show"))
{ # iterate through remotes
  while(<$p>)
  { chomp;
    my $remote = $_;
    remotestatus($remote,$branch,'');
    my $master = 'master';
    $master = $ENV{'GITMASTERBRANCH'} if $ENV{'GITMASTERBRANCH'} ne '';
    remotestatus($remote,$master,$master) unless $branch eq $master;
  }
  close($p);
}

# finally check the local changes
my $stag=0;
my $mod=0;
my $untr=0;
my $soth=0;
my $moth=0;
if (open($p, "-|", "git status --porcelain -uall"))
{ while(<$p>)
  { if (/^(\?.|.\?)\s+/)
    { $untr++;
      next;
    }
    if (/^ .\s+/)
    {
    }
    elsif (/^(A|M|D|R|C|U).\s+/)
    { $stag++;
    }
    else { $soth++; }
    if (/^. \s+/)
    {
    }
    elsif (/^.(A|M|D|R|C|U)\s+/)
    { $mod++;
    }
    else { $moth++; }
  }
  close($p);
}
push @r, "\033[32mstaged:$stag\033[36m" if $stag>0;
push @r, "\033[31mmodified:$mod\033[36m" if $mod>0;
push @r, "\033[33muntracked:$untr\033[36m" if $untr>0;
push @r, "\033[35mother:$soth+$moth\033[36m" if $soth>0 or $moth>0;

# print the result
print "\033[1;36m||".join("|", @r);
print "\033[1;36m";
