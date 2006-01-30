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
