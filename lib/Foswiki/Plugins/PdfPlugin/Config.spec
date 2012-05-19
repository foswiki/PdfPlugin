#---+ Extensions
#---++ PdfPlugin

# **STRING**
# Display url parameters to show an optimized page view, for instance the print version of a topic. Multiple parameters can be passed separated by <code>;</code> or <code>&</code>.
$Foswiki::cfg{Plugins}{PdfPlugin}{displayParams} = 'cover=print;viewtemplate=plain';

# **PATH**
# Location of the <code>wkhtmltopdf</code> executable.
$Foswiki::cfg{Plugins}{PdfPlugin}{wkhtmltopdf} = '/usr/local/bin/wkhtmltopdf';

# **BOOLEAN**
# Enable debugging (debug messages will be written to data/debug.txt)
$Foswiki::cfg{Plugins}{PdfPlugin}{Debug} = 0;

# **PERL H**
# This setting is required to enable executing pdf script from the bin directory
$Foswiki::cfg{SwitchBoard}{pdf} = {
    package  => 'Foswiki::Plugins::PdfPlugin',
    function => 'viewPdf',
    context  => {
    	view => 1,
		static => 1
    }
};

1;
