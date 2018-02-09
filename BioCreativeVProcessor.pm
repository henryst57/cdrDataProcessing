#BioCreative V Processor - reads in biocreative V data as a @documents
# array of document hashes
# USAGE: 
#  call processDataSet($inputFileName) to process the input file
#
# EXAMPLE:
#     use BioCreativeVProcessor;
#
#     my $biocreativeDocsRef = &BioCreativeVProcessor::processDataSet($cdr.xml);
#     foreach my $docRef(@{$biocreativeDocsRef}) {
#         print "${$docRef}{'pmid'}\n";
#     }

package BioCreativeVProcessor;

use strict;
use warnings;


#processes the CDR dataset and returns an array ref of 
# document hash refs. Each document is a hash ref containing:
#   document{'pmid'} = the pmid of the document
#   document{'relations'} = array ref of the relation hash refs of the document
#   document{'passages'} = array ref of the passage hash refs of the document
#
# each relation is hash ref containing:
#   relation{'id'} = the id of the relation
#   relation{'type'} = the relation type (e.g. CID)
#   relation{'chemical'} = DUI(s) of the chemical in the relation
#   relation{'disease'} = DUI(s) of the the disease of the relation
# NOTE: multiple DUI mappings can occur, and are seperated by a '|' 
#       (e.g. D000000|D111111 or D000000|-1)
# NOTE:  a '-1' is used to indicate that no DUI mapping exists
#
# each passage is a hash ref containing:
#   passage{'type'} - a string specifying type (title or abstract)
#   passage{'offset'} - a number indicating the passage text offset 
#   passage{'text'} - the text of the passage
#   passage{'annotations'} - an array ref of the annotation hash refs in the passage
#
# each annotation is a hash ref containing:
#   annotation{'id'} = a string indicating the id 
#   annotation{'type'} = a string indicating the type (Disease, Chemical, etc)
#   annotation{'dui'} = a string indicating the MeSH DUI(s) 
#   annotation{'offsets'} = an array ref containing offsets
#   annotation{'lengths'} = an array ref of lengths
#   annotation{'text'} = the text of the annotation
#   annotation{'sourceText'} = the passage text that the annotation was derived from
# NOTE: multiple DUI mappings can occur, and are seperated by a '|' 
#       (e.g. D000000|D111111 or D000000|-1)
# NOTE:  a '-1' is used to indicate that no DUI mapping exists
# NOTE: the offsets and lengths indicate in passage text where the word starts
#       and its length. When multiple words are used for a term, there are
#       multiple offsets and lengths, one for each word.
sub processDataSet {
    my $cdrFile = shift;

    #read in all citations of passages of the corpus
    open IN, $cdrFile or die ("ERROR: unable to open input CDR file: $cdrFile\n");
    my @documents = ();
    while (my $line = <IN>) {

	#check if a new document is reached
	if ($line =~ /<document>/) {
	    #new document started so read in all document lines
	    my @documentLines = ();
	    while ($line = <IN>) {
		push @documentLines, $line;
		if ($line =~ /<\/document>/) {
		    last;
		}
	    }

	    #process the document lines
	    push @documents, &_processDocument(\@documentLines);
	}
    }
    close IN;

    #error checking and return
    (scalar @documents > 0) or die ("ERROR: no documents read in\n");
    return \@documents
}

