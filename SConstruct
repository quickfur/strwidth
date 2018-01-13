#!/usr/bin/scons

env = Environment(
	DMD = '/usr/src/d/bin/dmd',
	DMDFLAGS = [ '-O', '-unittest' ]
)

env.Command('compileWidth', 'compileWidth.d',
	"$DMD $DMDFLAGS -of$TARGET $SOURCES"
)

env.Command('benchmark', [ 'benchmark.d', 'strwidth.d' ],
	"$DMD $DMDFLAGS -of$TARGET $SOURCES"
)
