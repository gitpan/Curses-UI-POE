#!/usr/bin/perl

BEGIN { $ENV{TERM} = "dumb" }

use strict;
use warnings FATAL => "all";

use Test::Simple tests => 4;
sub POE::Kernel::ASSERT_DEFAULT () { 1 }
use Curses::UI::POE;

my $cui = new Curses::UI::POE inline_states => {
    _start => sub {
        ok(1, "_start");

        $_[KERNEL]->alias_set("TEST");
        $_[KERNEL]->yield("test");
        $_[KERNEL]->yield("shutdown");
    },

    test => sub {
        ok(2, "yield");
    },

    _stop => sub {
        ok(3, "_stop");
    },
};

run POE::Kernel;

ok(4, "exit");
