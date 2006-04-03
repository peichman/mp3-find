package MP3::Find::DB;

use strict;
use warnings;

use base qw(MP3::Find::Base);
use Carp;

use DBI;
use SQL::Abstract;

my $sql = SQL::Abstract->new;

my @COLUMNS = (
    [ mtime        => 'INTEGER' ],  # the filesystem mtime, so we can do incremental updates
    [ FILENAME     => 'TEXT' ], 
    [ TITLE        => 'TEXT' ], 
    [ ARTIST       => 'TEXT' ], 
    [ ALBUM        => 'TEXT' ],
    [ YEAR         => 'INTEGER' ], 
    [ COMMENT      => 'TEXT' ], 
    [ GENRE        => 'TEXT' ], 
    [ TRACKNUM     => 'INTEGER' ], 
    [ VERSION      => 'NUMERIC' ],
    [ LAYER        => 'INTEGER' ], 
    [ STEREO       => 'TEXT' ],
    [ VBR          => 'TEXT' ],
    [ BITRATE      => 'INTEGER' ], 
    [ FREQUENCY    => 'INTEGER' ], 
    [ SIZE         => 'INTEGER' ], 
    [ OFFSET       => 'INTEGER' ], 
    [ SECS         => 'INTEGER' ], 
    [ MM           => 'INTEGER' ],
    [ SS           => 'INTEGER' ],
    [ MS           => 'INTEGER' ], 
    [ TIME         => 'TEXT' ],
    [ COPYRIGHT    => 'TEXT' ], 
    [ PADDING      => 'INTEGER' ], 
    [ MODE         => 'INTEGER' ],
    [ FRAMES       => 'INTEGER' ], 
    [ FRAME_LENGTH => 'INTEGER' ], 
    [ VBR_SCALE    => 'INTEGER' ],
);

my $DEFAULT_STATUS_CALLBACK = sub {
    my ($action_code, $filename) = @_;
    print STDERR "$action_code $filename\n";
};

