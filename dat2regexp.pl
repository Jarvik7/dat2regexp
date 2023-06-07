use strict;
use warnings;
use Time::HiRes qw(gettimeofday tv_interval);

sub generateMissingRegex {
    my $missingArray = shift;
    my @regexElements;
    my $missingRegex = '';

    foreach my $missingSet (@$missingArray) {
        my $escapedSet = $missingSet;
        $escapedSet =~ s/([\(\)\*\+\^\$])/\\$1/ig;
        push @regexElements, $escapedSet;

        if (@regexElements > 1000) {  # Adjust the threshold as needed
            $missingRegex .= join('|', @regexElements) . '\.';
            print "Missing set regex: $missingRegex\n\n";
            @regexElements = ();
            $missingRegex = '';
        }
    }

    if (@regexElements) {
        $missingRegex .= join('|', @regexElements) . '\.';
        print "Missing set regex: $missingRegex\n" if length $missingRegex;
    }
}

sub readDatFile {
    my ($datPath, $datDbRef) = @_;

    print "Reading Dat File: $datPath\n\n";

    open my $file, "<", $datPath or die "Cannot open dat file: $!";
    my @lines = <$file>;
    close $file;

    my $beginBlock = 0;
    my $clrHeader = 0;
    my $lineNo = 0;

    my $rlsName;

    foreach my $line (@lines) {
        ++$lineNo;

        if ($line =~ /^\s*<(?:game|machine) name="(.+?)">/) {
            $rlsName = $1;
            $rlsName =~ s/&amp;/&/g;
            $rlsName =~ s/&apos;/'/g;

            $beginBlock = 1;

            next;
        } elsif ($line =~ /^game\s*\(\s*$/) {
            $beginBlock = 2;

            next;
        } elsif ($line =~ /^clrmamepro\s*\(\s*$/) {
            $clrHeader = 1;

            next;
        }

        if ($beginBlock == 2) {
            if ($line =~ /^\s*name\s*["]?(.*)["]?\s*$/) {
                $rlsName = $1;
                $rlsName =~ s/&amp;/&/g;
                $rlsName =~ s/&apos;/'/g;

                next;
            }
        }

        my $reset = 0;

        $reset = 1 if $line =~ /^\s*<\/(?:game|machine)>/;
        $reset = 1 if $line =~ /^\s*\)\s*$/;

        if ($reset) {
            if (!$beginBlock && !$clrHeader) {
                die "Bad dat line: $lineNo $line";
            }

            $beginBlock = 0;
            $clrHeader = 0;

            $rlsName = '';

            next;
        }

        if ($beginBlock) {
            my $elemName = undef;
            my $elemSize = undef;
            my $elemCRC = undef;
            my $elemMD5 = undef;
            my $elemSHA1 = undef;

            my $matched = 0;

            if ($line =~ /<rom name="(.+?)"\s*size="(\d+?)"\s*crc="([0-9a-fA-F]+?)"\s*md5="(.+?)"\s*sha1="(.+?)"/) {
                ($elemName, $elemSize, $elemCRC, $elemMD5, $elemSHA1) = ($1, $2, $3, $4, $5);
                $matched = 1;
            } elsif ($line =~ /<rom name="(.+?)"\s*size="(\d+?)"\s*crc="([0-9a-fA-F]+?)"\s*sha1="(.+?)"\s*md5="(.+?)"/) {
                ($elemName, $elemSize, $elemCRC, $elemSHA1, $elemMD5) = ($1, $2, $3, $4, $5);
                $matched = 1;
            } elsif ($line =~ /<rom name="(.+?)"\s*size="(\d+?)"\s*crc="([0-9a-fA-F]+?)"\s*md5="(.+?)"/) {
                ($elemName, $elemSize, $elemCRC, $elemMD5, $elemSHA1) = ($1, $2, $3, $4, "0000000000000000000000000000000000000000");
                $matched = 1;
            } elsif ($line =~ /rom\s*\(\s*name\s*["]?(.+?)["]?\s*size\s*(\d+?)\s*crc\s*([0-9a-fA-F]+?)\s*md5\s*(.+?)\s*sha1\s*(.+?)\s*\)/) {
                ($elemName, $elemSize, $elemCRC, $elemMD5, $elemSHA1) = ($1, $2, $3, $4, $5);
                $matched = 1;
            }

            if ($matched) {
                $elemName =~ s/&amp;/&/g;

                push @{$datDbRef->{$rlsName}}, {
                    NAME    => $elemName,
                    SIZE    => $elemSize,
                    CRC     => $elemCRC,
                    MD5     => $elemMD5,
                    SHA1    => $elemSHA1,
                    MATCHED => 0,
                    HAVE    => 0
                };
            }
        }
    }
}

sub fixDatToRegex {
    my $datPath = shift;

    my %datDb;
    my $start_time = [gettimeofday()];  # Record the start time

    readDatFile($datPath, \%datDb);

    my @sortedKeys = sort keys %datDb;
    generateMissingRegex(\@sortedKeys);

    my $end_time = [gettimeofday()];  # Record the end time
    my $execution_time = tv_interval($start_time, $end_time) * 1000;  # Calculate execution time in milliseconds

    print "Script execution time: $execution_time ms\n";
}

fixDatToRegex($ARGV[0]);

