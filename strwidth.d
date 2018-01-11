/**
 * Experimental code to explore fast implementations of string width.
 */

/**
 * Reference implementation that takes into account:
 *
 * - Non-ASCII characters
 * - Combining diacritics
 */
size_t width0(string s)
{
    import std.uni : graphemeStride;

    size_t w = 0;
    for (size_t i = 0; i < s.length; i += graphemeStride(s, i))
        w++;
    return w;
}

/**
 * Optimized implementation that tries to maximize performance without
 * compromising correctness.
 */
size_t width(string s)
{
    assert(0, "TBD");
}

unittest
{
    void test(alias impl)()
    {
        /* ASCII base cases */

        assert(impl("") == 0);
        assert(impl("a") == 1);
        assert(impl("abc def 123 456") == 15);

        /* Combining diacritics */

        // Non-ASCII test cases with no combining diacritics.
        assert(impl("Это круто!") == 10);
        assert(impl("Starts with ASCII but ends with кирилица") == 40);

        // Combining diacritics with ASCII base
        assert(impl("á") == 1 && impl("a\u0301") == 1);
        assert(impl("abc\u0301def") == 6);
        assert(impl("abc\u0301\u0302\u0303def") == 6);

        // Combining diacritics with non-ASCII base
        assert(impl("Кру\u0301той") == 6);
        assert(impl("Кру\u0301\u0302\u0303той") == 6);

        // Mixture of ASCII, non-ASCII, and combining marks for each.
        assert(impl("I lo\u0301ve yo\u0302u, душа\u0301 моя\u0301\u0302!") ==
               21);

        // TBD: Hangul / Jamo grapheme clusters

        /* Zero-width characters */
        // TBD

        /* Double-width characters */
        // TBD
    }

    test!width0;
    //test!width;
}

// vim:set sw=4 ts=4 et:
