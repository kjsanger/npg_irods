package WTSI::NPG::HTS::PacBio::Sequel::RunPublisherTest;

use strict;
use warnings;

use English qw[-no_match_vars];
use File::Basename;
use File::Spec::Functions;
use File::Temp;
use Log::Log4perl;
use Test::More;

use base qw[WTSI::NPG::HTS::Test];

use WTSI::NPG::HTS::PacBio::Sequel::APIClient;
use WTSI::NPG::HTS::PacBio::Sequel::RunPublisher;
use WTSI::NPG::iRODS;
use WTSI::NPG::iRODS::DataObject;
use WTSI::NPG::iRODS::Metadata;

Log::Log4perl::init('./etc/log4perl_tests.conf');

{
  package TestDB;
  use Moose;

  with 'npg_testing::db';
}

{
  package TestAPIClient;
  use Moose;

  extends 'WTSI::NPG::HTS::PacBio::Sequel::APIClient';
  override 'query_dataset_reports' => sub { my @r; return [@r]; }
}

my $pid          = $PID;
my $test_counter = 0;
my $data_path    = 't/data/pacbio/sequel';
my $fixture_path = "t/fixtures";
my $db_dir       = File::Temp->newdir;

my $SEQUENCE_PRODUCT      = $WTSI::NPG::HTS::PacBio::Sequel::RunPublisher::SEQUENCE_PRODUCT;
my $SEQUENCE_AUXILIARY    = $WTSI::NPG::HTS::PacBio::Sequel::RunPublisher::SEQUENCE_AUXILIARY;
my $FILE_PREFIX_PATTERN   = $WTSI::NPG::HTS::PacBio::Sequel::RunPublisher::FILE_PREFIX_PATTERN;
my $SEQUENCE_FILE_FORMAT  = $WTSI::NPG::HTS::PacBio::Sequel::RunPublisher::SEQUENCE_FILE_FORMAT;
my $SEQUENCE_INDEX_FORMAT = $WTSI::NPG::HTS::PacBio::Sequel::RunPublisher::SEQUENCE_INDEX_FORMAT;
my $SEQUENCE_TYPES        = $WTSI::NPG::HTS::PacBio::Sequel::RunPublisher::SEQUENCE_TYPES;

my $wh_schema;

my $irods_tmp_coll;

sub setup_databases : Test(startup) {
  my $wh_db_file = catfile($db_dir, 'ml_wh.db');
  $wh_schema = TestDB->new(sqlite_utf8_enabled => 1,
                           verbose             => 0)->create_test_db
    ('WTSI::DNAP::Warehouse::Schema', "$fixture_path/ml_warehouse",
     $wh_db_file);
}

sub teardown_databases : Test(shutdown) {
  $wh_schema->storage->disconnect;
}

sub setup_test : Test(setup) {
  my $irods = WTSI::NPG::iRODS->new(environment          => \%ENV,
                                    strict_baton_version => 0);

  $irods_tmp_coll =
    $irods->add_collection("PacBioSequelRunPublisherTest.$pid.$test_counter");
  $test_counter++;
}

sub teardown_test : Test(teardown) {
  my $irods = WTSI::NPG::iRODS->new(environment          => \%ENV,
                                    strict_baton_version => 0);
  $irods->remove_collection($irods_tmp_coll);
}

sub require : Test(1) {
  require_ok('WTSI::NPG::HTS::PacBio::Sequel::RunPublisher');
}

sub list_xml_files : Test(1) {
  my $irods = WTSI::NPG::iRODS->new(environment          => \%ENV,
                                    strict_baton_version => 0);
  my $runfolder_path = "$data_path/r54097_20170727_165601";
  my $dest_coll = $irods_tmp_coll;

  my $pub = WTSI::NPG::HTS::PacBio::Sequel::RunPublisher->new
    (dest_collection => $dest_coll,
     irods           => $irods,
     mlwh_schema     => $wh_schema,
     runfolder_path  => $runfolder_path);

  my @expected_paths =
    map { catfile("$runfolder_path/1_A02", $_) }
    ('m54097_170727_170646.subreadset.xml');

  is_deeply($pub->list_files('1_A02',
     $FILE_PREFIX_PATTERN .'[.]'. '(' . 'subreadset' .')[.]xml$',1),
     \@expected_paths, 'Found meta XML file 1_A02');
}

