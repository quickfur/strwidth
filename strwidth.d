/**
 * Experimental code to explore fast implementations of string width.
 */

/**
 * Reference implementation that takes into account:
 *
 * - Non-ASCII characters
 * - Combining diacritics
 * - Zero-width spaces
 */
size_t width0(string s)
{
    import std.algorithm.comparison : among;
    import std.range.primitives;
    import std.uni : graphemeStride;
    import std.utf : decode;

    size_t w = 0;
    for (size_t i = 0; i < s.length; i += graphemeStride(s, i))
    {
        auto ch = s[i .. $].front; // depends on autodecoding (ugh)
        if (!ch.among('\u200B', '\u200C', '\u200D', '\uFEFF'))
            w++;
    }
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
    static struct S
    {
        string str;
        size_t correctWidth;
    }

    S[] testcases = [
        /* ASCII base cases */

        S("", 0),
        S("a", 1),
        S("abc def 123 456", 15),

        /* Combining diacritics */

        // Non-ASCII test cases with no combining diacritics.
        S("Это круто!", 10),
        S("Starts with ASCII but ends with кирилица", 40),
        S("á", 1),

        // Combining diacritics with ASCII base
        S("a\u0301", 1),
        S("abc\u0301def", 6),
        S("abc\u0301\u0302\u0303def", 6),

        // Combining diacritics with non-ASCII base
        S("Кру\u0301той", 6),
        S("Кру\u0301\u0302\u0303той", 6),

        // Mixture of ASCII, non-ASCII, and combining marks for each.
        S("I lo\u0301ve yo\u0302u, душа\u0301 моя\u0301\u0302!", 21),

        // TBD: Hangul / Jamo grapheme clusters

        /* Zero-width characters and BOMs */
        S("zero\u200Bwidth", 9),
        S("zero\u200Cwidth non-joiner", 20),
        S("zero\u200Dwidth joiner", 16),
        S("\uFEFFBOM", 3),

        /* Double-width characters */
        // TBD
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
    //test!width;
}

// vim:set sw=4 ts=4 et:
