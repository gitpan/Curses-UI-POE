# $Id$

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

use warnings FATAL => qw( all );
use strict;

use POE;
use base qw( Curses::UI );

use Exporter;
use vars qw( @EXPORT );
@EXPORT = qw( MainLoop );

*VERSION = \0.020;
our $VERSION;

# This is our hook into the Curses::UI Constructor.  We make it do what
# it would normally do, but we make it create our session as well since
# it will only be called from the end of the Curses::UI object, generally.

sub new { 
    my $result = Curses::UI->new(@_);

    POE::Session->create
        ( inline_states => {
            _start        => sub {
                $_[KERNEL]->select(\*STDIN, "got_keystroke");
                $Curses::UI::rootobject->set_read_timeout;
            },
            got_keystroke => sub {
                $Curses::UI::rootobject->do_one_event;
                Curses::curs_set($Curses::UI::rootobject->{-cursor_mode});
            },
            got_timer     => sub {
                $Curses::UI::rootobject->do_one_event;
                Curses::curs_set($Curses::UI::rootobject->{-cursor_mode});
            },
          },
        );

    return bless $result, "Curses::UI::POE";
}

# Session is created in global space so just dialog only applications will work.

sub MainLoop { 
    unless ($Curses::UI::rootobject) {
        die "MailLoop: Curses::UI::rootobject not created.";
    }

    $Curses::UI::rootobject->mainloop 
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

    $poe_kernel->delay(got_timer => $new_timeout);

    # Force the read timeout to be 0, so Curses::UI polls.
    $this->{-read_timeout} = 0;
    return $this;
}

# The tempdialog does this modalfocus in Curses::UI::Widget which
# starts a secondary event loop.  I need to force use of POE. 

sub tempdialog {
    my $this = shift;
    my $class = shift;
    my %args = @_;

    my $id = "__window_$class";

    my $dialog = $this->add($id, $class, %args);

    $dialog->{-has_modal_focus} = 1;

    $dialog->focus;
    $dialog->draw;

    # Do individual pieces of the POE Event loop without the whole thing...
    # just for a bit...  Also stop that warning.
    while ( $dialog->{-has_modal_focus} ) {
        $poe_kernel->loop_do_timeslice;
    }

    my $return = $dialog->get;

    $dialog->{-focus} = 0;

    $this->delete($id);
    $this->root->focus(undef, 1);

    unless ($POE::Kernel::kr_run_warning) {
        $POE::Kernel::kr_run_warning |= POE::Kernel::KR_RUN_SESSION;
    }

    return $return;
}

=head1 NAME

Curses::UI::POE

=head1 SYNOPSIS

 use Curses::UI::POE;
 my $cui = new Curses::UI::POE;
 $cui->mainloop

=head1 INTRODUCTION

This is a subclass for Curses::UI that enables it to work with POE.
It is designed to simply slide over Curses::UI.  Keeping the API the
same and simply forcing Curses::UI to do all of its event handling
via POE, instead of internal to itself.  This allows you to use POE
behind the scenes for things like networking clients, without Curses::UI
breaking your programs' functionality.

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

=head1 SEE ALSO

L<POE>, L<Curses::UI>.  Use of this module requires understanding of both
the Curses::UI widget set and the POE Framework.

=head1 BUGS

The Hello world examples, and other programs that use ONLY the Curses::UI
dialogs and no Curses::UI mainloop, currently cause a warning from POE
stating that POE::Kernel's run method was never called.  However, dialogs
work in and out of Curses::UI's mainloop, and use POE instead of blocking.

Hopefully that warning will be fixed soon.

Find any?  Send them to me!  tag@cpan.org

=head1 AUTHOR

=over 2

=item Original Author

Rocco Caputo (rcaputo@cpan.org)

=item Concept, Many Fixes, Current Maintainer

Scott McCoy (tag@cpan.org)

=back

=cut

1;
