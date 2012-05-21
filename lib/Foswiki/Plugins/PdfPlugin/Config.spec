#---+ Extensions
#---++ PdfPlugin

# **PATH**
# Location of the <code>wkhtmltopdf</code> executable, downloadable from <a href='http://code.google.com/p/wkhtmltopdf'>http://code.google.com/p/wkhtmltopdf</a>.
$Foswiki::cfg{Plugins}{PdfPlugin}{wkhtmltopdf} = '/usr/local/bin/wkhtmltopdf';

# **STRING**
# Parameters passed to <code>wkhtmltopdf</code>.
$Foswiki::cfg{Plugins}{PdfPlugin}{pdfparams} = '-q --enable-plugins --outline --print-media-type';

# **BOOLEAN**
# Enable debugging (debug messages will be written to data/debug.txt)
$Foswiki::cfg{Plugins}{PdfPlugin}{Debug} = 0;


1;
