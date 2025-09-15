/********************************************************************************
*
* PROGRAM NAME: m_printdata_ae.sas
* AUTHORS     : Josh Horstman and Richann Watson
* DATE        : May 16, 2025
*
* PURPOSE     : Print the AE section of the patient profile
*
********************************************************************************/

%macro m_printdata_ae;

   /* get the number of AE records for the current subject */
   proc sql noprint;
      select count(*) into :numaerecs
      from aefinal
      where USUBJID="&&usubj&i";
   quit;

   %if &numaerecs > 0 %then %do;
      ods proclabel='Adverse Events';
      proc report data=aefinal nowindows split='~' contents=''
                  style(report)=[just=left] 
                  out=work.qc_ae_&i;
         where USUBJID="&&usubj&i";
         columns dummy AESPID
                 %if %nrbquote(&highlight_updates)=Y %then newflag modcols;
                 ('Adverse Events' _aeterm aedtc aestart aeend _aeser aedur _aesev _aerel _aeout _aeacn _aetrtem);
         define dummy    / order noprint;
         define AESPID   / order noprint;
         %if %nrbquote(&highlight_updates)=Y %then %do;
            define newflag   / display noprint;
            define modcols   / display noprint;
         %end;
         define _aeterm   / display style=[cellwidth=1.5in just=l] 'Sponsor Defined~Identifier and~Verbatim Term';
		 define aedtc     / noprint;
         define aestart   / display style=[cellwidth=0.6in just=c] 'Start~Date~(Day)';
         define aeend     / display style=[cellwidth=0.6in just=c] 'End~Date~(Day)';
         define _aeser    / display style=[cellwidth=0.4in just=c] 'Ser-~ious?';
         define aedur     / display style=[cellwidth=0.4in just=c] 'Dur-~ation~(days)';
         define _aesev    / display style=[cellwidth=0.5in just=c] 'Sever-~ity';
         define _aerel    / display style=[cellwidth=0.6in just=c] 'Relation-~ship';
         define _aeout    / display style=[cellwidth=1.0in just=c] 'Outcome';
         define _aeacn    / display style=[cellwidth=0.7in just=c] 'Action~Taken';
         define _aetrtem  / display style=[cellwidth=0.7in just=c] 'Treatment~Emergent?';
         break before dummy / contents='' ;  ** remove third level PDF bookmarks;
         compute _aetrtem;
            /* red text for adverse events that are related or serious */
            if _aerel in ('Possibly Related' 'Probably Related') or _aeser in ('Yes' '') then 
               call define(_row_, "style", "style=[color=red]");
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
      data PDATA.PP_AE;
         set PDATA.PP_AE
            work.qc_ae_&i(
				in=currsubj
                where=(_break_='')
			);
         if currsubj then USUBJID="&&usubj&i";
         drop dummy _break_;
      run;
   %end;

%mend m_printdata_ae;
