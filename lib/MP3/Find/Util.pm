package MP3::Find::Util;

use strict;
use warnings;

use base qw(Exporter);
use vars qw(@EXPORT_OK);

@EXPORT_OK = qw(build_query get_mp3_metadata);

use Carp;
use MP3::Info;

eval { require MP3::Tag };
my $CAN_USE_ID3V2 = $@ ? 0 : 1;

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

sub get_mp3_metadata {
    my $args = shift;

    my $filename = $args->{filename} or croak "get_mp3_metadata needs a 'filename' argument";
    
    my $mp3 = {
        FILENAME => $filename,
        # ID3v2 tags, if present, override ID3v1 tags
        %{ get_mp3tag($filename, 0, 2)  || {} },
        %{ get_mp3info($filename)       || {} },
    };

    return $mp3;
}

# module return
1;
