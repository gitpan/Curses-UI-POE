#!/usr/bin/perl

BEGIN { $ENV{TERM} = "dumb" }

use strict;
use warnings FATAL => "all";

use Test::Simple tests => 4;

BEGIN {
    open OLDERR, ">&", \*STDERR;
    open OLDOUT, ">&", \*STDOUT;

    open STDOUT, ">>", "/dev/null";
    open STDERR, ">>", "/dev/null";
}

use Curses::UI::POE;

my $cui = new Curses::UI::POE inline_states => {
    _start => sub {
        open STDOUT, ">>&=", \*OLDOUT;
        open STDERR, ">>&=", \*OLDERR;

        ok("_start");

        $_[KERNEL]->yield("test");
        $_[KERNEL]->yield("shutdown");
    },

    test => sub {
        ok("yield");
    },

    _stop => sub {
        ok("_stop");
        open STDOUT, ">>", "/dev/null";
        open STDERR, ">>", "/dev/null";
    },
}, -no_output => 1; # Lotta good -no_output does..

$cui->mainloop;

ok("exit");