sub list_adapter_files : Test(1) {
  my $irods = WTSI::NPG::iRODS->new(environment          => \%ENV,
                                    strict_baton_version => 0);
  my $runfolder_path = "$data_path/r54097_20170727_165601";
  my $dest_coll = $irods_tmp_coll;

  my $pub = WTSI::NPG::HTS::PacBio::Sequel::RunPublisher->new
    (dest_collection => $dest_coll,
     irods           => $irods,
     mlwh_schema     => $wh_schema,
     runfolder_path  => $runfolder_path);

  my @expected_paths =
    map { catfile("$runfolder_path/1_A02", $_) }
    ('m54097_170727_170646.adapters.fasta');

  is_deeply($pub->list_files('1_A02', 
     $FILE_PREFIX_PATTERN .'[.]adapters[.]fasta$'), \@expected_paths,
     'Found adapter fasta file 1_A02');
}

sub list_sequence_files : Test(2) {
  my $irods = WTSI::NPG::iRODS->new(environment          => \%ENV,
                                    strict_baton_version => 0);
  my $runfolder_path = "$data_path/r54097_20170727_165601";
  my $dest_coll = $irods_tmp_coll;

  my $pub = WTSI::NPG::HTS::PacBio::Sequel::RunPublisher->new
    (dest_collection => $dest_coll,
     irods           => $irods,
     mlwh_schema     => $wh_schema,
     runfolder_path  => $runfolder_path);

  my @expected_paths1 =
    map { catfile("$runfolder_path/1_A02", $_) }
    ('m54097_170727_170646.subreads.bam');

  my @expected_paths2 =
    map { catfile("$runfolder_path/1_A02", $_) }
    ('m54097_170727_170646.scraps.bam');

  is_deeply($pub->list_files('1_A02', 
    $FILE_PREFIX_PATTERN .q{[.]}.$SEQUENCE_PRODUCT.q{[.]}.$SEQUENCE_FILE_FORMAT .q{$}), 
    \@expected_paths1, 'Found sequence files 1: A01_1');
  is_deeply($pub->list_files('1_A02',
    $FILE_PREFIX_PATTERN .q{[.]}.$SEQUENCE_AUXILIARY.q{[.]}.$SEQUENCE_FILE_FORMAT .q{$}), 
    \@expected_paths2, 'Found sequence files 2: A01_1');
}

sub list_index_files : Test(1) {
  my $irods = WTSI::NPG::iRODS->new(environment          => \%ENV,
                                    strict_baton_version => 0);
  my $runfolder_path = "$data_path/r54097_20170727_165601";
  my $dest_coll = $irods_tmp_coll;

  my $pub = WTSI::NPG::HTS::PacBio::Sequel::RunPublisher->new
    (dest_collection => $dest_coll,
     irods           => $irods,
     mlwh_schema     => $wh_schema,
     runfolder_path  => $runfolder_path);

  my @expected_paths =
    map { catfile("$runfolder_path/1_A02", $_) }
    ('m54097_170727_170646.scraps.bam.pbi',
     'm54097_170727_170646.subreads.bam.pbi');

  my $file_pattern = $FILE_PREFIX_PATTERN .q{[.]}. $SEQUENCE_TYPES. q{[.]}.
        $SEQUENCE_FILE_FORMAT .q{[.]}. $SEQUENCE_INDEX_FORMAT .q{$};

  is_deeply($pub->list_files('1_A02',$file_pattern), \@expected_paths,
            'Found sequence index files 1_A02');
}

sub list_image_archive_files : Test(1) {
  my $irods = WTSI::NPG::iRODS->new(environment          => \%ENV,
                                    strict_baton_version => 0);
  my $runfolder_path = "$data_path/r54097_20170727_165601";
  my $dest_coll = $irods_tmp_coll;

  my $pub = WTSI::NPG::HTS::PacBio::Sequel::RunPublisher->new
    (dest_collection => $dest_coll,
     irods           => $irods,
     mlwh_schema     => $wh_schema,
     runfolder_path  => $runfolder_path);

  my @expected_paths =
    map { catfile("$runfolder_path/1_A02", $_) }
    ('m54097_170727_170646.primary_qc.tar.xz');

  is_deeply($pub->list_files('1_A02',$FILE_PREFIX_PATTERN .'[.]primary_qc[.]tar[.]xz$'),
    \@expected_paths, 'Found image archive files 1_A02');
}

