/* utility macro to retrieve data needed for AE section of patient profiles */
%macro m_getdata_ae;
   proc format;
      value $yn
         'Y' = 'Yes'
         'N' = 'No';
   run;

   %supp2par_v1(inlib = SDTM, parent = AE, supp = SUPPAE, outname = aemerge)

   data aefinal;
      set aemerge;
      %if &subj_subset ne  %then where &subj_subset; ;
      length _aeterm $200 aestart aeend $20 _aeser $3 _aesev $8 _aerel $18 _aeout $32
             _aeacn $16 _aecontrt _sympacro _aedis $3;
      _aeterm   = catx(': ', AESPID, AETERM);
      aestart   = catx(' ', AESTDTC, ifc(AESTDY, cats('(', AESTDTY, ')'), ''));
      aeend     = catx(' ', AEENDTC, ifc(AEENDY, cats('(', AEENDTY, ')'), ''));
      _aeser    = put(AESER, $yn.);
      _aesev    = propocase(AESESV);
      _aerel    = propcase(AEREL);
      _aeout    = propcase(AEOUT);
      _aeacn    = propcase(AEACN);
      _aecontrt = put(AECONTRT, $yn.);
      _sympacro = put(ACROSYMP, $yn.);
      _aedis    = ifc(index(upcase(AEACNOTH), 'STUDY DISCONTINUE'), 'Yes', 'No');
      if not missing(AESTDY, AEENDY) then aedur = AEENDY - AESTDY + 1;
   run;

   %if %nrbquote(&highlight_updates) = Y %then %do;
      %m_add_update_vars(dsetin_curr = aefinal,
                         dsetin_prev = PREVPAT.PP_AE,
                         dsetout     = aefinal,
                         keyvarlist  = USUBJID _aeterm,
                         othvarlist  = aestart aeend _aeser aedur _aesev _aerel _aeacn _aecontr _aedis _sympacro);
   %end;
%mend m_getdata_ae;