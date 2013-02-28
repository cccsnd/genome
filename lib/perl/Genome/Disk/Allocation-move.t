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

*Genome::Sys::current_user_is_admin = sub { return 1 };

my $test_dir = tempdir(
    'allocation_testing_XXXXXX',
    TMPDIR => 1,
    UNLINK => 1,
    CLEANUP => 1,
);

# Add our testing group to the allowed list of disk groups
push @Genome::Disk::Allocation::APIPE_DISK_GROUPS, 'testing_group';
$Genome::Disk::Allocation::CREATE_DUMMY_VOLUMES_FOR_TESTING = 0;

# Make a dummy group
my $group = Genome::Disk::Group->create(
    disk_group_name => 'testing_group',
    permissions => '755',
    sticky => '1',
    subdirectory => 'testing',
    unix_uid => 0,
    unix_gid => 0,
);
ok($group, 'successfully made testing group') or die;

# Make two dummy volumes, one to create allocation on and one to move it to
my @volumes;
for (1..2) {
    my $volume_path = tempdir(
        "test_volume_" . $_ . "_XXXXXXX",
        DIR => $test_dir,
        CLEANUP => 1,
        UNLINK => 1,
    );
    my $volume = Genome::Disk::Volume->create(
        id => $_,
        hostname => 'foo',
        physical_path => 'foo/bar',
        mount_path => $volume_path,
        total_kb => Filesys::Df::df($volume_path)->{blocks},
        disk_status => 'active',
        can_allocate => '1',
    );
    ok($volume, 'made testing volume') or die;
    push @volumes, $volume;

    my $assignment = Genome::Disk::Assignment->create(
        dv_id => $volume->id,
        dg_id => $group->id,
    );
    ok($assignment, 'made disk assignment') or die;
    Genome::Sys->create_directory(join('/', $volume->mount_path, $group->subdirectory));
}

# Make sure dummy objects can be committed
ok(UR::Context->commit, 'commit of dummy objects to db successful') or die;

# Create a fake owner of the allocation
my $user = Genome::Sys::User->create(email => 'fakeguy@genome.wustl.edu', name => 'Fake McFakerton', username => 'fakeguy');
ok($user, 'created user');

# Create a dummy allocation
my %params = (
    disk_group_name => 'testing_group',
    mount_path => $volumes[0]->mount_path,
    allocation_path => 'testing/1/2/3',
    kilobytes_requested => 100,
    owner_class_name => 'Genome::Sys::User',
    owner_id => $user->id,
    group_subdirectory => 'testing',
);
my $allocation = Genome::Disk::Allocation->create(%params);
ok($allocation, 'successfully created test allocation');

my $original_path = $allocation->absolute_path;
my $rv = $allocation->move(
    target_mount_path => $volumes[1]->mount_path,
);
ok($rv, 'successfully moved allocation');
my $new_path = $allocation->absolute_path;
is($allocation->mount_path, $volumes[1]->mount_path, 'allocation has expected mount path');
printf("original mount path = %s\n", $original_path);
ok(-d $new_path, 'new path exists, as expected');

$rv = $allocation->move(
    disk_group_name => $group->disk_group_name,
);
ok($rv, 'successfully moved allocation given disk group instead of mount path');
is($allocation->mount_path, $volumes[0]->mount_path, 'allocation moved to only other volume in group');
ok(-d $original_path, 'new allocation path exists');

done_testing();


1;