sub publish_files : Test(4) {
  my $irods = WTSI::NPG::iRODS->new(environment          => \%ENV,
                                    strict_baton_version => 0);
  my $runfolder_path = "$data_path/r54097_20170727_165601";
  my $dest_coll = "$irods_tmp_coll/publish_files";

  my $client = WTSI::NPG::HTS::PacBio::Sequel::APIClient->new();

  my $tmpdir = File::Temp->newdir(TEMPLATE => "./batch_tmp.XXXXXX");
  my $pub = WTSI::NPG::HTS::PacBio::Sequel::RunPublisher->new
    (api_client      => $client,
     dest_collection => $dest_coll,
     irods           => $irods,
     mlwh_schema     => $wh_schema,
     restart_file    => catfile($tmpdir->dirname, 'published.json'),
     runfolder_path  => $runfolder_path);

  my ($num_files, $num_processed, $num_errors) = $pub->publish_files;
  my $num_expected = 8;

  cmp_ok($num_processed, '==', $num_expected, "Published $num_expected files");
  cmp_ok($num_errors,    '==', 0);

  my $restart_file = $pub->restart_file;
  $pub->write_restart_file;
  ok(-e $restart_file, "Restart file $restart_file was written by publisher");

  my $restart_state = WTSI::NPG::HTS::PublishState->new;
  $restart_state->read_state($restart_file);
  cmp_ok($restart_state->num_published, '==', $num_files,
         "Restart file recorded $num_files files published") or
           diag explain $restart_state->state;

  my $repub = WTSI::NPG::HTS::PacBio::RunPublisher->new
    (dest_collection => $dest_coll,
     irods           => $irods,
     mlwh_schema     => $wh_schema,
     restart_file    => catfile($tmpdir->dirname, 'published.json'),
     runfolder_path  => $runfolder_path);
 
  unlink $pub->restart_file;
}

sub publish_xml_files : Test(14) {
  my $irods = WTSI::NPG::iRODS->new(environment          => \%ENV,
                                    strict_baton_version => 0);
  my $runfolder_path = "$data_path/r54097_20170727_165601";
  my $dest_coll = "$irods_tmp_coll/publish_xml_files";

  my $tmpdir = File::Temp->newdir(TEMPLATE => "./batch_tmp.XXXXXX");
  my $pub = WTSI::NPG::HTS::PacBio::Sequel::RunPublisher->new
    (dest_collection => $dest_coll,
     irods           => $irods,
     mlwh_schema     => $wh_schema,
     restart_file    => catfile($tmpdir->dirname, 'published.json'),
     runfolder_path  => $runfolder_path);

  my @expected_paths =
    map { catfile("$dest_coll/1_A02", $_) }
    ('m54097_170727_170646.sts.xml',
     'm54097_170727_170646.subreadset.xml');

  my ($num_files, $num_processed, $num_errors) =
    $pub->publish_xml_files('1_A02', 'subreadset|sts',2);
  cmp_ok($num_files,     '==', scalar @expected_paths);
  cmp_ok($num_processed, '==', scalar @expected_paths);
  cmp_ok($num_errors,    '==', 0);

  my @observed_paths = observed_data_objects($irods, $dest_coll);
  is_deeply(\@observed_paths, \@expected_paths,
            'Published correctly named metadata XML files') or
              diag explain \@observed_paths;

  check_common_metadata($irods, @observed_paths);

  unlink $pub->restart_file;
}

sub publish_adapter_files : Test(9) {
  my $irods = WTSI::NPG::iRODS->new(environment          => \%ENV,
                                    strict_baton_version => 0);
  my $runfolder_path = "$data_path/r54097_20170727_165601";
  my $dest_coll = "$irods_tmp_coll/publish_adapter_files";

  my $tmpdir = File::Temp->newdir(TEMPLATE => "./batch_tmp.XXXXXX");
  my $pub = WTSI::NPG::HTS::PacBio::Sequel::RunPublisher->new
    (dest_collection => $dest_coll,
     irods           => $irods,
     mlwh_schema     => $wh_schema,
     restart_file    => catfile($tmpdir->dirname, 'published.json'),
     runfolder_path  => $runfolder_path);

  my @expected_paths =
    map { catfile("$dest_coll/1_A02", $_) }
    ('m54097_170727_170646.adapters.fasta');

  my ($num_files, $num_processed, $num_errors) =
    $pub->publish_adapter_files('1_A02');
  cmp_ok($num_files,     '==', scalar @expected_paths);
  cmp_ok($num_processed, '==', scalar @expected_paths);
  cmp_ok($num_errors,    '==', 0);

  my @observed_paths = observed_data_objects($irods, $dest_coll);
  is_deeply(\@observed_paths, \@expected_paths,
            'Published correctly named metadata XML files') or
              diag explain \@observed_paths;

  check_common_metadata($irods, @observed_paths);

  unlink $pub->restart_file;
}

