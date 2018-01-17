#!/usr/bin/scons

env = Environment(
	DMD = '/usr/src/d/bin/dmd',
	DMDFLAGS = [ '-O', '-unittest' ]
)

env.Command('compileWidth', 'compileWidth.d',
	"$DMD $DMDFLAGS -of$TARGET $SOURCES"
)

env.Command('benchmark', Split("""
		benchmark.d
		strwidth.d
		widthtbl.d
	"""),
	"$DMD $DMDFLAGS -of$TARGET $SOURCES"
)

env.Command('widthtbl.d', 'compileWidth',
	"./compileWidth -f trie > $TARGET"
)

env.Precious('widthtbl.d')
