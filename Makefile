MKDIR=mkdir -p
PODDOC1=pod2html --htmlroot=.
PODDOC2=pod2html --htmlroot=..
PODDOC3=pod2html --htmlroot=../..

HTMLDOC=./doc/html

DOCS=$(HTMLDOC)/Audicon.html \
     $(HTMLDOC)/Audicon/Database.html \
     $(HTMLDOC)/Audicon/Tools.html \
     $(HTMLDOC)/Audicon/File.html \
     $(HTMLDOC)/Audicon/NeuralNet.html \
     $(HTMLDOC)/Audicon/Feature.html \
     $(HTMLDOC)/Audicon/ProgressMeter.html \
     $(HTMLDOC)/Audicon/Feature/CentroidFreq.html \
     $(HTMLDOC)/Audicon/Feature/KeyAmplitudes.html \
     $(HTMLDOC)/Audicon/Feature/MagnitudeRatio.html \
     $(HTMLDOC)/Audicon/Feature/SpectralRolloff.html \
     $(HTMLDOC)/Audicon/Feature/SpectralFlux.html \
     $(HTMLDOC)/Audicon/Feature/ZeroCrossings.html \

doc: $(DOCS) clean-podtemp

$(DOCS): docdir

clean-podtemp:
	$(RM) pod2htmi.tmp pod2htmd.tmp

docdir:
	$(MKDIR) "$(HTMLDOC)/Audicon/Feature"

$(HTMLDOC)/Audicon.html:
	$(PODDOC1) Audicon.pm >"$(HTMLDOC)/Audicon.html"

$(HTMLDOC)/Audicon/Database.html:
	$(PODDOC2) Audicon/Database.pm >"$(HTMLDOC)/Audicon/Database.html"

$(HTMLDOC)/Audicon/Tools.html:
	$(PODDOC2) Audicon/Tools.pm >"$(HTMLDOC)/Audicon/Tools.html"

$(HTMLDOC)/Audicon/File.html:
	$(PODDOC2) Audicon/File.pm >"$(HTMLDOC)/Audicon/File.html"

$(HTMLDOC)/Audicon/NeuralNet.html:
	$(PODDOC2) Audicon/NeuralNet.pm >"$(HTMLDOC)/Audicon/NeuralNet.html"

$(HTMLDOC)/Audicon/Feature.html:
	$(PODDOC2) Audicon/Feature.pm >"$(HTMLDOC)/Audicon/Feature.html"

$(HTMLDOC)/Audicon/ProgressMeter.html:
	$(PODDOC2) Audicon/Progressmeter.pm >"$(HTMLDOC)/Audicon/Progressmeter.html"

$(HTMLDOC)/Audicon/Feature/CentroidFreq.html:
	$(PODDOC3) Audicon/Feature/CentroidFreq.pm >"$(HTMLDOC)/Audicon/Feature/CentroidFreq.html"

$(HTMLDOC)/Audicon/Feature/KeyAmplitudes.html:
	$(PODDOC3) Audicon/Feature/KeyAmplitudes.pm >"$(HTMLDOC)/Audicon/Feature/KeyAmplitudes.html"

$(HTMLDOC)/Audicon/Feature/MagnitudeRatio.html:
	$(PODDOC3) Audicon/Feature/MagnitudeRatio.pm >"$(HTMLDOC)/Audicon/Feature/MagnitudeRatio.html"

$(HTMLDOC)/Audicon/Feature/SpectralRolloff.html:
	$(PODDOC3) Audicon/Feature/SpectralRolloff.pm >"$(HTMLDOC)/Audicon/Feature/SpectralRolloff.html"

$(HTMLDOC)/Audicon/Feature/SpectralFlux.html:
	$(PODDOC3) Audicon/Feature/SpectralFlux.pm >"$(HTMLDOC)/Audicon/Feature/SpectralFlux.html"

$(HTMLDOC)/Audicon/Feature/ZeroCrossings.html:
	$(PODDOC3) Audicon/Feature/ZeroCrossings.pm >"$(HTMLDOC)/Audicon/Feature/ZeroCrossings.html"
