/**
 * Tool for parsing EastAsianWidth.txt and coalescing ranges as much as
 * possible.
 */
import std.algorithm;
import std.conv;
import std.range;
import std.regex;
import std.stdio;

struct CharRange
{
    int start = int.min;
    int end = int.min;

    void toString(scope void delegate(const(char)[]) sink)
    {
        import std.format : formattedWrite;
        if (start == int.min) return;
        if (start == end)
            sink.formattedWrite("%04x", start);
        else
            sink.formattedWrite("%04x..%04x", start, end);
    }
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
                writeln(curRange);
                curRange.start = curRange.end = ch;
            }
        }
        else
        {
            auto start = m[1].to!int(16);
            auto end   = m[2].to!int(16);

            if (curRange.end + 1 <= start)
            {
                // Can merge with current range.
                curRange.end = max(end, curRange.end);
            }
            else
            {
                // Disjoint from current range; yield current range and start
                // new range.
                writeln(curRange);
                curRange.start = start;
                curRange.end = end;
            }
        }
    }

    if (curRange.start != -1)
        writeln(curRange);
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
}

void main()
{
    auto data = File("ext/unicode-10.0.0/EastAsianWidth.txt", "r").byLine;
    parse(data);
}

// vim:set sw=4 ts=4 et:
