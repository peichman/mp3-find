package MP3::Find::Base;

use strict;
use warnings;

use vars qw($VERSION);
use Carp;

$VERSION = '0.01';

my %format_codes = (
    a => 'ARTIST',
    t => 'TITLE',
    b => 'ALBUM',
    n => 'TRACKNUM',
    y => 'YEAR',
    g => 'GENRE',
);

sub new {
    my $invocant = shift;
    my $class = ref $invocant || $invocant;
    my $self = {};
    bless $self, $class;
}

sub find_mp3s {
    my $self = shift;
    my %opt = @_;
    
    my $dir = $opt{dir} || $ENV{HOME};
    my @DIRS = ref $dir eq 'ARRAY' ? @$dir : ($dir);
    
    my %QUERY = %{ $opt{query} || {} };
    
    # array ref for multiple sort fields, but allow
    # a simple scalar for single values
    my @SORT = $opt{sort} ? 
        (ref $opt{sort} eq 'ARRAY' ? @{ $opt{sort} } : ($opt{sort})) :
        ();
    
    
    foreach (keys %QUERY) {
        # so we don't have spurious warnings when trying to match against undef
        delete $QUERY{$_} unless defined $QUERY{$_};
        # package everything unioformly, so subclasses don't need to unpack
        $QUERY{$_} = [ $QUERY{$_} ] unless ref $QUERY{$_} eq 'ARRAY';
    }
    
    # do the search
    my @results = $self->search(\%QUERY, \@DIRS, \@SORT, \%opt);
    
    # maybe they want the unformatted data
    return @results if $opt{no_format};
    
    if ($opt{printf}) {
        # printf style output format
        foreach (@results) {
            my $output = $opt{printf};
            for my $code (keys %format_codes) {
                
                while ($output =~ m/%((-\d)?\d*)$code/g) {
                    # field size modifier
                    my $modifier = $1 || '';
                    # figure out the size of the formating code
                    my $code_size = 2 + length($modifier);
                    my $value = sprintf("%${modifier}s", $_->{$format_codes{$code}} || '');
                    substr($output, pos($output) - $code_size, $code_size, $value);
                }
            }
            # to allow literal '%'
            $output =~ s/%%/%/g;        
            $_ = $output;
        }
    } else {
        # just the filenames, please
        @results = map { $_->{FILENAME} } @results;
    }
    
    return @results;
}

sub search {
    croak "Method 'search' not implemented in " . __PACKAGE__;
}

# module return
1;

=head1 NAME

MP3::Find - Search and sort MP3 files based on their ID3 tags

=head1 SYNOPSIS

    use MP3Find;
    
    print "$_\n" foreach find_mp3s(
        dir => '/home/peter/cds',
        query => {
            artist => 'ilyaimy',
            title => 'deep in the am',
        },
        ignore_case => 1,
        match_words => 1,
        sort => [qw(year album tracknum)],
        printf => '%2n. %a - %t (%b: %y)',
    );

=head1 DESCRIPTION

This module allows you to search for MP3 files by their ID3 tags.
You can ask for the results to be sorted by one or more of those
tags, and return either the list of filenames (the deault), a
C<printf>-style formatted string for each file using its ID3 tags,
or the actual Perl data structure representing the results.

=head1 REQUIRES

L<File::Find>, L<MP3::Info>, L<Scalar::Util>

L<DBI> and L<DBD::SQLite> are needed if you want to have a
database backend.

=head1 EXPORTS

=head2 find_mp3s

    my @results = find_mp3s(%options);

Takes the following options:

=over

=item C<dir>

Where to start the search. This can either be a single string or
an arrayref. Defaults to your home directory.

=item C<query>

Hashref of search parameters. Recognized fields are anything that
L<MP3::Info> knows about. Field names can be given in either upper
or lower case; C<find_mp3s> will convert them into upper case for 
you. Value may either be strings, which are converted into regular
exporessions, or may be C<qr[...]> regular expressions already.

=item C<ignore_case>

Ignore case when matching search strings to the ID3 tag values.

=item C<exact_match>

Adds an implicit C<^> and C<$> around each query string.

=item C<sort>

What field or fields to sort the results by. Can either be a single
scalar field name to sort by, or an arrayref of field names. Again,
acceptable field names are anything that L<MP3::Info> knows about.

=item C<printf>

By default, C<find_mp3s> just returns the list of filenames. The 
C<printf> option allows you to provide a formatting string to apply
to the data for each file. The style is roughly similar to Perl's
C<printf> format strings. The following formatting codes are 
recognized:

    %a - artist
    %t - title
    %b - album
    %n - track number
    %y - year
    %g - genre
    %% - literal '%'

Numeric modifers may be used in the same manner as with C<%s> in
Perl's C<printf>.

=item C<no_format>

Causes C<find_mp3s> to return an array of hashrefs instead of an array
of (formatted) strings. Each hashref consists of the key-value pairs
from C<MP3::Info::get_mp3_tag> and C<MP3::Info::get_mp3_info>, plus
the key C<FILENAME> (with the obvious value ;-)

    @results = (
        {
            FILENAME => ...,
            TITLE    => ...,
            ARTIST   => ...,
            ...
            SECS     => ...,
            BITRATE  => ...,
            ...
        },
        ...
    );

=back

=head1 TODO

More of a structured query would be nice; currently everything
is and-ed together, and it would be nice to be able to put query
keys together with a mixture of and and or.

Searching a big directory is slo-o-ow! Investigate some sort of 
caching of results?

The current sorting function is also probably quite inefficient.

=head1 SEE ALSO

See L<MP3::Info> for more information about the fields you can
search and sort on.

L<File::Find::Rule::MP3Info> is another way to search for MP3
files based on their ID3 tags.

=head1 AUTHOR

Peter Eichman <peichman@cpan.org>

=head1 COPYRIGHT AND LICENSE

Copyright (c) 2006 by Peter Eichman. All rights reserved.

This program is free software; you can redistribute it and/or
modify it under the same terms as Perl itself.

=cut
