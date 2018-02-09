# extracts implicit and explicit relations from the CDR corpus XML file
# these are saved as two different files and can be used to evaluate LBD
# the output files contain DUI<>DUI pairs that indicate a relation between 
# that pair exists in the dataset. The first DUI is the chemical, and
# the second DUI is the disease. Each line contains only that DUI pair.
# The implicit relations file contains all the implicit relations, while
# the explicit relations file contains all the explicit relations (can
# be used for training)
use strict;
use warnings;
use BioCreativeVProcessor;

#user input
=comment
my $cdrFile = 'CDR_TrainingSet.BioC.xml';
my $sentenceFolder = 'Halil_split/train/';
my $implicitOut = 'implicitRelations_trainingSet';
my $explicitOut = 'explicitRelations_trainingSet';
=cut

=comment
my $cdrFile = 'CDR_DevelopmentSet.BioC.xml';
my $sentenceFolder = 'Halil_split/train/';
my $implicitOut = 'implicitRelations_developmentSet';
my $explicitOut = 'explicitRelations_developmentSet';
=cut

#=comment
my $cdrFile = 'CDR_TestSet.BioC.xml';
my $sentenceFolder = 'Halil_split/test/';
my $implicitOut = 'implicitRelations_testSet';
my $explicitOut = 'explicitRelations_testSet';
#=cut

#################################
# Parameter Error Checking
##################################
open IN, $cdrFile or die ("ERROR: unable to open input CDR file: $cdrFile\n");
close IN;
open OUT_IMPLICIT, ">$implicitOut" 
    or die ("ERROR: unable to open implicit output file: $implicitOut\n");
close OUT_IMPLICIT;
open OUT_EXPLICIT, ">$explicitOut" 
    or die ("ERROR: unable to open explicit output file: $explicitOut\n");
close OUT_EXPLICIT;



#################################
# Begin Code
##################################

#read in all the biocreative V documents
my $biocreativeDocsRef = &BioCreativeVProcessor::processDataSet($cdrFile);
print STDERR "num docs extracted = ".(scalar @{$biocreativeDocsRef})."\n";

#for each document find the implicit and explicit relationship
# stores the results as a hash{relationID} = relationRef;
my %implicitRelations = ();
my %explicitRelations = ();
my %cooccurrenceCounts = ();
foreach my $docRef(@{$biocreativeDocsRef}) {
    #grab the implicit and explicit relations from the document
    (my $docImplicitRef, my $docExplicitRef, my $docCooccurrenceCounts) 
	= &getImplicitAndExplicitRelations($docRef);

    #add to global relation hashes for recording across documents
    my $pmid = ${$docRef}{'pmid'};
    foreach my $relation (@{$docImplicitRef}) {
	$implicitRelations{$pmid.${$relation}{'id'}} = $relation;
    }
    foreach my $relation (@{$docExplicitRef}) {
	$explicitRelations{$pmid.${$relation}{'id'}} = $relation;
    }
    foreach my $key (keys %{$docCooccurrenceCounts}) {
	$cooccurrenceCounts{$key} +=  ${$docCooccurrenceCounts}{$key};
    }
}
print STDERR "num implicit relations = ".(scalar keys %implicitRelations)."\n";
print STDERR "num explicit relations = ".(scalar keys %explicitRelations)."\n";
print STDERR "num unique co-occurrences = ".(scalar keys %cooccurrenceCounts)."\n";


# ensure that implicit relationships are globally implicit
# ...since it is possible that a relationship implicit to one
# document is explicit to another document, this step ensures
# that the implicit relationships are globally implicit (never
# explicitly mentioned in any document
foreach my $implicitKey (keys %implicitRelations) {
    my $implicitChemical = ${$implicitRelations{$implicitKey}}{'chemical'};
    my $implicitDisease = ${$implicitRelations{$implicitKey}}{'disease'};

    foreach my $explicitKey (keys %explicitRelations) {
	my $explicitChemical = ${$explicitRelations{$explicitKey}}{'chemical'};
	my $explicitDisease = ${$explicitRelations{$explicitKey}}{'disease'};
	
	#check if the implicit chemical-disease pair
	# matches the explicit chemical-disease pair
	if ($implicitChemical eq $explicitChemical
	    && $implicitDisease eq $explicitDisease) {
	    #disease pair match, remove from the list of implicitRelations
	    delete $implicitRelations{$implicitKey};
	    last;
	}
    }
}
print STDERR "after checking for explicit implicits, num implicit = ".(scalar keys %implicitRelations)."\n";


=comment
# Checks for repeat relations ... There are none
####################
#check for and remove any duplicate relations
foreach my $key1 (keys %implicitRelations) {
    my $chemical1 = ${$implicitRelations{$key1}}{'chemical'};
    my $disease1 = ${$implicitRelations{$key1}}{'disease'};

    foreach my $key2 (keys %explicitRelations) {
	my $chemical2 = ${$explicitRelations{$key2}}{'chemical'};
	my $disease2 = ${$explicitRelations{$key2}}{'disease'};
	
	#check if the implicit chemical-disease pair
	# matches the explicit chemical-disease pair
	if ($chemical1 eq $chemical2
	    && $disease1 eq $disease2) {
	    #disease pair match, remove from the list of implicitRelations
	    delete $implicitRelations{$key1};
	    last;
	}
    }
}
foreach my $key1 (keys %explicitRelations) {
    my $chemical1 = ${$explicitRelations{$key1}}{'chemical'};
    my $disease1 = ${$explicitRelations{$key1}}{'disease'};

    foreach my $key2 (keys %explicitRelations) {
	my $chemical2 = ${$explicitRelations{$key2}}{'chemical'};
	my $disease2 = ${$explicitRelations{$key2}}{'disease'};
	
	#check if the implicit chemical-disease pair
	# matches the explicit chemical-disease pair
	if ($chemical1 eq $chemical2
	    && $disease1 eq $disease2) {
	    #disease pair match, remove from the list of implicitRelations
	    delete $explicitRelations{$key1};
	    last;
	}
    }
}
####################
=cut


#TODO, so no co-occurrence count of implicit relations? (I think there were no repeats anyway)
#output the implicit and explicit relations to files as dui<>dui pairs
# output implicit relations
open OUT, ">$implicitOut" 
    or die ("ERROR: unable to open implicit output file: $implicitOut\n");
foreach my $key (keys %implicitRelations) {
    my $chemical = ${$implicitRelations{$key}}{'chemical'};
    my $disease = ${$implicitRelations{$key}}{'disease'};
    print OUT "$chemical<>$disease\n";
}
close OUT;


#output explicit relations as dui<>dui<>co-occurrenceCount triplets
open OUT, ">$explicitOut" 
    or die ("ERROR: unable to open explicit output file: $explicitOut\n");
foreach my $key (keys %explicitRelations) {
    my $chemical = ${$explicitRelations{$key}}{'chemical'};
    my $disease = ${$explicitRelations{$key}}{'disease'};
    my $cooccurrenceCount = $cooccurrenceCounts{"$chemical,$disease"};
    print OUT "$chemical<>$disease<>$cooccurrenceCount\n";
}
close OUT;

print "Done!\n";






#################################
# Helper Methods
################################

#reads a sentence split file and grabs the sentences from it
# sentences are returned as an array of sentences texts (strings)
sub getSentences {
    my $inputFile = shift;

    #open the sentence split file
    open IN, $inputFile
	or die ("ERROR cannot open sentence split file: $inputFile"); 

    #read all sentences from the file
    my @sentences = ();
    while (my $line = <IN>) {
	#check if you are at the start of a new sentence
	if ($line =~ /<sentence/) {
	    #read the lines of the sentence until the text is encountered
	    while ($line = <IN>) {
		#if the text is encountered, add it to the sentences array
		if ($line =~ /<text xml:space="preserve">(.+)<\/text>/) {
		    #replace any special chars (&apos; &lt;) and add to list
		    my $text = &BioCreativeVProcessor::replaceSpecialChars($1);
		    push @sentences, $text;
		}
	    }

	}
    }
    close IN;
    
    #return the extracted sentences
    return \@sentences;
}


#determines which of the relations in the document are explicit
# and which of the relations in the documebt are implicit
# returns them as two arrays containing references to the 
# relations themselves. Also returns a coocurrence count
# hash in which the keys are the ChemicalDUI,DiseaseDUI pair
# and the value is the number of times that relation occurs in
# the corpus (e.g. counts{"D000000,D111111"}=2
# OUTPUT is: (\@implicitRelations, \@explicitRelations, \%cooccurrenceCounts)
sub getImplicitAndExplicitRelations {
    my $docRef = shift;
    #grab document info
    my $pmid = ${$docRef}{'pmid'};

    #grab sentences from the sentence split file
    my $sentencesRef = &getSentences($sentenceFolder.'PMID-'.$pmid.'.xml');

    #grab the annotations from the document and store as a 
    # hash{$dui} = 'sourceText'
    my %annotations = ();
    foreach my $passageRef (@{${$docRef}{'passages'}}) {
	foreach my $annotationRef (@{${$passageRef}{'annotations'}}) {

	    #grab the duis (possibly multiple ones split by |)
	    my $duiText = ${$annotationRef}{'dui'};
	    my @duis = split(/\|/,$duiText);

	    #if there are multiple duis, store hash elements for each possibility
	    foreach my $dui (@duis) {
		$annotations{$dui} = ${$annotationRef}{'sourceText'};
	    }
	    #NOTE: duis of -1 will be overwritten, but I don't know of a 
            #      better way to do this...I think I should just drop any 
	    #      -1's in relations
	}
    }

    #find implicit relations by checking if the annotations DO NOT occur 
    # in any of the same sentences of the document
    #Also save the explicit relations (ones that fail the test)
    my @implicitRelations = ();
    my @explicitRelations = ();
    my %cooccurrenceCounts = ();
    #check each relation
    foreach my $relation (@{${$docRef}{'relations'}}) {
	#count the number of times the pair co-occurrs
	my $count = 0;

	#grab the chemical and disease texts
	my $chemicalText = $annotations{${$relation}{'chemical'}};
	my $diseaseText = $annotations{${$relation}{'disease'}};

	#see if the DUIs of the relation co-occur in any sentence
	# ...thereby showing that it is explicit
	# and count their number of co-occurrences
	foreach my $sentence (@{$sentencesRef}) {
	    #see if both chemical and disease co-occur in a sentence
	    if ($sentence =~ /\Q$chemicalText\E/ && $sentence =~ /\Q$diseaseText\E/) {
		$count++
	    }
	}

	#add to the appropriate array
	if ($count == 0) {
	    push @implicitRelations, $relation;

	    #Error Checking --- See if a chemical and disease match nothing in the dataset
	    my $chemicalMatch = 0;
	    my $diseaseMatch = 0;
	    foreach my $sentence (@{$sentencesRef}) {
		if ($sentence =~ /\Q$chemicalText\E/) {
		    $chemicalMatch = 1;
		}

		if ($sentence =~ /\Q$diseaseText\E/) {
		    $diseaseMatch = 1;
		}
	    }
	    if ($chemicalMatch == 0) {
		print STDERR "WARNING: Chemical never matches any text: $chemicalText\n";
		print STDERR "         from PMID = ${$docRef}{pmid}\n"
	    }
	    if ($diseaseMatch == 0) {
		print STDERR "WARNING: Disease never matches any text: $diseaseText\n";
		print STDERR "         from PMID = ${$docRef}{pmid}\n"
	    }
	}
	else {
	    push @explicitRelations, $relation;
	    $cooccurrenceCounts{"${$relation}{chemical},${$relation}{disease}"} += $count;
	}
    }

    #return the implicit and explicit relations
    return (\@implicitRelations, \@explicitRelations, \%cooccurrenceCounts);
}