sub publish_sequence_files : Test(36) {
  my $irods = WTSI::NPG::iRODS->new(environment          => \%ENV,
                                    strict_baton_version => 0);
  my $runfolder_path = "$data_path/r54097_20170727_165601";
  my $dest_coll = "$irods_tmp_coll/publish_sequence_files";

  my $tmpdir = File::Temp->newdir(TEMPLATE => "./batch_tmp.XXXXXX");
  my $pub = WTSI::NPG::HTS::PacBio::Sequel::RunPublisher->new
    (dest_collection => $dest_coll,
     irods           => $irods,
     mlwh_schema     => $wh_schema,
     restart_file    => catfile($tmpdir->dirname, 'published.json'),
     runfolder_path  => $runfolder_path);

  my $pattern  = $FILE_PREFIX_PATTERN .'[.]'. q[subreadset] .'[.]xml$';
  my $metafile = $pub->list_files('1_A02', $pattern, '1')->[0];
  my $meta = WTSI::NPG::HTS::PacBio::Sequel::MetaXMLParser->new->parse_file($metafile);

  my @expected_paths =
    map { catfile("$dest_coll/1_A02", $_) }
    ('m54097_170727_170646.scraps.bam',
     'm54097_170727_170646.subreads.bam');

  my ($num_files1, $num_processed1, $num_errors1) =
    $pub->publish_sequence_files('1_A02',$SEQUENCE_PRODUCT,$meta);
  my ($num_files2, $num_processed2, $num_errors2) =
    $pub->publish_sequence_files('1_A02',$SEQUENCE_AUXILIARY,$meta);

  cmp_ok($num_files1 + $num_files2, '==', scalar @expected_paths);
  cmp_ok($num_processed1 + $num_processed2, '==', scalar @expected_paths);
  cmp_ok($num_errors1 + $num_errors2, '==', 0);

  my @observed_paths = observed_data_objects($irods, $dest_coll);
  is_deeply(\@observed_paths, \@expected_paths,
            'Published correctly named sequence files') or
              diag explain \@observed_paths;

  check_primary_metadata($irods, @observed_paths);
  check_common_metadata($irods, @observed_paths);
  check_study_metadata($irods, @observed_paths);

  unlink $pub->restart_file;
}

sub publish_index_files : Test(14) {
  my $irods = WTSI::NPG::iRODS->new(environment          => \%ENV,
                                    strict_baton_version => 0);
  my $runfolder_path = "$data_path/r54097_20170727_165601";
  my $dest_coll = "$irods_tmp_coll/publish_sequence_files";

  my $tmpdir = File::Temp->newdir(TEMPLATE => "./batch_tmp.XXXXXX");
  my $pub = WTSI::NPG::HTS::PacBio::Sequel::RunPublisher->new
    (dest_collection => $dest_coll,
     irods           => $irods,
     mlwh_schema     => $wh_schema,
     restart_file    => catfile($tmpdir->dirname, 'published.json'),
     runfolder_path  => $runfolder_path);

  my @expected_paths =
    map { catfile("$dest_coll/1_A02", $_) }
    ('m54097_170727_170646.scraps.bam.pbi',
     'm54097_170727_170646.subreads.bam.pbi');

  my ($num_files, $num_processed, $num_errors) =
    $pub->publish_index_files('1_A02');
  cmp_ok($num_files,     '==', scalar @expected_paths);
  cmp_ok($num_processed, '==', scalar @expected_paths);
  cmp_ok($num_errors,    '==', 0);

  my @observed_paths = observed_data_objects($irods, $dest_coll);
  is_deeply(\@observed_paths, \@expected_paths,
            'Published correctly named index files') or
              diag explain \@observed_paths;

  check_common_metadata($irods, @observed_paths);

  unlink $pub->restart_file;
}

