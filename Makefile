debug:
	odin build ./src -out:vwv.exe -debug --thread-count:1
release:
	odin build ./src -resource:app.rc -out:vwv.exe -subsystem:windows

clean:
	rm vwv.exe vwv.pdb

cody:
	@cody -direxclude ./src/dude/vendor -q