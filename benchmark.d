/**
 * Benchmark for strwidth.
 */

string randomASCIIString(size_t len)
out(s) { assert(s.length == len); } do
{
    import std.random : uniform;

    auto buf = new char[len];
    foreach (i; 0 .. len)
        buf[i] = cast(char) uniform(32, 128);
    return buf.idup;
}

string randomUnicodeString(size_t len)
out(s) { assert(s.length == len); } do
{
    import std.random : uniform;

    char[] buf;
    while (buf.length < len)
    {
        import std.utf : codeLength, encode, isValidDchar;

        // We only include planes 0-2, since planes 3-13 are unassigned and
        // planes 14-16 are special-purpose / private use and rarely
        // encountered.
        dchar ch;
        while (!isValidDchar(ch = uniform(32, 0x2FFFF))) {}

        if (buf.length + ch.codeLength!char < len)
            buf.encode(ch);
        else
        {
            // Fill the rest with ASCII.
            while (buf.length < len)
                buf ~= cast(char) uniform(32, 128);
            break;
        }
    }

    import std.exception : assumeUnique;
    return assumeUnique(buf);
}

alias Seq(A...) = A;

size_t byGraphemeWalk(string s)
{
    import std.range.primitives : walkLength;
    import std.uni : byGrapheme;

    return s.byGrapheme.walkLength;
}

size_t graphemeStrideWalk(string s)
{
    import std.uni : graphemeStride;

    size_t count;
    for (size_t i = 0; i < s.length; i += graphemeStride(s, i))
        count++;
    return count;
}

void main(string[] args)
{
    import std.datetime.stopwatch : benchmark;
    import std.range.primitives : walkLength;
    import std.stdio;

    import strwidth : width0, width;

    int numIter = 10_000;
    if (args.length >= 2)
    {
        import std.conv : to;
        numIter = args[1].to!int;
    }

    foreach (func; Seq!(walkLength, byGraphemeWalk, graphemeStrideWalk, width0,
                        width))
    {
        writefln("[%s] (%d iterations):", __traits(identifier, func), numIter);
        foreach (len; [ 32, 128, 1024 ])
        {
            import std.array : appender;
            auto asciiStrs = appender!(string[]);
            auto uniStrs   = appender!(string[]);
            foreach (i; 0 .. numIter)
            {
                asciiStrs.put(randomASCIIString(len));
                uniStrs.put(randomUnicodeString(len));
            }

            auto rs = benchmark!({
                foreach (s; asciiStrs.data)
                    auto w = func(s);
            }, {
                foreach (s; uniStrs.data)
                    auto w = func(s);
            })(1);

            writefln("\tASCII strings of %d bytes:\t%s", len, rs[0]);
            writefln("\tUnicode strings of %d bytes:\t%s", len, rs[1]);
        }
    }
}

// vim:set sw=4 ts=4 et:
