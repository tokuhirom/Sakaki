use File::Spec;
use File::Basename qw(dirname);
use File::Path;

my $basedir = File::Spec->rel2abs(File::Spec->catdir(dirname(__FILE__), '..'));
my $dbpath;
my $datpath;
if ( -d '/home/dotcloud/') {
    $dbpath = "/home/dotcloud/deployment.db";
    $datpath = '/home/dotcloud/sakaki-dat/';
} else {
    $dbpath = File::Spec->catfile($basedir, 'db', 'deployment.db');
    $datpath = File::Spec->catdir($basedir, 'dat');
}
mkpath($datpath);
+{
    'DBI' => [
        "dbi:SQLite:dbname=$dbpath",
        '',
        '',
        +{
            sqlite_unicode => 1,
        }
    ],
    root_dir => $datpath,
};
