%if %upcase(&sysuserid) = JMHOR %then %do;
	%let rootdir = C:\Users\jmhor\OneDrive\Documents\GitHub\Patient-Profiles;
%end;
%else %do;
	%let rootdir = C:\Users\gonza\OneDrive - datarichconsulting.com\Desktop\GitHub\Patient-Profiles;
%end;

libname sdtm "&rootdir.\SDTM";
libname pdata "&rootdir.\pdata";
libname prevpat "&rootdir.\pdataold";

data prevpat.pp_ae;
	set pdata.pp_ae;
	_rand = ranuni(0);
	if _rand < 0.2 then delete;
	else if _rand < 0.5 and _aesev='Moderate' then _aesev='Mild';
	else if _rand < 0.5 and _aerel='Probable' then _aerel='Possible';
run;

data prevpat.pp_dm;
	set pdata.pp_dm;
run;

data prevpat.pp_sv;
	set pdata.pp_sv;
run;

data prevpat.pp_vs;
	set pdata.pp_vs;
run;
