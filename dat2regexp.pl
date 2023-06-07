use strict;

sub generateMissingRegex {
	my $missingArray = shift;
	
	my $missingRegex;
	
	foreach my $missingSet (@$missingArray) {
		$missingSet =~ s/([\(\)\*\+\^\$\'])/\\\1/ig;
		$missingRegex = "$missingRegex|$missingSet\\.";
		
		if(length $missingRegex > 28000) {
			$missingRegex = substr $missingRegex, 1 if length $missingRegex;
			
			print "Missing set regex: $missingRegex\n" if length $missingRegex;
			print "\n";
			
			$missingRegex = "";
		}
	}
	
	$missingRegex = substr $missingRegex, 1 if length $missingRegex;
	
	print "Missing set regex: $missingRegex\n" if length $missingRegex;
}

sub readDatFile {
	my $datPath = shift;
	my $datDbRef = shift;
	
	print "Reading Dat File: $datPath\n\n";
	
	open my $file, "<$datPath" or die "Cannot open dat file: $!";
	my @lines = <$file>;
	close $file;
	
	my $beginBlock = 0;
	my $clrHeader = 0;
	my $lineNo = 0;
	
	my $rlsName;
	
	foreach(@lines) {
		++$lineNo;
		
		if(/\s*<(?:game|machine) name=\"(.+?)\">/) {
			$rlsName = $1;
			$rlsName =~ s/&amp;/&/g;
			$rlsName =~ s/&apos;/'/g;
			
			$beginBlock = 1;
			
			next;
		} elsif(/^game\s*\(\s*$/) {
			$beginBlock = 2;
			
			next;
		} elsif(/^clrmamepro\s*\(\s*$/) {
			$clrHeader = 1;
			
			next;
		}
		
		if($beginBlock == 2) {
			if(/^\s*name\s*([\"]?)(.*)\1\s*$/) {
				$rlsName = $2;
				$rlsName =~ s/&amp;/&/g;
				$rlsName =~ s/&apos;/'/g;
				
				next;
			}
		}
		
		#print "RLS: $rlsName\n" if $rlsName =~ /&[^\s]/;
		
		my $reset = 0;
		
		$reset = 1 if /\s*<\/(?:game|machine)>/;
		$reset = 1 if /^\s*\)\s*$/;
		
		if($reset) {
			if(!$beginBlock && !$clrHeader) {
				die "Bad dat line: $lineNo $_";
			}
			
			$beginBlock = 0;
			$clrHeader = 0;
			
			$rlsName = "";
			
			next;
		}
		
		if($beginBlock) {
			my $elemName = undef;
			my $elemSize = undef;
			my $elemCRC = undef;
			my $elemMD5 = undef;
			my $elemSHA1 = undef;
			
			my $matched = 0;
			
			if(/<rom name=\"(.+?)\"\s*size=\"(\d+?)\"\s*crc=\"([0-9a-fA-F]+?)\"\s*md5=\"(.+?)\"\s*sha1=\"(.+?)\"/) {
				$elemName = $1;
				$elemSize = $2;
				$elemCRC = $3;
				$elemMD5 = $4;
				$elemSHA1 = $5;
				
				$matched = 1;
			} elsif(/<rom name=\"(.+?)\"\s*size=\"(\d+?)\"\s*crc=\"([0-9a-fA-F]+?)\"\s*sha1=\"(.+?)\"\s*md5=\"(.+?)\"/) {
				$elemName = $1;
				$elemSize = $2;
				$elemCRC = $3;
				$elemSHA1 = $4;
				$elemMD5 = $5;
				
				$matched = 1;
			} elsif(/<rom name=\"(.+?)\"\s*size=\"(\d+?)\"\s*crc=\"([0-9a-fA-F]+?)\"\s*md5=\"(.+?)\"/) {
				$elemName = $1;
				$elemSize = $2;
				$elemCRC = $3;
				$elemMD5 = $4;
				$elemSHA1 = "0000000000000000000000000000000000000000";
				
				$matched = 1;
			} elsif(/rom\s*\(\s*name\s*[\"]?(.+?)[\"]?\s*size\s*(\d+?)\s*crc\s*([0-9a-fA-F]+?)\s*md5\s*(.+?)\s*sha1\s*(.+?)\s*\)/) {
				$elemName = $1;
				$elemSize = $2;
				$elemCRC = $3;
				$elemMD5 = $4;
				$elemSHA1 = $5;
				
				$matched = 1;
			}
			
			if($matched) {
				$elemName =~ s/&amp;/&/g;
				
				push @{$datDbRef->{$rlsName}}, {NAME => $elemName, SIZE => $elemSize, CRC => $elemCRC, MD5 => $elemMD5, SHA1 => $elemSHA1, MATCHED => 0, HAVE => 0};
			}
		}
	}
}

sub fixDatToRegex {
	my $datPath = shift;
	
	my %datDb;
	readDatFile $datPath, \%datDb;
	
	my @sortedKeys = sort keys %datDb;
	generateMissingRegex \@sortedKeys;
}

fixDatToRegex $ARGV[0];
