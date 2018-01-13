D equivalent of Posix wcwidth / wcswidth
========================================

Relevant issues
---------------

* https://issues.dlang.org/show_bug.cgi?id=7054
* https://issues.dlang.org/show_bug.cgi?id=17810


Manifest
--------

	strwidth.d	// main implementation.
	compileWidth.d	// optional utility for extracting needed width data
			// from Unicode data file.


Contents
--------

The main code is in strwidth.d.

The width0() function is a rather slow reference implementation that's supposed
to represent what the correct behaviour should be.

The width() function is a fast, trie-based function that's supposed to be
optimized for real-world use.  Currently it's still not as fast as it could be,
but should be a lot better than width0().

The large unittest at the end contains a bunch of test cases, some rather
obscure, to test various corner cases that need to be addressed correctly.
These test cases are applied both to width0() and width() to ensure that they
both function correctly.

To run the unittests:

	dmd -unittest -main -run strwidth.d


Generating lookup tables
------------------------

The lookup tables used by isWide(), width0(), and width() are, in part,
generated from the EastAsianWidth.txt file published by the Unicode Consortium:

	ftp://ftp.unicode.org/Public/UNIDATA/EastAsianWidth.txt

The code for parsing this file is in compileWidth.d.

To run compileWidth:

	dmd -unittest -O compileWidth.d
	./compileWidth <path_to_widths_file>

There's a bunch of output options that you can comment/uncomment at the end of
the code in main().  There's no nice CLI interface for this because it's meant
as a crude tool to extract the needed data, massage it appropriately, and
output it in a form that can be copied into the width() code.

The eventual goal is to move the ugly Trie construction code in width() into
compileWidth.d, and have it compile the Trie into a static list of pages that
can be statically copied into std/internal/unicode_tables.d in Phobos.  Having
this process automated is important, so that when the Unicode Consortium
publishes new revisions of EastAsianWidth.txt, we can update the implementation
of width() just by running compileWidth on the new file instead of needing to
manually tweak a bunch of numerical tables.

