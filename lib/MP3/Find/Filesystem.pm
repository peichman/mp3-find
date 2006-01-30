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
