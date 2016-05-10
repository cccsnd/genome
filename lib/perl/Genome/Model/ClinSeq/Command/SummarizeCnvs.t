#!/usr/bin/env genome-perl

#Written by Malachi Griffith

use strict;
use warnings;
use File::Basename;
use Cwd 'abs_path';

BEGIN {
    $ENV{UR_DBI_NO_COMMIT}               = 1;
    $ENV{UR_USE_DUMMY_AUTOGENERATED_IDS} = 1;
}

use above "Genome";
use Test::More tests => 12;  #One per 'ok', 'is', etc. statement below
use Genome::Model::ClinSeq::TestData;
use Data::Dumper;

use Genome::Utility::Test;

my $pkg = 'Genome::Model::ClinSeq::Command::SummarizeCnvs';
use_ok($pkg) or die;

#Define the test where expected results are stored
my $expected_output_dir = Genome::Utility::Test->data_dir_ok($pkg, '2016-05-10');

#Create a temp dir for results
my $temp_dir = Genome::Sys->create_temp_directory();
ok($temp_dir, "created temp directory: $temp_dir") or die;

#Get a clin-seq build
my $data = Genome::Model::ClinSeq::TestData->load();
my $clinseq_build_id = $data->{CLINSEQ_BUILD};
my $clinseq_build    = Genome::Model::Build->get($clinseq_build_id);
ok($clinseq_build, "obtained a clinseq build for build id: $clinseq_build_id") or die;
my $clinseq_dir = $clinseq_build->data_directory;
ok(-e $clinseq_dir && -d $clinseq_dir, "clinseq dir exists and is a valid directory: $clinseq_dir") or die;

my $cnv_hmm_file  = $clinseq_dir . "/FAKE1/clonality/cnaseq.cnvhmm";
my $gene_amp_file = $clinseq_dir . "/FAKE1/cnv/cnview/cnv.All_genes.amp.tsv";
my $gene_del_file = $clinseq_dir . "/FAKE1/cnv/cnview/cnv.All_genes.del.tsv";

ok(-e $cnv_hmm_file,  "found cnv hmm file: $cnv_hmm_file")   or die;
ok(-e $gene_amp_file, "found gene amp file: $gene_amp_file") or die;
ok(-e $gene_del_file, "found gene del file: $gene_del_file") or die;

#Get a wgs somatic-variation build from this clinseq build
my $wgs_build = $clinseq_build->wgs_build;
ok($wgs_build, "obtained a wgs_build from the clinseq build: $clinseq_build_id") or die;

#Create summarize-cnvs command and execute
#genome model clin-seq summarize-cnvs --outdir=/tmp/  --cnv-hmm-file=? --gene-amp-file=? --gene-del-file=? 119390903
my $summarize_cnvs_cmd = $pkg->create(
    outdir        => $temp_dir,
    cnv_hmm_file  => $cnv_hmm_file,
    gene_amp_file => $gene_amp_file,
    gene_del_file => $gene_del_file,
    build         => $wgs_build
);
$summarize_cnvs_cmd->queue_status_messages(1);
my $r1 = $summarize_cnvs_cmd->execute();
is($r1, 1, 'Testing for successful execution.  Expecting 1.  Got: ' . $r1);

#Dump the output of summarize-cnvs to a log file
my @output1  = $summarize_cnvs_cmd->status_messages();
my $log_file = $temp_dir . "/SummarizeCnvs.log.txt";
my $log      = IO::File->new(">$log_file");
$log->print(join("\n", @output1));
ok(-e $log_file, "Wrote message file from summarize-cnvs to a log file: $log_file");

#The first time we run this we will need to save our initial result to diff against
#Genome::Sys->shellcmd(cmd => "cp -r -L $temp_dir/* $expected_output_dir");

#Perform a diff between the stored results and those generated by this test
my @diff = `diff -r $expected_output_dir $temp_dir`;
my $ok = ok(@diff == 0, "Found only expected number of differences between expected results and test results");
unless ($ok) {
    diag("expected: $expected_output_dir\nactual: $temp_dir\n");
    diag("differences are:");
    diag(@diff);
    my $diff_line_count = scalar(@diff);
    print "\n\nFound $diff_line_count differing lines\n\n";
    Genome::Sys->shellcmd(cmd => "rm -fr /tmp/last-summarize-cnvs-result/");
    Genome::Sys->shellcmd(cmd => "mv $temp_dir /tmp/last-summarize-cnvs-result");
}
