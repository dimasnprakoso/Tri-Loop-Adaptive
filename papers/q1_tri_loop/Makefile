PAPER = main

.PHONY: all clean refresh

all: $(PAPER).pdf

$(PAPER).pdf: $(PAPER).tex references.bib tables/*.tex figures/*.pdf
	pdflatex $(PAPER)
	bibtex $(PAPER) || true
	pdflatex $(PAPER)
	pdflatex $(PAPER)

# Refresh dynamic assets dari pipeline build (assumes simulasi sudah jalan)
refresh:
	cp ../../results/processed/comparative_table.tex tables/
	cp ../../results/figures/fig_comparative_heatmap.pdf figures/
	cp ../../results/figures/fig_mc_pareto.pdf figures/
	cp ../../results/figures/fig_mc_ci.pdf figures/
	cp ../../results/figures/fig_mc_histogram.pdf figures/
	cp ../../results/figures/fig_eigen_locus.pdf figures/
	cp ../../results/figures/fig_eigen_damping.pdf figures/
	cp ../../results/figures/fig_eigen_dominant.pdf figures/
	cp ../../results/figures/fig_s6_madiun_summary.pdf figures/
	cp ../../results/figures/fig_validation_simulink_s1.pdf figures/
	cp ../../results/figures/fig_validation_simulink_s3.pdf figures/

clean:
	rm -f $(PAPER).aux $(PAPER).log $(PAPER).bbl $(PAPER).blg \
	      $(PAPER).out $(PAPER).toc $(PAPER).synctex.gz $(PAPER).fdb_latexmk \
	      $(PAPER).fls
