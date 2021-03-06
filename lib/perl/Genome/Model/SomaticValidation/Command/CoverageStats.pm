package Genome::Model::SomaticValidation::Command::CoverageStats;

use strict;
use warnings;

use File::Path qw(rmtree);

use Genome;

class Genome::Model::SomaticValidation::Command::CoverageStats {
    is => ['Genome::Model::SomaticValidation::Command::WithMode'],

    has_param => [
        lsf_queue => {
            default => Genome::Config::get('lsf_queue_build_worker'),
        },
    ],
    has_optional_output => [
        reference_coverage_result_id => {
            is => 'Number',
            doc => 'ID of the result from running this step',
        },
    ],
    has_optional => [
        reference_coverage_result => {
            is => 'Genome::InstrumentData::AlignmentResult::Merged::CoverageStats',
            id_by => 'reference_coverage_result_id',
            doc => 'The result from running this step',
        },
    ],
    doc => 'runs ref-cov on the bam(s) produced in the alignment step',
};

sub sub_command_category { 'pipeline steps' }

sub shortcut {
    my $self = shift;

    unless($self->should_run) {
        $self->debug_message('Sample not specified on build; skipping.');
        return 1;
    }

    my %params = $self->params_for_result;
    my $result = Genome::InstrumentData::AlignmentResult::Merged::CoverageStats->get_with_lock(%params);

    if($result) {
        $self->debug_message('Using existing result ' . $result->__display_name__);
        return $self->link_result_to_build($result);
    } else {
        return;
    }
}

sub execute {
    my $self = shift;
    my $build = $self->build;

    unless($self->should_run) {
        $self->debug_message('Sample not specified on build; skipping.');
        return 1;
    }

    unless($self->_reference_sequence_matches) {
        die $self->error_message;
    }

    my %params = (
        $self->params_for_result,
        log_directory => $build->log_directory,
    );

    my $result = Genome::InstrumentData::AlignmentResult::Merged::CoverageStats->get_or_create(%params);

    $self->link_result_to_build($result);

    my $as_ref = $result->alignment_summary_hash_ref;
    unless ($as_ref) {
        $self->error_message('Failed to load the alignment summary metrics!');
        die($self->error_message);
    }
    my $cov_ref = $result->coverage_stats_summary_hash_ref;
    unless ($cov_ref) {
        $self->error_message('Failed to load the coverage summary metrics!');
        die($self->error_message);
    }

    return 1;
}

sub _reference_sequence_matches {
    my $self = shift;

    my $roi_list = $self->build->region_of_interest_set;
    my $roi_reference = $roi_list->reference;
    my $reference = $self->build->reference_sequence_build;

    unless($roi_reference) {
        $self->error_message('no reference set on region of interest ' . $roi_list->name);
        return;
    }

    unless ($roi_reference->is_compatible_with($reference)) {
        if(Genome::Model::Build::ReferenceSequence::Converter->exists_for_references($roi_reference, $reference)) {
            $self->debug_message('Will run converter on ROI list.');
        } else {
            $self->error_message('reference sequence: ' . $reference->name . ' does not match the reference on the region of interest: ' . $roi_reference->name);
            return;
        }
    }

    return 1;
}

sub should_run {
    my $self = shift;

    return unless $self->build->region_of_interest_set;
    return $self->SUPER::should_run;
}

sub params_for_result {
    my $self = shift;
    my $build = $self->build;
    my $pp = $build->processing_profile;

    my $alignment_result = $self->alignment_result_for_mode;

    my $fl = $build->region_of_interest_set;

    my $result_users = Genome::SoftwareResult::User->user_hash_for_build($build);

    return (
        alignment_result_id => $alignment_result->id,
        region_of_interest_set_id => $fl->id,
        minimum_depths => $pp->refcov_minimum_depths,
        wingspan_values => $pp->refcov_wingspan_values,
        minimum_base_quality => ($pp->refcov_minimum_base_quality || 0),
        minimum_mapping_quality => ($pp->refcov_minimum_mapping_quality || 0),
        use_short_roi_names => $pp->refcov_use_short_names,
        merge_contiguous_regions => $pp->refcov_merge_roi_regions,
        roi_track_name => ($pp->refcov_roi_track_name || undef),
        test_name => (Genome::Config::get('software_result_test_name') || undef),
        users => $result_users,
    );
}

sub link_result_to_build {
    my $self = shift;
    my $result = shift;
    $self->reference_coverage_result($result);
    return $self->SUPER::link_result_to_build($result, "coverage", "coverage_stats");
}

sub add_metrics_to_build {
    #override parent method so metrics aren't added
    return 1;
}

1;
