#!/usr/bin/perl -w
use strict;

use Test::More 'no_plan'; #tests => 4;
BEGIN { use_ok('MP3::Find::Filesystem') };

my $SEARCH_DIR = 't/mp3s';
my $MP3_COUNT = 0;

# exercise the object

my $finder = MP3::Find::Filesystem->new;
isa_ok($finder, 'MP3::Find::Filesystem');

# a most basic search:
my @res = $finder->find_mp3s(dir => $SEARCH_DIR);
is(scalar(@res), $MP3_COUNT, 'dir as scalar');

@res = $finder->find_mp3s(dir => [$SEARCH_DIR]);
is(scalar(@res), $MP3_COUNT, 'dir as ARRAY ref');

#TODO: get some test mp3s
