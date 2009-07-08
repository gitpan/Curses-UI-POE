#!/usr/bin/perl

use strict;
use warnings;
use FindBin;
use lib "$FindBin::Bin/../lib";

use Toolkit;

# Create the UI
use Curses::UI;
use Curses::UI::POE;

my $cui = new Curses::UI::POE(-debug => 0);
my $win = $cui->add('window_id',
                    'Window',
                    -border => 1
    );

my $label = $win->add('label',
                      'Label',
                      -text      => 'Press c to calculate or s to sleep.',
                      -width => 70,
                      #-y => 10
    );
$label->draw;

my $input_label = $win->add('inputlabel',
                      'Label',
                      -text      => '',
                      -width => 70,
                      -y => 1
    );
$input_label->draw;

$cui->set_binding(sub {exit(0)}, "q");
$cui->set_binding(\&calculate, "c");
$cui->set_binding(\&do_sleep,  "s");
$cui->set_binding(\&update_input, "1");
$cui->set_binding(\&update_input, "2");
$cui->set_binding(\&update_input, "3");
$cui->set_binding(\&update_input, "4");
$cui->set_binding(\&update_input, "5");
$cui->set_binding(\&update_input, "6");
$cui->set_binding(\&update_input, "7");
$cui->set_binding(\&update_input, "8");
$cui->set_binding(\&update_input, "9");
$cui->set_binding(\&update_input, "0");

$cui->mainloop;

sub calculate {
    $label->text('Starting calculate');
    $label->draw;

    my $number_to_add = 50000;
    my $value = 0;
    for (my $c = 0; $c < $number_to_add; $c++) {
        $value += $number_to_add;
        $label->text("Calculated $value");
        $label->draw;
    }

    $label->text('Finished calculate');
}
sub do_sleep {
    $label->text('Starting sleep');
    $label->draw;

    sleep 5;

    $label->text('Finished sleep');
}

sub update_input {
    shift;
    my $key = shift;
#   print STDERR "Pressed $key\n";
    my $old_text = $input_label->text;
    $input_label->text($old_text . $key);
    $input_label->draw;
}
