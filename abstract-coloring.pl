#!/usr/bin/perl
#	Abstract coloring pages generator
#
#	(c) 2022 Maria Matejka <mq@jmq.cz>
#
#	License: GNU GPL 2

use common::sense;
use Data::Dump;
use Cairo;
use List::Util qw(shuffle);

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
my $rotsym = 6;
my $starlike = 0;

#my $rad_gran = 20;
#my $tan_gran = 12;

my $rad_gran = 37;
my $tan_gran = 41;

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

  say "nextcnt: $nextcnt";

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

my $area_id = 1;
my $dummy_center_area = { size => 0, id => -1 };
my @areas = ( [ $dummy_center_area, $dummy_center_area ] );
my @area_index;

sub set_neigh {
  my ($a, $b) = @_;

  say "setting neighbor $a->{id} $b->{id}";
  push @{$a->{neigh}}, $b;
  push @{$b->{neigh}}, $a;
}

for (my $p = 1; $p < @points; $p++) {
  say "p=$p";
  my (@al_down, @al_up);
  my @alup_prev = @{$areas[@areas-1]};

  my $areas_cnt = scalar @{$points[$p]} + (($points[$p][0][1] == 0) ? (-1) : 1);

  my $three_more = ($areas_cnt - 3 == scalar @alup_prev);
  my $three_less = ($areas_cnt + 3 == scalar @alup_prev);
  my $three = $three_more || $three_less;

  if ($three_more) {
    my $plus_area = { size => 1, id => $area_id++, };
    push @al_down, $plus_area;
    push @al_up, $plus_area unless $p == @points - 1;
  }
  say "three $three";

  for (my $a = $three_more; $a < $areas_cnt-$three_more; $a++) {
    my $area_down = { size => 1, id => $area_id++, };

    if (@alup_prev > $areas_cnt) {
      # If the previous line is larger, both adjacent areas are there
      say "previous larger $p $a $areas_cnt";
      set_neigh($area_down, $alup_prev[$a+$three]);
      set_neigh($area_down, $alup_prev[$a+1+$three]);
    } else {
      # Otherwise, the border areas have only one neighbor
      say "previous smaller $p $a $areas_cnt";
      set_neigh($area_down, $alup_prev[$a-1-$three]) unless ($a == $three);
      set_neigh($area_down, $alup_prev[$a-$three]) unless ($a == $areas_cnt - 1 - $three);
    }

    push @al_down, $area_down;
    push @area_index, $area_down;

    next if $p == @points - 1;

    my $area_up = { size => 1, id => $area_id++, };
    set_neigh($area_down, $area_up);

    push @al_up, $area_up;
    push @area_index, $area_up;
  }

  if ($three_more) {
    my $plus_area = { size => 1, id => $area_id++, };
    push @al_down, $plus_area;
    push @al_up, $plus_area unless $p == @points - 1;

    say "previous much smaller $p";
    set_neigh($al_down[0], $al_down[1]);
    set_neigh($al_down[$areas_cnt-1], $al_down[$areas_cnt-2]);
  }

  if ($three_less) {
    say "previous much bigger $p";
    set_neigh($alup_prev[0], $alup_prev[1]);
    set_neigh($alup_prev[@alup_prev-1], $alup_prev[@alup_prev-2]);
  }

  say "adding areas";
  dump_areas(@al_down);
  dump_areas(@al_up);

  push @areas, [@al_down];
  push @areas, [@al_up] unless $p == @points - 1;
}

#dd [ @areas ];

my $randindex = intrand(scalar @area_index);
#$area_index[$randindex]->{id} = $area_index[$randindex]->{neigh}[0]->{id};

sub dump_areas {
  my @nums;
  foreach my $a (@_) {
    push @nums, $a->{id};
  }

  say "Areas: ", join ", ", @nums;
}

sub check_neigh_ {
  my ($a, $b) = @_;

  foreach my $n (@{$a->{neigh}}) {
    return if $n == $b;
  }
  
  die "$a->{id} doesn't have a neighbor $b->{id}";
}

sub check_neigh {
  my ($a, $b) = @_;

  check_neigh_($a, $b);
  check_neigh_($b, $a);
}

say "Total number of areas: " . (scalar @areas);
foreach my $a (@areas) {
  dump_areas(@$a);
}

my @prev_up = @{shift @areas};
dump_areas(@prev_up);

for (my $i = 1; $i < @points; $i++) {
  say "Total number of areas: " . (scalar @areas);

  my @lastline = @{$points[$i-1]};
  my @curline = @{$points[$i]};

  my @al_down = @{shift @areas};
  my @al_up = @{shift @areas};

  printf "%d %d %d %d %d\n", $i, scalar @lastline, scalar @curline, scalar @al_down, scalar @prev_up;

  say "Prev Up:";
  dump_areas(@prev_up);
  say "Down:";
  dump_areas(@al_down);
  say "Up:";
  dump_areas(@al_up);

  my $shifted = $curline[0][1] != 0;
  say "shifted" if $shifted;

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
	#	say "al_down/up $p";
	check_neigh($al_down[$p-1+$shifted], $al_up[$p-1+$shifted]) unless $i == @points - 1;
	if (($i == @points - 1) or ($al_down[$p-1+$shifted]->{id} != $al_up[$p-1+$shifted]->{id})) {
	  $cr->line_to(0, $curline[$p][0]);
	} else {
	  say "moveto $i $p";
	  $cr->move_to(0, $curline[$p][0]);
	}
	$cr->restore;
      }
      $cr->stroke;
    }
  }

  my @wave;
  my @wblock;

  if (@lastline > @curline) {
    while (@lastline and @curline) {
      push @wave, (pop @lastline);
      push @wave, (pop @curline);
    }
    push @wave, pop @lastline;
  } else {
    while (@lastline and @curline) {
      push @wave, (pop @curline);
      push @wave, (pop @lastline);
    }
    push @wave, pop @curline;
  }

  if (@al_down > @prev_up) {
    push @wblock, (pop @al_down) if scalar @al_down == 3 + scalar @prev_up;
    while (@al_down and @prev_up) {
      push @wblock, (pop @al_down);
      push @wblock, (pop @prev_up);
    }
    push @wblock, (pop @al_down);
    push @wblock, (pop @al_down) if @al_down;
  } else {
    push @wblock, (pop @prev_up) if scalar @prev_up == 3 + scalar @al_down;
    while (@al_down and @prev_up) {
      push @wblock, (pop @prev_up);
      push @wblock, (pop @al_down);
    }
    push @wblock, (pop @prev_up);
    push @wblock, (pop @prev_up) if @prev_up;
  }

  say "Wblock:";
  dump_areas(@wblock);

  die sprintf "%d %d %d %d", scalar @lastline, scalar @curline, scalar @al_down, scalar @prev_up if @lastline or @curline or @al_down or @prev_up;

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
	check_neigh($wblock[$p], $wblock[$p-1]);
	if ($wblock[$p]->{id} != $wblock[$p-1]->{id}) {
	  $cr->line_to(0, $wave[$p][0]);
	} else {
	  say "moveto $i $p $wblock[$p]->{id} $wblock[$p-1]->{id}";
	  $cr->move_to(0, $wave[$p][0]);
	}
	$cr->restore;
      }
      $cr->stroke;
    }
  }

  @prev_up = @al_up;
}
