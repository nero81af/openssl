# Minimal Locale::Maketext::Simple for the perl of Git for Windows, which does not ship it.
# IPC::Cmd (used by OpenSSL's Configure) only needs loc(): plain English with [_N] / %N placeholders.
package Locale::Maketext::Simple;

use strict;
use warnings;

our $VERSION = '0.21';

sub import {
    my $caller = caller;
    no strict 'refs';
    *{"${caller}::loc"} = sub {
        my ($text, @args) = @_;
        $text =~ s/\[_(\d+)\]/defined $args[$1 - 1] ? $args[$1 - 1] : ''/ge;
        $text =~ s/%(\d+)/defined $args[$1 - 1] ? $args[$1 - 1] : ''/ge;
        return $text;
    };
    *{"${caller}::loc_lang"} = sub { };
}

1;
