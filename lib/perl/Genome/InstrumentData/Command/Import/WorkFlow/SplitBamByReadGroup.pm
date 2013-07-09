package Genome::InstrumentData::Command::Import::WorkFlow::SplitBamByReadGroup;

use strict;
use warnings;

use Genome;

require IO::File;
require List::MoreUtils;

class Genome::InstrumentData::Command::Import::WorkFlow::SplitBamByReadGroup { 
    is => 'Command::V2',
    has_input => [
        bam_path => {
            is => 'Text',
            doc => 'The path of the unsorted bam to sort.',
        }
    ],
    has_output => [ 
        read_group_bam_paths => {
            is => 'Text',
            is_many => 1,
            doc => 'The paths of the read group bams.',
        },
    ],
};

sub execute {
    my $self = shift;
    $self->status_message('Spilt bam by read group...');

    my $headers = $self->_load_headers;
    return if not $headers; 
    
    my @read_group_ids = keys %{$headers->{read_groups}};
    if ( not @read_group_ids or @read_group_ids == 1 ) {
        $self->read_group_bam_paths([ $self->bam_path ]);
        return 1;
    }

    my $read_group_fhs = $self->_open_file_handles_for_each_read_group_bam(keys %{$headers->{read_groups}});
    return if not $read_group_fhs;

    my $write_headers_ok = $self->_write_headers_to_read_group_bams($read_group_fhs, $headers);
    return if not $write_headers_ok;

    my $write_reads_ok = $self->_write_reads($read_group_fhs);
    return if not $write_reads_ok;

    my $verify_read_count_ok = $self->_verify_read_count;
    return if not $verify_read_count_ok;

    $self->status_message('Spilt bam by read group...done');
    return 1;
}

sub _load_headers {
    my $self = shift;
    $self->status_message('Load headers...');

    my $bam_path = $self->bam_path;
    $self->status_message("Bam path: $bam_path");
    my $headers_fh = IO::File->new("samtools view -H $bam_path |");
    if ( not $headers_fh ) {
        $self->error_message('Failed to open file handle to samtools command!');
        return;
    }

    my $headers = {};
    while ( my $line = $headers_fh->getline ) {
        if ( $line =~ /^\@RG/ ) {
            $line =~ m/ID:(.*?)\t/;
            $headers->{read_groups}->{$1} = $line;
        }
        else {
            push @{$headers->{all}}, $line;
        }
    }
    $headers_fh->close;

    $self->status_message('Load headers...done');
    return $headers;
}

sub _open_file_handles_for_each_read_group_bam {
    my ($self, @read_group_ids) = @_;
    $self->status_message('Open file handle for each read group bam...');

    Carp::confess('No read group ids to open bams!') if not @read_group_ids;

    $self->status_message('Read group count: '.@read_group_ids);
    my (%read_group_fhs, @read_group_bam_paths);
    for my $read_group_id ( @read_group_ids ){
        my $read_group_bam_path = $self->bam_path;
        $read_group_bam_path =~ s/\.bam$//;
        $read_group_bam_path .= '.'.$read_group_id.'.bam';
        push @read_group_bam_paths, $read_group_bam_path;
        my $fh = IO::File->new("| samtools view -S -b -o $read_group_bam_path -");
        if ( not $fh ) {
            $self->error_message('Failed to open file handle to samtools command!');
            return;
        }
        $read_group_fhs{$read_group_id} = $fh;
    }
    $self->read_group_bam_paths(\@read_group_bam_paths);

    $self->status_message('Open file handle for each read group bam...done');
    return \%read_group_fhs;
}

sub _write_headers_to_read_group_bams {
    my ($self, $read_group_fhs, $headers) = @_;

    Carp::confess('No read group fhs to write headers to bams!') if not $read_group_fhs;
    Carp::confess('No headers to write to bams!') if not $headers;

    for my $read_group_id ( keys %$read_group_fhs ) {
        $read_group_fhs->{$read_group_id}->print( join('', @{$headers->{all}}) );
        $read_group_fhs->{$read_group_id}->print( $headers->{read_groups}->{$read_group_id} );
    }

    return 1;
}

sub _write_reads {
    my ($self, $read_group_fhs) = @_;
    $self->status_message('Write reads...');

    my $bam_path = $self->bam_path;
    $self->status_message("Bam path: $bam_path");
    my $bam_fh = IO::File->new("samtools view $bam_path |");
    if ( not $bam_fh ) {
        $self->error_message('Failed to open file handle to samtools command!');
        return;
    }

    while ( my $line = $bam_fh->getline ) {
        $line =~ m/\sRG:Z:(.*?)\s/;
        my $read_group_id = $1;
        $read_group_id //= 'unknown';
        $read_group_fhs->{$read_group_id}->print($line);
    }

    for my $fh ( $bam_fh, values %$read_group_fhs ) {
        $fh->close;
    }

    $self->status_message('Write reads...done');
    return 1;
}

sub _verify_read_count {
    my $self = shift;
    $self->status_message('Verify read count...');

    my $helpers = Genome::InstrumentData::Command::Import::WorkFlow::Helpers->get;

    my @read_group_bam_paths = $self->read_group_bam_paths;
    my $read_count = 0;
    for my $read_group_bam_path ( @read_group_bam_paths ) {
        print Data::Dumper::Dumper($read_group_bam_path);
        my $flagstat = $helpers->run_flagstat($read_group_bam_path);
        return if not $flagstat;
        $read_count += $flagstat->{total_reads};
    }

    my $original_flagstat = $helpers->load_flagstat($self->bam_path.'.flagstat');
    return if not $original_flagstat;

    $self->status_message('Original bam read count: '.$original_flagstat->{total_reads});
    $self->status_message('Read group bams read count: '.$read_count);

    if ( $original_flagstat->{total_reads} != $read_count ) {
        $self->error_message('Original and read group bam read counts do not match!');
        return;
    }

    $self->status_message('Verify read count...done');
    return 1;
}


1;