sub publish_image_archive : Test(9) {
  my $irods = WTSI::NPG::iRODS->new(environment          => \%ENV,
                                    strict_baton_version => 0);
  my $runfolder_path = "$data_path/r54097_20170727_165601";
  my $dest_coll = "$irods_tmp_coll/publish_sequence_files";

  my $client = TestAPIClient->new(default_interval => 10000,);
  my $tmpdir = File::Temp->newdir(TEMPLATE => "./batch_tmp.XXXXXX");

  my $pub = WTSI::NPG::HTS::PacBio::Sequel::RunPublisher->new
    (api_client      => $client,
     dest_collection => $dest_coll,
     irods           => $irods,
     mlwh_schema     => $wh_schema,
     restart_file    => catfile($tmpdir->dirname, 'published.json'),
     runfolder_path  => $runfolder_path);

  my $pattern  = $FILE_PREFIX_PATTERN .'[.]'. q[subreadset] .'[.]xml$';
  my $metafile = $pub->list_files('1_A02', $pattern, '1')->[0];
  my $meta = WTSI::NPG::HTS::PacBio::Sequel::MetaXMLParser->new->parse_file($metafile);

  my @expected_paths =
    map { catfile("$dest_coll/1_A02", $_) }
    ('m54097_170727_170646.primary_qc.tar.xz');

  my ($num_files, $num_processed, $num_errors) =
    $pub->publish_image_archive('1_A02', $meta);
  cmp_ok($num_files,     '==', scalar @expected_paths);
  cmp_ok($num_processed, '==', scalar @expected_paths);
  cmp_ok($num_errors,    '==', 0);

  my @observed_paths = observed_data_objects($irods, $dest_coll);
  is_deeply(\@observed_paths, \@expected_paths,
            'Published correctly named image archive file') or
              diag explain \@observed_paths;

  check_common_metadata($irods, @observed_paths);

  unlink $pub->restart_file;
}

sub observed_data_objects {
  my ($irods, $dest_collection, $regex) = @_;

  my ($observed_paths) = $irods->list_collection($dest_collection, 'RECURSE');
  my @observed_paths = @{$observed_paths};
  if ($regex) {
    @observed_paths = grep { m{$regex}msx } @observed_paths;
  }
  @observed_paths = sort @observed_paths;

  return @observed_paths;
}

sub check_common_metadata {
  my ($irods, @paths) = @_;

  foreach my $path (@paths) {
    my $obj = WTSI::NPG::iRODS::DataObject->new($irods, $path);
    my $file_name = fileparse($obj->str);

    foreach my $attr ($DCTERMS_CREATED, $DCTERMS_CREATOR, $DCTERMS_PUBLISHER,
                      $FILE_TYPE, $FILE_MD5) {
       my @avu = $obj->find_in_metadata($attr);
       cmp_ok(scalar @avu, '==', 1, "$file_name $attr metadata present");
    }
  }
}

sub check_primary_metadata {
  my ($irods, @paths) = @_;

  foreach my $path (@paths) {
    my $obj = WTSI::NPG::iRODS::DataObject->new($irods, $path);
    my $file_name = fileparse($obj->str);

    foreach my $attr
      ($PACBIO_CELL_INDEX,
       $PACBIO_COLLECTION_NUMBER,
       $PACBIO_DATA_LEVEL,
       $PACBIO_INSTRUMENT_NAME,
       $PACBIO_RUN,
       $PACBIO_WELL,
       $PACBIO_SAMPLE_LOAD_NAME) {
      my @avu = $obj->find_in_metadata($attr);
      cmp_ok(scalar @avu, '==', 1, "$file_name $attr metadata present");
    }
  }
}

sub check_study_metadata {
  my ($irods, @paths) = @_;

  foreach my $path (@paths) {
    my $obj = WTSI::NPG::HTS::DataObject->new($irods, $path);
    my $file_name = fileparse($obj->str);

    # study_name is legacy metadata
    foreach my $attr ($STUDY_ID, $STUDY_NAME, $STUDY_ACCESSION_NUMBER,
                      $PACBIO_STUDY_NAME) {
      my @avu = $obj->find_in_metadata($attr);
      cmp_ok(scalar @avu, '==', 1, "$file_name $attr metadata present");
    }
  }
}

1;
