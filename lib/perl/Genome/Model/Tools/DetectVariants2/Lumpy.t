#/~/genome/lib/perl/Genome/Model/Tools/DetectVariants2/Lumpy.t

use strict;
use warnings;

BEGIN {
    print "$^X\n";
    $ENV{NO_LSF} = 1;
    $ENV{UR_DBI_NO_COMMIT} = 1;
    $ENV{UR_USE_DUMMY_AUTOGENERATED_IDS} = 1;
};

use above 'Genome';
use Genome::SoftwareResult;

use Test::More;
use File::Compare qw(compare);
use Genome::Utility::Test qw(compare_ok); 


use_ok('Genome::Model::Tools::DetectVariants2::Lumpy');


    my $refbuild_id = 101947881;

    my $test_dir = $ENV{GENOME_TEST_INPUTS} . '/Genome-Model-Tools-DetectVariants2-Lumpy';
    my $output_dir = Genome::Sys-> create_temp_directory();

    my $tumor_bam = $test_dir .'/tumor.bam';

my $command = Genome::Model::Tools::DetectVariants2::Lumpy->create(
        reference_build_id => $refbuild_id,
        aligned_reads_input => $tumor_bam,
        params  =>"-mw:4,-tt:0.0//min_non_overlap:150,discordant_z:4,back_distance:20,weight:1,id:2,min_mapping_threshold:20//back_distance:20,weight:1,id:2,min_mapping_threshold:20",
        output_directory => $output_dir,
    );
ok($command, 'Created `gmt detect-variants2 Lumpy` command');


subtest "Execute"=>sub {
    #GENOME_SOFTWARE_RESULT_TEST_NAME=mir_thurs8 gmt detect-variants2 lumpy --output-directory ~/lumpy_results --reference-build GRCh37-lite-build37 --aligned-reads-input /gscmnt/gc8001/info/build_merged_alignments/merged-alignment-blade12-2-10.gsc.wustl.edu-idas-12597-dc83cc176c8849d2a1acdd6fa2943605/dc83cc176c8849d2a1acdd6fa2943605.bam --params -mw:4,-tt:0.0//min_non_overlap:150,discordant_z:4,back_distance:20,weight:1,id:2,min_mapping_threshold:20//back_distance:20,weight:1,id:2,min_mapping_threshold:20

    $command->dump_status_messages(1);
    ok($command->execute, 'Executed `gmt detect-variants2 Lumpy` command');

    my $output_file = "$output_dir/svs.hq";
    my $expected_file = "$test_dir/svs.hq";


    compare_ok($output_file,$expected_file);
};


subtest "test file without split reads"=>sub{
    
    my $wo_sr_bam = $test_dir .'/medlarge2.bam';
    
    my $output_dir2 = Genome::Sys-> create_temp_directory();

my $command2 = Genome::Model::Tools::DetectVariants2::Lumpy->create(
        reference_build_id => $refbuild_id,
        aligned_reads_input => $wo_sr_bam,
        params  =>"-mw:4,-tt:0.0//min_non_overlap:150,discordant_z:4,back_distance:20,weight:1,id:2,min_mapping_threshold:20//back_distance:20,weight:1,id:2,min_mapping_threshold:20",
        output_directory => $output_dir2,
    );

    ok($command2, 'Created `gmt detect-variants2 Lumpy` command');

    $command2->dump_status_messages(1);
    ok($command2->execute, 'Executed `gmt detect-variants2 Lumpy` command');

    my $output_file = "$output_dir2/svs.hq";
    my $expected_file = "$test_dir/wo_sr_svs.hq";

    $DB::single=1;

    compare_ok($output_file,$expected_file);
};


subtest "pe_arrange"=>sub{
    my $t_pe = "Test_PE_location";
    my $t_histo = "histo_loc";
    my $pe_text =$command->pe_param;

    my $mean = 123;
    my $std = 456;
   
   Sub::Install::reinstall_sub({
    into => 'Genome::Model::Tools::DetectVariants2::Lumpy',
    as => 'pe_alignment',
    code => sub {return $t_pe;},
});

  
   Sub::Install::reinstall_sub({
    into => 'Genome::Model::Tools::DetectVariants2::Lumpy',
    as => 'mean_stdv_reader',
    code => sub {return (mean=>$mean,stdv=>$std,histo=>$t_histo);},
});

    my $pe_cmd = $command->pe_cmd_arrangement($t_pe);
    is ($pe_cmd, "-pe bam_file:$t_pe,histo_file:$t_histo,mean:$mean,stdev:$std,read_length:150,$pe_text");

};

subtest "sr_arrange"=>sub{
   my $t_sr = "Test SR location";
   my $sr_text =$command->sr_param;

  my $sr_cmd = $command->sr_arrange($t_sr);
 
  is($sr_cmd, " -sr $sr_text,bam_file:$t_sr");
};

done_testing();


