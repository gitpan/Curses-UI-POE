# Copyright 2003 by Scott McCoy.  All rights reserved.  Released under
# the same terms as Perl itself.
#
# Portios Copyright 2003 by Rocco Caputo.  All rights reserved.  Released 
# under the same terms as Perl itself.
#
# Portions Copyright 2001-2003 by Maurice Makaay and/or Marcus
# Thiesen.  Released under the same terms as Perl itself.

# Good luck.  Send the author feedback.  Thanks for trying it.  :)
package Curses::UI::POE; 

use warnings FATAL => "all";
use strict;

use POE;
use POSIX qw( fcntl_h );
use base qw( Curses::UI );
use Curses::UI::Widget;

# Force POE::Kernel to have ran...stops my warnings...
# We do it in a BEGIN so there can be no sessions prior
# to our calling this unless somebody is being really, really bad.
BEGIN { run POE::Kernel }

*VERSION = \0.028;
our $VERSION;

use constant TOP => -1;
use constant PARENT => -2;
use constant ROOT => 0;

my @ModalObject;

sub import {
    my $caller = caller;

    no strict "refs";

    *{ $caller . "::MainLoop" } = \&MainLoop;
    eval "package $caller; use POE;";
}

sub new { 
    my $RootObject = &Curses::UI::new(@_);
    push @ModalObject, $RootObject; 

    my ($class, %Options) = @_;

    $Options{inline_states} ||= {};

    POE::Session->create
        ( inline_states => {
            %{ $Options{inline_states} },

            _start  => sub {
                $_[KERNEL]->select(\*STDIN, "-keyin");

                # Turn blocking back on for STDIN.  Some Curses
                # implementations don't deal well with non-blocking STDIN.
                my $flags = fcntl STDIN, F_GETFL, 0 or die $!;
                fcntl STDIN, F_SETFL, $flags & ~O_NONBLOCK or die $!;

                set_read_timeout($ModalObject[TOP]);

                $_[HEAP] = $RootObject;

                $Options{inline_states}{_start}(@_)
                    if defined $Options{inline_states}{_start};
            },

            -keyin  => sub {
                unless ($#ModalObject) {
                    $RootObject->do_one_event;
                }
                else {
                    $ModalObject[TOP]->root->do_one_event($ModalObject[TOP]);
                }
                Curses::curs_set($ModalObject[ROOT]->{-cursor_mode});

#                if (my $key = $_[HEAP]->get_key(0)) {
#                    $RootObject->feedkey($key) unless $key eq '-1';
#                    $RootObject->do_one_event;
#                }
            },

            -timer  => sub {
                $ModalObject[TOP]->do_timer;
                Curses::curs_set($ModalObject[ROOT]->{-cursor_mode});

                set_read_timeout($ModalObject[TOP]);
            },

            shutdown => sub {
                $_[KERNEL]->select(\*STDIN);
            },
          },

          heap => $RootObject,
        );

     $RootObject->{-no_output} = $Options{-no_output} || 0;

     return $RootObject;
}

sub MainLoop { 
    unless ($ModalObject[TOP]) {
        die "MailLoop: Curses::UI::rootobject not created.";
    }

    $ModalObject[TOP]->mainloop 
}

sub mainloop {
    my $this = shift;

    $this->focus(undef, 1);
    $this->draw;

    Curses::doupdate;

    run POE::Kernel;
}

sub set_read_timeout {
    my $this = shift; 

    my $new_timeout = -1;

    while (my ($id, $config) = each %{$this->{-timers}}) {
        next unless $config->{-enabled};

        $new_timeout = $config->{-time}
        unless $new_timeout != -1 and
            $new_timeout < $config->{-time};
    }

    $poe_kernel->delay(-timer => $new_timeout) if $new_timeout >= 0;

    # Force the read timeout to be 0, so Curses::UI polls.
    $this->{-read_timeout} = 0;

    return $this;
}

# Redefine the modalfocus loop because it sucks.
{
    no warnings "redefine"; 
    sub Curses::UI::Widget::modalfocus () {
        my $this = shift;

        # "Fake" focus for this object.
        $this->{-has_modal_focus} = 1;
        $this->focus;
        $this->draw;

        push @ModalObject, $this;

        # This is reentrant into the POE::Kernel 
        while ( $this->{-has_modal_focus} ) {
            $poe_kernel->loop_do_timeslice;
        }

        $this->{-focus} = 0;

        pop @ModalObject;

        return $this;
    }
}

