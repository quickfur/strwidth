/**
 * Experimental code to explore fast implementations of string width.
 */
import std.format : format;
import std.uni;

immutable CodepointSetTrie!(8, 5, 8) widechars;

static this()
{
    // Generated from EastAsianWidth.txt by compileWidth.
    auto set = CodepointSet(4352, 4448, 8986, 8988, 9001, 9003, 9193, 9197,
        9200, 9201, 9203, 9204, 9725, 9727, 9748, 9750, 9800, 9812, 9855, 9856,
        9875, 9876, 9889, 9890, 9898, 9900, 9917, 9919, 9924, 9926, 9934, 9935,
        9940, 9941, 9962, 9963, 9970, 9972, 9973, 9974, 9978, 9979, 9981, 9982,
        9989, 9990, 9994, 9996, 10024, 10025, 10060, 10061, 10062, 10063,
        10067, 10070, 10071, 10072, 10133, 10136, 10160, 10161, 10175, 10176,
        11035, 11037, 11088, 11089, 11093, 11094, 11904, 11930, 11931, 12020,
        12032, 12246, 12272, 12284, 12288, 12351, 12353, 12439, 12441, 12544,
        12549, 12591, 12593, 12687, 12688, 12731, 12736, 12772, 12784, 12831,
        12832, 12872, 12880, 13055, 13056, 19904, 19968, 42125, 42128, 42183,
        43360, 43389, 44032, 55204, 63744, 64256, 65040, 65050, 65072, 65107,
        65108, 65127, 65128, 65132, 65281, 65377, 65504, 65511, 94176, 94178,
        94208, 100333, 100352, 101107, 110592, 110879, 110960, 111356, 126980,
        126981, 127183, 127184, 127374, 127375, 127377, 127387, 127488, 127491,
        127504, 127548, 127552, 127561, 127568, 127570, 127584, 127590, 127744,
        127777, 127789, 127798, 127799, 127869, 127870, 127892, 127904, 127947,
        127951, 127956, 127968, 127985, 127988, 127989, 127992, 128063, 128064,
        128065, 128066, 128253, 128255, 128318, 128331, 128335, 128336, 128360,
        128378, 128379, 128405, 128407, 128420, 128421, 128507, 128592, 128640,
        128710, 128716, 128717, 128720, 128723, 128747, 128749, 128756, 128761,
        129296, 129343, 129344, 129357, 129360, 129388, 129408, 129432, 129472,
        129473, 129488, 129511, 131072, 196606, 196608, 262142);

    widechars = codepointSetTrie!(8, 5, 8)(set);
}

/**
 * Returns: true if ch is designated as a wide character according to TR11
 * (Unicode Standard Annex #11 "East Asian Width"); false otherwise.
 */
bool isWide(dchar ch) @safe pure nothrow @nogc
{
    return widechars[ch];
}

unittest
{
    foreach (ch; '\u0000' .. '\u10FF'+1)
        assert(!widechars[ch], format("%04X", ch));

    foreach (ch; '\u1100' .. '\u115F'+1)
        assert( widechars[ch], format("%04X", ch));

    foreach (ch; '\u1160' .. '\u2319'+1)
        assert(!widechars[ch], format("%04X", ch));

    foreach (ch; '\u27C0' .. '\u2B1A'+1)
        assert(!widechars[ch], format("%04X", ch));

    foreach (ch; '\u4E00' .. '\u9FFF'+1)
        assert( widechars[ch], format("%04X", ch));

    // TBD: check other ranges
}

/**
 * Reference implementation that takes into account:
 *
 * - Non-ASCII characters
 * - Combining diacritics
 * - Zero-width spaces
 */
size_t width0(string s) pure @safe
{
    import std.algorithm.comparison : among;
    import std.range.primitives;
    import std.uni : graphemeStride, unicode;
    import std.utf : decode;

    auto defaultIgnorable = unicode.Default_Ignorable_Code_Point;

    size_t w = 0;
    for (size_t i = 0; i < s.length; i += graphemeStride(s, i))
    {
        auto ch = s[i .. $].front; // depends on autodecoding (ugh)
        if (!defaultIgnorable[ch])
            w++;
        if (ch.isWide)
            w++;
    }
    return w;
}

private template widthMap()
{
    auto loadEntries()
    {
        import widthtbl : displayWidthTrieEntries, TrieEntry;

        // Snitched from std.uni, 'cos it's supposed to be private.
        auto asTrie(T...)(in TrieEntry!T e)
        {
            return const(CodepointTrie!T)(e.offsets, e.sizes, e.data);
        }
        return asTrie(displayWidthTrieEntries);
    }

    private alias Impl = typeof(loadEntries());
    private immutable(Impl) widthMap;

    static this()
    {
        widthMap = loadEntries();
    }
}

/**
 * Optimized implementation that tries to maximize performance without
 * compromising correctness.
 */
template width1()
{
    alias impl = widthMap!();

    ///
    size_t width1(string s) pure @nogc @safe
    {
        size_t result;
        foreach (dchar ch; s)
            result += impl[ch];
        return result;
    }

    unittest
    {
        assert(width1("a") == 1);
        assert(width1("abc") == 3);
        assert(width1("Ж") == 1);
        assert(width1("жук") == 3);
    }
}

