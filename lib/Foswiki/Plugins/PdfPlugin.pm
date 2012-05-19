# See bottom of file for license and copyright information

package Foswiki::Plugins::PdfPlugin;

use strict;
use warnings;

use Foswiki::Func;
use Foswiki::OopsException ();
use File::Temp qw( tempfile );
use Error qw( :try );
use Data::Dumper;    # for error output

our $VERSION          = '$Rev: 14686 $';
our $RELEASE          = '1.0.0';
our $SHORTDESCRIPTION = 'Generate high quality PDF files from topics';
our $NO_PREFS_IN_TOPIC = 1;
our $PDF_CMD           = $Foswiki::cfg{Plugins}{PdfPlugin}{wkhtmltopdf}
  || '/usr/local/bin/wkhtmltopdf';
our $DISPLAY_PARAMS = $Foswiki::cfg{Plugins}{PdfPlugin}{displayParams} || '';
our $pluginName = 'PdfPlugin';

=pod

=cut

sub initPlugin {
    my ( $topic, $web, $user, $installWeb ) = @_;

    debug("initPlugin");

    # check for Plugins.pm versions
    if ( $Foswiki::Plugins::VERSION < 1.026 ) {
        Foswiki::Func::writeWarning(
            "Version mismatch between $pluginName and Plugins.pm");
        return 0;
    }
    
    # Plugin correctly initialized
    return 1;
}

=pod

=cut

sub viewPdf {
    my $session = shift;

    debug("viewPdf");

    $Foswiki::Plugins::SESSION = $session;

    my $web      = $session->{webName};
    my $topic    = $session->{topicName};
    my $response = $session->{response};

    my $query = Foswiki::Func::getRequestObject();

    # Check for existence
    Foswiki::Func::redirectCgiQuery( $query,
        Foswiki::Func::getOopsUrl( $web, $topic, "oopsmissing" ) )
      unless Foswiki::Func::topicExists( $web, $topic );

    # check topic existence
    if ( !Foswiki::Func::topicExists( $web, $topic ) ) {
        Foswiki::Func::redirectCgiQuery( undef,
            Foswiki::Func::getScriptUrl( $web, $topic, 'view' ), 1 );
        return 0;
    }

    _checkAccessPermissions( $web, $topic );

    my $displayParams = _displayParams($query);

    my $viewUrl =
      Foswiki::Func::getScriptUrl( $web, $topic, 'view', %{$displayParams} );
    debug("viewUrl=$viewUrl");

    # Create a temp file for output
    my ( $ofh, $outputFile ) = tempfile(
        $pluginName . 'XXXXXXXXXX',
        DIR    => _getTempDir(),
        SUFFIX => '.pdf'
    );

    debug("outputFile=$outputFile");

    my @cmdArgs = ( $viewUrl, $outputFile );    # perhaps later more args

    my $cmdArgs = join( ' ', @cmdArgs );
    my ( $output, $exit ) =
      Foswiki::Sandbox->sysCommand( $PDF_CMD . ' ' . $cmdArgs );

    if ( !-e $outputFile ) {
        die "error running wkhtmltopdf ($PDF_CMD): $output\n";
    }

    if ( !-s $outputFile ) {
        die "wkhtmltopdf produced zero length output ($PDF_CMD): $output\n"
          . join( ' ', @cmdArgs ) . "\n";
    }

    # output to screen
    my $cd = "filename=${web}_$topic.%s";

    try {
        print CGI::header(
            -TYPE                => 'application/pdf',
            -Content_Disposition => sprintf $cd,
            'pdf'
        );
    }
    catch Error::Simple with {
        print STDERR "$pluginName caught Error::Simple";
        my $e = shift;
        use Data::Dumper;
        die Dumper($e);
    };

    open $ofh, $outputFile;
    binmode $ofh;
    while (<$ofh>) {
        print;
    }
    close $ofh;

    # Cleaning up temporary files
    unlink $outputFile;

    # SMELL:  Foswiki 1.0.x adds the headers,  1.1 does not.   However
    # deleting them doesn't appear to cause problems in 1.1.

    my $headers = $response->headers();
    $response->deleteHeader( 'X-Foswikiuri', 'X-Foswikiaction' );
}

=pod

=cut

sub _displayParams {
    my ($query) = @_;

    # handle revision separately, independent from view params
    my $rev = $query->param('rev');

    my $urlParamInput = _queryParams($query);
    _cleanupDisplayParams($urlParamInput);
    my %displayParams = Foswiki::Func::extractParameters($urlParamInput);
    delete $displayParams{rev} if defined $rev;

    if ( !keys %displayParams ) {
        my $defaultParamInput = $DISPLAY_PARAMS;
        _cleanupDisplayParams($defaultParamInput);
        %displayParams = Foswiki::Func::extractParameters($defaultParamInput);
    }

    $displayParams{rev} = $rev if defined $rev;

    while ( my ( $key, $value ) = each %displayParams ) {
        $displayParams{key} = _urlEncode($value);
    }

    debug( "_displayParams; returning:" . Dumper( \%displayParams ) );

    return \%displayParams;
}

sub _cleanupDisplayParams {

    #	my ( $text ) = @_;
    $_[0] =~ s/(\w+\=\w+)([;&])/$1 /go;
    $_[0] =~ s/(\w+)\=(\w+)/$1="$2"/go;
}

sub _urlEncode {
    my ($text) = @_;

    $text =~ s/([^0-9a-zA-Z-_.:~!*'\/])/'%'.sprintf('%02x',ord($1))/ge;

    return $text;
}

=pod

=cut

sub _checkAccessPermissions {
    my ( $web, $topic ) = @_;

    my $userId = Foswiki::Func::getWikiName();

    my $hasAccess =
      Foswiki::Func::checkAccessPermission( 'VIEW', $userId, undef, $topic,
        $web );

    if ( !$hasAccess ) {
        throw Foswiki::OopsException(
            'accessdenied',
            def    => 'topic_access',
            params => [ 'view', 'denied' ]
        );
    }
}

=pod

=cut

sub _getTempDir {
    my $dir;
    if ( defined $Foswiki::cfg{TempfileDir} ) {
        $dir = $Foswiki::cfg{TempfileDir};
    }
    else {
        $dir = File::Spec->tmpdir();
    }
    return $dir;
}

=pod

=cut

sub _queryParams {
    my ( $request, $params ) = @_;
    return () unless $request;

    my $format =
      defined $params->{format}
      ? $params->{format}
      : '$name=$value';
    my $separator = defined $params->{separator} ? $params->{separator} : "\n";
    my $encoding = $params->{encoding} || 'safe';

    my @list;
    foreach my $name ( $request->param() ) {

        # Issues multi-valued parameters as separate hiddens
        my $value = $request->param($name);
        $value = '' unless defined $value;

        my $entry = $format;
        $entry =~ s/\$name/$name/g;
        $entry =~ s/\$value/$value/;
        push( @list, $entry );
    }
    return join( $separator, @list );
}

=pod

Shorthand debug function call.

=cut

sub debug {
    my ($text) = @_;
    Foswiki::Func::writeDebug("$pluginName:$text")
      if $text && $Foswiki::cfg{Plugins}{PdfPlugin}{Debug};
}

1;

# Plugin for Foswiki - The Free and Open Source Wiki, http://foswiki.org/
#
# Copyright (c) 2012 Arthur Clemens
# All Rights Reserved. Foswiki Contributors
# are listed in the AUTHORS file in the root of this distribution.
# NOTE: Please extend that file, not this notice.
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version. For
# more details read LICENSE in the root of this distribution.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
#
# For licensing info read LICENSE file in the installation root.
