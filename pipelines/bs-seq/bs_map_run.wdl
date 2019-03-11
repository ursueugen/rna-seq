version development

import "bs_extract_run.wdl" as getter

struct MappedRun {
    String run
    String folder
    Boolean is_paired
    Array[File] report
    File mapstats
    File aligned
    File cpg
    File counts
}

workflow bs_map {
    input {
        String layout = "PAIRED"
        String run
        String output_folder
        File genome_index
        File genome
        Boolean copy_cleaned = false
        Int map_threads = 8
        Int extract_threads = 4
    }

    call getter.bs_extract_run as extract_run {
        input:
            layout = layout,
            run = run,
            folder = output_folder,
            copy_cleaned = copy_cleaned,
            extract_threads = extract_threads
    }


    call bitmapper {
        input:
            index_folder = genome_index,
            reads = extract_run.out.cleaned_reads,
            is_paired = extract_run.out.is_paired,
            filename = run,
            threads = map_threads
    }

    call copy as copy_bit {
        input:
            files = [bitmapper.out, bitmapper.stats],
            destination = output_folder
    }


    call picard_readgroups_sort {
        input: bam = bitmapper.out,
                    filename = run
    }


    call copy as copy_sorted {
        input:
            files = [picard_readgroups_sort.out],
            destination = output_folder
    }

    call methyldackel {
        input:
            bam = picard_readgroups_sort.out,
            genome = genome,
            threads = extract_threads
    }

    call copy as copy_methylation {
            input:
                files = [  methyldackel.cpg, methyldackel.counts],
                destination = output_folder
        }

    output {
        MappedRun out = object
        {
            run: run,
            folder: extract_run.out.folder,
            is_paired: extract_run.out.is_paired,
            report: extract_run.out.report,
            mapstats: bitmapper.stats,
            aligned: picard_readgroups_sort.out,
            cpg: methyldackel.cpg,
            counts: methyldackel.counts
        }
    }
    

}


task bitmapper {
   input {
        File index_folder
        Array[File] reads
        Boolean is_paired
        String filename
        Int threads
   }
   command {
        /opt/BitMapperBS/bitmapperBS --search ~{index_folder} ~{if(is_paired) then " --seq1 " + reads[0] + " --seq2 "+ reads[1] + " --sensitive --pe" else " --seq1 " + reads[0]} -t ~{threads} --mapstats --bam -o ~{filename}.bam
   }

  runtime {
    docker: "quay.io/comp-bio-aging/bit_mapper_bs:latest"
  }

  output {
    File out = "~{filename}.bam"
    File stats = "~{filename}.bam.mapstats"
  }
}

task picard_readgroups_sort{
    input {
        File bam
        String filename
    }
    command {
        picard AddOrReplaceReadGroups \
        I=~{bam} \
        O=~{filename}_sorted.bam \
        RGID=4 \
        RGLB=lib1 \
        RGPL=illumina \
        RGPU=unit1 \
        RGSM=20 \
        SORT_ORDER=coordinate
    }

    runtime {
        docker: "biocontainers/picard:v2.3.0_cv3"
    }

    output {
        File out = "~{filename}_sorted.bam"
    }

}

task methyldackel {
    input {
        File bam
        File genome
        Int threads = 4
    }

    command {
        MethylDackel extract --CHH --CHG --counts -@ ~{threads} ~{genome} ~{bam}
    }


    runtime {
        docker: "quay.io/biocontainers/methyldackel@sha256:d434c3e320a40648a3c74e268f410c57649ab208fcde4da93677243b22900c55" #0.3.0--h84994c4_3
    }

    output {
        File cpg = "alignments_CpG.bedGraph"
        File counts = "alignments.counts.bedGraph"
        #File chh = "-CHH and --CHG
    }
}

task copy {
    input {
        Array[File] files
        String destination
    }

    command {
        mkdir -p ~{destination}
        cp -L -R -u ~{sep=' ' files} ~{destination}
    }

    output {
        Array[File] out = files
    }
}