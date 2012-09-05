package Genome::Model::ClinSeq::Command::SummarizeCnvs;

#Written by Malachi Griffith

use strict;
use warnings;
use Genome;
use Data::Dumper;
use Term::ANSIColor qw(:constants);
use Genome::Model::ClinSeq::Util qw(:all);

class Genome::Model::ClinSeq::Command::SummarizeCnvs {
    is => 'Command::V2',
    has_input => [
        builds => { 
              is => 'Genome::Model::Build::ClinSeq',
              is_many => 1,
              shell_args_position => 1,
              require_user_verify => 0,
              doc => 'clinseq build(s) to summarize CNVs from',
        },
        outdir => { 
              is => 'FilesystemPath',
              doc => 'Directory where output files will be written', 
        },
    ],
    doc => 'summarize the CNVs of clinseq build',
};

sub help_synopsis {
    return <<EOS

genome model clin-seq summarize-cnvs --outdir=/tmp/  126680687

genome model clin-seq summarize-cnvs --outdir=/tmp/  id=126680687

genome model clin-seq summarize-cnvs --outdir=/tmp/  model.id=2887519760

genome model clin-seq summarize-cnvs --outdir=/tmp/  "model.name='ClinSeq - ALL1 - (Nov. 2011 PP) - v4'"

genome model clin-seq summarize-cnvs --outdir=/tmp/  'id in [126680687,126681790]'

EOS
}

sub help_detail {
    return <<EOS
Summarize copy number variants for one or more clinseq builds 

(put more content here)
EOS
}

sub __errors__ {
  my $self = shift;
  my @errors = $self->SUPER::__errors__(@_);

  unless (-e $self->outdir && -d $self->outdir) {
      push @errors, UR::Object::Tag->create(
	                                          type => 'error',
	                                          properties => ['outdir'],
	                                          desc => RED . "Outdir: " . $self->outdir . " not found or not a directory" . RESET,
                                          );
  }
  return @errors;
}

