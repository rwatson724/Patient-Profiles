/* utility to print the DM section of the patient profile */
%macro m_printdata_dm;

	ods proclabel='Demographics';
	proc report data=dmfinal split='~' contents=''
	      style(report)=[just=left] 
	      out=work.qc_dm_&i;
		where USUBJID="&&usubj&i";
		columns dummy
		     %if %nrbquote(&highlight_updates)=Y %then newflag modcols;
		     ('Demographics' country age sex race ethnic arm actarm);
		define dummy    / order noprint;
		%if %nrbquote(&highlight_updates)=Y %then %do;
			define newflag   / display noprint;
			define modcols   / display noprint;
		%end;
		define country / display style=[cellwidth=0.6in just=c] 'Country';
		define age     / display style=[cellwidth=0.6in just=c] 'Age (y)';
		define sex     / display style=[cellwidth=0.6in just=c] 'Sex';
		define race    / display style=[cellwidth=0.6in just=c] 'Race';
		define ethnic  / display style=[cellwidth=1.5in just=c] 'Ethnicity';
		define arm     / display style=[cellwidth=1.5in just=c] 'Planned Arm';
		define actarm  / display style=[cellwidth=1.5in just=c] 'Actual Arm';
		break before dummy / contents='' ;  ** remove third level PDF bookmarks;
		compute actarm;
		%if %nrbquote(&highlight_updates)=Y %then %do;
		   /* light orange background for records added since previous run */
		   if newflag=1 then call define(_row_, "style", "style=[background=verylightorange]");
		   /* light yellow background for values changed since prvious run */
		   do i=1 to countw(modcols);
		      call define(scan(modcols, i), "style", "style=[background=lightyellow]");
		   end;
		%end;
		endcomp;
	run;

	/* append PROC REPORT output data set to QC data set */
	data PDATA.PP_DM;
		set PDATA.PP_DM
			work.qc_dm_&i(
				in    = currsubj
				where = (_break_='')
				);
		if currsubj then USUBJID="&&usubj&i";
		drop dummy _break_;
	run;
   
%mend m_printdata_dm;
