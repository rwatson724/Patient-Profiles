/********************************************************************************
*
* PROGRAM NAME: m_getdata_sv.sas
* AUTHORS     : Josh Horstman and Richann Watson
* DATE        : May 16, 2025
*
* PURPOSE     : Retrieve data needed for SV section of patient profiles
*
********************************************************************************/

%macro m_getdata_sv;

   %addsupp(dsn=SV)

   proc sort data=sv_supp out=sv;
	by usubjid visitnum;
	%if &subj_subset ne  %then where &subj_subset; ;
   run;

   data svfinal;
	set sv;
	by usubjid;
	if first.usubjid then _xvar=1;
	else if visit ^=: 'UNSCHEDULED' then _xvar + 1;
	if visit ^=: 'UNSCHEDULED' then xvar = _xvar;
	drop _xvar;
   run;

   %if %nrbquote(&highlight_updates) = Y %then %do;
      %m_add_update_vars(dsetin_curr = svfinal,
                         dsetin_prev = PREVPDAT.PP_DM,
                         dsetout     = svfinal,
                         keyvarlist  = USUBJID,
                         othvarlist  = );
   %end;

%mend m_getdata_sv;
