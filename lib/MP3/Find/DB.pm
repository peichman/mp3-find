package MP3::Find::DB;

use strict;
use warnings;

use base qw(MP3::Find::Base);

use DBI;
use SQL::Abstract;

my $sql = SQL::Abstract->new;

sub search {
    my $self = shift;
    my ($query, $dirs, $sort, $options) = @_;
    
    my $dbh = DBI->connect("dbi:SQLite:dbname=$$options{db_file}", '', '');
    
    # use the 'LIKE' operator to ignore case
    my $op = $$options{ignore_case} ? 'LIKE' : '=';
    
    # add the SQL '%' wildcard to match substrings
    unless ($$options{exact_match}) {
        for my $value (values %$query) {
            $value = [ map { "%$_%" } @$value ];
        }
    }

    my ($where, @bind) = $sql->where(
        { map { $_ => { $op => $query->{$_} } } keys %$query },
        ( @$sort ? [ map { uc } @$sort ] : () ),
    );
    
    my $select = "SELECT * FROM mp3 $where";
    
    my $sth = $dbh->prepare($select);
    $sth->execute(@bind);
    
    my @results;
    while (my $row = $sth->fetchrow_hashref) {
        push @results, $row;
    }
    
    return @results;
}

# module return
1;

=head1 NAME

MP3::Find::DB - SQLite database backend to MP3::Find

=head1 SYNOPSIS

    use MP3::Find::DB;
    my $finder = MP3::Find::DB->new;
    
    my @mp3s = $finder->find_mp3s(
        dir => '/home/peter/music',
        query => {
            artist => 'ilyaimy',
            album  => 'myxomatosis',
        },
        ignore_case => 1,
    );

=head1 REQUIRES

L<DBI>, L<DBD::SQLite>, L<SQL::Abstract>

=head1 DESCRIPTION

This is the SQLite database backend for L<MP3::Find>.

B<Note:> I'm still working out some kinks in here, so this backend
is currently not as stable as the Filesystem backend.

=head2 Special Options

=over

=item C<db_file>

The name of the SQLite database file to use. Defaults to F<~/mp3.db>.

The database should have at least one table named C<mp3> with the
following schema:

    CREATE TABLE mp3 (
        mtime         INTEGER,
        FILENAME      TEXT, 
        TITLE         TEXT, 
        ARTIST        TEXT, 
        ALBUM         TEXT,
        YEAR          INTEGER, 
        COMMENT       TEXT, 
        GENRE         TEXT, 
        TRACKNUM      INTEGER, 
        VERSION       NUMERIC,
        LAYER         INTEGER, 
        STEREO        TEXT,
        VBR           TEXT,
        BITRATE       INTEGER, 
        FREQUENCY     INTEGER, 
        SIZE          INTEGER, 
        OFFSET        INTEGER, 
        SECS          INTEGER, 
        MM            INTEGER,
        SS            INTEGER,
        MS            INTEGER, 
        TIME          TEXT,
        COPYRIGHT     TEXT, 
        PADDING       INTEGER, 
        MODE          INTEGER,
        FRAMES        INTEGER, 
        FRAME_LENGTH  INTEGER, 
        VBR_SCALE     INTEGER
    );

=back

=head1 TODO

Move the database/table creation code from F<mp3db> into this
module.

Database maintanence routines (e.g. clear out old entries)

=head1 SEE ALSO

L<MP3::Find>, L<MP3::Find::DB>

=head1 AUTHOR

Peter Eichman <peichman@cpan.org>

=head1 COPYRIGHT AND LICENSE

Copyright (c) 2006 by Peter Eichman. All rights reserved.

This program is free software; you can redistribute it and/or
modify it under the same terms as Perl itself.

=cut