sub execute {
  my $self = shift;
  my @builds = $self->builds;
  my $outdir = $self->outdir;

  unless ($outdir =~ /\/$/){
    $outdir .= "/";
  }

  my $clinseq_build_count = scalar(@builds);
  for my $clinseq_build (@builds) {
    
    #Get the WGS somatic variation build from the clinseq build
    my $wgs_som_build = $clinseq_build->wgs_build;
    next unless $wgs_som_build;

    #If there is more than one clinseq build supplied... create sub-directories for each
    my $build_outdir;
    if ($clinseq_build_count > 1){
      $build_outdir = $outdir . $clinseq_build->id . "/";
      mkdir ($build_outdir);
    }else{
      $build_outdir = $outdir;
    }

    #Create a Stats.tsv and Summarize the number of CNV amp and del windows
    #Question Answer  Data_Type Analysis_Type Statistic_Type  Extra_Description
    my $stats_file = $build_outdir . "Stats.tsv";
    open (STATS, ">$stats_file") || die "\n\nCould not open stats file: $stats_file\n\n";
    print STATS "Question\tAnswer\tData_Type\tAnalysis_Type\tStatistic_Type\tExtra_Description\n";
    my $clinseq_build_dir = $clinseq_build->data_directory;
    my $wgs_som_build_dir = $wgs_som_build->data_directory;

    #Overall strategy
    #Get a copy of the cnvs.hq (10-kb copy number window values) and cna-seq (cnv-hmm files) and summarize
    my $cnv_hq = $wgs_som_build_dir . "/variants/cnvs.hq";
    my $cnv_hq_new = $build_outdir . "cnvs.hq";
    my $cp_cmd1 = "cp $cnv_hq $build_outdir";
    unless (-e $cnv_hq_new){
      Genome::Sys->shellcmd(cmd => $cp_cmd1);
    }

    #Gather CNV window stats:
    #Number of windows
    #Number windows with CNV diff >1, >2, >5, <-0.5, <-0.75, <-1.0
    #Number of windows with tumor/normal coverage >100 and >1000
    my ($window_count, $cum_cov, $amp_050, $amp_1, $amp_2, $amp_5, $amp_10, $del_025, $del_050, $del_075, $del_1, $del_15, $cov_100x, $cov_250x, $cov_1000x, $cov_2500x, $cov_5000x, $cov_10000x, $cov_25000x, $cov_50000x) = (0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0);
    if (-e $cnv_hq){
      open (CNV, "$cnv_hq") || die "\n\nCould not open cnv hq file: $cnv_hq\n\n";
      while(<CNV>){
        chomp($_);
        if ($_ =~ /^\#|^CHR/){
          next();
        }
        my @line = split("\t", $_);
        my $chr = $line[0];
        my $pos = $line[1];
        my $tumor = $line[2];
        my $normal = $line[3];
        my $cov = $tumor+$normal;
        my $diff = $line[4];
        $window_count++;
        $cum_cov+=$cov;
        if ($diff > 0.5){$amp_050++;}
        if ($diff > 1){$amp_1++;}
        if ($diff > 2){$amp_2++;}
        if ($diff > 5){$amp_5++;}
        if ($diff > 10){$amp_10++;}
        if ($diff < -0.25){$del_025++;}
        if ($diff < -0.5){$del_050++;}
        if ($diff < -0.75){$del_075++;}
        if ($diff < -1){$del_1++;}
        if ($diff < -1.5){$del_15++;}
        if ($cov > 100){$cov_100x++;}
        if ($cov > 250){$cov_250x++;}
        if ($cov > 1000){$cov_1000x++;}
        if ($cov > 2500){$cov_2500x++;}
        if ($cov > 5000){$cov_5000x++;}
        if ($cov > 10000){$cov_10000x++;}
        if ($cov > 25000){$cov_25000x++;}
        if ($cov > 50000){$cov_50000x++;}
       }
      close(CNV);
    }
    my $avg_cov = sprintf("%.2f", $cum_cov/$window_count);
    my $cov_100x_p = sprintf("%.2f", ($cov_100x/$window_count)*100);
    my $cov_250x_p = sprintf("%.2f", ($cov_250x/$window_count)*100);
    my $cov_1000x_p = sprintf("%.2f", ($cov_1000x/$window_count)*100);
    my $cov_2500x_p = sprintf("%.2f", ($cov_2500x/$window_count)*100);
    my $cov_5000x_p = sprintf("%.2f", ($cov_5000x/$window_count)*100);
    my $cov_10000x_p = sprintf("%.2f", ($cov_10000x/$window_count)*100);
    my $cov_25000x_p = sprintf("%.2f", ($cov_25000x/$window_count)*100);
    my $cov_50000x_p = sprintf("%.2f", ($cov_50000x/$window_count)*100);

    print STATS "Total CNV window count\t$window_count\twgs\tcnv_bamtocna\tcount\tNumber of windows from CNV analysis\n";
    print STATS "CNV amplified windows > 0.5\t$amp_050\twgs\tcnv_bamtocna\tcount\tTotal CNV window counts with tumor-normal diff > 0.5\n";
    print STATS "CNV amplified windows > 1\t$amp_1\twgs\tcnv_bamtocna\tcount\tTotal CNV window counts with tumor-normal diff > 1\n";
    print STATS "CNV amplified windows > 2\t$amp_2\twgs\tcnv_bamtocna\tcount\tTotal CNV window counts with tumor-normal diff > 2\n";
    print STATS "CNV amplified windows > 5\t$amp_5\twgs\tcnv_bamtocna\tcount\tTotal CNV window counts with tumor-normal diff > 5\n";
    print STATS "CNV amplified windows > 10\t$amp_10\twgs\tcnv_bamtocna\tcount\tTotal CNV window counts with tumor-normal diff > 10\n";
    print STATS "CNV deleted windows < -0.25\t$del_025\twgs\tcnv_bamtocna\tcount\tTotal CNV window counts with tumor-normal diff < -0.25\n";
    print STATS "CNV deleted windows < -0.50\t$del_050\twgs\tcnv_bamtocna\tcount\tTotal CNV window counts with tumor-normal diff > -0.50\n";
    print STATS "CNV deleted windows < -0.75\t$del_075\twgs\tcnv_bamtocna\tcount\tTotal CNV window counts with tumor-normal diff > -0.75\n";
    print STATS "CNV deleted windows < -1.0\t$del_1\twgs\tcnv_bamtocna\tcount\tTotal CNV window counts with tumor-normal diff > -1.0\n";
    print STATS "CNV deleted windows < -1.5\t$del_15\twgs\tcnv_bamtocna\tcount\tTotal CNV window counts with tumor-normal diff > -1.5\n";
    print STATS "Average coverage of CNV windows\t$avg_cov\twgs\tcnv_bamtocna\tmean\tCumulative coverage of tumor+normal divided by window count\n";
    print STATS "CNV windows with coverage > 100x\t$cov_100x_p\twgs\tcnv_bamtocna\tpercent\tCNV windows with tumor+normal coverage > 100 reads\n";
    print STATS "CNV windows with coverage > 250x\t$cov_250x_p\twgs\tcnv_bamtocna\tpercent\tCNV windows with tumor+normal coverage > 250 reads\n";
    print STATS "CNV windows with coverage > 1000x\t$cov_1000x_p\twgs\tcnv_bamtocna\tpercent\tCNV windows with tumor+normal coverage > 1000 reads\n";
    print STATS "CNV windows with coverage > 2500x\t$cov_2500x_p\twgs\tcnv_bamtocna\tpercent\tCNV windows with tumor+normal coverage > 2500 reads\n";
    print STATS "CNV windows with coverage > 5000x\t$cov_5000x_p\twgs\tcnv_bamtocna\tpercent\tCNV windows with tumor+normal coverage > 5000 reads\n";
    print STATS "CNV windows with coverage > 10000x\t$cov_10000x_p\twgs\tcnv_bamtocna\tpercent\tCNV windows with tumor+normal coverage > 10000 reads\n";
    print STATS "CNV windows with coverage > 25000x\t$cov_25000x_p\twgs\tcnv_bamtocna\tpercent\tCNV windows with tumor+normal coverage > 25000 reads\n";
    print STATS "CNV windows with coverage > 50000x\t$cov_50000x_p\twgs\tcnv_bamtocna\tpercent\tCNV windows with tumor+normal coverage > 50000 reads\n";

    #Summarise the CNV AMP and DEL genes from the CNView analyses stored in the ClinSeq results
    #TODO: The following is a horrible hack.  Get rid of it as soon as simple amp/del counts can be obtained elsewhere
    my $cnv_amp_search = "$clinseq_build_dir"."/*/cnv/cnview/cnv.AllGenes_Ensembl*.amp.tsv";
    my $cnv_amp = `ls $cnv_amp_search 2>/dev/null`;
    chomp ($cnv_amp);
    my $cnv_del_search = "$clinseq_build_dir"."/*/cnv/cnview/cnv.AllGenes_Ensembl*.del.tsv";
    my $cnv_del = `ls $cnv_del_search 2>/dev/null`;
    chomp($cnv_del);
    my $amp_count = -1;
    my $del_count = -1;
    if (-e $cnv_amp && -e $cnv_del){
      open (AMP, "$cnv_amp") || die "\n\nCould not open amp file: $cnv_amp\n\n";
      while(<AMP>){
        $amp_count++;
      }
      close(DEL);
      open (DEL, "$cnv_del") || die "\n\nCould not open del file: $cnv_del\n\n";
      while(<DEL>){
        $del_count++;
      }
      close(DEL);
      print STATS "CNV amplified genes\t$amp_count\twgs\tcnv_cnview\tcount\tNumber of CNV tumor vs. normal amplified genes according to CNView analysis\n";
      print STATS "CNV deleted genes\t$del_count\twgs\tcnv_cnview\tcount\tNumber of CNV tumor vs. normal deleted genes according to CNView analysis\n";
    }
    #Summarize the number of CNV amp and del segments from the hmm-segs file
    #Unfortunately, for now this is only available from the ClinSeq build itself... it would be better to get all this from somatic variation probably...
    my $cnv_hmm_search = "$clinseq_build_dir"."/*/clonality/cnaseq.cnvhmm";
    my $cnv_hmm = `ls $cnv_hmm_search 2>/dev/null`;
    chomp($cnv_hmm);
    if (-e $cnv_hmm){
      #Gather some basic stats from the cna-seg analysis
      my $amp_seg_count = 0;
      my $del_seg_count = 0;

      open (CNV_HMM, "$cnv_hmm") || die "\n\nCould not open CNV HMM file: $cnv_hmm\n\n";
      #Kind of a nasty format to these files.  Search for data entries like the following:
      #CN1 = Tumor?  and  CN2 = Normal? 
      #CHR	START	END	SIZE	nMarkers	CN1	Adjusted_CN1	CN2	Adjusted_CN2	LLR_Somatic	Status
      #4	7190000	7540000	350000	36	2	1.57	1	1.46	10.25	Gain
      while(<CNV_HMM>){
        chomp($_);
        next if ($_ =~ /^\#/);
        my @line = split("\t", $_);
        next unless (scalar @line == 11);

        #print "@line\n";
        my $chr = $line[0];
        my $start = $line[1];
        my $end = $line[2];
        my $size = $line[3];
        my $nmarkers = $line[4];
        my $cn1 = $line[5];
        my $cn1_adjusted = $line[6];
        my $cn2 = $line[7];
        my $cn2_adjusted = $line[8];
        my $llr_somatic = $line[9];
        my $status = $line[10];
        if ($status eq 'Gain'){
          $amp_seg_count++;
        }
        if ($status eq 'Loss'){
          $del_seg_count++;
        }
      }
      close (CNV_HMM);
      print STATS "CNV amplified segments\t$amp_seg_count\twgs\tcnv_cnaseq\tcount\tNumber of CNV tumor vs. normal amplified segments according to CNV hmm cna-seq analysis\n";
      print STATS "CNV deleted segments\t$del_seg_count\twgs\tcnv_cnaseq\tcount\tNumber of CNV tumor vs. normal deleted segments according to CNV hmm cna-seg analysis\n";
    }
    close (STATS);
  }
  $self->status_message("\n\n");

  return 1;
}

1;


