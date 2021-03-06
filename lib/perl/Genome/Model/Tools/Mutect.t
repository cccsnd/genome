#!/usr/bin/env genome-perl

use strict;
use warnings;

BEGIN {
    $ENV{UR_DBI_NO_COMMIT} = 1;
    $ENV{UR_USE_DUMMY_AUTOGENERATED_IDS} = 1;
};

use File::Path;
use File::Temp;
use Test::More;
use above 'Genome';
use Genome::SoftwareResult;
use Genome::Utility::Test qw(compare_ok);

my $archos = `uname -a`;
if ($archos !~ /64/) {
    plan skip_all => "Must run from a 64-bit machine";
}

use_ok('Genome::Model::Tools::Mutect');

my $tumor =  Genome::Config::get('test_inputs') . "/Genome-Model-Tools-Mutect/v2/tiny.tumor.bam";
my $normal = Genome::Config::get('test_inputs') . "/Genome-Model-Tools-Mutect/v2/tiny.normal.bam";
my $expected_out = Genome::Config::get('test_inputs') . "/Genome-Model-Tools-Mutect/v2/expected.out";
my $expected_vcf = Genome::Config::get('test_inputs') . "/Genome-Model-Tools-Mutect/v2/expected.vcf";

#Define path to a custom reference sequence build dir
my $custom_reference_dir = Genome::Config::get('test_inputs') . "/Genome-Model-Tools-Mutect/v2/custom_reference";
ok(-e $custom_reference_dir, "Found the custom reference dir: $custom_reference_dir");
my $fasta = $custom_reference_dir . "/all_sequences.fa";
ok( -s $fasta, "reference sequence fa file present");

my $test_base_dir = File::Temp::tempdir('MutectXXXXX', CLEANUP => 1, TMPDIR => 1);
my $test_output = "$test_base_dir/test.out";
my $test_vcf = "$test_base_dir/test.vcf";

my $mutect = Genome::Model::Tools::Mutect->create(
    tumor_bam=>$tumor, 
    normal_bam=>$normal,
    reference => $fasta,
    output_file => $test_output,
    vcf => $test_vcf,
    intervals => ['13:32913269-32913269',], 
);

ok($mutect, 'mutect command created');
my $rv = $mutect->execute;
is($rv, 1, 'Testing for successful execution.  Expecting 1.  Got: '.$rv);

ok(-s $test_output, "output file created");
ok(-s $test_vcf, "vcf file created");

compare_ok($expected_out, $test_output, name => 'output matched expected result', filters => [ qr/^##.*$/ ] );
compare_ok($expected_vcf, $test_vcf, name => 'vcf matched expected result', filters => [ qr/^##MuTect.*$/, qr/^##reference.*$/ ] );

done_testing();