#grabs information from lines of a document read from an XML file
# document contains sets of passages as well as other info
# returns a hash ref containing document info:
#   document{'pmid'} = the pmid of the document
#   document{'passages'} = array ref of the passage hash refs of the document
#   document{'relations'} = array ref of the relation hash refs of the document
sub _processDocument {
    my $documentLinesRef = shift;
    
    #grab document info
    my $pmid;
    my @passages = ();
    my @relations = ();
    my $line;
    for (my $i = 0; $i < scalar @{$documentLinesRef}; $i++) {
	$line = ${$documentLinesRef}[$i];

	#check for pmid
	if ($line =~ /<id>(\d+)<\/id>/) {
	    $pmid = $1;
	    next;
	}

	#check for a passage
	if ($line =~ /<passage>/) {
	    #read in all the passage lines
	    my @passageLines = ();
	    for ($i = $i; $i < scalar @{$documentLinesRef}; $i++) {
		$line = ${$documentLinesRef}[$i];
		push @passageLines, $line;
		if ($line =~ /<\/passage>/) {
		    last;
		}	
	    }
	    push @passages, &_processPassage(\@passageLines);
	    next;
	}

	#check for a relation
	if ($line =~ /<relation id='(.+)'>/) {
	    my $relationID = $1;

	    #read in all the relation lines
	    my @relationLines = ();
	    for ($i = $i; $i < scalar @{$documentLinesRef}; $i++) {
		$line = ${$documentLinesRef}[$i];
		push @relationLines, $line;
		if ($line =~ /<\/relation>/) {
		    last;
		}
	    }
	    push @relations, &_processRelation(\@relationLines, $relationID);
	}
    }

    #construct the document hash
    my %document = ();
    $document{'pmid'} = $pmid;
    $document{'passages'} = \@passages;
    $document{'relations'} = \@relations;

    #document error checking
    (defined $document{'pmid'}) or &_readingError(\%document, 'document');
    (scalar @{$document{'passages'}} > 0) or &_readingError(\%document, 'document');
    (scalar @{$document{'relations'}} > 0) or &_readingError(\%document, 'document');

    #return the document
    return \%document;
}


# TODO, this will only work for Chemical Induced Disease relation type, I will need
#    to write different functions for CDR types, etc... I'm not sure if my dataset
#    has this though.
#
# processes the lines of a relation to create a relation hash ref
#   relation{'id'} = the id of the relation
#   relation{'type'} = the relation type (e.g. CID)
#   relation{'chemical'} = DUI(s) of the chemical in the relation
#   relation{'disease'} = DUI(s) of the the disease of the relation
# NOTE: multiple DUI mappings can occur, and are seperated by a '|' 
#       (e.g. D000000|D111111 or D000000|-1)
# NOTE:  a '-1' is used to indicate that no DUI mapping exists
sub _processRelation {
    my $relationLinesRef = shift;
    my $relationID = shift;

    #grab info from the relation lines
    my $type;
    my $chemical;
    my $disease;
    foreach my $line (@{$relationLinesRef}) {
	#grab the type
	if ($line =~ /<infon key="relation">(.+)<\/infon>/) {
	    $type = $1;
	}
	
	#grab the chemical
	if ($line =~ /<infon key="Chemical">(([DC]\d{6}\|?|-1)+)<\/infon>/) {
	    $chemical = $1;
	}

        #grab the disease
	if ($line =~ /<infon key="Disease">(([DC]\d{6}\|?)+|-1)<\/infon>/) {
	    $disease = $1;
	}
    }

    #construct the relatio hash
    my %relation = ();
    $relation{'id'} = $relationID;
    $relation{'type'} = $type;
    $relation{'chemical'} = $chemical;
    $relation{'disease'} = $disease;

    #error checking
    (defined $relation{'id'}) or &_readingError(\%relation, 'relation');
    (defined $relation{'type'}) or &_readingError(\%relation, 'relation');
    (defined $relation{'chemical'}) or &_readingError(\%relation, 'relation');
    (defined $relation{'disease'}) or &_readingError(\%relation, 'relation');

    #return the relation
    return \%relation;
}


#processes lines of passage text, and returns a hash containing
# the passage info, specifically a hash containing:
#   passage{'type'} - a string specifying type (title or abstract)
#   passage{'offset'} - a number indicating the passage text offset 
#   passage{'text'} - the text of the passage
#   passage{'annotations'} - an array ref of the annotation hash refs in the passage
sub _processPassage {
    my $passageLinesRef = shift;
    
    #process the lines of the passage
    my $line;
    my $type;
    my $offset;
    my $text;
    my @annotations = ();
    for (my $i = 0; $i < scalar @{$passageLinesRef}; $i++) {
	$line = ${$passageLinesRef}[$i];

	#check for type
	if ($line =~ /<infon key="type">(.+)<\/infon>/) {
	    $type = $1;
	    next;
	}

	#check for offset
	if ($line =~ /<offset>(\d+)<\/offset>/) {
	    $offset = $1;
	    next;
	}

	#check for text
	if ($line =~ /<text>(.+)<\/text>/) {
	    $text = $1;
	    next;
	}

	#check for annotation
	if ($line =~ /<annotation id='(\d+)'>/) {
	    my $annotationID = $1;

	    #process the annotation
	    my @annotationLines = ();
	    for ($i = $i; $i < scalar @{$passageLinesRef}; $i++) {
		$line = ${$passageLinesRef}[$i];
		push @annotationLines, $line;
		if ($line =~ /<\/annotation>/) {
		    last;
		}	
	    }
	    push @annotations, &_processAnnotation(\@annotationLines, $annotationID);
	    next;
	}
    }

    #create and return the passage hash
    my %passage = ();
    $passage{'type'} = $type;
    $passage{'offset'} = $offset;
    $passage{'text'} = $text;
    $passage{'annotations'} = \@annotations;

    #passage error checking
    (defined $passage{'type'}) or &_readingError(\%passage, 'passage');
    (defined $passage{'offset'}) or &_readingError(\%passage, 'passage');
    (defined $passage{'text'}) or &_readingError(\%passage, 'passage');
    #(scalar @{$passage{'annotations'}} > 0) or &readingError(\%passage, 'passage');
    #NOTE: not all passages have annotations

    #replace any special text (e.g. &apos;, &lt; etc)
    $passage{'text'} = &replaceSpecialChars($passage{'text'});
    
    #add source text to each of the annotations
    # this is the text that the annotation was generated from
    # it is added after the loop since there is not garauntee the
    # passage text is read before annotations are
    &_addSourceTextToAnnotations(\%passage);

    #return the passage
    return \%passage;
}

#replace any special text (e.g. &apos;, &lt; etc) with their 
# normal symbols (e.g. ', <, etc)
sub replaceSpecialChars {
    my $text = shift;

    $text =~ s/&apos;/'/g; 
    $text =~ s/&quot;/"/g; 
    $text =~ s/&gt;/>/g; 
    $text =~ s/&lt;/</g; 
    $text =~ s/&amp;/</g; 

    return $text;
}

#processes the text of an annotation
# returns info about an annotation stored as a hash ref:
#   annotation{'id'} = a string indicating the id 
#   annotation{'type'} = a string indicating the type (Disease, Chemical, etc)
#   annotation{'dui'} = a string indicating the MeSH DUI(s) 
#   annotation{'offsets'} = an array ref containing offsets
#   annotation{'lengths'} = an array ref of lengths
#   annotation{'text'} = the text of the annotation
# NOTE: multiple DUI mappings can occur, and are seperated by a '|' 
#       (e.g. D000000|D111111 or D000000|-1)
# NOTE:  a '-1' is used to indicate that no DUI mapping exists
# NOTE: the offsets and lengths indicate in passage text where the word starts
#       and its length. When multiple words are used for a term, there are
#       multiple offsets and lengths, one for each word.
sub _processAnnotation {
    my $annotationLinesRef = shift;
    my $id = shift;

    #process the lines of the annotation
    my $line;
    my $type;
    my $dui;
    my @offsets = ();
    my @lengths = ();
    my $text;
    for (my $i = 0; $i < scalar @{$annotationLinesRef}; $i++) {
	$line = ${$annotationLinesRef}[$i];

	#check for type
	if ($line =~ /<infon key="type">(.+)<\/infon>/) {
	    $type = $1;
	    next;
	}
	
	#check for dui
	if ($line =~ /<infon key="MESH">(([DC]\d{6}\|?|-1)+)<\/infon>/) {
	    $dui = $1;
	    next;
	}

	#check for offset
	if ($line =~ /<location offset='(\d+)' length='(\d+)' \/>/) {
	    push @offsets, $1;
	    push @lengths, $2;
	    next;
	}

	#check for text
	if ($line =~ /<text>(.+)<\/text>/) {
	    $text = $1;
	    next;
	}
    }

    #construct the annotation
    my %annotation = ();
    $annotation{'id'} = $id;
    $annotation{'type'} = $type;
    $annotation{'dui'} = $dui;
    $annotation{'offsets'} = \@offsets;
    $annotation{'lengths'} = \@lengths;
    $annotation{'text'} = $text;

    #annotation error checking
    (defined $annotation{'id'}) or &_readingError(\%annotation, 'annotation');
    (defined $annotation{'type'}) or &_readingError(\%annotation, 'annotation');
    (defined $annotation{'dui'}) or &_readingError(\%annotation, 'annotation');
    (scalar @{$annotation{'offsets'}} > 0) or &_readingError(\%annotation, 'annotation');
    (scalar @{$annotation{'lengths'}} > 0) or &_readingError(\%annotation, 'annotation');
    (scalar @{$annotation{'offsets'}} == scalar @{$annotation{'lengths'}}) 
		   or &_readingError(\%annotation, 'annotation');
    (defined $annotation{'text'}) or &_readingError(\%annotation, 'annotation');
    
    #return the annotation
    return \%annotation;
}

#adds source text to all annotations of the passage. The
# source text is the text that the annotation was derived 
# from in the passage. Returns nothing, but adds the 
# "sourceText" key and value to each annotation of the passage
sub _addSourceTextToAnnotations {
    my $passageRef = shift;

    #add source text to each annotation
    # source data is all the text between the lowest offset and the highest offset+length
    foreach my $annotationRef(@{${$passageRef}{'annotations'}}) {
	#find the star and end chars of this annotation
	# intialize to the first offset and offset + length
	my $startCharIndex = ${${$annotationRef}{'offsets'}}[0];;
	my $endCharIndex = $startCharIndex + ${${$annotationRef}{'lengths'}}[0];
	for (my $i = 1; $i < scalar @{${$annotationRef}{'offsets'}}; $i++) {
	    my $offset = ${${$annotationRef}{'offsets'}}[$i];;
	    my $length = ${${$annotationRef}{'lengths'}}[$i];
	    
	    #update min/max
	    if ($offset < $startCharIndex) {
		$startCharIndex = $offset;
	    }
	    if (($offset + $length) > $endCharIndex) {
		$endCharIndex = ($offset + $length);
	    }
	}

	#now we have the starting index and ending index of the text that
	# generated the annotation, so grab that text from the passage text
        my $length = $endCharIndex-$startCharIndex;
	#subtract the passage offset
	$startCharIndex = $startCharIndex - ${$passageRef}{'offset'};
	${$annotationRef}{'sourceText'} = 
	    substr ${$passageRef}{'text'}, $startCharIndex, $length;
    }
    
    #Done, source texts have been added to all annotations of the passage
}



#reports an error reading in a data strucutre
# and exits the program
sub _readingError {
    my $hashRef = shift;
    my $type = shift;
    
    #output info on the error
    print STDERR "ERROR: error reading in $type:\n";

    #check each key and output to STDERR
    foreach my $key (keys %{$hashRef}) {	
	if (defined ${$hashRef}{$key}) {
	    #check if its an array
	    if (ref(${$hashRef}{$key}) eq 'ARRAY') {
		print STDERR "   $key = ".${$hashRef}{$key}.", size = ".(scalar @{${$hashRef}{$key}})."\n";
	    }
	    else {
		print STDERR "   $key = ".${$hashRef}{$key}."\n";
	    }

	}
	else {
	    print STDERR "  ERROR reading $key\n";
	}
    }
    #exit the program
    exit;
}

1;
