#!/usr/bin/perl
#	Abstract coloring pages generator
#
#	(c) 2022 Maria Matejka <mq@jmq.cz>
#
#	License: GNU GPL 2

use common::sense;
use Data::Dump;
use Cairo;

my $N = int $ARGV[0];

srand $N * 4743637;
sub intrand {
  return int ( $_[0] * rand );
}

my $mm = 72 / 25.4;
my $PI = atan2(1,1) * 4;

my $xpaper = 210 * $mm;
my $ypaper = 297 * $mm;

my $surface = Cairo::PdfSurface->create("abstract$N.pdf", $xpaper, $ypaper);
my $cr = Cairo::Context->create($surface);
$cr->translate($xpaper/2, $ypaper/2);
$cr->rotate($PI/2);
$cr->set_line_width(0.4);

my $radius = 90 * $mm;
my $rad_gran = 37;
my $rotsym = 6;
my $tan_gran = 17;
my $starlike = 0;

my $circ_tan_gran = $rotsym * 2 * $tan_gran;
my $endlen = $radius * 2 * $PI / $circ_tan_gran;

my @lastline = ( [ 0, 0 ] );
my @points = ( [ @lastline ] );

sub nextcnt {
  my ($loc_arcseg, $lastcnt) = @_;
  return 2 if $lastcnt == 1;
  return 3 if $lastcnt == 2;
  return $lastcnt - 1 if $lastcnt > $tan_gran;
  return $lastcnt - 1 if $loc_arcseg / ($lastcnt + 1) < $endlen / 2;
  return $lastcnt + 1 if $loc_arcseg / ($lastcnt - 1) > $endlen * 2;
  return $lastcnt - 1 + 2 * intrand(2);
}

sub randrad {
  my ($loc_rad) = @_;
  return $loc_rad + (rand - 0.5) * (0.8 * $radius / $rad_gran);
}

sub randang {
  my ($loc_ang) = @_;
  return $loc_ang + (rand - 0.5) * $PI / ($rotsym * $tan_gran * 1.5);
}

sub randbits {
  my ($count) = @_;
  my @out;
  for (my $i=0; $i<$count; $i++) {
    push @out, (0.35 > rand);
  }
  return @out;
}

for (my $i = 1; $i < $rad_gran; $i++) {
  my $loc_rad = $i * $radius / $rad_gran;
  my $loc_arcseg = $loc_rad * $PI / $rotsym;
  my $lastcnt = scalar @lastline;

  my $nextcnt = nextcnt($loc_arcseg, $lastcnt);

  my @nextline;
  if ($lastline[0][1] == 0) {
    my $angpart = $PI / ($rotsym * $nextcnt);
    for (my $i = 0; $i < $nextcnt; $i++) {
      push @nextline, [ randrad($loc_rad), randang(($i+0.5) * $angpart) ];
    }
  } else {
    my $angpart = $PI / ($rotsym * ($nextcnt - 1));
    push @nextline, [ randrad($loc_rad), 0 ];
    for (my $i = 1; $i < $nextcnt - 1; $i++) {
      push @nextline, [ randrad($loc_rad), randang($i * $angpart) ];
    }
    push @nextline, [ randrad($loc_rad), ($nextcnt - 1) * $angpart ];
  }

  push @points, [ @nextline ];
  @lastline = @nextline;
}

if ($starlike) {
  while (@lastline > 1) {
    my $loc_rad = (scalar @points) * $radius / $rad_gran;
    my $nextcnt = @lastline - 1;
    my @nextline;
    for (my $i = 0; $i < $nextcnt; $i++) {
      push @nextline, [ randrad($loc_rad), randang(($lastline[$i][1] + $lastline[$i+1][1]) / 2) ];
    }

    push @points, [ @nextline ];
    @lastline = @nextline;
  }
}

dd [ @points ];

for (my $i = 1; $i < @points; $i++) {
  my @lastline = @{$points[$i-1]};
  my @curline = @{$points[$i]};

  my @curblock = randbits(scalar @curline - 1);

  for (my $rot = 0; $rot < $rotsym; $rot++) {
    $cr->rotate(2 * $PI / $rotsym);

    for (my $flip = -1; $flip < 2; $flip += 2) {
      $cr->save;
      $cr->rotate($curline[0][1] * $flip);
      $cr->move_to(0, $curline[0][0]);
      $cr->restore;
      for (my $p = 1; $p < @curline; $p++) {
	$cr->save;
	$cr->rotate($curline[$p][1] * $flip);
	if ($curblock[$p-1]) {
	  $cr->line_to(0, $curline[$p][0]);
	} else {
	  $cr->move_to(0, $curline[$p][0]);
	}
	$cr->restore;
      }
      $cr->stroke;
    }
  }

  my @wave;
  if (@lastline > @curline) {
    while (@lastline and @curline) {
      push @wave, (pop @lastline);
      push @wave, (pop @curline);
    }
    push @wave, pop @lastline;
  }
  else {
    while (@lastline and @curline) {
      push @wave, (pop @curline);
      push @wave, (pop @lastline);
    }
    push @wave, pop @curline;
  }

  die if @lastline or @curline;
  
  my @wblock = randbits(scalar @wave - 1);

  for (my $rot = 0; $rot < $rotsym; $rot++) {
    $cr->rotate(2 * $PI / $rotsym);

    for (my $flip = -1; $flip < 2; $flip += 2) {
      $cr->save;
      $cr->rotate($wave[0][1] * $flip);
      $cr->move_to(0, $wave[0][0]);
      $cr->restore;
      for (my $p = 1; $p < @wave; $p++) {
	$cr->save;
	$cr->rotate($wave[$p][1] * $flip);
	if ($wblock[$p-1]) {
	  $cr->line_to(0, $wave[$p][0]);
	} else {
	  $cr->move_to(0, $wave[$p][0]);
	}
	$cr->restore;
      }
      $cr->stroke;
    }
  }

}
