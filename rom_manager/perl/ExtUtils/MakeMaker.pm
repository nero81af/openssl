# Minimal ExtUtils::MakeMaker for the perl of Git for Windows, which does not ship it.
# IPC::Cmd::can_run (used by OpenSSL's Configure) only calls MM->maybe_command.
package ExtUtils::MakeMaker;

use strict;
use warnings;

our $VERSION = '7.70';

package MM;

sub maybe_command {
    my ($self, $file) = @_;

    foreach my $candidate ($file, "$file.exe", "$file.cmd", "$file.bat") {
        return $candidate if -f $candidate && -x _;
    }

    return;
}

1;
