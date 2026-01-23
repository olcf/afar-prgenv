TEX := afar-prgenv
PDF := $(TEX).pdf

LATEX ?= pdflatex
LATEXFLAGS ?= -interaction=nonstopmode -halt-on-error
BIBTEX ?= bibtex

TEX_SOURCES := $(TEX).tex $(wildcard src/*.tex)
BIB_SOURCES := $(wildcard *.bib)

.PHONY: all clean distclean

all: $(PDF)

$(PDF): $(TEX_SOURCES) $(BIB_SOURCES)
	$(LATEX) $(LATEXFLAGS) $(TEX).tex
	$(BIBTEX) $(TEX)
	$(LATEX) $(LATEXFLAGS) $(TEX).tex
	$(LATEX) $(LATEXFLAGS) $(TEX).tex

clean:
	rm -f *.aux *.bbl *.blg *.log *.out *.toc *.lof *.lot \
		*.fls *.fdb_latexmk *.synctex.gz

distclean: clean
	rm -f $(PDF)
