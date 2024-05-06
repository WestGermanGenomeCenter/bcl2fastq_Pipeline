## RSEQC
import os
import pandas as pd
p = os.path.abspath(".")
sys.path.append(os.path.abspath(os.getcwd())+"/scripts")
from helper import validateSamplesheet, validateOutput, validateProjectNum


configfile: "config.yaml"
outputfolder = config["bcl2fastq"]["OutputFolder"]

# Check for projectNum in samplesheet name
projectNum=validateProjectNum(samplesheet)
if not projectNum:
    print("There was no project number to be found in the samplesheet and/or the name of the samplesheet")

sample_names = list()
if os.path.isfile(outputfolder+"/fastq_infiles_list.tx"):
    samples_dataframe = pd.read_csv(outputfolder+"/fastq_infiles_list.tx", header=None)
    fastqs = list(samples_dataframe.iloc[:, 0].values)
    sample_names = [fastq[:-9] for fastq in fastqs]

def getFiles():
    files = list()
    for sample in sample_names:
        trySplit = sample.split(os.sep)[-1]
        if trySplit:
            sampleName = trySplit.split("_R")[0]
            files.append(sampleName)
    return files


# Get the fastq.gz samples
if os.path.isfile(outputfolder+"/fastq_infiles_list.tx"):
    samples_dataframe = pd.read_csv(outputfolder+"/fastq_infiles_list.tx", header=None)
    fastqs = list(samples_dataframe.iloc[:, 0].values)
    sample_names = [fastq[:-9] for fastq in fastqs]

#localrules: count_matrix
#if not config["umi_tools"]["umi_tools_active"]:# since if umis are used, we need to use featurecounts
#    rule count_matrix:
#        input:
#            expand(outputfolder+"/star/{file}_ReadsPerGene.out.tab", file=sample_names)
#        output:
#            outputfolder+"/counts/all.tsv"
#        params:
#            samples=sample_names,
#            strand=config["rseqc"]["strandedness"]
#        conda:
#            p+"/envs/pandas.yaml"
#        script:
#            "../scripts/count-matrix.py"
    
rule rseqc_gtf2bed:
    input:
        config["rseqc"]["gtf_file"],
    output:
        bed=outputfolder+"/qc/rseqc/annotation.bed",
        db=temp("results/qc/rseqc/annotation.db")
    params:
    	qc_dir=outputfolder+"/qc",
    	rseqc_dir=outputfolder+"/qc/rseqc",
    log:
        outputfolder+"/logs/rseqc_gtf2bed.log",
    conda:
        p+"/envs/gffutils.yaml"
    script:
        "../scripts/gtf2bed.py"
#    shell:
#    	"""
#    	mkdir -p {params.qc_dir}
#    	mkdir -p {params.rseqc_dir}
#    	convert2bed -i gtf < {input} > {output.bed}
#    	python scripts/gtf2bed.py {input} {output.bed} 2>{log}
#    	#convert2bed -i gtf  < {input} >{output.bed} 2>{log}
#    	"""


rule rseqc_junction_annotation:
    input:
        bam=outputfolder + "/star/{file}_Aligned.sortedByCoord.out.bam" if not config["umi_tools"]["umi_tools_active"] else outputfolder+"/star/{file}_deduped.Aligned.sortedByCoord.out.bam",
        bed=outputfolder+"/qc/rseqc/annotation.bed",
    output:
        outputfolder+"/qc/rseqc/{file}.junctionanno.junction.bed"
    priority: 1
    log:
        outputfolder+"/logs/rseqc/rseqc_junction_annotation/{file}.log"
    params:
        extra=r"-q 255",  # STAR uses 255 as a score for unique mappers
        prefix=lambda w, output: output[0].replace(".junction.bed", ""),
    conda:
        p+"/envs/rseqc.yaml"
    shell:
        """
        junction_annotation.py {params.extra} -i {input.bam} -r {input.bed} -o {params.prefix} >> {log} 2>&1
        [ ! -f {output} ] && touch {output} || :
        """


rule rseqc_junction_saturation:
    input:
        bam=outputfolder + "/star/{file}_Aligned.sortedByCoord.out.bam" if not config["umi_tools"]["umi_tools_active"] else outputfolder+"/star/{file}_deduped.Aligned.sortedByCoord.out.bam",
        bed=outputfolder+"/qc/rseqc/annotation.bed",
    output:
        outputfolder+"/qc/rseqc/{file}.junctionsat.junctionSaturation_plot.pdf"
    priority: 1
    log:
        outputfolder+"/logs/rseqc/rseqc_junction_saturation/{file}.log"
    params:
        extra=r"-q 255",
        prefix=lambda w, output: output[0].replace(".junctionSaturation_plot.pdf", ""),
    conda:
        p+"/envs/rseqc.yaml"
    shell:
        "junction_saturation.py {params.extra} -i {input.bam} -r {input.bed} -o {params.prefix} "
        ">> {log} 2>&1"


rule rseqc_stat:
    input:
        outputfolder + "/star/{file}_Aligned.sortedByCoord.out.bam" if not config["umi_tools"]["umi_tools_active"] else outputfolder+"/star/{file}_deduped.Aligned.sortedByCoord.out.bam"
    output:
        outputfolder+"/qc/rseqc/{file}.stats.txt"
    priority: 1
    log:
        outputfolder+"/logs/rseqc/rseqc_stat/{file}.log"
    conda:
        p+"/envs/rseqc.yaml"
    shell:
        "bam_stat.py -i {input} > {output} 2> {log}"


rule rseqc_infer:
    input:
        bam=outputfolder + "/star/{file}_Aligned.sortedByCoord.out.bam" if not config["umi_tools"]["umi_tools_active"] else outputfolder+"/star/{file}_deduped.Aligned.sortedByCoord.out.bam",
        bed=outputfolder+"/qc/rseqc/annotation.bed",
    output:
        outputfolder+"/qc/rseqc/{file}.infer_experiment.txt"
    priority: 1
    log:
        outputfolder+"/logs/rseqc/rseqc_infer/{file}.log"
    conda:
        p+"/envs/rseqc.yaml"
    shell:
        "infer_experiment.py -r {input.bed} -i {input.bam} > {output} 2> {log}"


rule rseqc_innerdis:
    input:
        bam=outputfolder + "/star/{file}_Aligned.sortedByCoord.out.bam" if not config["umi_tools"]["umi_tools_active"] else outputfolder+"/star/{file}_deduped.Aligned.sortedByCoord.out.bam",
        bed=outputfolder+"/qc/rseqc/annotation.bed",
    output:
        outputfolder+"/qc/rseqc/{file}.inner_distance_freq.inner_distance.txt"
    priority: 1
    log:
        outputfolder+"/logs/rseqc/rseqc_innerdis/{file}.log",
    params:
        prefix=lambda w, output: output[0].replace(".inner_distance.txt", ""),
        nvc_outpre=outputfolder+"/qc/rseqc/{file}_nucleotide_composition_bias",
        tin_prefix=outputfolder+"/qc/rseqc/{file}_tin_.bed",
        genebody_pre=outputfolder+"/qc/rseqc/{file}_genebody_coverage",
        fpkm_out=outputfolder+"/qc/rseqc/{file}_rseqc_fpkm_count.tsv",
    conda:
        p+"/envs/rseqc.yaml"
    shell: #attaching a lot of stuff here to check how useful these might be 
        """
        # inner distance moved to bottom 
        read_NVC.py -i {input.bam} -o {params.nvc_outpre} >> {log} 2>&1
        # needs too long, not useful for most assays tin.py -r {input.bed} -i {input.bam} >{params.tin_prefix}
        # also very ressource intensive, already covered by rseqc geneBody_coverage.py -r {input.bed} -i {input.bam} -o {params.genebody_pre} >> {log} 2>&1
        FPKM_count.py -r {input.bed} -i {input.bam} -o {params.fpkm_out} >> {log} 2>&1
        inner_distance.py -r {input.bed} -i {input.bam} -o {params.prefix} >> {log} 2>&1
        """


rule rseqc_readdis:
    input:
        bam=outputfolder + "/star/{file}_Aligned.sortedByCoord.out.bam" if not config["umi_tools"]["umi_tools_active"] else outputfolder+"/star/{file}_deduped.Aligned.sortedByCoord.out.bam",
        bed=outputfolder+"/qc/rseqc/annotation.bed",
    output:
        outputfolder+"/qc/rseqc/{file}.readdistribution.txt"
    priority: 1
    log:
        outputfolder+"/logs/rseqc/rseqc_readdis/{file}.log"
    conda:
        p+"/envs/rseqc.yaml"
    shell:
        "read_distribution.py -r {input.bed} -i {input.bam} > {output} 2> {log}"


rule rseqc_readdup:
    input:
        outputfolder + "/star/{file}_Aligned.sortedByCoord.out.bam" if not config["umi_tools"]["umi_tools_active"] else outputfolder+"/star/{file}_deduped.Aligned.sortedByCoord.out.bam"
    output:
        outputfolder+"/qc/rseqc/{file}.readdup.DupRate_plot.pdf"
    priority: 1
    log:
        outputfolder+"/logs/rseqc/rseqc_readdup/{file}.log"
    params:
        prefix=lambda w, output: output[0].replace(".DupRate_plot.pdf", ""),
    conda:
        p+"/envs/rseqc.yaml"
    shell:
        "read_duplication.py -i {input} -o {params.prefix} >> {log} 2>&1"


rule rseqc_readgc:
    input:
        outputfolder + "/star/{file}_Aligned.sortedByCoord.out.bam" if not config["umi_tools"]["umi_tools_active"] else outputfolder+"/star/{file}_deduped.Aligned.sortedByCoord.out.bam"
    output:
        outputfolder+"/qc/rseqc/{file}.readgc.GC_plot.pdf"
    priority: 1
    log:
        outputfolder+"/logs/rseqc/rseqc_readgc/{file}.log"
    params:
        prefix=lambda w, output: output[0].replace(".GC_plot.pdf", ""),
    conda:
        p+"/envs/rseqc.yaml"
    shell:
        "read_GC.py -i {input} -o {params.prefix} >> {log} 2>&1"


rule rseqc_done:
    input:
        expand(
            outputfolder + "/star/{file}_Aligned.sortedByCoord.out.bam" if not config["umi_tools"]["umi_tools_active"] else outputfolder+"/star/{file}_deduped.Aligned.sortedByCoord.out.bam",
            file=sample_names,
        ),
        expand(
            outputfolder+"/qc/rseqc/{file}.junctionanno.junction.bed",
            file=sample_names,
        ),
        expand(
            outputfolder+"/qc/rseqc/{file}.junctionsat.junctionSaturation_plot.pdf",
            file=sample_names,
        ),
        expand(
            outputfolder+"/qc/rseqc/{file}.infer_experiment.txt",
            file=sample_names,
        ),
        expand(
            outputfolder+"/qc/rseqc/{file}.stats.txt",
            file=sample_names,
        ),
        expand(
            outputfolder+"/qc/rseqc/{file}.inner_distance_freq.inner_distance.txt",
            file=sample_names,
        ),
        expand(
            outputfolder+"/qc/rseqc/{file}.readdistribution.txt",
            file=sample_names,
        ),
        expand(
            outputfolder+"/qc/rseqc/{file}.readdup.DupRate_plot.pdf",
            file=sample_names,
        ),
        expand(
            outputfolder+"/qc/rseqc/{file}.readgc.GC_plot.pdf",
            file=sample_names,
        ),
        expand(
            outputfolder+"/logs/rseqc/rseqc_junction_annotation/{file}.log",
            file=sample_names,
        ),
#        expand(outputfolder+"/counts/all.tsv"),
    output:
        outputfolder+"/qc/rseqc/done.flag",
    shell:
        """
        touch {output}
        """
