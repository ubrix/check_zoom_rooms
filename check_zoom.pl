#!/usr/bin/env perl

# How to get with curl:
# curl https://api.zoom.us/v1/metrics/zoomrooms --data 'api_key=yourkey&api_secret=yourseceret' | prettyjson | grep "status\|name"

use strict;
use warnings;
use utf8;
use Getopt::Std;
use JSON;
use LWP::Simple;
use LWP::UserAgent;
use HTTP::Request;
use Data::Dumper;

my $usage ='
Usage:
# ./check_zoom.pl -a -s <secret> -k <key> -u <url>

For testing using file:
# ./check_zoom.pl -f < <input-file-name>

Check zoom rooms.

    -a    Check via http
    -s    secret
    -k    key
    -u    url
    -d    debug enabled
    -f    Check using stdin
    -h    help
    -r    regex filter
    -o    ok string
    -w    warning string
    -c    critical string

';

my $secret = "";
my $key = "";

my $host = "";

my %room_hash;
my $line_counter;

my $response;
my $filter = ".*";
my $ok_string = "Available";
my $warn_string = "Offline";
my $critical_string = "Unknown";

our ($opt_a,$opt_h,$opt_d,$opt_f,$opt_u,$opt_k,$opt_s,$opt_r,$opt_o,$opt_w,$opt_c);
getopts('abdhfu:k:s:r:');

if ( $opt_h ) {
    usage();
}

if($opt_d) {
    print "Debug on\n";
}

if ($opt_r) {
    $filter = $opt_r;
}

if ($opt_o) {
    $ok_string = $opt_o;
}

if ($opt_w) {
    $warn_string = $opt_w;
}

if ($opt_c) {
    $critical_string = $opt_c;
}

my $url = "$host";
my $data = {api_key => "$key", api_secret => "$secret"};
my $urlencode = "?api_key=$key&api_secret=$secret";
if($opt_a) {
    $url = $opt_u;
    $key = $opt_k;
    $secret = $opt_s;
    print "URL: $url\n" if $opt_d;
    $response = curl_url($url,"api_key=$key&api_secret=$secret");
} elsif ($opt_f) {
    while (my $line=<STDIN>) {
        $response .= $line;
    }
} else {
    usage();
}

process_json($response);
check_all($ok_string);

sub check_all {
    my ($accepted, $warning) = @_;
    my $all_ok = 1;
    my $result = "";
    my $perfdata = "";
    my %perfdatarooms;
    my $count_available = 0;
    my $count_bad = 0;
    my $count_tot = 0;
    foreach my $key (keys %room_hash) {
        unless ( $key =~ /$filter/) {
            next;
        }
        $count_tot++;
        if ($room_hash{$key} eq $accepted) {
            $count_available++;
            $perfdatarooms{$key} = 1;
        } elsif ($room_hash{$key} eq "In Meeting") {
            $perfdatarooms{$key} = 2;
        } else {
            $all_ok = 0;
            $perfdatarooms{$key} = 0;
            $count_bad++;
        }
        $result .= "$key: $room_hash{$key}, ";
    }

    $perfdata .= "room_count=$count_tot available_count=$count_available;;;0;$count_tot";

    foreach my $key (keys %perfdatarooms) {
        $perfdata .= " '$key'=$perfdatarooms{$key};;;0;2";
    }
    $result =~ s/, $//mg;
    print "$result | $perfdata \n";
    if ($all_ok) {
        exit 0;
    } else {
        exit 1;
    }
}

sub process_json {
    my $decoded_json = JSON->new->decode( $_[0] );

    if ($opt_d) {
        print "key: $_\n" for keys %{$decoded_json};
        print "\n";
        print "\n";
    }

    foreach my $item ( @{$decoded_json->{zoom_rooms}} ) {
        my $room_name = "noname";
        my $room_status = "nostatus";

        $room_name = $item->{room_name};
        $room_status = $item->{status};

        $room_hash{$room_name}=$room_status;

        $line_counter++;
    }
}

sub print_all {
    foreach my $key (keys %room_hash) {
        printf("%s: \"%s\" \n", $key, $room_hash{$key});
    }
    my $size = keys %room_hash;
    print "Count: $line_counter; room_hash_size: $size\n";
}

sub get_url {
    my ($url, $data) = @_;
    my $ua = LWP::UserAgent->new(ssl_opts => { verify_hostname => 1 });
    my $header = ['Content-Type' => 'application/x-www-form-urlencoded'];
    my $request = HTTP::Request->new('POST', $url, $header, $data);
    my $response = $ua->request($request);

    if ($opt_d) {
    print "\n";
    print "Response: ".$response->decoded_content . "\n";
    if ($response->is_success){
        print "URL success: $url\nHeaders:\n";
        print $response->headers_as_string;
    }elsif ($response->is_error){
        print "Error:$url\n";
        print $response->error_as_HTML;
    }
    }
    return $response->decoded_content;
}

sub curl_url {
    my ($url, $data) = @_;
    my $result = `curl -s $url --data '$data'`;
    return "$result";
}

sub usage {
    print $usage;
}
