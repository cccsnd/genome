#!/usr/bin/env genome-perl

use strict;
use warnings;

use above 'Genome';

use Test::More tests => 2;

use_ok('Genome::Disk::Group') or die;

subtest 'is archive' => sub{
    plan tests => 7;

    my $disk_group_name = 'mckinley';
    my $group = Genome::Disk::Group->__define__(disk_group_name => $disk_group_name);
    ok($group, 'defined $disk_group_name group');
    isnt(Genome::Config::get('disk_group_archive'), $disk_group_name, "disk_group_archive is not $disk_group_name");
    ok(!$group->is_archive, 'group is not archive');
    ok(!$group->is_archive($disk_group_name), 'group is not archive');

    my @guard = Genome::Config::set_env('disk_group_archive', $disk_group_name);
    is(Genome::Config::get('disk_group_archive'), $disk_group_name, "disk_group_archive is now $disk_group_name");
    ok($group->is_archive, 'group is archive');
    ok($group->is_archive($disk_group_name), 'group is archive');

};

done_testing();
