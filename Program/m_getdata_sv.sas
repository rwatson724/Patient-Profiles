/* utility macro to retrieve data needed for SV section of patient profiles */
%macro m_getdata_sv;

	proc sort data=sdtm.sv out=sv;
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
/*
   %if %nrbquote(&highlight_updates) = Y %then %do;
      %m_add_update_vars(dsetin_curr = dmfinal,
                         dsetin_prev = PREVPAT.PP_DM,
                         dsetout     = dmfinal,
                         keyvarlist  = USUBJID,
                         othvarlist  = );
   %end;
*/
%mend m_getdata_sv;
