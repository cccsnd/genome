#!/usr/bin/env genome-perl

BEGIN {
    $ENV{NO_LSF} = 1;
    $ENV{UR_DBI_NO_COMMIT} = 1;
    $ENV{UR_USE_DUMMY_AUTOGENERATED_IDS} = 1;
};

use strict;
use warnings;

use above 'Genome';
use Test::More;

use_ok('Genome::Model::Tools::Relationship::MergeAndFixVcfs');

my $test_data_dir = $ENV{GENOME_TEST_INPUTS} .
        '/Genome-Model-Tools-Relationship-MergeAndFixVcfs';

my $input_denovo = join('/', $test_data_dir, 'DS10000.denovo.vcf.gz');
my $input_standard = join('/', $test_data_dir, 'DS10000.standard.vcf.gz');
my $expected_dir = "$test_data_dir/expected.v3";
my $expected = join('/', $expected_dir, 'DS10000.merged.vcf.gz');

ok(-s $input_denovo, "input denovo vcf file output $input_denovo exists");
ok(-s $input_standard,
        "input standard vcf file output $input_standard exists");
ok(-s $expected, "expected merged vcf file $expected exists");

my $output_dir = File::Temp::tempdir('Relationship-MergeAndFixVcfsXXXXX',
        CLEANUP => 1, TMPDIR => 1);
my $output_vcf = join('/', $output_dir, 'merged.output.vcf');

my $cmd = Genome::Model::Tools::Relationship::MergeAndFixVcfs->create(
        denovo_vcf=> $input_denovo,
        standard_vcf => $input_standard,
        output_vcf => $output_vcf,
);
ok($cmd->execute(), 'executed filter command');

ok(-s $output_vcf, "denovo vcf output exists and has size");
my $diff = Genome::Utility::Vcf::diff_vcf_file_vs_file(
        $expected, $output_vcf);
ok(!$diff, 'got expected results') or diag($diff);

done_testing();
1;
