#!/bin/bash

#SBATCH --cpus-per-task=4
#SBATCH --mem=5000
#SBATCH --nice=0
#SBATCH --job-name=merge
#SBATCH --license=proj-highio

########################

# change the "basename" result
# check if the data-files are called R1 and R2
	## for i in *_1.fastq; do output=$(echo $i | sed 's/_1.fastq/_R1.fastq/g'); mv $i $output; done
	## for i in *_2.fastq; do output=$(echo $i | sed 's/_2.fastq/_R2.fastq/g'); mv $i $output; done
# check the name for the division( _; .; -; ...)
# outside: -first field = the name with the complete directory of the R1 file
#	   -second field = the output-directory with an additional "folder" at the end

# usage: sbatch directory/to/bin/merge_and_quality.sh /complete/directory/to/<sample>_R1.fastq /complete/directory/to/your/output/directory/with/an/additional/"folder"/at/the/end

########################

module load samtools
#module load mapdamage/2.0.8
module load pear/0.9.10
module load samtools
module load fastqc

# takes the first array written on the terminal as Forward
Forward=$1

# name the category for were your samples will be stored
category=$2


# For Reverse take the same as for Forward but exchange the R1 with R2
Reverse=$(echo $Forward | sed 's/R1/R2/g')

# name2 = the filename without the directory of Forward
# name = only the first array (option -f) of the filename. Arrays are divided by _ (option -d) = only the sample ID
name2=$(basename $Forward)
name=$(echo $name2 | cut -d "_" -f1)

# print the names of the used files, directories,... to check if the right "things" are used
# -e = to enable interpretation of backslash escapes
echo -e "the forward file \t\t= " $Forward
echo -e "the reverse file \t\t= " $Reverse
echo -e "the output-category \t\t= " $category
echo -e "the filename of the sample \t= " $name2
echo -e "the sample ID \t\t\t= " $name

gzip -d $Forward
gzip -d $Reverse


#add a quality here?
#y 1000M : memory to use
# merge the raw data (fastq-files without trimming adapters before): 
#-v: minimum number of overlapping bases; 
#-f: input forward-file; 
#-r: input reverse-file; 
#-o: prefix of the outputfiles (4 output-files per sample); 
#-n: Specify   the  minimum  possible  length  of  the  assembled sequences. 
#-j: Number of threads to use. adapters are trimmed in assembeled reads 
pear -v 11 -n 25 -f $Forward -r $Reverse -j 4 -y 5000M -o $TMPDIR/$name.pear > $TMPDIR/$name.pear.log

#output files:
#1. output_prefix.assembled.fastq - the assembled pairs
#2. output_prefix.unassembled.forward.fastq - unassembled forward reads
#3. output_prefix.unassembled.reverse.fastq - unassembled reverse reads
#4. output_prefix.dicarded.fastq  - reads which did not meet criteria specified in options

#
# run the quality script; -c = Quality cutoff value; -n = Max. # of bases < cutoff
(python /proj/IcemanInstitute/wurst/scripts/QualityFilterFastQ.py -c 30 -n 5 -o $TMPDIR --outfile=$name.pear.assembled_quality.fastq $TMPDIR/$name.pear.assembled.fastq ) >& $TMPDIR/$name.quality.log


# count the reads after the quality-chek
echo $name >> $TMPDIR/readcounts_quality
awk '{s++}END{print s/4}' $TMPDIR/$name.pear.assembled_quality.fastq >> $TMPDIR/$name.readcounts_quality

gzip $TMPDIR/$name.pear.assembled_quality.fastq

mkdir -p /scratch/granehaell/$category/

fastqc $TMPDIR/$name.pear.assembled_quality.fastq.gz -d $TMPDIR -o /scratch/granehaell/$category/

# create a new folder but only if it is not yet existing (= option -p)
mkdir -p /scratch/granehaell/$category/quality/

mv $TMPDIR/$name.pear.assembled_quality.fastq.gz /scratch/granehaell/$category/quality/
mv $TMPDIR/$name.readcounts_quality /scratch/granehaell/$category/
mv $TMPDIR/$name.pear.log /scratch/granehaell/$category/
mv $TMPDIR/$name.quality.log /scratch/granehaell/$category/

# delete the unzipped raw data files
rm $Forward
rm $Reverse
