#!/usr/bin/scons

env = Environment(
	LDC = '/usr/src/d/ldc/latest/bin/ldc2',
	LDCFLAGS = [ '-O', '-g', '-gc' ]
)

# Convenience shorthand for building both the 'real' executable and a
# unittest-only executable.
def DProgram(env, target, sources):
	# Build real executable
	env.Command(target, sources, "$LDC $LDCFLAGS $LDCOPTFLAGS $SOURCES -of$TARGET")

	# Build test executable
	testprog = File(target + '-test').path
	teststamp = '.' + target + '-teststamp'
	#env.Depends(target, teststamp)
	env.Command(teststamp, sources, [
		"$LDC $LDCFLAGS $LDCTESTFLAGS $SOURCES -of%s" % testprog,
		"./%s" % testprog,
		"\\rm -f %s*" % testprog,
		"touch $TARGET"
	])
AddMethod(Environment, DProgram)

env.DProgram('compileWidth', 'compileWidth.d')

env.DProgram('benchmark', Split("""
		benchmark.d
		strwidth.d
		widthtbl.d
	"""))

env.Command('widthtbl.d', 'compileWidth',
	"./compileWidth -f trie > $TARGET"
)

env.Precious('widthtbl.d')
