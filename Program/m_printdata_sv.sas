/********************************************************************************
*
* PROGRAM NAME: m_printdata_sv.sas
* AUTHORS     : Josh Horstman and Richann Watson
* DATE        : May 16, 2025
*
* PURPOSE     : Print the SV section of the patient profile
*
********************************************************************************/

%macro m_printdata_sv;

	ods proclabel='Subject Visits';
	proc report data=svfinal split='~' contents=''
	      style(report)=[just=left] 
	      out=work.qc_sv_&i;
		where USUBJID="&&usubj&i";
		columns dummy
		     %if %nrbquote(&highlight_updates)=Y %then newflag modcols;
		     ('Subject Visits' visit visitdy svstdtc);
		define dummy    / order noprint;
		%if %nrbquote(&highlight_updates)=Y %then %do;
			define newflag   / display noprint;
			define modcols   / display noprint;
		%end;
		define visit   / display style=[cellwidth=1.5in just=c] 'Visit';
		define visitdy / display style=[cellwidth=0.6in just=c] 'Visit Day';
		define svstdtc / display style=[cellwidth=0.8in just=c] 'Visit Date';
		break before dummy / contents='' ;  ** remove third level PDF bookmarks;
		compute svstdtc;
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
	data PDATA.PP_SV;
		set PDATA.PP_SV
			work.qc_sv_&i(
				in    = currsubj
				where = (_break_='')
				);
		if currsubj then USUBJID="&&usubj&i";
		drop dummy _break_;
	run;
   
%mend m_printdata_sv;
