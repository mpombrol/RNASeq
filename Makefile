
#
# Makefile 
# 
# Used to process Illumina Hiseq 3000 single-end 150 bp mRNA-derived reads from nine T. pseduonana samples. 

DIRPATH = /nfs1/MICRO/Halsey_Lab/lightlim_tp
DB = $(DIRPATH)/DB
BINPATH = /local/cluster
GFF = $(DB)/Tpseudo_annot.gff
FASTQCCMD = /local/cluster/hts/fastqc/fastqc_v0.10.0/FastQC/fastqc
TOPHAT = tophat
I = 50000
PROCS = 4
OPTIONS = --library-type fr-unstranded -i 70 -I $(I) -p $(PROCS)
BOW_OPTIONS = -v 2 -f -a --best -S -p $(PROCS)
CUFF_OPTIONS = -p $(PROCS) -g $(GFF) -I $(I)
CUFFDIFF_OPTIONS = -p $(PROCS)
SAMTOOLS_STATS = stats
SGE_OPTIONS = -q 'all.q'

FILELIST = `ls -1 $(DIRPATH)/READS/ | grep fastq | sed 's/.fastq.gz//g' | sed 's/.fastq//g'` 

all:
	@echo "    This folder is used to process RNA-SEQ data using fastq data files."
	@echo ""
	@echo "    The current GENOME path is:  $(DB)"
	@echo "    The current GFF file is:   $(GFF)"
	@echo "    The process FILE list is:    "
	@for file in $(FILELIST); do \
	echo "                                        $${file}"; \
	done ;
	@echo ""
	@echo "    Please type....."
	@echo " 	make unzip"
	@echo "    	make zip"
	@echo "     	make sickle"
	@echo "    	make hisat"
	@echo "    	make sam2bam"
	@echo "    	make samsort"
#	@echo "    	make samstat"
#	@echo "    	make tophat_pe"
#	@echo "    	make samstat_pe"
#	@echo "    	make cufflinks"
#	@echo "    	make cufflinks_pe"
#	@echo "    	make cuffdiff"
	@echo "    	make clean"
	@echo ""

test:
	@echo "TEST Rule Set ++==>"
	@date; sleep 2; date

sgetest:
	@echo "SGE-TEST Rule Set ++==>"
	@SGE_Batch -c "date; sleep 20; date" -r Date_Sleep_20_StdOut

unzip:
	@echo "Unzipping fastq.gz files ++==>"
	@SGE_Batch -c "gunzip $(DIRPATH)/READS/*.fastq.gz" -r unzip-StdOut

zip: 
	@echo "Zipping fastq files back up ++==>"
	@SGE_Batch -c "gzip $(DIRPATH)/READS/*.fastq" -r zip-StdOut

#Trims reads based on a phred score threshold of 33 and length threshold of 50bp. Note that new Illumina outputs are Sanger-encoded (-t sanger).
sickle:
	@echo "Quality trimming using Sickle ++==>"
	@test -d $(DIRPATH)/RNA_SEQ/Sickle_Output || mkdir $(DIRPATH)/RNA_SEQ/Sickle_Output
	@for file in $(FILELIST); do \
	SGE_Batch -c "$(BINPATH)/mueller/sickle se -f $(DIRPATH)/READS/$${file}.fastq -o $(DIRPATH)/RNA_SEQ/Sickle_Output/$${file}_qual -t sanger -q 33 -l 50" -r Sickle-$${file}-StdOut -P $(PROCS);\
	done ;

#Aligns trimmed reads to reference genome using pre-built index (tp_index, located in ~/Halsey_Lab/lightlim_tp/DB). See README for commands used to build index.
hisat:
	@echo "Aligning using HISAT2 ++==>"
	@test -d $(DIRPATH)/RNA_SEQ/Hisat_Output || mkdir $(DIRPATH)/RNA_SEQ/Hisat_Output
	@for file in $(FILELIST); do \
	SGE_Batch -c "$(BINPATH)/hisat2-2.1.0/hisat2 -x $(DIRPATH)/DB/tp_index -U $(DIRPATH)/RNA_SEQ/Sickle_Output/$${file}_qual -S $(DIRPATH)/RNA_SEQ/Hisat_Output/$${file}_hisat --dta" -r Hisat-$${file}-StdOut -P $(PROCS);\
	done ;

#Converts SAM files created by HISAT2 to BAM files using samtools 
sam2bam:
	@echo "Converting SAM to BAM using samtools ++==>"
	@test -d $(DIRPATH)/RNA_SEQ/BAM || mkdir $(DIRPATH)/RNA_SEQ/BAM
	@for file in $(FILELIST); do \
	SGE_Batch -c "$(BINPATH)/samtools-1.6/bin/samtools view -Sb $(DIRPATH)/RNA_SEQ/Hisat_Output/$${file}_hisat -o $(DIRPATH)/RNA_SEQ/BAM/$${file}.bam" -r sam2bam-$${file}-StdOut -P $(PROCS);\
	done ; 

###Maybe add some functionality that deletes the unsorted BAM files after?###
#Sorts reads in "genomic order" using samtools
samsort:
	@echo "Sorting reads in BAM files ++==>"
	@test -d $(DIRPATH)/RNA_SEQ/BAM || mkdir $(DIRPATH)/RNA_SEQ/BAM
	@for file in $(FILELIST); do \
	SGE_Batch -c "$(BINPATH)/samtools-1.6/bin/samtools sort $(DIRPATH)/RNA_SEQ/BAM/$${file}.bam -o $(DIRPATH)/RNA_SEQ/BAM/$${file}_sorted.bam" -r samsort-$${file}-StdOut -P $(PROCS);\
	done ; 

samindex:
	@echo "Creating indexed BAM files ++==>"
	@test -d $(DIRPATH)/RNA_SEQ/BAM || mkdir $(DIRPATH)/RNA_SEQ/BAM
	@for file in $(FILELIST); do \
	SGE_Batch -c "$(BINPATH)/samtools-1.6/bin/samtools index $(DIRPATH)/RNA_SEQ/BAM/$${file}_sorted.bam $(DIRPATH)/RNA_SEQ/BAM/$${file}.bai" -r samindex-$${file}-StdOut -P $(PROCS);\
	done ;

bamstats:
	@echo "Calculating stats from BAM files ++==>"
	@test -d $(DIRPATH)/RNA_SEQ/BamStats_Output || mkdir $(DIRPATH)/RNA_SEQ/BamStats_Output
	@for file in $(FILELIST); do \
	SGE_Batch -c "$(BINPATH)/samtools-1.6/bin/samtools $(SAMTOOLS_STATS) $(DIRPATH)/RNA_SEQ/BAM/$${file}_sorted.bam > $(DIRPATH)/RNA_SEQ/BamStats_Output/$${file}_stats" -r bamstats-$${file}-StdOut -P $(PROCS);\
	done ; 

coverageqc:
	@echo "Calculating coverage depth using bedtools ++==>"
	@test -d $(DIRPATH)/RNA_SEQ/CoverageQC || mkdir $(DIRPATH)/RNA_SEQ/CoverageQC
	@for file in $(FILELIST); do \
	SGE_Batch -c "$(BINPATH)/BEDTools/bin/genomeCoverageBed -ibam $(DIRPATH)/RNA_SEQ/BAM/$${file}_sorted.bam -g $(DIRPATH)/DB/Tpseudo_genome_lengths.txt > $(DIRPATH)/RNA_SEQ/CoverageQC/$${file}_coverage.txt" -r bedtools-$${file}-StdOut -P $(PROCS);\
	done ;

coveragehist:
	@echo "Creating a histogram based on bedtools coverage output ++==>"
	@test -d $(DIRPATH)/RNA_SEQ/CoverageQC || mkdir $(DIRPATH)/RNA_SEQ/CoverageQC
	@for file in $(FILELIST); do \
	SGE_Batch -c "R --slave --args $(DIRPATH)/RNA_SEQ/CoverageQC/$${file}_genome_coverage.txt $(DIRPATH)/RNA_SEQ/CoverageQC/$${file}.cvg.png < $(DIRPATH)/SCRIPTS/coverage_hist.R" -r cvghist-$${file}-StdOut -P $(PROCS);\
	done ;

stassemble:
	@echo "Assembling reads into putative transcripts ++==>"
	@test -d $(DIRPATH)/RNA_SEQ/StringTie_Output || mkdir $(DIRPATH)/RNA_SEQ/StringTie_Output
	@for file in $(FILELIST); do \
	SGE_Batch -c "stringtie -G $(GFF) $(DIRPATH)/RNA_SEQ/BAM/$${file}_sorted.bam -o $(DIRPATH)/RNA_SEQ/StringTie_Output/$${file}_assembled.gtf" -r StringTie-$${file}-StdOut -P $(PROCS);\
	done ;

stabundance:
	@echo "Estimating transcript abundance and creating a Ballgown directory structure (compatible with DESeq2) for downstream differential expression analysis ++==>"
	@test -d $(DIRPATH)/RNA_SEQ/DESeq2 || mkdir $(DIRPATH)/RNA_SEQ/DESeq2
	@for file in $(FILELIST); do \
	SGE_Batch -c "stringtie -eB -G $(DIRPATH)/RNA_SEQ/StringTie_Output/stringtiemerged.gtf -o $(DIRPATH)/RNA_SEQ/DESeq2/ballgown/$${file}/$${file}_abundances.gtf $(DIRPATH)/RNA_SEQ/BAM/$${file}_sorted.bam" -r STabundance-$${file}-StdOut -P $(PROCS);\
	done ;  



