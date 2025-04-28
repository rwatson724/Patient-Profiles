
%if %upcase(&sysuserid) = JMHOR %then %do;
	%let rootdir = C:\Users\jmhor\OneDrive\Documents\GitHub\Patient-Profiles;
%end;
%else %do;
	%let rootdir = C:\Users\gonza\OneDrive - datarichconsulting.com\Desktop\GitHub\Patient-Profiles;
%end;

libname sdtm "&rootdir.\SDTM";
libname pdata "&rootdir.\pdata";
filename ppmacros "&rootdir.\Program";
%let outpath = &rootdir.\Output;
options mautosource sasautos=(sasautos ppmacros);

%let rundate = %sysfunc(date(), date9.);
%let subj_subset = %str();                 ** specify subset of subjects to include in profiles;
%let highlight_updates = N;                ** highlight new/changed records since prior run (Y or N);

/* if highlighting of change is enabled, date of prior run to the use as a basis for comparsion is specified in COMPDATE macro variable in the INIT.SAS file */
options nomlogic nomprint nosymbolgen;
ods graphics / reset = all noborder attrpriority = none width = 6in height = 6in;

%let sectionlist = DM SV AE VS; *DM RP DC SV DS AE MH CM PR MRI ULT QS LB EG VS;
%let pageafter = AE; *SV AE MH NP QS LB EG;


/* set up format to label visits for tables and figures */

proc format;
	value vislbl
		1.0   = 'SCR1'
		2.0   = 'SCR2'
		3.0   = 'BSLN'
		3.5   = 'ECPL'
		4.0   = 'WK02'
		5.0   = 'WK04'
		6.0   = 'ECRM'
		7.0   = 'WK06'
		8.0   = 'WK08'
		8.1   = 'WK10'
		9.0   = 'WK12'
		9.1   = 'WK14'
		10.0  = 'WK16'
		10.1  = 'WK18'
		11.0  = 'WK20'
		11.1  = 'WK22'
		12.0  = 'WK24'
		13.0  = 'WK26'
		101.0 = 'AEFU'
		201.0 = 'RETR'
		501.0 = 'RAFU'
	;
	invalue visord
		'SCR1' =  1
		'SCR2' =  2  
		'BSLN' =  3 
		'ECPL' =  4
		'WK02' =  5
		'WK04' =  6
		'ECRM' =  7
		'WK06' =  8
		'WK08' =  9
		'WK10' = 10
		'WK12' = 11
		'WK14' = 12
		'WK16' = 13
		'WK18' = 14
		'WK20' = 15
		'WK22' = 16
		'WK24' = 17
		'WK26' = 18
		'AEFU' = 19
		'RETR' = 20
		'RAFU' = 21
	;
run;

/* retrieve the data for each section */
%macro get_profile_data;
   %do secnum = 1 %to %sysfunc(countw(&sectionlist));
      %let sec = %scan(&sectionlist, &secnum);
      %put === Getting Data for &sec section ===;

      %let macro_to_call = m_getdata_&sec;
      %&macro_to_call;

      /* add dummy variable to final data set for use in removing unwanted PDF bookmarks */
      data &sec.final;
         set &sec.final;
         dummy = 1;
      run;

      /* create empty shell of QC output data set for this section */
      /* PROC REPORT output will be appeneded later one subject at a time */
      data PDATA.PP_&sec;
         length USUBJID $23;
         call missing(USUBJID);
         stop;
      run;
   %end;
%mend get_profile_data;

%get_profile_data

/* define custom template to use for patient profiles */

proc template;
   define style STYLES.SMALLER;
      parent = STYLES.PRINTER;
      * reduce all sizes by 2pt;
      class fonts from fonts / 'TitleFont2'          = ("Times", 10pt, Bold Italic)
                               'TitleFont'           = ("Times", 11pt, Bold Italic)
                               'StrongFont'          = ("Times", 8pt, Bold)
                               'EmphasisFont'        = ("Times", 8pt, Italic)
                               'FixedStrongFont'     = ("Courier New, Courier", 7pt, Bold)
                               'FixedEmphasisFont'   = ("Courier New, Courier", 7pt, Italic)
                               'FixedHeadingFont'    = ("Courier New, Courier", 7pt, Bold)
                               'BatchFixedFont'      = ("SAS Monospace, Courier New, Courier", 5pt)
                               'HeadingFont'         = ("Times", 9pt, Bold)
                               'HeadingEmphasisFont' = ("Times", 9pt, Bold Italic)
                               'DocFont'             = ("Times", 8pt);
      class table from output / rules = ALL
                                cellpadding = 2pt
                                cellspacing = 0.25pt
                                borderwidth = 0.75pt;
   end;
run;

/* create patient profile master list in Excel */

/* Get last visit for each patient */
proc sort data=sdtm.sv out=sv;
	by usubjid visitnum;
