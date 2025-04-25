libname sdtm "C:\Users\gonza\OneDrive - datarichconsulting.com\Desktop\GitHub\Patient-Profiles\SDTM";


%let rundate = %sysfunc(date(), date9.);
%let subj_subset = %str();                 ** specify subset of subjects to include in profiles;
%let highlight_updates = N;                ** highlight new/changed records since prior run (Y or N);

8/* if highlighting of change is enabled, date of prior run to the use as a basis for comparsion is specified in COMPDATE macro variable in the INIT.SAS file */
options nomlogic nomprint nosymbolgen;
ods graphics / reset = all noborder attrpriority = none width = 6in heigh = 6in;

%let sectionlist = DM RP DC SV DS AE MH CM PR MRI ULT QS LB EG VS;
%let pageafter = SV AE MH NP QS LB EG;


/* set up format to label visits for tables and figures */
proc sql;
   create table vislblfmt as
   select distinct 'VISLBL' as fmtname,
                   'N' as type,
                   SV.VISITNUM as start,
                   case 
                      when SV.VISITNUM < 9 then cats('S', SV.VISITNUM)
                      when SV.VISITNUM = 109 then 'ET'
                      when int(SV.VISITNUM) = SV.VISITNUM then cats(first(scan(TV.VISIT, 1)), scan(TV.VISIT, 2))
                      else cats(first(scan(TV.VISIT, 1)), scan(TV.VISIT, 2), substr(put(SV.VISITNUM, best.), index(put(SV.VISITNUM, best.), '.')))
                   end as label
   from SDTM.SV
        left join
        SDTM.TV
   on int(SV.VISITNUM) = TV.VISITNUM
   order by SV.VISITNUM;
quit;

proc fomrat cntlin = vislblfmt;
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
      /* reduce all sizes by 2pt */
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
/* Algorithm to derive subject status          */
/* ADD LATER */
proc sql;
   create table profilelist as
   select a.USUBJID label = 'Unique Subject ID',
          a.SUBJID label = 'Subject ID',
          scan(a.RFICDTC, 1, 'T') as icfdate,
          scan(a.RFXSTDTC, 1, 'T') as firstdose,
          case
             when not missing(b.etdate)   then cats('Early Termination (', b.ETDATE, ')')
             when not missing(c.oledate)  then 'On Treatment - OLE'
             when not missing(d.rescdate) then 'On Treatment - Rescue'
             when not missing(a.RFXSTDTC) then 'On Treatment - RC'
             else 'In Screening'
          end as subjstatus label = 'Subject Status' length = 50,
          coalescec(e.VISIT, 'No visit records') as lastvis label = 'Last Visit' length = 50,
          e.VISABBR,
          f.ASDCOMP
   from (select * from dmfinal where ACTARMCD ne '') a
        left join
        (select USUBJID, DSSTDTC as etdate 
         from SDTM.DS
         where DSSCAT = 'EARLY TERMINATION') b
        on a.USUBJID = b.USUBJID

        left join
        (select USUBJID, DSSTDTC as oledate
         from SDTM.DS
         where DSSCAT = 'ENTERED OPEN-LABEL EXTENSION PHASE') c
        on a.USUBJID = c.USUBJID

        left join
        (select USUBJID, min(CMSTDTC) as rescdate
         from cmfinal
         where upcase(CMTYPE) = 'RESCUE'
         group by USUBJID) d
        on a.USUBJID = d.USUBJID
        
        left join
        lastvis e
        on a.USUBJD = e.USUBJID

        left join
        asdcomp f
        on a.USUBJID = f.USUBJID
        order by a.USUBJIJD, a.SUBJID;
quit;

ods listing close;
ods excel file "&path\patient_profile_master_list_&rundate..xlsx"
          options (sheet_name = "Patient Profile List");

proc report data = profilelist;
 /*** missing rest of code ***/
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
      %let subjcount = $sqlobs;
   quit;

   %do i = 1 %to &subjcount;
      proc sql noprint;
         select coalescec(icfcate, 'No Data'), 
                coalescec(firstdose, 'No Data'),
                subjstatus, lastvis, visabbr
                into
                :icfdate, :firstdose, :subjstatus, :lastvis, :visabbr trimmed
          from profilelist
          where USUBJID = "&&usubj&i";

          select count(*) into :oleflag
          from SDTM.DS
          where DSSCAT = 'OPEN LABEL EXTENSION PHASE' and DSDECOD = 'ENTERED INTO TRIAL' and USUBJID = "&&usubj&i";
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

      ods pdf file = "&path\profile_&&subj&i.._&visabbr._&rundate..pdf"
              startpage = no nogtitle nogfootnote pdftoc = 1 style = STYLES.SMALLEr;

      title1 j = l "Study: XXXX"                   j = r "Page ^{thispage} of ^{lastpage}";
      title2 j = l "Subject: &&usubj&i (&&subj&i)" j = r "ASD Compliance: No Data";
      title3 j = l "ICF DAte: &icfdate"            j = r "First Dose Date: &firstdose";
      title4 j = l "Current Visit: &lastvis"       j = r "Status: &subjstat";
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

         /* insert a page break between sections only when specified */
         %if %index(&pageafter, &sec) %then ods startpage = yes;
         else ods startpage = no;
         ;
      %end;

      ods pdf close;
   %end;

   /* set length of all character variables in all QC data sets to the length of the longest value to faciliate QC */
   proc sql noprint;
      select distinct MEMNAME into :ds1 - 
      from DICTIONARY.TABLES
      where LIBNAME = 'PDATA' and MEMTYPE = 'DATA' and NOBS > 0;
      %let dscount = &sqlobs;
   quit;

   %do &dsnum = 1 %to &dscount;
      %m_minvarlen(indsn = PDATA.&&ds&dsnum)
   %end;
%mend create_profile_outputs;