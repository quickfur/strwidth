D equivalent of Posix wcwidth / wcswidth
========================================

Relevant issues
---------------

* https://issues.dlang.org/show_bug.cgi?id=7054
* https://issues.dlang.org/show_bug.cgi?id=17810


Manifest
--------

	strwidth.d	// main implementations.
	benchmark.d	// benchmarking utility.
	compileWidth.d	// optional utility for extracting needed width data
			// from Unicode data file.
	(widthtbl.d)	// file generated by compileWidth from Unicode data


Contents
--------

The main code is in strwidth.d.

The width0() function is a rather slow reference implementation that's supposed
to represent what the correct behaviour should be.

The width1() function is a fast, trie-based function.

The width2() and width3() functions are further optimizations of width1 that
implement a short-circuit path for ASCII or mostly-ASCII strings that
completely bypass auto-decoding and a trie lookup when the character is in the
ASCII range.

The large unittest at the end contains a bunch of test cases, some rather
obscure, to test various corner cases that need to be addressed correctly.
These test cases are applied both to all widthX implementations to ensure that
they function correctly.

To run the unittests:

	dmd -unittest -main -run strwidth.d widthtbl.d


Benchmarking
------------

To compile the benchmarking tool, if you have SCons, just run:

	scons

and it will compile the benchmarking (as well the compileWidth tool, see
below). You may have to edit SConstruct to point to the location of dmd on your
machine.

Otherwise:

	dmd -unittest -O benchmark.d strwidth.d widthtbl.d

Running the benchmark utility will test the various widthX() implementations
alongside various baselines:

* walkLength, which is very fast but incorrect because it does not take
  grapheme clusters into account;

* byGraphemeWalk and graphemeStrideWalk, which do take grapheme clusters into
  account but are also incorrect because they don't account for East Asian
  Width and zero-width characters. They're also pretty slow because grapheme
  segmentation is expensive.

These are all tested against randomly-generated strings of various lengths and
contents (ASCII-only, or a random mixture of ASCII and non-ASCII Unicode
characters).

The `benchmark` utility takes an optional command-line argument specifying the
number of strings to test per function per string type. The default number is
10000.


Generating lookup tables
------------------------

The lookup tables used by isWide() and the widthX() implementations are, in
part, generated from the EastAsianWidth.txt file published by the Unicode
Consortium:

	ftp://ftp.unicode.org/Public/UNIDATA/EastAsianWidth.txt

The code for parsing this file is in compileWidth.d.

To run compileWidth:

	dmd -unittest -O compileWidth.d   # or just `scons` if you have it
	./compileWidth <path_to_widths_file>

The precompiled Trie data in widthtbl.d is generated by:

	./compileWidth -f trie > widthtbl.d

Note that EastAsianWidth.txt is a required input for generating this table; be
sure not to overwrite widthtbl.d if you do not have this file at hand,
otherwise the widthX() functions will not work correctly.

