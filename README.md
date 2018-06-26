# RNASeq_Tpseudonana

4/15/18

The purpose of this project is to identify genes that are differentially expressed by the model diatom Thalassiosira
pseudonana under varying light-dependent growth rates (for more info on culture conditions, see Fisher and Halsey 2016).
RNA was extracted from cells grown under continuous culture. Three separate cultures were grown under each of three
conditions, leadings to a total of 9 samples (High light (HLA/B/C), medium light (MLA/B/C), and low light (LLA/B/C)).

The RNA-Seq pipeline used in this analysis:

***Sickle***
Purpose: quality trimming
Output: FASTQ
Location: local/cluster/mueller/
Command: sickle se -f $(DIRPATH)/READS/$${file}.fastq -o $(DIRPATH)/RNA_SEQ/Sickle_Output/$${file}_qual -t sanger -q 33 -l 50

***HISAT2: Index build***
Purpose: builds a HISAT2 index for aligning RNA reads to reference genome
Output: Index files, .ht2
Location: /local/cluster/hisat2-2.1.0/
Commands:
	/local/cluster/hisat2-2.1.0/hisat2_extract_splice_sites.py Tpseudo_annot.gtf > tp.ss
        /local/cluster/hisat2-2.1.0/hisat2_extract_exons.py Tpseudo_annot.gtf > tp.ex
        /local/cluster/hisat2-2.1.0/hisat2-build --ss tp.ss --exon tp.ex Tpseudo_genome.fa tp_index
Runtime: ~5 minutes total
Notes: Used gffread (/local/cluster/bin/) to convert annotated genome from NCBI (accession # GCA_000149405.2) from GFF to GTF format. Python s$
provided in HISAT2 package for index building do not accept GFF files.

***HISAT2***
Purpose: aligns reads to reference genome
Output: SAM
Location: local/cluster/bin/hisat2-2.1.0/
Command: hisat2 -x $(DIRPATH)/DB/tp_index -U $(DIRPATH)/RNA_SEQ/Sickle_Output/$${file}_qual -S $(DIRPATH)/RNA_SEQ/Hisat_Output/$${file}_hisat

##Add: samtools, stats, bedtools, R coverage historgram script



