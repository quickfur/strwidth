/**
 * Tool for parsing EastAsianWidth.txt and coalescing ranges as much as
 * possible.
 */
import std.algorithm;
import std.conv;
import std.range;
import std.regex;
import std.stdio;
import std.uni;

struct CharRange
{
    int start = int.min;
    int end = int.min;

    void toString(scope void delegate(const(char)[]) sink)
    {
        import std.format : formattedWrite;
        if (start == end)
            sink.formattedWrite("%04X", start);
        else
            sink.formattedWrite("%04X..%04X", start, end);
    }

    bool opCast(T : bool)() { return start >= 0; }
}

void parse(alias writeln = std.stdio.writeln, R)(R data)
    if (isInputRange!R && is(ElementType!R : const(char)[]))
{
    auto re = regex(`^([0-9A-F]{4,})(?:\.\.([0-9A-F]{4,}))?;(A|F|H|N|Na|W)\b`);
    CharRange curRange;
    foreach (line; data)
    {
        auto m = line.matchFirst(re);
        if (!m) continue;

        auto width = m[3];
        if (width != "F" && width != "W")
            continue; // ignore non-wide entries

        if (m[2].length == 0)
        {
            auto ch = m[1].to!int(16);
            if (ch <= curRange.end + 1)
            {
                // Can extend current range.
                curRange.end = ch;
            }
            else
            {
                // Disjoint from current range; yield current range and start
                // new range.
                if (curRange) writeln(curRange);
                curRange.start = curRange.end = ch;
            }
        }
        else
        {
            auto start = m[1].to!int(16);
            auto end   = m[2].to!int(16);

            if (curRange.end + 1 >= start)
            {
                // Can merge with current range.
                curRange.end = max(end, curRange.end);
            }
            else
            {
                // Disjoint from current range; yield current range and start
                // new range.
                if (curRange) writeln(curRange);
                curRange.start = start;
                curRange.end = end;
            }
        }
    }
    if (curRange) writeln(curRange);
}

unittest
{
    CharRange[] output;
    parse!((r) { if (r.start != int.min) output ~= r; })([
        "0000;N"
    ]);
    assert(output == []);

    output = [];
    parse!((r) { if (r.start != int.min) output ~= r; })([
        "0000;W"
    ]);
    assert(output == [ CharRange(0x0000, 0x0000) ]);

    output = [];
    parse!((r) { if (r.start != int.min) output ~= r; })([
        "0000;W",
        "0001;W"
    ]);
    assert(output == [ CharRange(0x0000, 0x0001) ]);

    output = [];
    parse!((r) { if (r.start != int.min) output ~= r; })([
        "0000;W",
        "0001;N",
        "0002;W"
    ]);
    assert(output == [
        CharRange(0x0000, 0x0000),
        CharRange(0x0002, 0x0002),
    ]);

    output = [];
    parse!((r) { if (r.start != int.min) output ~= r; })([
        "0000;W",
        "0001..0002;W"
    ]);
    assert(output == [ CharRange(0x0000, 0x0002) ]);

    output = [];
    parse!((r) { if (r.start != int.min) output ~= r; })([
        "0000..0001;W"
    ]);
    assert(output == [ CharRange(0x0000, 0x0001) ]);

    output = [];
    parse!((r) { if (r.start != int.min) output ~= r; })([
        "0000..0001;W",
        "0002;F"
    ]);
    assert(output == [ CharRange(0x0000, 0x0002) ]);

    output = [];
    parse!((r) { if (r.start != int.min) output ~= r; })([
        "0000..0001;F",
        "0002..0003;W"
    ]);
    assert(output == [ CharRange(0x0000, 0x0003) ]);

    output = [];
    parse!((r) { if (r.start != int.min) output ~= r; })([
        "0000..0001;Na",
        "0002..0003;W"
    ]);
    assert(output == [ CharRange(0x0002, 0x0003) ]);

    output = [];
    parse!((r) { if (r.start != int.min) output ~= r; })([
        "0000..0001;W",
        "0002;F",
        "0003..0004;W"
    ]);
    assert(output == [ CharRange(0x0000, 0x0004) ]);

    output = [];
    parse!((r) { if (r.start != int.min) output ~= r; })([
        "0000..0001;W",
        "0002;N",
        "0003..0004;W"
    ]);
    assert(output == [
        CharRange(0x0000, 0x0001),
        CharRange(0x0003, 0x0004)
    ]);

    output = [];
    parse!((r) { if (r.start != int.min) output ~= r; })([
        "0000..0001;W",
        "0002;F",
        "0003..0004;N"
    ]);
    assert(output == [ CharRange(0x0000, 0x0002) ]);
}

