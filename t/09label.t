# -*- perl -*-
use Test::More tests => 5;
use FindBin;
use lib "$FindBin::RealBin/fakelib";
use lib "$FindBin::RealBin/../lib";
require ("$FindBin::RealBin/lorem.pl");

$ENV{LINES} = 25;
$ENV{COLUMNS} = 80;

BEGIN { use_ok( "Curses::UI::POE"); }

my $cui = new Curses::UI::POE("-clear_on_exit" => 0);

$cui->leave_curses();

isa_ok($cui, "Curses::UI::POE");

my $mainw = $cui->add("testw","Window");

isa_ok($mainw, "Curses::UI::Window");

my $wid = $mainw->add("testwidget","Label");

isa_ok($wid, "Curses::UI::Label");

$wid->text($lorem);

ok($wid->get() eq $lorem,"set and get");
