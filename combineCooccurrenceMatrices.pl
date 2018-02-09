#combines two co-occurrence matrix files by summing values with
# the same term pair, co-occurrence matrix files are of the 
# form: term<>term<>count\n
use strict;
use warnings;

#user input
my $file1 = 'implicitRelations_trainingSet';
my $file2 = 'implicitRelations_developmentSet';
my $outFile = 'implicitRelations_trainingAndDevelopmentSets';

#test file I/O
open IN1, $file1 or die ("ERROR opening file1: $file1\n");
open IN2, $file2 or die ("ERROR opening file2: $file2\n");
open OUT, ">$outFile" or die ("ERROR opening outFile: $outFile\n");

#read first file into a hash
print STDERR "reading file 1\n";
my %matrix = ();
while (my $line = <IN1>) {
    chomp $line;
    my @vals = split(/<>/,$line);
    $matrix{"$vals[0]<>$vals[1]"} += $vals[2];
}
close IN1;


#read and merge second file into the hash
print STDERR "reading file 2\n";
while (my $line = <IN2>) {
    chomp $line;
    my @vals = split(/<>/,$line);
    $matrix{"$vals[0]<>$vals[1]"} += $vals[2];
}
close IN2;


#output the results
print STDERR "outputting\n";
foreach my $key (keys %matrix) {
    my @keyVals = split(/<>/, $key);
    print OUT "$keyVals[0]<>$keyVals[1]<>$matrix{$key}\n";

}
close OUT;

print STDERR "Done!\n";