run;
data lastvis;
	set sv;
	by usubjid;
	if last.usubjid;
	length visabbr $4;
	visabbr = put(visitnum,vislbl.);
run;

proc sql;
   create table profilelist as
   select a.USUBJID label = 'Unique Subject ID',
          a.SUBJID label = 'Subject ID',
          scan(a.RFXSTDTC, 1, 'T') as firstdose label='First Dose Date',
		  b.DSDECOD as subjstatus label = 'Subject Status' length = 50,
          coalescec(c.VISIT, 'No visit records') as lastvis label = 'Last Visit' length = 50,
	      c.visabbr
   from (select * from dmfinal where ACTARMCD not in ('Scrnfail','')) a
        left join
	        (select USUBJID, DSDECOD
	         from SDTM.DS
	         where DSCAT = 'DISPOSITION EVENT') b
	        on a.USUBJID = b.USUBJID     
        left join
		    lastvis c
		    on a.USUBJID = c.USUBJID;
quit;

ods listing close;
ods excel file="&outpath.\patient_profile_master_list_&rundate..xlsx"
          options (sheet_name = "Patient Profile List");

proc report data = profilelist;
	columns usubjid subjid firstdose subjstatus lastvis;
run;

ods excel close;

/* create patient profile output */

ods _all_ close;
options nodate nonumber orientation = portrait;
ods escapechar = '^';

%macro create_profile_outputs();
   proc sql noprint;
      select distinct USUBJID, SUBJID
             into
             :usubj1 - , :subj1 -
      from profilelist
      order by USUBJID;
      %let subjcount = &sqlobs;
   quit;

   %do i = 1 %to 10;*&subjcount;
      proc sql noprint;
         select coalescec(firstdose, 'No Data'),
                subjstatus, lastvis, visabbr
                into
                :firstdose, :subjstatus, :lastvis, :visabbr trimmed
          from profilelist
          where USUBJID = "&&usubj&i";
      quit;

      %put;
      %put ******************************************************;
      %put ******************************************************;
      %put **;
      %put ** Generating Patient Profile &i of &subjcount;
      %put ** USUBJID: &&usubj&i;
      %put ** SUBJID:  &&subj&i;
      %put **;
      %put ******************************************************;
      %put ******************************************************;
      %put;

      ods pdf file = "&outpath\profile_&&subj&i.._&visabbr._&rundate..pdf"
              startpage=no nogtitle nogfootnote pdftoc=1 style=STYLES.SMALLER;

      title1 j = l "Study: CDISCPILOT01"           j = r "Page ^{thispage} of ^{lastpage}";
      title2 j = l "Subject: &&usubj&i (&&subj&i)" j = r "First Dose Date: &firstdose";
      title3 j = l "Status: &subjstatus"           j = r "Current Visit: &lastvis";
      
      footnote "FULLY VALIDATED, For Internal Use Only";

      %do secnum = 1 %to %sysfunc(countw(&sectionlist));
         %let sec = %scan(&sectionlist, &secnum);
         %put === Printing Data for &sec section for Subject &&usubj&i (&&subj&i) ===;

         %if &sec = LB %then %do;
            %m_printdata_lb(labpage = 1,  labtestlist = IGF~ICGF1, grplabel = IGF-1)
            %m_printdata_lb(labpage = 2,  labtestlist = GH~SOMATRO, grplabel = Growth Hormone)
            %m_printdata_lb(labpage = 3,  labtestlist = HORMONES~T3FR HORMONES~T4FR HORMONES~TSH, grplabel = Chemistry Part 1)
            %m_printdata_lb(labpage = 4,  labtestlist = CHEMISTRY~ALB CHEMISTRY~CL CHEMISTRY~PHOS CHEMISTRY~CA, grplabel = Chemistry Ppart 2)
            ...
            %m_printdata_lb(labpage = 20, labtestlist = PREGNANCYTEST~HCG, grplabel = Pregnancy Test)
         %end;
         %else %do;
            %let macro_to_call = m_printdata_&sec;
            %&macro_to_call;
         %end;

         *insert a page break between sections only when specified;
         %if %index(&pageafter, &sec) %then ods startpage = yes;
         %else ods startpage = no;
         ;
      %end;

      ods pdf close;
   %end;

   /* set length of all character variables in all QC data sets to the length of the longest value to faciliate QC */
/*
   proc sql noprint;
      select distinct MEMNAME into :ds1 - 
      from DICTIONARY.TABLES
      where LIBNAME = 'PDATA' and MEMTYPE = 'DATA' and NOBS > 0;
      %let dscount = &sqlobs;
   quit;

   %do &dsnum = 1 %to &dscount;
      %m_minvarlen(indsn = PDATA.&&ds&dsnum)
   %end;
*/
%mend create_profile_outputs;

%create_profile_outputs;
