package MP3::Find::Util;

use strict;
use warnings;

use base qw(Exporter);
use vars qw(@EXPORT_OK);

@EXPORT_OK = qw(build_query);

sub build_query {
    my @args = @_;
    
    # first find all the directories
    my @dirs;
    while (local $_ = shift @args) {
        if (/^-/) {
            # whoops, there's the beginning of the query
            unshift @args, $_;
            last;
        } else {
            push @dirs, $_;
        }
    }
    
    # now build the query hash
    my %query;
    my $field;
    while (local $_ = shift @args) {
        if (/^--?(.*)/) {
            $field = uc $1;
        } else {
            $field ? push @{ $query{$field} }, $_ : die "Need a field name before value '$_'\n";
        }
    }
    
    return (\@dirs, \%query);
}

# module return
1;