=head1 NAME

Curses::UI::POE - A subclass makes Curses::UI POE Friendly.

=head1 SYNOPSIS

 use Curses::UI::POE;

 my $cui = new Curses::UI::POE inline_states => {
     _start => sub {
         $_[HEAP]->dialog("Hello!");
     },

     _stop => sub {
         $_[HEAP]->dialog("Good bye!");
     },
 };

 $cui->mainloop

=head1 INTRODUCTION

This is a subclass for Curses::UI that enables it to work with POE.
It is designed to simply slide over Curses::UI.  Keeping the API the
same and simply forcing Curses::UI to do all of its event handling
via POE, instead of internal to itself.  This allows you to use POE
behind the scenes for things like networking clients, without Curses::UI
breaking your programs' functionality.

=head1 ADDITIONS

This is a list of distinct changes between the Curses::UI API, and the
Curses::UI::POE API.  They should all be non-obstructive additions only,
keeping Curses::UI::POE a drop-in replacement for Curses::UI.

=head2 Constructor Options

=over 2

=item inline_states

The inline_states constructor option allows insertion of inline states
into the Curses::UI::POE controlling session.  Since Curses::UI::POE is
implimented with a small session I figured it may be useful provide the
ability to the controlling session for all POE to Interface interaction.

While Curses::UI events are still seamlessly forced to use POE, this allows
you to use it for a little bit more, such as catching responses from another
POE component that should be directly connected with output.  (See the IRC
client example).

In this controlling session, however, the heap is predefined as the root
Curses::UI object, which is a hash reference.  In the Curses::UI object,
all private data is indexed by a key begining with "-".  So if you wish
to use the heap to store other data, simply dont use the "-" hash index
prefix to avoid conflicts.

=back

=head1 TIMERS

The undocumented Curses::UI timers ($cui->timer) will still work, and
they will be translated into POE delays.  I would suggest not using them,
however, as POE's internal alarms and delays are far more robust.

=head1 DIALOGS

The Curses::UI::POE dialog methods contain thier own miniature event loop,
similar to the way Curses::UI's dialog methods worked.  However instead
of blocking and polling on readkeys, it incites its own custom miniature
POE Event loop until the dialog has completed, and then its result is
returned as per the Curses::UI specifications.

=head1 MODALITY

Curses::UI::POE builds its own internal modality structure.  This allows
Curses::UI to manage it, and POE to issue the (hopefully correct) events.
To do this it uses its own custom (smaller) event loop, which is reentrant
into the POE::Loop in use (In this case, usually POE::Loop::Select).  This
way there can be several recursed layers of event loops, forcing focus on
the current modal widget, without stopping other POE::Sessions from running.

=head1 SEE ALSO

L<POE>, L<Curses::UI>.  Use of this module requires understanding of both
the Curses::UI widget set and the POE Framework.

=head1 BUGS

None Known.  Whoohoo!

Find any?  Send them to me!  tag@cpan.org

=head1 AUTHOR

=over 2

=item Rocco Caputo (rcaputo@cpan.org)

Rocco has helped in an astronomical number of ways.  He helped me work out
a number of issues (including how to do this in the first place) and atleast
half the code if not more came from his fingertips.

=head1 MAINTAINER

=item Scott McCoy (tag@cpan.org)

This was my stupid idea.  I also got to maintain it, although the original
code (some of which may or may not still exist) came from Rocco.

=back

=cut

1;

__END__
This is a block of no longer needed code.  When I feel up to it,
I will remove it.

# The tempdialog does this modalfocus in Curses::UI::Widget which
# starts a secondary event loop.  I need to force use of POE. 

#sub tempdialog {
#    my $this = shift;
#    my $class = shift;
#    my %args = @_;
#
#    my $id = "__window_$class";
#
#    my $dialog = $this->add($id, $class, %args);
#
#    $dialog->{-has_modal_focus} = 1;
#
#    $dialog->focus;
#    $dialog->draw;
#
#    # We loop ourself, this is a modial dialog..but its still gotta multitask.
#    while ( $dialog->{-has_modal_focus} ) {
#        $poe_kernel->loop_do_timeslice;
#    }
#
#    my $return = $dialog->get;
#
#    $dialog->{-focus} = 0;
#
#    $this->delete($id);
#    $this->root->focus(undef, 1);
#
#    return $return;
#}

# This is null prototyped only to match the Curses::UI::Widget
# subroutine it replaces...it SHOULDN'T be prototyped at all
# since it is a method.

