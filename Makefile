# Find all .typ files in content/ that don't start with an underscore in their path
TYPST ?= typst
PREVIEW_PORT ?= 8080
TYP_FILES := $(shell find content -name '*.typ' -not -path '*/_*')

# Generate corresponding HTML file paths in _site/
HTML_FILES := $(patsubst content/%.typ,_site/%.html,$(TYP_FILES))

# The main target 'html' depends on all generated HTML files and assets
html: $(HTML_FILES) assets

# Pattern rule to compile .typ files to .html files
# $< is the first prerequisite (the .typ file)
# $@ is the target (the .html file)
# $(@D) is the directory part of the target
_site/%.html: content/%.typ
	@mkdir -p $(@D)
	$(TYPST) compile --root .. --features html --format html $< $@

assets:
	@mkdir -p _site/assets
	@cp -r assets/* _site/assets/

# Serve the site with the same /xiaoxu/ prefix used by GitHub Pages.
preview: html
	@mkdir -p _preview
	@ln -sfn ../_site _preview/xiaoxu
	@echo "Preview: http://127.0.0.1:$(PREVIEW_PORT)/xiaoxu/"
	python3 -m http.server $(PREVIEW_PORT) --directory _preview

# A clean rule to remove generated files
clean:
	rm -rf _site/*

.PHONY: html preview clean assets
