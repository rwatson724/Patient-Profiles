/* utility to print the AE section of the patient profile */
%macro m_printdata_vs;
   %local vitalvislist numvitalsvisits vitalsvisnum xmin xmax blk3lbl;

   %let blk3lbl = %sysfunc(ifc(&oleflag, OLE, Follow-Up));

   /* create a subject-specific visit format for figure x-axis labels */
   proc sql;
      create table vsfigfmt as
      select distinct xvar as start,
                      put(VISITNUM, vislbl.) as label,
                      case when VISITNUM < 9 then 'Screening'
                           when VISITNUM >= 20 then "&blk3lbl"
                           else 'Treatment'
                      end as blocklbl,
                      'XVARFMT' as fmtname
      from svfinal
      where VISITNUM = int(VISITNUM) and USUBJID = "&&usubj&i";
   quit;

   proc format cntlin = vsfigfmt; run;

   /* create a format to label vital signs */
   proc sql;
      create table vsfmtin as
      select distinct VSTESTCD as start,
                      catx(' ', tranwrd(VSTEST, 'Blood Pressure', 'BP'), cats('(', VSSTRESU, ')')) as label,
                      'VSFMT' as fmtname,
                      'C' as type
      from vsfinal
      where not missing(VSSTRESU);
   quit;

   proc formt cntlin = vsfmtin; run;

   /* create a distinct attribute map data set for block coloring */
   data vsattrmap;
      length id $11 value $9;
      id = 'blockcolors';
      do i = 1 to 3;
         value = choosec(i, 'Screening', 'Treatment', "&blk3lbl");
         fillcolor = choosec(i, 'CXe7E8C6', 'CXEBEFF7', 'CXF7DFDB');
         output;
      end;
   run;

   /* subset data for current subject */
   data vssubset;
      set vsfinal end = eof;
      where USUBJID = "&&usubj&i" and 
            VSTESTCD in ('DIABP' 'SYSBP' 'HR' 'RESP' 'TEMP' 'WEIGHT') and
            not nmiss(VSSTRESN, VISITNUM);

      /* round all vital results for display */
      VSSTRESN = round(VSSTRESN, 0.1);

      /* derive block labels */
      length blocklbl $9;
      if VISITNUM < 9 then blocklbl = 'Screening';
      else if VISITNUM >= 20 then blocklbl = "&blk3lbl";
      else blocklbl = 'Treatment';
   run;

   /* get number of records for current subject */
   proc sql noprint;
      select count(*) into :numvsrecs
      from vssubset;
   quit;

   %if &numvsrecs > 0 %then %do;
      proc sort data = vssubset;
          by dummy VSTESTCD VSSTEST;
      run;

      proc transpose data = vssubset
                     out = vstrans (drop = _:);
         by dummy VSTESTCD;
         var VSSTRESN;
         id vislbl;
      run;

      /* get list of all visits for the current subject */
      proc sql noprint;
         select distinct NAME,
                         whichc(first(NAME), 'S', 'D', 'W', 'E') as sort1,
                         ifn(index(NAME, '_'), 1, 0) as sort2,
                         input(substr(NAME, anydigit(NAME)), best.) as sort3
                         into
                         :vitalsvislist separated by ' ',
                         :dumm1, :dummy2, :dummy3
         from DICTIONARY.COLUMNS
         where LIBNAME = 'WORK' and MEMNAME = 'VSTRANS' and 
               (NAME like 'S%' or NAME like 'W%' or NAME like '01%' or NAME = 'ET')
         order by sort1, sort2, sort3;
         %let numvitalsvisits = &sqlobs;
      quit;

      %if nrbquote(&highlight_upates) = Y %then %do;
         data vsprev;
            set PREVDAT.PP_VS;
            where USUBJID = "&&usubj&i";
            drop USUBJID;
         run;

         %m_add_update_vars(dsetin_curr = vstrans,
                            dsetin_prev = vsprev,
                            dsetout     = vstrans,
                            keyvarlist  = VSTESTCD,
                            othvarlist  = &vitalsvislist);
      %end;

      /* produce the table */
      ods proclabel = 'Vital Signs Table';
      proc report data = vstrans nowindows split = '~' contents = ''
                  style(report) = [just = left] 
                  out = work.qc_vs_&i;
         columns dummy ('Vital Signs' VSTESTCD
                        %if nrbquote(&highlight_upates) = Y %then newflag modcols;
                        &vitalvislist);
         define dummy    / order noprint;
         define VSTESTCD / display 'Vital Sign Parameter' format = $vsfmt. style = [cellwidth = 1.5in just = c];
         %if nrbquote(&highlight_upates) = Y %then %do;
            define newflag   / display noprint;
            define modcols   / display noprint;
         %end;
         %do vitalsvisnum = 1 %to &numvitalsvisits;
            define %scan(&vitalsvislist, &vitalsvisnum) / display "%sysfunc(translate(%scan(&vitalsvislist, &vitalsvisnum), ., _))"
                   %if &numvitalsvisits < 5 %then style = [cellwidth = 1.0in just = c];
                   %else %if &numvitalsvisits < 10 %then style = [cellwidth = 0.7in just = c];
                   %else style = [cellwidth = 0.5in just = c];
                   ;
         %end;
         break before dummy / contents = '' ;  ** remove third level PDF bookmarks;
         %if %nrbquote(&highlight_updates) = Y %then %do;
            compute %scan(&vitalsvislist, &numvitalsvisits);
               /* light orange background for records added since previous run */
               if newflag = 1 then call define(_row_, "style", "style = [background = verylightorange]");
               /* light yellow background for values changed since prvious run */
               do i = 1 to countw(modcols);
                  call define(scan(modcols, i), "style", "style = [background = lightyellow]");
               end;
            endcomp;
         %end;
      run;

      ods startpage = no;

      /* get minimum and maximum x values for current subject */
      proc sql noprint;
         select min(xvar), max(xvar)
                into
                :xmin, :xmax
         from svfinal
         where VISITNUM = int(VISITNUM) and USUBJID = "&&usubj&i";
      quit;

      /* reduce subjest to only scheduled visits for figures and merge in derived x variable */
      proc sql;
         create table vssubset2 as
         select a.*, b.*xvar
         from (select * from vssubset 
               where VISITNUM = int(VISITNUM)) a
              left join
              svfinal b
              on a.USUBJID = b.USUBJID and a.VISITNUM = b.VISITNUM
              order by a.VSTESTCD, b.xvar;
      quit;

      /* add records to ensure proper rendering of blocks across all visits */
      proc sql;
         create table blockrecs as
         select * 
         from (select distinct VSTESTCD, VSTEST
               from vssubset2) a,
              (select start as xvar, blocklbl from vsfigfmt) b
      quit;

      data vsfigure;
         set vssubset2 blockrecs;
      run;

      proc sort dta = vsfigure;
         by VSTESTCD xvar;
      run;

      ods proclabel = 'Vital Signs Figure';
      proc sgpanel noautolegend data = vsfigure dattrmap = vsattrmap;
         format xvar xvarfmt. VSTESTCD vsfmt.;
         panelby VSTESTCD / onepanel uniscale = column novarname layout = rowlattice headattrs = (size = 8pt);
         block x = xvar block = blocklbl / extendmissing attrid = blockcolors valueattrs = (size = 7pt);
         series x = xvar y = VSSTRESN / markers
                                        markerattrs = (symbol = circlefilled color = black size = 8px)
                                        lineattrs = (pattern = solid color = black thickness = 1px);
         rowaxis display = (nolabel) thresholdmax = 1 thresholdmin = 1 offsetmax = 0.1;
         colaxi label = 'Visit' values = (&xmin to &xmax by 1) fitpolicy = staggerthin;
      run;

      /* append PROC REPORT output data set to QC data set */
      data PDATA.PP_VS;
         set PDATA.PP_VS
             work.qc_ae_&i (in = currsubj
                            where = (_break_ = ''));
         length REPORTCOLS $200;
         if currsubj then do;
            USUBJID = "&&usubj&i";
            REPORTCOLS = "&vitalsvislist";
         end;
         drop dummy _break_;
      run;
   %end;
%mend m_printdata_vs;