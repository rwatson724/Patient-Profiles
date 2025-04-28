/* utility macro to retrieve data needed for VS section of patient profiles */
%macro m_getdata_vs;
   proc sql;
      create table vsmerge as
      select a.*
      from SDTM.VS a,
           SDTM.DM b
      where a.USUBJID = b.USUBJID and not missing(a.VISITNUM)
      order by a.USUBJID, a.VSTESTCD, a.VSTEST, a.VISITNUM, a.VSDTC, a.VSSEQ;
   quit;

   data vsfinal;
      set vsmerge;
      %if &subj_subset ne  %then where &subj_subset; ;
      by USUBJID VSTESTCD VSTEST VISITNUM;
      if last.VISITNUM;
      length vislbl $6;
	  if visit =: 'UNSCHEDULED' then vislbl = cats('UN',translate(scan(visit,2,' '),'_','.'));
      else vislbl = put(VISITNUM, vislbl.);
   run;
%mend m_getdata_vs;
