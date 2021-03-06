use File::Spec;
use File::Basename qw(dirname);
use File::Temp qw(tempdir);
my $basedir = File::Spec->rel2abs(File::Spec->catdir(dirname(__FILE__), '..'));
my $dbpath;
if ( -d '/home/dotcloud/') {
    $dbpath = "/home/dotcloud/test.db";
} else {
    $dbpath = File::Spec->catfile($basedir, 'db', 'test.db');
}
+{
    'DBI' => [
        "dbi:SQLite:dbname=$dbpath",
        '',
        '',
        +{
            sqlite_unicode => 1,
        }
    ],
    root_dir => tempdir(CLEANUP => 1),
    'Cache::FileCache' => {
        cache_root => tempdir(CLEANUP => 1),
    },
};
