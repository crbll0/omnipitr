package OmniPITR::Tools;
use strict;
use warnings;
use English qw( -no_match_vars );
use Carp;
use Digest::MD5;
use File::Temp qw( tempfile );
use base qw( Exporter );

our @EXPORT_OK = qw( file_md5sum run_command ext_for_compression );
our %EXPORT_TAGS = ( 'all' => \@EXPORT_OK );

sub ext_for_compression {
    my $compression = lc shift;
    return '.gz'   if $compression eq 'gzip';
    return '.bz2'  if $compression eq 'bzip2';
    return '.lzma' if $compression eq 'lzma';
    croak 'Unknown compression type: ' . $compression;
}

sub file_md5sum {
    my $filename = shift;

    my $ctx = Digest::MD5->new;

    open my $fh, '<', $filename or croak( sprintf( 'Cannot open file for md5summing %s : %s', $filename, $OS_ERROR ) );
    $ctx->addfile( $fh );
    my $md5 = $ctx->hexdigest();
    close $fh;

    return $md5;
}

sub run_command {
    my ( $temp_dir, @cmd ) = @_;

    my $real_command = join( ' ', map { quotemeta } @cmd );

    my ( $stdout_fh, $stdout_filename ) = tempfile( 'stdout.XXXXXX', 'DIR' => $temp_dir );
    my ( $stderr_fh, $stderr_filename ) = tempfile( 'stderr.XXXXXX', 'DIR' => $temp_dir );

    $real_command .= sprintf ' 2>%s >%s', quotemeta $stderr_filename, quotemeta $stdout_filename;

    my $reply = {};
    $reply->{ 'status' } = system $real_command;
    local $/ = undef;
    $reply->{ 'stdout' } = <$stdout_fh>;
    $reply->{ 'stderr' } = <$stderr_fh>;

    close $stdout_fh;
    close $stderr_fh;

    unlink( $stdout_filename, $stderr_filename );

    if ( $CHILD_ERROR == -1 ) {
        $reply->{ 'error_code' } = $OS_ERROR;
    }
    elsif ( $CHILD_ERROR & 127 ) {
        $reply->{ 'error_code' } = sprintf "child died with signal %d, %s coredump\n", ( $CHILD_ERROR & 127 ), ( $CHILD_ERROR & 128 ) ? 'with' : 'without';
    }
    else {
        $reply->{ 'error_code' } = $CHILD_ERROR >> 8;
    }

    return $reply;
}

1;