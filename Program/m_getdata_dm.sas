/* utility macro to retrieve data needed for DM section of patient profiles */
%macro m_getdata_dm;

   data dmfinal;
      set sdtm.dm;
      %if &subj_subset ne  %then where &subj_subset; ;
   run;

   %if %nrbquote(&highlight_updates) = Y %then %do;
      %m_add_update_vars(dsetin_curr = dmfinal,
                         dsetin_prev = PREVPDAT.PP_DM,
                         dsetout     = dmfinal,
                         keyvarlist  = USUBJID,
                         othvarlist  = );
   %end;

%mend m_getdata_dm;