void dumpRanges(R)(R data)
    if (isInputRange!R && is(ElementType!R : const(char)[]))
{
    data.parse();
}

void dumpIntervals(R)(R data)
    if (isInputRange!R && is(ElementType!R : const(char)[]))
{
    data.parse!((CharRange r) {
        writefln("%d, %d,", r.start, r.end+1);
    });
}

void genCode(R)(R data)
    if (isInputRange!R && is(ElementType!R : const(char)[]))
{
    import std.uni;

    uint[] ranges;
    data.parse!((CharRange r) {
        ranges ~= [ r.start, r.end+1 ];
    });

    auto wideChars = CodepointSet(ranges);
    writeln(wideChars.toSourceCode("isWide"));
}

/**
 * Construct trie of character display widths, and generate precompiled
 * TrieNode declarations.
 */
void genTrie(R, File)(R data, File sink)
    if (isInputRange!R && is(ElementType!R : const(char)[]))
{
    // Not the most efficient, but doesn't matter since we're just generating
    // code.
    byte[dchar] widthMap;

    // Fill in wide characters from EastAsianWidth.txt.
    data.parse!((CharRange r) {
        foreach (ch; r.start .. r.end+1)
            widthMap[ch] = 2;
    });

    /**
     * Anything that extends a grapheme will be assigned width 0, so that
     * we only count grapheme bases. This shortcut saves us from needing to
     * explicitly segment by graphemes, which is very slow.
     *
     * Also include Default_Ignorable_Code_Point in the zero width
     * category. This deals with zero-width separators and other
     * non-spacing modifiers.
     */
    foreach (ch; (unicode.Grapheme_extend |
                  unicode.hangulSyllableType("V") |
                  unicode.hangulSyllableType("T") |
                  unicode.Default_Ignorable_Code_Point).byCodepoint)
    {
        widthMap[ch] = 0;
    }

    alias Seq(A...) = A;
    alias Params = Seq!(8, 5, 8);

    auto trie = codepointTrie!(byte, Params)(widthMap, 1);

    sink.writef(q"PROLOGUE
struct TrieEntry(T...)
{
    size_t[] offsets;
    size_t[] sizes;
    size_t[] data;
}
PROLOGUE");

    sink.writef("//%d bytes\nenum WidthTrieEntries = TrieEntry!(%s",
                trie.bytes, typeof(trie[0]).stringof);
    foreach (lvl; Params[0 .. $])
        sink.writef(", %d", lvl);
    sink.writeln(")(");
    trie.store(sink.lockingTextWriter);
    sink.writeln(");");
}

void main(string[] args)
{
    import std.getopt;

    enum OutputFmt
    {
        ranges, intervals, code, trie
    }

    OutputFmt outfmt;
    getopt(args,
        "format|f", "Output format", &outfmt,
    );

    string datafile = "ext/unicode-10.0.0/EastAsianWidth.txt";
    if (args.length >= 2)
        datafile = args[1];

    auto data = File(datafile, "r").byLine;
    final switch(outfmt)
    {
        case OutputFmt.ranges:
            dumpRanges(data);
            break;

        case OutputFmt.intervals:
            dumpIntervals(data);
            break;

        case OutputFmt.code:
            genCode(data);
            break;
    
        case OutputFmt.trie:
            genTrie(data, stdout);
            break;
    }
}

// vim:set sw=4 ts=4 et:
