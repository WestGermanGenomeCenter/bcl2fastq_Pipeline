# imports
from snakemake.utils import min_version, validate
import os
import sys
sys.path.append(os.path.abspath(os.getcwd())+"/scripts")
from helper import validateSamplesheet, validateOutput, validateProjectNum, adaptersToStringParams
import pandas as pd
p = os.path.abspath(".")

# Snakemake configs and setup
min_version("6.4.0")

configfile: "config.yaml"
validate(config, schema="../schemas/config.schema.yaml")
samplesheet = config["bcl2fastq"]["SampleSheet"]
outputfolder = config["bcl2fastq"]["OutputFolder"]

### include rules ###

include: "qc.smk"

# Get the fastq.gz samples
sample_names = list()
if os.path.isfile(outputfolder+"/fastq_infiles_list.tx"):
    samples_dataframe = pd.read_csv(outputfolder+"/fastq_infiles_list.tx", header=None)
    fastqs = list(samples_dataframe.iloc[:, 0].values)
    sample_names = [fastq[:-9] for fastq in fastqs]

# Validate input from config
def validateBefore(outputfolder):
    success = validateSamplesheet(samplesheet)
    outputfolder = validateOutput(outputfolder)
    return True if success and outputfolder is not None else False

validRun = validateBefore(outputfolder)


# Check for projectNum in samplesheet name
projectNum=validateProjectNum(samplesheet)
if not projectNum:
    print("There was no project number to be found in the samplesheet and/or the name of the samplesheet")



# Set expected pipeline output
def getOutput():
    all = list()

    if config["gocryptfs"]["gocryptfs_active"]:
        all.extend(expand("{out}/encrypted/gocryptfs.conf",out=outputfolder))
    else:
        all.extend(expand("{out}/untrimmed_fastq/{file}.fastq.gz",out=outputfolder,file=sample_names))
        all.extend(expand("{out}/multiqc_report_{prj}.html",out=outputfolder,prj=projectNum))

    if config["rseqc"]["rseqc_mapping_active"]:
        all.extend(expand("{out}/counts/all.tsv",out=outputfolder))
        all.extend(expand("{out}/multiqc_report_complete_{prj}.html",out=outputfolder,prj=projectNum))
        all.extend(expand("{out}/qc/qualimap/{file}/qualimapReport.html",out=outputfolder,file=sample_names)) # final qualimap output
        all.extend(expand("{out}/stringtie/transcripts_{file}.gtf",out=outputfolder,file=sample_names)) # test this 
        all.extend(expand("{out}/samtools/{file}_samtools_stats.stats",out=outputfolder,file=sample_names)) # test this 
        # samtools_stats_file=outputfolder + "/samtools/{file}_samtools_stats.stats",
        #print("getOutput list of files:")
        #print (all)
    if config["rseqc"]["rseqc_modules_active"]:
        all.extend(expand("{out}/qc/rseqc/done.flag",out=outputfolder)) # outputfolder+"/qc/rseqc/done.flag"
    if config["umi_tools"]["umi_tools_active"]:
        for sample in sample_names:
            all.extend(expand("{out}/umi_extract/{file}.umis-extracted.fastq.gz",out=outputfolder,file=sample_names))
            all.extend(expand("{out}/star/{file}_deduped.Aligned.sortedByCoord.out.bam",out=outputfolder,file=sample_names))


#    if config["kmer_spectra"]["kmer_spectra_on"]:
#        all.extend(expand("{out}/kmer_spectra/{file}_kmer_gcbias.mx.pdf",out=outputfolder,file=sample_names))
#         _kmer_gcbias.mx.pdf"
    if config["blast"]["blast_active"]:
        all.extend(expand("{out}/blast/blast_report_{file}.tsv",out=outputfolder,file=sample_names))

    if config["cutadapt"]["cutadapt_active"]:
        all.extend(expand("{out}/trimmed/{file}_trimmed.fastq.gz",out=outputfolder,file=sample_names))
        all.extend(expand("{out}/multiqc_report_complete_{prj}.html",out=outputfolder,prj=projectNum))

    if config["kraken2"]["kraken2_active"]:
        all.extend(expand("{out}/kraken2/{file}.report",out=outputfolder,file=sample_names))

    if config["transfer"]["transfer_active"]:
        all.extend(expand("{out}/transfer/transfer_log.log",out=outputfolder))
    
    if config["preseq"]["preseq_active"]:
        all.extend(expand("{out}/preseq/{file}_c_curve_out.txt",out=outputfolder,file=sample_names))

    if not validRun or not os.path.isfile(outputfolder+"/fastq_infiles_list.tx"):
        all = list()
        print("It seems like the bcl2fastq2 run didnt finish properly or the fastq_infiles_list.tx doesnt exist")
    return all


def getFastQCs(wildcards):
    fastQCs = list()# if we cutadapt, make the list empty, then we only want fastqc from the cutadapt output
    fastQCs.extend(expand("{out}/fastqc_untrimmed/untrimmed_{file}_fastqc.{ext}",out=outputfolder,file=sample_names,ext=["html","zip"]))
    if config["rseqc"]["rseqc_mapping_active"]:
        fastQCs.extend(expand("{out}/qc/qualimap/{file}/qualimapReport.html",out=outputfolder,file=sample_names)) # final qualimap output
        fastQCs.extend(expand("{out}/star/{file}_ReadsPerGene.out.tab",out=outputfolder,file=sample_names))
        fastQCs.extend(expand("{out}/samtools/{file}_samtools_stats.stats",out=outputfolder,file=sample_names)) # test this 
            #print("sample names from getFastQCs, maybe fixed:")
            #print(sample_names)
    if config["rseqc"]["rseqc_modules_active"]:
        fastQCs.extend(expand("{out}/qc/rseqc/done.flag",out=outputfolder)) # outputfolder+"/qc/rseqc/done.flag"
    
    if config["umi_tools"]["umi_tools_active"]:
        fastQCs.extend(expand("{out}/fastqc/{file}.umis-extracted_fastqc.{ext}",out=outputfolder,file=sample_names,ext=["html","zip"]))
    elif config["cutadapt"]["cutadapt_active"]:
        #relativePath = os.path.dirname(sample)+"/" if "/" in sample else ""
        fastQCs.extend(expand("{out}/fastqc/{file}_trimmed_fastqc.{ext}",out=outputfolder,file=sample_names,ext=["html","zip"]))
 #   if config["kmer_spectra"]["kmer_spectra_on"]:
 #       for sample in sample_names:
 #           fastQCs.extend(expand("{out}/kmer_spectra/{file}_kmer_gcbias.mx.pdf",out=outputfolder,file=sample_names))
    if config["kraken2"]["kraken2_active"]:
        fastQCs.extend(expand("{out}/kraken2/{file}.report",out=outputfolder,file=sample_names))
    if config["preseq"]["preseq_active"]:
        fastQCs.extend(expand("{out}/preseq/{file}_c_curve_out.txt",out=outputfolder,file=sample_names))

    return fastQCs



def get_raw_FastQCs(wildcards):
    fastQCs_raw = list()# if we cutadapt, make the list empty, then we only want fastqc from the cutadapt output
    fastQCs_raw.extend(expand("{out}/fastqc_untrimmed/untrimmed_{file}_fastqc.{ext}",out=outputfolder,file=sample_names,ext=["html","zip"]))
    return fastQCs_raw


def isSingleEnd() -> bool:
    """
    Returns wether the fastqs are single-end=True or paired-end=False
    """
    R1 = list()
    R2 = list()
    for sample in sample_names:
        if sample.split("_R")[1].startswith("1"):
            R1.append(sample)
        else:
            R2.append(sample)
    if len(R1)!=len(R2):
        return True
    return False


def getSamples(wildcards):
    
    if isSingleEnd():
        
        for sample in sample_names:
            if str(wildcards) in sample:
                if config["umi_tools"]["umi_tools_active"]:
                    return expand("{out}/umi_extract/{file}.umis-extracted.fastq.gz",out=outputfolder,file=sample)
                elif config["cutadapt"]["cutadapt_active"]:# continue here - we have 3 cases: raw, cutadapt, umi_tools
                    return expand("{out}/trimmed/{file}_trimmed.fastq.gz",out=outputfolder,file=sample)
                else:
                    return expand("{out}/untrimmed_fastq/{file}.fastq.gz",out=outputfolder,file=sample)
                
    else:   
    	sampleName = str(wildcards).split("_R")[0]
    	R1and2 = list()
    	for sample in sample_names:
        	trySplit = sample.split(os.sep)[-1]
        	if trySplit:
            		if trySplit.startswith(sampleName):
                		R1and2.append(sample)
    	if config["umi_tools"]["umi_tools_active"]:
        	return expand("{out}/umi_extract/{file}.umis-extracted.fastq.gz",out=outputfolder,file=R1and2)
    	elif config["cutadapt"]["cutadapt_active"]:# continue here - we have 3 cases: raw, cutadapt, umi_tools
            return expand("{out}/trimmed/{file}_trimmed.fastq.gz",out=outputfolder,file=R1and2)
    	else:
        	return expand("{out}/untrimmed_fastq/{file}.fastq.gz",out=outputfolder,file=R1and2)


def getFastqs(wildcards):
    samples = getSamples(wildcards)
    if len(samples)>1:
        return " ".join(samples)
    #print ("getFastqs file list:")
    #print (samples)
    return samples

localrules: all, gocryptfs


rule all:
    input:
        getOutput() if projectNum else ""


rule FastQC_untrimmed:
    input:
        samples = outputfolder+"/untrimmed_fastq/{file}.fastq.gz"
    params:
    #    path=getPath,
        fastp_report = outputfolder+"/fastqc_untrimmed/untrimmed_{file}_fastp.html",
        fastp_json = outputfolder+"/fastqc_untrimmed/untrimmed_{file}_fastp.json",
        html = outputfolder+"/fastqc_untrimmed/{file}_fastqc.html",
        zip = outputfolder+"/fastqc_untrimmed/{file}_fastqc.zip",
        out = outputfolder
    output:
        zip = outputfolder+"/fastqc_untrimmed/untrimmed_{file}_fastqc.zip", 
        html = outputfolder+"/fastqc_untrimmed/untrimmed_{file}_fastqc.html",
    threads: config["others"]["fastQC_threads"]
    log:
        outputfolder+"/logs/fastqc/untrimmedFastQC{file}.log"
    conda:
        p+"/envs/fastqc.yaml"
    message:
        "Run untrimmed FastQC"
    shell:
        """
        mkdir -p {params.out}/fastqc_untrimmed/
        chmod ago+rwx -R {params.out}/fastqc_untrimmed/ || :
        unset command_not_found_handle
        fastqc -q --threads {threads} {input} -o {params.out}/fastqc_untrimmed/ >> {log} 2>&1
        fastp -i {input} -h {params.fastp_report} -j {params.fastp_json}>> {log} 2>&1
        mv {params.zip} {output.zip}
        mv {params.html} {output.html}
        """


rule cutadapt:
    input:
        outputfolder+"/untrimmed_fastq/{file}.fastq.gz"

    params:
        adapters=adaptersToStringParams(config["cutadapt"]["adapters"],config["cutadapt"]["adapter_type"]),
        otherParams=config["cutadapt"]["other_params"],
        out=outputfolder,
        sha_sum_file=outputfolder+"/trimmed/sha256sums_fastqfiles_trimmed.sha256"
    output:
        outputfolder+"/trimmed/{file}_trimmed.fastq.gz"
    threads: config["cutadapt"]["cutadapt_threads"]
    log:
        outputfolder+"/logs/cutadapt/{file}_trimmed.log"
    message:
        "Run cutadapt"
    conda:
        p+"/envs/cutadapt.yaml"
    shell:
        """
        mkdir -p {params.out}/trimmed
        cutadapt {params.adapters} {params.otherParams} -o {output} {input} 2> {log}
        sha256sum {output} >>{params.sha_sum_file}
        """
          
rule align:
    input:
        fastqs=getSamples
    output:
        bams=outputfolder + "/star/{file}_Aligned.sortedByCoord.out.bam", #this needs to be deduped 
        tabs=outputfolder + "/star/{file}_ReadsPerGene.out.tab"
    wildcard_constraints:
        file="(.*(?:_).*)"
    log:
        outputfolder+"/logs/star/{file}.log"
    params:
        # optional parameters
        extra="--outSAMtype BAM SortedByCoordinate --quantMode GeneCounts --sjdbGTFfile {} {}".format(
            config["rseqc"]["gtf_file"], config["rseqc"]["other_params"]),
        outp = lambda w: os.path.dirname(outputfolder+"/star/"+w.file+"/"+w.file)+"/",
        prefix = outputfolder + "/star/{file}_",
        genDir = config["rseqc"]["genomeDir"],
        qc_dir = outputfolder + "/qc",
        rseqc_dir = outputfolder+"/qc/rseqc",
        fastqs=lambda w: getFastqs(w.file),

        
    threads: config["rseqc"]["STAR_threads"]
    conda:
        p+"/envs/STAR.yaml"
    shell:
        """
        mkdir -p {params.qc_dir}
        mkdir -p {params.rseqc_dir}
        STAR {params.extra} --genomeDir {params.genDir} --runThreadN {threads} --readFilesIn {params.fastqs} --readFilesCommand zcat --outFileNamePrefix {params.prefix} --outStd Log {log}
        chmod ago+rwx -R {output} >> {log} 2>&1
        """

rule samtools:
    input:
        bams =outputfolder + "/star/{file}_Aligned.sortedByCoord.out.bam" if not config["umi_tools"]["umi_tools_active"] else outputfolder+"/star/{file}_deduped.Aligned.sortedByCoord.out.bam"
    params:
        samtools_logfolder=outputfolder + "/logs/samtools/",
        samtools_coverage_file=outputfolder + "/samtools/{file}_samtools.coverage",
        samtools_folder=outputfolder+"/samtools/",
        sorted_bam=outputfolder + "/star/sorted_{file}_Aligned.sortedByCoord.out.bam",
        samtools_plot_prefix=outputfolder+"/samtools/statplot_{file}"        
    log:
        samtools_logfolder=outputfolder + "/logs/samtools/{file}_samtools.log"
    conda:
        p+"/envs/STAR.yaml"
    output:
        samtools_stats_file=outputfolder + "/samtools/{file}_samtools_stats.stats",
    shell:
        """
        mkdir -p {params.samtools_logfolder}
        samtools index {input.bams} >> {log} 2>&1
        mkdir -p {params.samtools_folder} >> {log} 2>&1
        samtools stats {input.bams} >{output.samtools_stats_file} 2>{log}
        samtools coverage {input.bams} >{params.samtools_coverage_file} 2>{log}
        plot-bamstats {output.samtools_stats_file} -p {params.samtools_plot_prefix}   2>{log}      
        chmod ago+rwx -R {output} >> {log} 2>&1
        """


rule preseq:
    input:
        bams =outputfolder + "/star/{file}_Aligned.sortedByCoord.out.bam" if not config["umi_tools"]["umi_tools_active"] else outputfolder+"/star/{file}_deduped.Aligned.sortedByCoord.out.bam"    
    params:
        log_folder= outputfolder + "/logs/preseq/",
        preseq_folder=outputfolder + "/preseq/",
        bed_bam=outputfolder + "/preseq/{file}_bam2bed.bed",
        sorted_bam=outputfolder + "/star/sorted_{file}_Aligned.sortedByCoord.out.bam",
    log:
         outputfolder + "/logs/preseq/{file}_preseq.log"
    conda:
        p+"/envs/preseq.yaml"
    output:
        c_curve_out=outputfolder + "/preseq/{file}_c_curve_out.txt",
        #lc_extrap_out=outputfolder + "/preseq/{file}_lc_extrap_out.txt"
    shell:
        """
        mkdir -p {params.log_folder}
        mkdir -p {params.preseq_folder}
        samtools sort {input} -o {params.sorted_bam} 2>{log}
        samtools index {params.sorted_bam} 2>{log}
        bedtools bamtobed -i {input} >{params.bed_bam} 2>{log}
        preseq c_curve -P {params.bed_bam} -o {output.c_curve_out} 2>{log}
        chmod ago+rwx -R {output} >> {log} 2>&1
    
        """

rule Qualimap:
    input:
        bams =outputfolder + "/star/{file}_Aligned.sortedByCoord.out.bam" if not config["umi_tools"]["umi_tools_active"] else outputfolder+"/star/{file}_deduped.Aligned.sortedByCoord.out.bam"
    params:
    	gtf=config["rseqc"]["gtf_file"],
    	qualimap_out =  outputfolder+"/qc/qualimap/{file}",
    	qualimap_folder = outputfolder+"/qc/qualimap",
    	qualimap_logfolder = outputfolder+"/logs/qualimap"
    log:
    	qualimap_log = outputfolder+"/logs/qualimap/qualimap_{file}.log",
    output:
    	qualimap_report = outputfolder+"/qc/qualimap/{file}/qualimapReport.html"
    conda:
    	p+"/envs/STAR.yaml"
    shell:
    	"""
    	mkdir -p {params.qualimap_logfolder}
    	mkdir -p {params.qualimap_folder} >> {log} 2>&1
    	mkdir -p {params.qualimap_out} >> {log} 2>&1
    	qualimap rnaseq -bam {input.bams} -gtf {params.gtf} --java-mem-size=16G -p strand-specific-forward --outdir {params.qualimap_out} >> {log} 2>&1                  
    	chmod ago+rwx -R {output} >> {log} 2>&1  
    	"""

rule stringtie:
    input:
        bams =outputfolder + "/star/{file}_Aligned.sortedByCoord.out.bam" if not config["umi_tools"]["umi_tools_active"] else outputfolder+"/star/{file}_deduped.Aligned.sortedByCoord.out.bam"
    params:
        gtf=config["rseqc"]["gtf_file"],
        out_folder=outputfolder+"/stringtie/",
        stie_log_folder=outputfolder+"/logs/stringtie/"
    log:
        outputfolder+"/logs/stringtie/stringtie_{file}.log"
    conda:
        p+"/envs/umi_tools.yaml"
    output:
        stringtie_out_file=outputfolder+"/stringtie/transcripts_{file}.gtf"
    shell:# stringtie -p 32 bam  -g ../mm39.ncbiRefSeq.gtf -o stringtie_out_2
        """
        mkdir -p {params.stie_log_folder}
        mkdir -p {params.out_folder} >> {log} 2>&1
        stringtie {input.bams} -g {params.gtf} -o {output} >> {log} 2>&1
        chmod ago+rwx -R {output} >> {log} 2>&1
        """

rule FastQC:
    input:  # need to test this if this works, also the input fun of kraken rule 
        outputfolder + "/umi_extract/{file}.umis-extracted.fastq.gz"  if config["umi_tools"]["umi_tools_active"] else outputfolder+"/trimmed/{file}_trimmed.fastq.gz"
    params:
        #path=getPath,
        out=outputfolder,
        fastp_report=outputfolder+"/fastqc/{file}_after_filtering_fastp.html",
        fastp_json= outputfolder+"/fastqc/{file}_after_filtering_fastp.json"

    output:
        outputfolder+"/fastqc/{file}_trimmed_fastqc.html" if not config["umi_tools"]["umi_tools_active"] else outputfolder+"/fastqc/{file}.umis-extracted_fastqc.html",
        outputfolder+"/fastqc/{file}_trimmed_fastqc.zip" if not config["umi_tools"]["umi_tools_active"] else outputfolder+"/fastqc/{file}.umis-extracted_fastqc.zip",

    threads: config["others"]["fastQC_threads"]
    log:
        outputfolder+"/logs/fastqc/FastQC_{file}.log"
    conda:
        p+"/envs/fastqc.yaml"
    message:
        "Run FastQC"
    shell:
        """
        mkdir -p {params.out}/fastqc/ >> {log} 2>&1
        fastqc -q --threads {threads} {input} -o {params.out}/fastqc/ >> {log} 2>&1
        fastp -i {input} -h {params.fastp_report} -j {params.fastp_json} >> {log} 2>&1
        chmod ago+rwx -R {params.out}/fastqc/ >> {log} 2>&1
        """

if config["umi_tools"]["umi_tools_active"]:# umi can be used without cutadapt, but thats not the default
    rule umi_extract:
        input:
            outputfolder+"/untrimmed_fastq/{file}.fastq.gz" if not config["cutadapt"]["cutadapt_active"] else outputfolder+"/trimmed/{file}_trimmed.fastq.gz"
        params:
            #path=getPath,
            umi_ptrn=lambda wc:config["umi_tools"]["pattern"], # need the lambda pseudo-fun for correct curly bracket in pattern recognition
            unzipped_files=outputfolder+"/{file}.fastq",
            extended_name=config["umi_tools"]["extended_name"],
            outputf=outputfolder+"/umi_extract",
            logfolder=outputfolder+"/logs/umi_tools/",
            checksum_file=expand(outputfolder+"/umi_extract/checksums_umis_extracted_{prj}.sha256", prj=projectNum)
        log:
            outputfolder+"/logs/umi_tools/{file}.umi_extract.log"
        conda:
            p+"/envs/umi_tools.yaml"
        output:
            outputfolder + "/umi_extract/{file}.umis-extracted.fastq.gz"
        shell:
            """
            mkdir -p {params.outputf}
            mkdir -p {params.logfolder}
            umi_tools extract --stdin={input} --extract-method=regex --bc-pattern={params.umi_ptrn} --log={log} --stdout={output}
            chmod ago+rwx -R {params.outputf}
            sha256sum {output} >>{params.checksum_file}
            """ 
    
    rule umi_dedup:
        input:
            outputfolder+"/star/{file}_Aligned.sortedByCoord.out.bam"
        params:
            out=outputfolder,
            sorted_bam=outputfolder+"/star/{file}_sorted.Aligned.sortedByCoord.out.bam",
            logfolder=outputfolder+"/logs/umi_tools/"
        log:
            outputfolder+"/logs/umi_tools/{file}.umi_dedup.log"
        conda:
            p+"/envs/umi_tools.yaml"
        threads:
            config["umi_tools"]["threads"]
        output:
            outputfolder+"/star/{file}_deduped.Aligned.sortedByCoord.out.bam"
        shell:
            """
            mkdir -p {params.logfolder}
            samtools sort --threads {threads} {input} -o {params.sorted_bam} 2>{log}
            samtools index {params.sorted_bam} 2>{log}
            umi_tools dedup -I {params.sorted_bam} --output-stats={log} -S {output} 2>{log}
            chmod ago+rwx -R {params.out} 2>{log}
            """



rule featurecounts:
    input:
        expand("{out}/star/{file}_deduped.Aligned.sortedByCoord.out.bam",out=outputfolder,file=sample_names) if config["umi_tools"]["umi_tools_active"] else expand("{out}/star/{file}_Aligned.sortedByCoord.out.bam",out=outputfolder,file=sample_names)
    params:
        gtf=config["rseqc"]["gtf_file"],
        stranded=config["umi_tools"]["stranded"],
        outdir=outputfolder+"/counts",
    threads:
        config["umi_tools"]["threads"]
    conda:
        p+"/envs/umi_tools.yaml"
    output:
        counts_file=outputfolder+"/counts/all.tsv"
    shell:
        """
        mkdir -p {params.outdir}
        featureCounts -a {params.gtf} -o {output.counts_file} {input} -T {threads} -g gene_id -s {params.stranded}
        chmod ago+rwx -R {params.outdir}
        """


if config["kraken2"]["kraken2_active"]:
    rule kraken2:
        input:
            outputfolder+"/untrimmed_fastq/{file}.fastq.gz" if not config["cutadapt"]["cutadapt_active"] else outputfolder+"/trimmed/{file}_trimmed.fastq.gz"
        params:
            kraken2_db=config["kraken2"]["kraken2_database"],
            outfile=temp(outputfolder+"/kraken2/{file}.kraken2"),
            outdir=outputfolder+"/kraken2",
            logdir=outputfolder+"/logs/kraken/",
            summary=outputfolder+"/kraken2/{file}.summary"
        log:
            outputfolder+"/logs/kraken/{file}.kraken2.log"
        threads:
            config["kraken2"]["kraken2_threads"]
        conda:
            p+"/envs/kraken2.yaml"
        output:
            report_file=outputfolder+"/kraken2/{file}.report"
        shell:
            """
            mkdir -p {params.outdir}
            mkdir -p {params.logdir} 2>{log}
            kraken2 --use-names --db {params.kraken2_db} --threads {threads} --gzip-compressed --confidence 0.05 --report {output} {input} >{params.outfile} >> {log} 2>&1
            chmod ago+rwx -R {params.outdir} >> {log} 2>&1
            """

rule blast:
    input:
        outputfolder+"/trimmed/{file}_trimmed.fastq.gz" if config["cutadapt"]["cutadapt_active"] else outputfolder+"/umis_extract/{file}.umis-extracted.fastq.gz" # only possible if cutadapt and/or umi_tools are active 
    params:
        blast_folder=outputfolder+"/blast/",
        blast_log_folder=outputfolder+"/logs/blast/",
        blast_subsampled_fasta=outputfolder+"/blast/subsampled_{file}.fa",
        blast_db=config["blast"]["blast_db"],
        summary_file=outputfolder+"/blast/blast_summary_{file}.tsv",
        convert_script="scripts/fastq_to_fasta.sh",
        summarize_script="scripts/filter_blast.sh",
        script_dir=config["blast"]["blast_script_dir"]
    log:
        outputfolder+"/logs/blast/{file}.blast.log"
    threads: config["blast"]["blast_threads"]
    
    conda:
        p+"/envs/blast.yaml"
    output:
        blast_out=outputfolder+"/blast/blast_report_{file}.tsv"
    shell:
        """
        mkdir -p {params.blast_folder}
        mkdir -p {params.blast_log_folder}
        bash {params.script_dir}/fastq_to_fasta.sh {input} {params.blast_subsampled_fasta} 2>{log} 
        blastn -db {params.blast_db} -query {params.blast_subsampled_fasta} -outfmt 7 -max_target_seqs 5 -num_threads {threads} >{output.blast_out}  2>{log}
        chmod -R 755 {params.blast_folder}
        bash {params.script_dir}/filter_blast.sh {output} {params.summary_file}  2>{log}       
        """


rule transfer_files:
    input:
        folder_to_transfer = outputfolder,
        multiqc_complete = "{out}/multiqc_report_complete_{prj}.html".format(out=outputfolder,prj=projectNum)
    params:
        i_d = config["transfer"]["transfer_as"],
        destination = config["transfer"]["transfer_to"],
        outdir_transfer = outputfolder+"/transfer",
        outfolder_all = outputfolder
    threads:
        2
    conda:
        p+"/envs/transfer.yaml"
    output:
        logfile = outputfolder+ "/transfer/transfer_log.log"
    shell:
        """
        mkdir -p {params.outdir_transfer}
        rsync -rzvP {params.outfolder_all} {params.i_d}{params.destination} 2>{output.logfile}
        """


rule multiqc:
    input:
        getFastQCs
    output:
        "{out}/multiqc_report_complete_{prj}.html".format(out=outputfolder,prj=projectNum)
    params:
        output=outputfolder
    log:
        outputfolder+"/logs/MultiQC.log"
    conda:
        p+"/envs/multiqc.yaml"
    shell:
        """
        multiqc --filename {output}  --ignore-samples Undetermined* -x Undetermined* {params.output} -o {params.output} --no-data-dir --fullnames >> {log} 2>&1
        chmod ago+rwx -R {params.output}
        """


rule multiqc_raw:
    input:
    	get_raw_FastQCs
    output:
    	"{out}/multiqc_report_{prj}.html".format(out=outputfolder,prj=projectNum)
    params:
    	output_folder= outputfolder,
    	list_file_raw= outputfolder + "/logs/fastq_file_list.tsv",
    	folder_to_check=outputfolder + "/fastqc_untrimmed" if config["cutadapt"]["cutadapt_active"] else outputfolder+"/fastqc"
    log:
    	outputfolder+"/logs/MultiQC_raw.log"
    message:
    	"Run MultiQC for raw fastqs"
    conda:
       	p+"/envs/multiqc.yaml"
    shell:
    	"""
    	cd {params.output_folder}
       	ls -f1 {params.folder_to_check}/*fastqc* >{params.list_file_raw}
       	multiqc --filename {output} --fullnames -q --ignore-samples Undetermined* -x Undetermined*  -m 'fastqc'  --file-list {params.list_file_raw} --no-data-dir
       	chmod ago+rwx -R {output}
        chmod ago+rwx -R {params.output_folder}
       	"""
                                                                             

rule gocryptfs:
    input:
        rules.multiqc.output
    output:
        "{out}/encrypted/gocryptfs.conf".format(out=outputfolder)
    params:
        output=outputfolder
    log:
        outputfolder+"/logs/gocryptfs.log"
    message: "Run Gocryptfs"
    envmodules:
        config["gocryptfs"]["gocryptfs_version"]
    shell:
        """
        mkdir -p {params.output}/encrypted/
        gocryptfs -init {params.output}/encrypted/
        mkdir -p {params.output}/plain/
        echo 'Password:'
        gocryptfs {params.output}/encrypted/ {params.output}/plain/ >> {log} 2>&1
        rsync -av --progress {params.output}/* {params.output}/plain/ --exclude encrypted/ --exclude plain/ --remove-source-files
        fusermount -u {params.output}/plain/
        rm -r {params.output}/plain/
        shopt -s extglob
        rm -rf {params.output}/!(encrypted)/
        """

onsuccess:
    print("Workflow finished without errors")
    if config["cutadapt"]["cutadapt_active"]:
        print("Cutadapt ran with the following adapters and settings: %s" % adaptersToStringParams(config["cutadapt"]["adapters"],config["cutadapt"]["adapter_type"]))

onerror:
    print("An error occurred during runtime")

onstart:
    print("Setting up and running pipeline")
#
#
# Future directions:
# jellyfish: https://bioinformatics.uconn.edu/genome-size-estimation-tutorial/
# sortmerna: https://github.com/sortmerna/sortmerna/tree/master/data/rRNA_databases
# seqwho: https://daehwankimlab.github.io/seqwho/
