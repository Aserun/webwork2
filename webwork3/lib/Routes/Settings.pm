### Library routes
##
#  These are the routes for all library functions in the RESTful webservice
#
##

package Routes::Settings;

our $PERMISSION_ERROR = "You don't have the necessary permissions.";

use strict;
use warnings;
use Utils::CourseUtils qw/getCourseSettings/;
use Dancer ':syntax';

####
#
#  get /courses/:course_id/settings
#
#  return an array of all course settings
#
###

get '/courses/:course_id/settings' => sub {

	if(session->{permission} < 10){send_error($PERMISSION_ERROR,403)}

	return getCourseSettings;

};

####
#
#  CRUD for /courses/:course_id/settings/:setting_id
#
#  returns the setting where the var is *setting_id*
#
###

get '/courses/:course_id/settings/:setting_id' => sub {

	if(session->{permission} < 10){send_error($PERMISSION_ERROR,403)}

	my $ConfigValues = getConfigValues(vars->{ce});

	foreach my $oneConfig (@$ConfigValues) {
		foreach my $hash (@$oneConfig) {
			if (ref($hash)=~/HASH/){
				if ($hash->{var} eq params->{setting_id}){
					if($hash->{type} eq 'boolean'){
						$hash->{value} = $hash->{value} ? JSON::true : JSON::false;
					}
					return $hash;
				}
			}
		}
	}

	return {};
};

## save the setting

put '/courses/:course_id/settings/:setting_id' => sub {

	if(session->{permission} < 10){send_error($PERMISSION_ERROR,403)}

	debug "in PUT /course/:course_id/settings/:setting_id";
	debug request->params;

	my $ConfigValues = getCourseSettingsWW2();
	foreach my $oneConfig (@$ConfigValues) {
		foreach my $hash (@$oneConfig) {
			if (ref($hash)=~/HASH/){
				if ($hash->{var} eq params->{setting_id}){
					if($hash->{type} eq 'boolean'){
						$hash->{value} = params->{value} ? 1 : 0;
					} else {
						$hash->{value} = params->{value};
					}
					return writeConfigToFile(vars->{ce},$hash);
				}
			}
		}
	}

	return {};
};


# the following are used for loading settings in the WW2 way.  
# we should change the settings so they are stored as a JSON file instead.  This
# eliminate the need for these subroutines.  

sub getCourseSettingsWW2 {

	my $ConfigValues = vars->{ce}->{ConfigValues};

	# get the list of theme folders in the theme directory and remove . and ..
	my $themeDir = vars->{ce}->{webworkDirs}{themes};
	opendir(my $dh, $themeDir) || die "can't opendir $themeDir: $!";
	my $themes =[grep {!/^\.{1,2}$/} sort readdir($dh)];


	foreach my $oneConfig (@$ConfigValues) {
		foreach my $hash (@$oneConfig) {
			if (ref($hash) eq "HASH") {
				my $string = $hash->{var};
				if ($string =~ m/^\w+$/) {
					$string =~ s/^(\w+)$/\{$1\}/;
				} else {
					$string =~ s/^(\w+)/\{$1\}->/;
				}
				$hash->{value} = eval('vars->{ce}->' . $string);

				if ($hash->{var} eq 'defaultTheme'){
					$hash->{values} = $themes;	
				}
			}
		}
	}


	my $tz = DateTime::TimeZone->new( name => vars->{ce}->{siteDefaults}->{timezone}); 
	my $dt = DateTime->now();

	my @tzabbr = ("tz_abbr", $tz->short_name_for_datetime( $dt ));

	push(@$ConfigValues, \@tzabbr);

	return $ConfigValues;
}



sub writeConfigToFile {

	my ($ce,$config) = @_;

	my $filename = $ce->{courseDirs}->{root} . "/simple.conf";

	debug $config;
	debug("Write to file: " . $filename);

		my $fileoutput = "#!perl
# This file is automatically generated by WeBWorK's web-based
# configuration module.  Do not make changes directly to this
# file.  It will be overwritten the next time configuration
# changes are saved.\n\n";


	# read in the file 

	my @raw_data =();
	if (-e $filename){
		open(DAT, $filename) || die("Could not open file!");
		@raw_data=<DAT>;
		close(DAT);
	} 

	my $line;
	my $varFound = 0; 

	foreach $line (@raw_data)
	{
		chomp $line;
	 	if ($line =~ /^\$/) {
	 		my ($var,$value) = ($line =~ /^\$(.*)\s+=\s+(.*);$/);
	 		if ($var eq $config->{var}){ 
	 			$fileoutput .= writeLine($config->{var},$config->{value});
	 			$varFound = 1; 
	 		} else {
	 			$fileoutput .= writeLine($var,$value);
	 		}
		}
	}

	if (! $varFound) {
		$fileoutput .= writeLine($config->{var},$config->{value});
	}

	my $writeFileErrors;
	eval {                                                          
		local *OUTPUTFILE;
		if( open OUTPUTFILE, ">", $filename) {
			print OUTPUTFILE $fileoutput;
			close OUTPUTFILE;
		} else {
			$writeFileErrors = "I could not open $fileoutput".
				"We will not be able to make configuration changes unless the permissions are set so that the web server can write to this file.";
		}
	};  # any errors are caught in the next block

	$writeFileErrors = $@ if $@;

	if ($writeFileErrors){
		return {error=>$writeFileErrors};
	} else {
		debug $config;
		if($config->{type} eq 'boolean'){
			$config->{value} = $config->{value} ? JSON::true : JSON::false;
		}
		return $config;
	}
}

sub writeLine {
	my ($var,$value) = @_;
	my $val = (ref($value) =~/ARRAY/) ? to_json($value,{pretty=>0}): $value;
	$val = "'".$val . "'" if ($val =~ /^[a-zA-Z\s]+$/);
	#$val =~ s/'//g;
	return "\$" . $var . " = " . $val . ";\n";
}



1;
