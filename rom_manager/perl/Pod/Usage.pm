# Minimal Pod::Usage for the perl of Git for Windows, which does not ship it.
# OpenSSL's configdata.pm only calls pod2usage() to print its help.
package Pod::Usage;

use strict;
use warnings;
use Exporter 'import';

our $VERSION = '2.03';
our @EXPORT = qw(pod2usage);

sub pod2usage {
    my %options = @_ == 1 && ref $_[0] eq 'HASH' ? %{$_[0]} : @_ == 1 ? (-exitval => $_[0]) : @_;
    my $exit = defined $options{-exitval} ? $options{-exitval} : 2;

    print STDERR "$options{-message}\n" if defined $options{-message};
    exit $exit unless $exit eq 'NOEXIT';
}

1;
