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

*VERSION = \0.01;
our $VERSION;

sub mainloop {
    my $this = shift;

    $this->focus(undef, 1); # 1 = forced focus
        $this->draw;
    Curses::doupdate();

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

    run POE::Kernel;
}

sub set_read_timeout() {
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
breaking your programs functionality.

=head1 TIMERS

The undocumented Curses::UI timers ($cui->timer) will still work, and
they will be translated into POE delays.  I would suggest not using them,
however, as POE's internal alarms and delays are far more robust.

=head1 SEE ALSO

L<POE>, L<Curses::UI>.  Use of this module requires understanding of both
the Curses::UI widget set and the POE Framework.

=head1 BUGS

Find any?  Send them to me!  tag@cpan.org

=head1 AUTHOR

=head3 Original Author

Rocco Caputo (rcaputo@cpan.org)

=head3 Concept, Many Fixes, Current Maintainer

Scott McCoy (tag@cpan.org)

=cut

1;
