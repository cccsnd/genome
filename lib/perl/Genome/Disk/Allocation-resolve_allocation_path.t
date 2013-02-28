#!/usr/bin/env genome-perl

BEGIN {
    $ENV{UR_DBI_NO_COMMIT} = 1;
    $ENV{UR_USE_DUMMY_AUTOGENERATED_IDS} = 1;
}

use strict;
use warnings;

use above "Genome";
use Test::More;
use File::Temp 'tempdir';
use Filesys::Df qw();

use_ok('Genome::Disk::Allocation') or die;

my $test_dir = tempdir(
    'allocation_testing_XXXXXX',
    TMPDIR => 1,
    UNLINK => 1,
    CLEANUP => 1,
);
ok(-d $test_dir, "created test dir at $test_dir");
$Genome::Disk::Allocation::CREATE_DUMMY_VOLUMES_FOR_TESTING = 0;

my $volume_path = tempdir(
    "test_volume_" . "_XXXXXXX",
    DIR => $test_dir,
    CLEANUP => 1,
    UNLINK => 1,
);
my $volume = Genome::Disk::Volume->create(
    hostname => 'foo',
    physical_path => 'foo/bar',
    mount_path => $volume_path,
    total_kb => Filesys::Df::df($volume_path)->{blocks},
    disk_status => 'active',
    can_allocate => '1',
);
ok($volume, 'made testing volume') or die;

my $group = Genome::Disk::Group->create(
    disk_group_name => 'testing_group',
    permissions => '755',
    sticky => '1',
    subdirectory => 'testing',
    unix_uid => 0,
    unix_gid => 0,
);
ok($group, 'successfully made testing group') or die;
push @Genome::Disk::Allocation::APIPE_DISK_GROUPS, $group->disk_group_name;

my $assignment = Genome::Disk::Assignment->create(
    dg_id => $group->id,
    dv_id => $volume->id,
);
ok($assignment, 'assigned volume to testing group');

my $path = join('/', $volume->mount_path, $group->subdirectory, 'testing');
my $mount_path = Genome::Disk::Allocation->_get_mount_path_from_full_path($path);
is($mount_path, $volume->mount_path, 'returned correct mount path');

my $group_dir = Genome::Disk::Allocation->_get_group_subdir_from_full_path_and_mount_path($path, $mount_path);
is($group_dir, $group->subdirectory, 'returned correct group subdirectory');

my $allocation_path = Genome::Disk::Allocation->_allocation_path_from_full_path($path);
is($allocation_path, 'testing', 'returned correct allocation path');

$path = join('/', $volume->mount_path, 'foo', 'testing');
$group_dir = Genome::Disk::Allocation->_get_group_subdir_from_full_path_and_mount_path($path, $mount_path);
ok(!$group_dir, 'correctly failed to resolve group dir');

$path = join('/', 'blah', $group->subdirectory, 'testing');
$mount_path = Genome::Disk::Allocation->_get_mount_path_from_full_path($path);
ok(!$mount_path, 'correctly failed to resolve mount path');

my $allocation = Genome::Disk::Allocation->create(
    disk_group_name => $group->disk_group_name,
    allocation_path => 'testing123/blah',
    owner_class_name => 'UR::Value',
    owner_id => 'foo',
    kilobytes_requested => 1,
);
ok($allocation, 'created test allocation');

my $retrieved_allocation = Genome::Disk::Allocation->_get_parent_allocation($allocation->allocation_path);
ok($retrieved_allocation, 'found parent allocation');
is($retrieved_allocation->id, $allocation->id, 'retrieved correct allocation via _get_parent_allocation method');

$retrieved_allocation = Genome::Disk::Allocation->_get_parent_allocation($allocation->allocation_path . '/foo/bar/baz');
ok($retrieved_allocation, 'found parent allocation');
is($retrieved_allocation->id, $allocation->id, 'retrieved correct allocation via _get_parent_allocation method');

my @allocations = Genome::Disk::Allocation->_get_child_allocations('testing123');
ok(@allocations, 'found some child allocations');
ok(@allocations == 1, 'found expected number of child allocations');
ok($allocations[0]->id eq $allocation->id, 'found expected child allocation');
done_testing();