stringtiemerge:
	@echo "Assembling transcripts from multiple input files to generate a unified non-redundant set of isoforms ++==>"
	@for file in $(FILELIST); do \
	SGE_Batch -c "stringtie --merge -G $(GFF) $(DIRPATH)/RNA_SEQ/StringTie_Output/$${file}_assembled.gtf -o $(DIRPATH)/RNA_SEQ/StringTie_Output/stringtie_merged.gtf" -r STMerge-$${file}-Stdout -P $(PROCS);\
	done ;  


#countreads:
#       @echo "Here we go Count READS ++==>"
#       @test -d $(DIRPATH)/RNA_SEQ/READCOUNTS_Output || mkdir $(DIRPATH)/RNA_SEQ/READCOUNTS_Output
#       @for file in $(FILELIST); do \
#       SGE_Batch -c "$(BINPATH)/fastq_count_reads.pl -o $(DIRPATH)/RNA_SEQ/READCOUNTS_Output/$${file}.tab -f $(DIRPATH)/READS/$${file}.fastq" 
-o ReadCount-$${file}-StdOut;\
        done ;

#samstat:
#       @echo "Here we go SAMTOOLS ++==>"
#       @@test -d $(DIRPATH)/RNA_SEQ/SAMSTAT_Output || mkdir $(DIRPATH)/RNA_SEQ/SAMSTAT_Output
#       @for file in $(FILELIST); do \
#       SGE_Batch -c "$(SAMTOOLS) $(SAM_OPTIONS) $(DIRPATH)/RNA_SEQ/TopHat_Output/$${file}/accepted_hits.bam > $(DIRPATH)/RNA_SEQ/SAMSTAT_Outpu
t/$${file}_stat.txt" -o SAM-$${file}-StdOut;\
        done ;


#cufflinks:
#       @echo "Here we go CuffLinks ++==>"
#       @test -d $(DIRPATH)/RNA_SEQ/TopHat_Cufflinks || mkdir $(DIRPATH)/RNA_SEQ/TopHat_Cufflinks
#       @for file in $(FILELIST); do \
#       SGE_Batch -c "$(BINPATH)/cufflinks $(CUFF_OPTIONS) -o $(DIRPATH)/RNA_SEQ/TopHat_Cufflinks/$${file} $(DIRPATH)/RNA_SEQ/TopHat_Output/$${
file}/accepted_hits.bam" -m 8G -o Cufflinks-$${file}-StdOut -P $(PROCS) ;\
        done ;

#gtf_txt:
#       @echo "Generating the master GTF file list into \"Cufflinks_GFT_Files.txt\"  ++==>"
#       find ./ | grep transcripts.gtf | grep TopHat_Cufflinks > TopHat_Cufflinks/Cufflinks_GTF_Files.txt

#cuffmerge:
#       @echo "Generating the master GTF file list into \"Cufflinks_GFT_Files.txt\"  ++==>"
#       @test -d $(DIRPATH)/RNA_SEQ/Cuffmerge_Output_PE || mkdir $(DIRPATH)/RNA_SEQ/Cuffmerge_Output_PE
#       SGE_Batch -c "cuffmerge -g $(GFF) -p $(PROCS) -o Cuffmerge_Output/transcripts_all.gtf TopHat_Cufflinks/Cufflinks_GTF_Files.txt" -r Cuffmerge-StdOut -P $(PROCS) $(SGE_OPTIONS)


clean: 
        @echo ""
        @echo "Removing StdOut folders:"
        @while [ -z "$$CONTINUE" ]; do \
            read -r -p "This will get rid of all StdOut Folders that has been generated... [y/n] " CONTINUE; \
        done ; \
        if [ ! $$CONTINUE == "y" ]; then \
        if [ ! $$CONTINUE == "Y" ]; then \
            echo ""; \
            echo "OK if you want to keep them! Exiting Now!" ; exit 1 ; \
        fi \
        fi
        @echo ""
        @echo "Removing all the StdOut folders:"
        /bin/rm -r *StdOut*

realclean:
        @echo ""
        @echo "Removing Everything:"
        @while [ -z "$$CONTINUE" ]; do \
            read -r -p "This will get rid of everything that has been generated... [y/n] " CONTINUE; \
        done ; \
        if [ ! $$CONTINUE == "y" ]; then \
        if [ ! $$CONTINUE == "Y" ]; then \
            echo ""; \
            echo "Yeah probably a good idea not to do that! Exiting Now!" ; exit 1 ; \
        fi \
        fi
        @echo ""
        @echo "Removing basically everything that was good....."
        /bin/rm -r *StdOut* TopHat_Output TopHat_Cufflinks Cuffmerge_Output_PE READCOUNTS_Output
