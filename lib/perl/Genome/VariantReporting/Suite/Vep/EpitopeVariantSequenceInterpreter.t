#!/usr/bin/env genome-perl

BEGIN {
    $ENV{UR_DBI_NO_COMMIT} = 1;
    $ENV{UR_USE_DUMMY_AUTOGENERATED_IDS} = 1;
}

use strict;
use warnings;

use above "Genome";
use Test::More;
use Test::Exception;
use Genome::File::Vcf::Reader;

my $pkg = "Genome::VariantReporting::Suite::Vep::EpitopeVariantSequenceInterpreter";
use_ok($pkg);

my $factory = Genome::VariantReporting::Framework::Factory->create();
isa_ok($factory->get_class('interpreters', $pkg->name), $pkg);

my $test_dir = File::Spec->join(__FILE__ . '.d');

subtest 'input file with length 17' => sub {
    my $interpreter = $pkg->create(peptide_sequence_length => 17);
    lives_ok(sub {$interpreter->validate}, "Interpreter validates");

    my %expected_return_values = (
        T => {
            variant_sequences => {
                '>WT.PRAMEF4.R195H' => 'LKILGMPFRNIRSILKM',
                '>MT.PRAMEF4.R195H' => 'LKILGMPFHNIRSILKM',
            }
        }
    );

    my $input_file = File::Spec->join($test_dir, 'input.vcf');
    my $reader = Genome::File::Vcf::Reader->new($input_file);
    my $entry = $reader->next();

    is_deeply({$interpreter->interpret_entry($entry, ['T'])}, \%expected_return_values, "Entry gets interpreted correctly");
};

subtest 'input file with length 21' => sub {
    my $interpreter = $pkg->create(peptide_sequence_length => 21);
    lives_ok(sub {$interpreter->validate}, "Interpreter validates");

    my %expected_return_values = (
        T => {
            variant_sequences => {
                '>WT.PRAMEF4.R195H' => 'KKLKILGMPFRNIRSILKMVN',
                '>MT.PRAMEF4.R195H' => 'KKLKILGMPFHNIRSILKMVN',
            }
        }
    );

    my $input_file = File::Spec->join($test_dir, 'input.vcf');
    my $reader = Genome::File::Vcf::Reader->new($input_file);
    my $entry = $reader->next();

    is_deeply({$interpreter->interpret_entry($entry, ['T'])}, \%expected_return_values, "Entry gets interpreted correctly");
};

subtest 'input file with length 31' => sub {
    my $interpreter = $pkg->create(peptide_sequence_length => 31);
    lives_ok(sub {$interpreter->validate}, "Interpreter validates");

    my %expected_return_values = (
        T => {
            variant_sequences => {
                '>WT.PRAMEF4.R195H' => 'LHLCCKKLKILGMPFRNIRSILKMVNLDCIQ',
                '>MT.PRAMEF4.R195H' => 'LHLCCKKLKILGMPFHNIRSILKMVNLDCIQ',
            }
        }
    );

    my $input_file = File::Spec->join($test_dir, 'input.vcf');
    my $reader = Genome::File::Vcf::Reader->new($input_file);
    my $entry = $reader->next();

    is_deeply({$interpreter->interpret_entry($entry, ['T'])}, \%expected_return_values, "Entry gets interpreted correctly");
};

subtest 'input file with mutations at relative end of full sequence' => sub {
    my $interpreter = $pkg->create(peptide_sequence_length => 21);
    lives_ok(sub {$interpreter->validate}, "Interpreter validates");

    my %expected_return_values = (
        T => {
            variant_sequences => {
                '>WT.PRSS55.S343F' => 'SPRSWLLLCPLSHVLFRAILY',
                '>MT.PRSS55.S343F' => 'SPRSWLLLCPLFHVLFRAILY',
            }
        }
    );

    my $input_file = File::Spec->join($test_dir, 'input_2.vcf');
    my $reader = Genome::File::Vcf::Reader->new($input_file);
    my $entry = $reader->next();

    is_deeply({$interpreter->interpret_entry($entry, ['T'])}, \%expected_return_values, "Entry gets interpreted correctly");
};

