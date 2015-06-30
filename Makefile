OUTPUT ?= build
SASS_PATH=sass/

build: prepare $(OUTPUT)/index.html $(OUTPUT)/style.css $(OUTPUT)/kanban.js

prepare:
	[ -d $(OUTPUT) ] || mkdir $(OUTPUT)

clean:
	rm -r $(OUTPUT) || :

$(OUTPUT)/%.css: %.sass
	sass -I $(SASS_PATH) $< > $@

$(OUTPUT)/%.js: %.coffee
	coffee -cs <$< > $@

$(OUTPUT)/%.html: %.html
	cp $< $@

.PHONY: build prepare clean
