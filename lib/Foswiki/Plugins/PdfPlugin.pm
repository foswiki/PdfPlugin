# See bottom of file for license and copyright information

package Foswiki::Plugins::PdfPlugin;

use strict;
use warnings;

use Foswiki::Func;
use File::Temp qw( tempfile );

our $VERSION           = '$Rev: 14686 $';
our $RELEASE           = '1.1.0';
our $SHORTDESCRIPTION  = 'Generate high quality PDF files from topics';
our $NO_PREFS_IN_TOPIC = 1;
our $PDF_CMD           = $Foswiki::cfg{Plugins}{PdfPlugin}{pdfCmd}
  || '/usr/local/bin/wkhtmltopdf';
our $PDF_CMD_RENDER_PARAMS = $Foswiki::cfg{Plugins}{PdfPlugin}{pdfparams}
  || '-q --enable-plugins --outline --print-media-type';
our $PDF_CMD_FILE_PARAMS = '%INFILE|F% %OUTFILE|F%';

our $pluginName = 'PdfPlugin';

=pod

=cut

sub initPlugin {
    my ( $topic, $web, $user, $installWeb ) = @_;

    debug("initPlugin");

    if ( $Foswiki::Plugins::VERSION < 2.0 ) {
        Foswiki::Func::writeWarning( 'Version mismatch between ',
            __PACKAGE__, ' and Plugins.pm' );
        return 0;
    }

    # Plugin correctly initialized
    return 1;
}

=pod

Method (almost verbatim) copied from GenPDFWebkitPlugin.
Author: Michael Daum

=cut

sub completePageHandler {

    #my($html, $httpHeaders) = @_;

    my $query = Foswiki::Func::getCgiQuery();
    my $contenttype = $query->param("contenttype") || 'text/html';

    debug("completePageHandler");

    # is this a pdf view?
    return unless $contenttype eq "application/pdf";

    require File::Temp;
    require Foswiki::Sandbox;

    # remove left-overs
    $_[0] =~ s/([\t ]?)[ \t]*<\/?(nop|noautolink)\/?>/$1/gis;

    # create temp files
    my $htmlFile = new File::Temp( PREFIX => $pluginName . 'XXXXXXXXXX', SUFFIX => '.html' );
    my $pdfFile  = new File::Temp( PREFIX => $pluginName . 'XXXXXXXXXX', SUFFIX => '.pdf' );

    debug("htmlFile=$htmlFile");
    debug("pdfFile=$pdfFile");

    # creater html file
    print $htmlFile "$_[0]";

    # execute
    my $pdfCmd = "$PDF_CMD $PDF_CMD_RENDER_PARAMS $PDF_CMD_FILE_PARAMS";
    debug("pdfCmd=$pdfCmd");
    my ( $output, $exit ) = Foswiki::Sandbox->sysCommand(
        $pdfCmd,
        OUTFILE => $pdfFile->filename,
        INFILE  => $htmlFile->filename,
    );

    local $/ = undef;

    if ($exit) {
        throw Error::Simple(
            "$pluginName -- execution of wkhtmltopdf failed ($exit)");
    }

    $_[0] = <$pdfFile>;
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