subtest 'input file with mutations at relative beginning of full sequence' => sub {
    my $interpreter = $pkg->create(peptide_sequence_length => 21);
    lives_ok(sub {$interpreter->validate}, "Interpreter validates");

    my %expected_return_values = (
        T => {
            variant_sequences => {
                '>WT.IGHV3-53.V8I' => 'MEFWLSWVFLVAILKGVQCEV',
                '>MT.IGHV3-53.V8I' => 'MEFWLSWIFLVAILKGVQCEV',
            }
        }
    );

    my $input_file = File::Spec->join($test_dir, 'input_3.vcf');
    my $reader = Genome::File::Vcf::Reader->new($input_file);
    my $entry = $reader->next();

    is_deeply({$interpreter->interpret_entry($entry, ['T'])}, \%expected_return_values, "Entry gets interpreted correctly");
};

subtest 'input file with wildtype sequence shorter than desired peptite sequence length' => sub {
    my $interpreter = $pkg->create(peptide_sequence_length => 21);
    lives_ok(sub {$interpreter->validate}, "Interpreter validates");

    my %expected_return_values = (
        C => {
            variant_sequences => {
                '>WT.IGHJ5.F3L' => 'NWFDPWGQGTLVTVSS',
                '>MT.IGHJ5.F3L' => 'NWLDPWGQGTLVTVSS',
            }
        }
    );

    my $input_file = File::Spec->join($test_dir, 'input_short_wildtype_sequence.vcf');
    my $reader = Genome::File::Vcf::Reader->new($input_file);
    my $entry = $reader->next();

    is_deeply({$interpreter->interpret_entry($entry, ['C'])}, \%expected_return_values, "Entry gets interpreted correctly");
};

subtest 'input file with inframe insertion - amino acid replacement' => sub {
    my $interpreter = $pkg->create(peptide_sequence_length => 21);
    lives_ok(sub {$interpreter->validate}, "Interpreter validates");

    my %expected_return_values = (
        GTGC => {
            variant_sequences => {
                '>WT.CNDP1.V15VL' => 'LGRMAASLLAVLLLLLERGMF',
                '>MT.CNDP1.V15VL' => 'LGRMAASLLAVLLLLLLERGMF',
            }
        }
    );

    my $input_file = File::Spec->join($test_dir, 'input_inframe_insertion.vcf');
    my $reader = Genome::File::Vcf::Reader->new($input_file);
    my $entry = $reader->next();

    is_deeply({$interpreter->interpret_entry($entry, ['GTGC'])}, \%expected_return_values, "Entry gets interpreted correctly");
};

subtest 'input file with inframe deletion - amino acid replacement' => sub {
    my $interpreter = $pkg->create(peptide_sequence_length => 21);
    lives_ok(sub {$interpreter->validate}, "Interpreter validates");

    my %expected_return_values = (
        A => {
            variant_sequences => {
                '>WT.OR14A16.SL163-164L' => 'IAVMHTAGTFSLSYCGSNMVHQ',
                '>MT.OR14A16.SL163-164L' => 'IAVMHTAGTFLSYCGSNMVHQ',
            }
        }
    );

    my $input_file = File::Spec->join($test_dir, 'input_inframe_deletion.vcf');
    my $reader = Genome::File::Vcf::Reader->new($input_file);
    my $entry = $reader->next();

    is_deeply({$interpreter->interpret_entry($entry, ['A'])}, \%expected_return_values, "Entry gets interpreted correctly");
};

subtest 'input file with inframe insertion - amino acid insertion' => sub {
    my $interpreter = $pkg->create(peptide_sequence_length => 21);
    lives_ok(sub {$interpreter->validate}, "Interpreter validates");

    my %expected_return_values = (
        TAGC => {
            variant_sequences => {
                '>WT.OXA1L.-478-479S' => 'PGKDNPPNIPSSSSKPKSKY',
                '>MT.OXA1L.-478-479S' => 'PGKDNPPNIPSSSSSKPKSKY',
            }
        }
    );

    my $input_file = File::Spec->join($test_dir, 'input_inframe_insertion2.vcf');
    my $reader = Genome::File::Vcf::Reader->new($input_file);
    my $entry = $reader->next();

    is_deeply({$interpreter->interpret_entry($entry, ['TAGC'])}, \%expected_return_values, "Entry gets interpreted correctly");
};

