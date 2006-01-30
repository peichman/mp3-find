package MP3::Find::Filesystem;

use strict;
use warnings;

use base 'MP3::Find::Base';

use File::Find;
use MP3::Info;
use Scalar::Util qw(looks_like_number);

use_winamp_genres();

sub search {
    my $self = shift;
    my ($query, $dirs, $sort, $options) = @_;
    
    # prep the search patterns as regexes
    foreach (keys(%$query)) {
        my $ref = ref $$query{$_};
        # make arrays into 'OR' searches
        if ($ref eq 'ARRAY') {
            $$query{$_} = '(' . join('|', @{ $$query{$_} }) . ')';
        }
        # convert to a regex unless it already IS a regex        
        unless ($ref eq 'Regexp') {
            $$query{$_} = "^$$query{$_}\$" if $$options{exact_match};
            $$query{$_} = $$options{ignore_case} ? qr[$$query{$_}]i : qr[$$query{$_}];
        }
    }
    
    # run the actual find
    my @results;
    find(sub { match_mp3($File::Find::name, $query, \@results) }, $_) foreach @$dirs;
    
    # sort the results
    if (@$sort) {
        @results = sort {
            my $compare;
            foreach (map { uc } @$sort) {
                # use Scalar::Util to do the right sort of comparison
                $compare = (looks_like_number($a->{$_}) && looks_like_number($b->{$_})) ?
                    $a->{$_} <=> $b->{$_} :
                    $a->{$_} cmp $b->{$_};
                # we found a field they differ on
                last if $compare;
            }
            return $compare;
        } @results;
    }
    
    return @results
}

sub match_mp3 {
    my ($filename, $query, $results) = @_;
    
    return unless $filename =~ m{[^/]\.mp3$};
    my $mp3 = {
        FILENAME => $filename,
        %{ get_mp3tag($filename)  || {} },
        %{ get_mp3info($filename) || {} },
    };
    for my $field (keys(%{ $query })) {
        my $value = $mp3->{uc($field)};
        return unless defined $value;
        return unless $value =~ $query->{$field};
    }
    
    push @{ $results }, $mp3;
}

# module return
1;

=head1 NAME

MP3::Find::Filesystem - File::Find-based backend to MP3::Find

=head1 SYNOPSIS

    use MP3::Find::Filesystem;
    my $finder = MP3::Find::Filesystem->new;
    
    my @mp3s = $finder->find_mp3s(
        dir => '/home/peter/music',
        query => {
            artist => 'ilyaimy',
            album  => 'myxomatosis',
        },
        ignore_case => 1,
    );

=head1 REQUIRES

L<File::Find>, L<MP3::Info>, L<Scalar::Util>

=head1 DESCRIPTION

This module implements the C<search> method from L<MP3::Find::Base>
using a L<File::Find> based search of the local filesystem.

=head2 Special Options

There are no special options for B<MP3::Find::Filesystem>. See
L<MP3::Find> for the description of the general options.

=head1 SEE ALSO

L<MP3::Find>, L<MP3::Find::DB>

=head1 AUTHOR

Peter Eichman <peichman@cpan.org>

=head1 COPYRIGHT AND LICENSE

Copyright (c) 2006 by Peter Eichman. All rights reserved.

This program is free software; you can redistribute it and/or
modify it under the same terms as Perl itself.

=cut
