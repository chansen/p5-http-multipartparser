package Parse::HTTP::Multipart;

use strict;
use warnings;

BEGIN {
    our $VERSION = '0.01';
}

use Carp         qw[];
use Scalar::Util qw[];

my $_mk_parser;

sub new {
    my ($class, %params) = @_;

    Carp::croak(q/Mandatory parameter 'boundary' is missing/)
      unless exists $params{boundary};

    Carp::croak(q/Parameter 'boundary' is not a non-empty string/)
      unless ref \$params{boundary} eq 'SCALAR' && length $params{boundary};

    Carp::croak(q/Mandatory parameter 'on_header' is missing/)
      unless exists $params{on_header};

    Carp::croak(q/Parameter 'on_header' is not a CODE reference/)
      unless ref $params{on_header} eq 'CODE'; 

    Carp::croak(q/Mandatory parameter 'on_body' is missing/)
      unless exists $params{on_body};

    Carp::croak(q/Parameter 'on_body' is not a CODE reference/)
      unless ref $params{on_body} eq 'CODE';

    Carp::croak(q/Parameter 'on_error' is not a CODE reference/)
      unless !exists $params{on_error} || ref $params{on_error} eq 'CODE';

    my $self  = bless {
        max_preamble_size => 32 * 1024,
        max_header_size   => 32 * 1024,
        on_error          => \&Carp::croak,
        %params,
    }, $class;
    $self->{parser} = $_mk_parser->($self);
    return $self;
}

sub parse {
    @_ == 2 || Carp::croak(q/Usage: $parser->parse($octets)/);
    return $_[0]->{parser}->($_[1]);
}

sub finish {
    @_ == 1 || Carp::croak(q/Usage: $parser->finish()/);
    return $_[0]->{parser}->('', 1);
}

sub is_aborted {
    @_ == 1 || Carp::croak(q/Usage: $parser->is_aborted()/);
    return $_[0]->{aborted};
}

sub CRLF  () { "\x0D\x0A" }
sub TRUE  () { !!1 }
sub FALSE () { !!0 }

sub STATE_PREAMBLE () { 1 }
sub STATE_BOUNDARY () { 2 }
sub STATE_HEADER   () { 3 }
sub STATE_BODY     () { 4 }
sub STATE_EPILOGUE () { 5 }

$_mk_parser = sub {
    Scalar::Util::weaken(my $self = $_[0]);

    my $on_header = $self->{on_header};
    my $on_body   = $self->{on_body};
    my $on_error  = sub {
        $self->{aborted} = 1;
        goto $self->{on_error};
    };

    # RFC 2616 3.7.2 Multipart Types
    # The message body is itself a protocol element and MUST therefore use only
    # CRLF to represent line breaks between body-parts.
    my $boundary           = $self->{boundary};
    my $boundary_preamble  =        '--' . $boundary;
    my $boundary_delimiter = CRLF . '--' . $boundary;

    study $boundary_delimiter;

    my $body   = '';
    my $buffer = '';
    my $finish = FALSE;
    my $state  = STATE_PREAMBLE;
    return sub {
        $buffer .= $_[0];
        $finish  = $_[1];

        while (!$self->{aborted}) {
            if ($state == STATE_PREAMBLE) {
                my $pos = index($buffer, $boundary_preamble);
                if ($pos < 0) {
                    if (length $buffer > $self->{max_preamble_size}) {
                        $on_error->(q/Size of preamble exceeds maximum allowed/);
                        last;
                    }
                    $finish && $on_error->(q/End of stream encountered while parsing preamble/);
                    last;
                }
                substr($buffer, 0, $pos + 2 + length $boundary, '');
                $state = STATE_BOUNDARY;
            }
            elsif ($state == STATE_BOUNDARY) {
                if (length $buffer < 2) {
                    $finish && $on_error->(q/End of stream encountered while parsing boundary/);
                    last;
                }
                elsif (substr($buffer, 0, 2) eq CRLF) {
                    substr($buffer, 0, 2, '');
                    $state = STATE_HEADER;
                }
                elsif (substr($buffer, 0, 2) eq '--') {
                    if (length $buffer < 4) {
                        $finish && $on_error->(q/End of stream encountered while parsing closing boundary/);
                        last;
                    }
                    elsif (substr($buffer, 2, 2) eq CRLF) {
                        substr($buffer, 0, 4, '');
                        $state = STATE_EPILOGUE;
                    }
                    else {
                        $on_error->(q/Closing boundary does not terminate with CRLF/);
                        last;
                    }
                }
                else {
                    $on_error->(q/Boundary does not terminate with CRLF or hyphens/);
                    last;
                }
            }
            elsif ($state == STATE_HEADER) {
                my $pos = index($buffer, CRLF . CRLF);
                if ($pos < 0) {
                    if (length $buffer > $self->{max_header_size}) {
                        $on_error->(q/Size of part header exceeds maximum allowed/);
                        last;
                    }
                    $finish && $on_error->(q/End of stream encountered while parsing part header/);
                    last;
                }

                my @headers;
                for (split /\x0D\x0A/, substr($buffer, 0, $pos)) {
                    if (s/\A[\x09\x20]+//) {
                        if (!@headers) {
                            $on_error->(q/Continuation line seen before first header/);
                            return;
                        }
                        $headers[-1] .= $_;
                    }
                    else {
                        push @headers, $_;
                    }
                }
                substr($buffer, 0, $pos + 4, '');
                $state = STATE_BODY;
                $on_header->(\@headers);
            }
            elsif ($state == STATE_BODY) {
                my $take = index($buffer, $boundary_delimiter);
                if ($take < 0) {
                    $take = length($buffer) - (6 + length $boundary);
                    if ($take <= 0) {
                        $finish && $on_error->(q/End of stream encountered while parsing part body/);
                        last;
                    }
                }
                else {
                    $state = STATE_BOUNDARY;
                }

                $body = substr($buffer, 0, $take, '');

                if ($state == STATE_BOUNDARY) {
                    substr($buffer, 0, 4 + length $boundary, '');
                }

                $on_body->($body, $state == STATE_BOUNDARY);
            }
            # RFC 2616 3.7.2 Multipart Types
            # Unlike in RFC 2046, the epilogue of any multipart message MUST be
            # empty; HTTP applications MUST NOT transmit the epilogue (even if the
            # original multipart contains an epilogue). These restrictions exist in
            # order to preserve the self-delimiting nature of a multipart message-
            # body, wherein the "end" of the message-body is indicated by the
            # ending multipart boundary.
            elsif ($state == STATE_EPILOGUE) {
                (length $buffer == 0)
                  || $on_error->(q/Nonempty epilogue/);
                last;
            }
            else {
                Carp::croak(qq/panic: unknown state: $state/);
            }
        }
        return !$self->{aborted};
    };
};

1;