sub search {
    my $self = shift;
    my ($query, $dirs, $sort, $options) = @_;
    
    croak 'Need a database name to search (set "db_file" in the call to find_mp3s)' unless $$options{db_file};
    
    my $dbh = DBI->connect("dbi:SQLite:dbname=$$options{db_file}", '', '', {RaiseError => 1});
    
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

sub create_db {
    my $self = shift;
    my $db_file = shift or croak "Need a name for the database I'm about to create";
    my $dbh = DBI->connect("dbi:SQLite:dbname=$db_file", '', '', {RaiseError => 1});
    $dbh->do('CREATE TABLE mp3 (' . join(',', map { "$$_[0] $$_[1]" } @COLUMNS) . ')');
}

sub update_db {
    my $self = shift;
    my $db_file = shift or croak "Need the name of the database to update";
    my $dirs = shift;
    
    my $status_callback = $self->{status_callback} || $DEFAULT_STATUS_CALLBACK;
    
    my @dirs = ref $dirs eq 'ARRAY' ? @$dirs : ($dirs);
    
    my $dbh = DBI->connect("dbi:SQLite:dbname=$db_file", '', '', {RaiseError => 1});
    my $mtime_sth = $dbh->prepare('SELECT mtime FROM mp3 WHERE FILENAME = ?');
    my $insert_sth = $dbh->prepare(
        'INSERT INTO mp3 (' . 
            join(',', map { $$_[0] } @COLUMNS) .
        ') VALUES (' .
            join(',', map { '?' } @COLUMNS) .
        ')'
    );
    my $update_sth = $dbh->prepare(
        'UPDATE mp3 SET ' . 
            join(',', map { "$$_[0] = ?" } @COLUMNS) . 
        ' WHERE FILENAME = ?'
    );
    
    # the number of records added or updated
    my $count = 0;
    
    # look for mp3s using the filesystem backend
    require MP3::Find::Filesystem;
    my $finder = MP3::Find::Filesystem->new;
    for my $mp3 ($finder->find_mp3s(dir => \@dirs, no_format => 1)) {
        # see if the file has been modified since it was first put into the db
        $mp3->{mtime} = (stat($mp3->{FILENAME}))[9];
        $mtime_sth->execute($mp3->{FILENAME});
        my $records = $mtime_sth->fetchall_arrayref;
        
        warn "Multiple records for $$mp3{FILENAME}\n" if @$records > 1;
        
        #TODO: maybe print status updates somewhere else?
        if (@$records == 0) {
            $insert_sth->execute(map { $mp3->{$$_[0]} } @COLUMNS);
            $status_callback->(A => $$mp3{FILENAME});
            $count++;
        } elsif ($mp3->{mtime} > $$records[0][0]) {
            # the mp3 file is newer than its record
            $update_sth->execute((map { $mp3->{$$_[0]} } @COLUMNS), $mp3->{FILENAME});
            $status_callback->(U => $$mp3{FILENAME});
            $count++;
        }
    }
    
    # as a workaround for the 'closing dbh with active staement handles warning
    # (see http://rt.cpan.org/Ticket/Display.html?id=9643#txn-120724)
    foreach ($mtime_sth, $insert_sth, $update_sth) {
        $_->{RaiseError} = 0;  # don't die on error
        $_->{PrintError} = 0;  # ...and don't even say anything
        $_->{Active} = 1;
        $_->finish;
    }
    
    return $count;
}

sub sync_db {
    my $self = shift;
    my $db_file = shift or croak "Need the name of the databse to sync";

    my $status_callback = $self->{status_callback} || $DEFAULT_STATUS_CALLBACK;

    my $dbh = DBI->connect("dbi:SQLite:dbname=$db_file", '', '', {RaiseError => 1});
    my $select_sth = $dbh->prepare('SELECT FILENAME FROM mp3');
    my $delete_sth = $dbh->prepare('DELETE FROM mp3 WHERE FILENAME = ?');
    
    # the number of records removed
    my $count = 0;
    
    $select_sth->execute;
    while (my ($filename) = $select_sth->fetchrow_array) {
        unless (-e $filename) {
            $delete_sth->execute($filename);
            $status_callback->(D => $filename);
            $count++;
        }
    }
    
    return $count;    
}

sub destroy_db {
    my $self = shift;
    my $db_file = shift or croak "Need the name of a database to destory";
    unlink $db_file;
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
        db_file => 'mp3.db',
    );
    
    # you can do things besides just searching the database
    
    # create another database
    $finder->create_db('my_mp3s.db');
    
    # update the database from the filesystem
    $finder->update_db('my_mp3s.db', ['/home/peter/mp3', '/home/peter/cds']);
    
    # and then blow it away
    $finder->destroy_db('my_mp3s.db');

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

=head1 METHODS

=head2 new

    my $finder = MP3::Find::DB->new(
        status_callback => \&callback,
    );

The C<status_callback> gets called each time an entry in the
database is added, updated, or deleted by the C<update_db> and
C<sync_db> methods. The arguments passed to the callback are
a status code (A, U, or D) and the filename for that entry.
The default callback just prints these to C<STDERR>:

    sub default_callback {
        my ($status_code, $filename) = @_;
        print STDERR "$status_code $filename\n";
    }

To suppress any output, set C<status_callback> to an empty sub:

    status_callback => sub {}

=head2 create_db

    $finder->create_db($db_filename);

Creates a SQLite database in the file named c<$db_filename>.

=head2 update_db

    my $count = $finder->update_db($db_filename, \@dirs);

Searches for all mp3 files in the directories named by C<@dirs>
using L<MP3::Find::Filesystem>, and adds or updates the ID3 info
from those files to the database. If a file already has a record
in the database, then it will only be updated if it has been modified
sinc ethe last time C<update_db> was run.

=head2 sync_db

    my $count = $finder->sync_db($db_filename);

Removes entries from the database that refer to files that no longer
exist in the filesystem. Returns the count of how many records were
removed.

=head2 destroy_db

    $finder->destroy_db($db_filename);

Permanantly removes the database.

=head1 TODO

Database maintanence routines (e.g. clear out old entries)

Allow the passing of a DSN or an already created C<$dbh> instead
of a SQLite database filename; or write driver classes to handle
database dependent tasks (create_db/destroy_db).

=head1 SEE ALSO

L<MP3::Find>, L<MP3::Find::Filesystem>, L<mp3db>

=head1 AUTHOR

Peter Eichman <peichman@cpan.org>

=head1 COPYRIGHT AND LICENSE

Copyright (c) 2006 by Peter Eichman. All rights reserved.

This program is free software; you can redistribute it and/or
modify it under the same terms as Perl itself.

=cut