subtest 'input file with inframe deletion - amino acid deletion' => sub {
    my $interpreter = $pkg->create(peptide_sequence_length => 21);
    lives_ok(sub {$interpreter->validate}, "Interpreter validates");

    my %expected_return_values = (
        T => {
            variant_sequences => {
                '>WT.LRRC17.E214-' => 'RQIKSEQLCNEEEKEQLDPKP',
                '>MT.LRRC17.E214-' => 'RQIKSEQLCNEEKEQLDPKP',
            }
        }
    );

    my $input_file = File::Spec->join($test_dir, 'input_inframe_deletion2.vcf');
    my $reader = Genome::File::Vcf::Reader->new($input_file);
    my $entry = $reader->next();

    is_deeply({$interpreter->interpret_entry($entry, ['T'])}, \%expected_return_values, "Entry gets interpreted correctly");
};

subtest 'input file with framshift variant feature truncation' => sub {
    my $interpreter = $pkg->create(peptide_sequence_length => 21);
    lives_ok(sub {$interpreter->validate}, "Interpreter validates");

    my %expected_return_values = (
        T => {
            variant_sequences => {
                '>WT.NECAP2.FS.209' => 'LIPPPGEQLA',
                '>MT.NECAP2.FS.209' => 'LIPPPGEQLAGGSLVQPAVAPSSDQLPARPSQAQAGSSSDLSTVFPHVTSGKALPHLGQRKEDEALLSWPVFGAWGDPSSSQQLLPVQINFQPDPARHRLGPVLT',
            }
        }
    );

    my $input_file = File::Spec->join($test_dir, 'input_frameshift_variant_feature_truncation.vcf');
    my $reader = Genome::File::Vcf::Reader->new($input_file);
    my $entry = $reader->next();

    is_deeply({$interpreter->interpret_entry($entry, ['T'])}, \%expected_return_values, "Entry gets interpreted correctly");
};

subtest 'input file with framshift variant feature elongation' => sub {
    my $interpreter = $pkg->create(peptide_sequence_length => 21);
    lives_ok(sub {$interpreter->validate}, "Interpreter validates");

    my %expected_return_values = (
        CG => {
            variant_sequences => {
                '>WT.HSPG2.FS.322' => 'DGSDELDCGP',
                '>MT.HSPG2.FS.322' => 'DGSDELDCGPPATL',
            }
        }
    );

    my $input_file = File::Spec->join($test_dir, 'input_frameshift_variant_feature_elongation.vcf');
    my $reader = Genome::File::Vcf::Reader->new($input_file);
    my $entry = $reader->next();

    is_deeply({$interpreter->interpret_entry($entry, ['CG'])}, \%expected_return_values, "Entry gets interpreted correctly");
};

subtest 'position out of bounds' => sub {
    my $interpreter = $pkg->create(peptide_sequence_length => 21);
    lives_ok(sub {$interpreter->validate}, "Interpreter validates");

    my %expected_return_values = (
        T => { variant_sequences => '', }
    );

    my $input_file = File::Spec->join($test_dir, 'input_position_out_of_bounds.vcf');
    my $reader = Genome::File::Vcf::Reader->new($input_file);
    my $entry = $reader->next();

    is_deeply({$interpreter->interpret_entry($entry, ['T'])}, \%expected_return_values, "Entry gets interpreted correctly");
};


subtest 'distance_from_start' => sub {
    my $sequence = 'KKLKILGMPFRNIRSILKMVN';
    my $position = 5;

    is(
        Genome::VariantReporting::Suite::Vep::EpitopeVariantSequenceInterpreter::distance_from_start($position, $sequence),
        5,
        'Distance from start gets calculated correctly'
    );
};

subtest 'distance_from_end' => sub {
    my $sequence = 'KKLKILGMPFRNIRSILKMVN';
    my $position = 5;

    is(
        Genome::VariantReporting::Suite::Vep::EpitopeVariantSequenceInterpreter::distance_from_end($position, $sequence),
        15,
        'Distance from end gets calculated correctly'
    );
};

done_testing;