/**
 * Optimized implementation that tries to skip over ASCII segments for even
 * better performance.
 */
template width2()
{
    alias impl = widthMap!();

    ///
    size_t width2(string s) pure @nogc @safe nothrow
    {
        size_t result;
        for (size_t i = 0; i < s.length;)
        {
            if ((s[i] & 0x80) == 0)
            {
                i++;
                result++;
            }
            else
            {
                import std.utf : decode;
                import std.typecons : Yes;

                result += impl[decode!(Yes.useReplacementDchar)(s, i)];
            }
        }
        return result;
    }
}

/**
 * Optimized implementation that tries to skip over ASCII segments for even
 * better performance, and also short-circuit characters < U+300, since that's
 * the first character with width != 1.
 */
template width3()
{
    alias impl = widthMap!();

    ///
    size_t width3(string s) pure @nogc @safe nothrow
    {
        size_t result;
        for (size_t i = 0; i < s.length;)
        {
            if ((s[i] & 0x80) == 0)
            {
                i++;
                result++;
            }
            else
            {
                import std.utf : decode;
                import std.typecons : Yes;

                auto ch = decode!(Yes.useReplacementDchar)(s, i);
                result += (ch < 0xAD) ? 1 : impl[ch];
            }
        }
        return result;
    }
}

unittest
{
    static struct S
    {
        string str;
        size_t correctWidth;
    }

    S[] testcases = [
        /*
         * ASCII base cases
         */

        S("", 0),
        S("a", 1),
        S("abc def 123 456", 15),

        /*
         * Combining diacritics
         */

        // Non-ASCII test cases with no combining diacritics.
        S("Это круто!", 10),
        S("Starts with ASCII but ends with кирилица", 40),
        S("á", 1),

        // Combining diacritics with ASCII base
        S("a\u0301", 1),
        S("abc\u0301def", 6),
        S("abc\u0301\u0302\u0303def", 6),

        // Combining diacritics with non-ASCII base
        S("Круто\u0311й", 6),
        S("Кру\u0301\u0330\u0336то\u0313й", 6),

        // Mixture of ASCII, non-ASCII, and combining marks for each.
        S("I lo\u0301ve yo\u0302u, душа\u0301 моя\u0301\u0302!", 21),

        /*
         * Zero-width characters and BOMs.
         *
         * See: http://www.unicode.org/faq/unsup_char.html
         * See also: DerivedCoreProperties.txt (Default_Ignorable_Code_Point)
         */

        S("zero\u200Bwidth", 9),
        S("zero\u200Cwidth non-joiner", 20),
        S("zero\u200Dwidth joiner", 16),
        S("Left\u200E-to-right mark", 18),
        S("\uFEFFBOM", 3),

        S("soft hyph\u00ADen", 11),
        S("word\u2060joiner", 10),
        S("Func\u2061Application", 15),
        S("word\u2064joiner", 10),

        // Various Default Ignorable characters
        S("nb\u00A0sp", 5),
        S("Khmer\u17B4 AQ", 8),
        S("Khmer\u17B5 AA", 8),

        // Cf
        S("Mongolian variation\u180B", 19),
        S("Mongolian vowel\u180E sep", 19),
        S("Language\U000E0001Tag", 11),
        S("M\U0001D173usi\U0001D17Ac", 5),
        S("Reserved\U000E01F0.", 9),

        // Exceptional cases from Cf that should be displayed, so they should
        // have non-zero width (see TR44, Default_Ignorable_Code_Point).
        S("Arabic\u0600#", 8),
        S("Arabic\u0605z", 8),
        S("end of ayah\u06DD", 12),
        S("syriac abbrev\u070Fiation", 20),
        S("An\uFFF9no\uFFFAta\uFFFBtion", 13),
        S("Disputed\u08E2Ayah", 13),
        S("Kaithi\U000110BD#", 8),

        /*
         * East Asian Width
         */

        // Wide (W).
        S("張", 2),
        S("abc張123", 8),

        // Full (F).  Note: F ⊆ W, according to TR11.
        S("一\u3000二", 6),

        // Narrow (Na).
        S("\u2985張\u2986", 4),

        // Half-width (H). Note: H ⊆ Na, according to TR11.
        S("abc\u20A9def", 7),

        // Ambiguous (A): according to TR11, section 5 "Recommendations",
        // ambiguous width characters should be treated as narrow by default,
        // barring additional information.
        S("\u3248張\u324F", 4),

        // Hangul / Jamo grapheme clusters.
        // I love this one. It's a single grapheme, but since it is in a block
        // designated as having wide (W) East Asian Width, it should be counted
        // as taking up two character cells. Good luck making this work
        // efficiently.
        S("\u1100\u1161\u11A8", 2),

        /*
         * Kitchen sink test case
         */
        S("\uFEFF01\u200Cx\u0335ж\u0306\u0325大工\u0301,*", 10),
    ];

    void test(alias impl)()
    {
        foreach (test; testcases)
        {
            import std.format : format;
            auto w = impl(test.str);
            assert(w == test.correctWidth,
                   format("%s returned %d for input '%s', expected: %d",
                          __traits(identifier, impl), w, test.str,
                          test.correctWidth));
        }
    }

    test!width0;
    test!width1;
    test!width2;
    test!width3;
}

// vim:set sw=4 ts=4 et:
