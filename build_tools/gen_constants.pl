#!/usr/bin/perl

use strict;
use warnings;

open E, "< enums.decl" or die "unable to open enums.h";
open O, "> enums.h" or die "unable to open enums.c";

my %enum;
my %tag;
my @s;
my $c;
my $last = 0;
while(<E>) {
    s|/\*.*/||;
    s|^\s\* .*||;
    s|^.*\*/||;
    if (my ($name, $tag) = /^enum\s*(\w+)\s*(?:=>\s*(\w+))?/) {
        $last = 0;
	# $name =~ s/^ldap_//;
	$c = $enum{$name} = [];
        $tag{$name} = $tag;
    }
    elsif (/^\s*((?:P[QG]|CONN)\w+)\s*=\s*(\d+),/) {
        $c->[$2] = $1;

        $last = $2 + 1;
    }
    elsif (/^\s*((?:P[QG]|CONN)\w+)\s*,/) {
        $c->[$last++] = $1;
    }
    elsif (m|^\s*s/(\w+)/(\w*)/|) {
        push @s, [$1, $2];
    }
}

@s = sort { length($b->[0]) <=> length($a->[0]) } @s;
# use Data::Dumper; print Dumper \@s;

print O <<HEAD;
/*
 *
 * This file is generated by gen_constants.pl
 * Do not edit by hand!
 *
 */

HEAD

for my $enum (sort keys %enum) {
    my $len = @{$enum{$enum}};
    print O "SV *enum2sv_${enum}[$len];\n";
}

# print O <<DECL for @c;
# SV *${_}_sv;
# DECL

print O <<INIT;

static void
init_constants(void) {
INIT

for my $enum (sort keys %enum) {
    my $c = $enum{$enum};
    my $tag = $tag{$enum};

    if (defined $tag and length $tag) {
        $tag = qq("$tag");
    }
    else {
        $tag = 'NULL';
    }


    for my $ix (0..$#$c) {
	my $name = $c->[$ix];
	my $value;
	if (defined $name) {
	    $value = $name;
            unless (defined $c->[0]) {
                $c->[0] = "$value - $ix"
            }
	}
	else {
	    $name = uc "${enum}_$ix";
	    $value = $ix;
	}

        for my $s (@s) {
            my ($f, $t) = @$s;
            $name =~ s/^$f/$t/;
        }

	printf O <<C, $ix, $name, length($name), $value, $tag;
    enum2sv_${enum}[%d] = make_constant("%s", %d, %s, %s);
C

    }
    print O "\n";
}

print O <<END;
}
END

for my $enum (sort keys %enum) {
    my $len = @{$enum{$enum}};
    print O <<ETS;
static SV *
${enum}2sv(I32 ix) {
    SV *sv;
    ix -= $enum{$enum}[0];
    if ((ix < 0) || (ix >= $len)) {
        return newSViv(ix);
    }
    sv = newSVsv(enum2sv_${enum}[ix]);
    return sv;
}

ETS
}