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
      length _aeterm $200 aestart aeend $20 _aeser $3 _aesev $8 _aerel $8 _aeout $200
             _aeacn $30 _aetrtem $3;
      _aeterm   = catx(': ', AESPID, AETERM);
      aestart   = catx(' ', AESTDTC, ifc(AESTDY, cats('(', AESTDY, ')'), ''));
      aeend     = catx(' ', AEENDTC, ifc(AEENDY, cats('(', AEENDY, ')'), ''));
      _aeser    = put(AESER, $yn.);
      _aesev    = propcase(AESEV);
      _aerel    = propcase(AEREL);
      _aeout    = propcase(AEOUT);
      _aeacn    = propcase(AEACN);
      _aetrtem  = put(AETRTEM, $yn.);
      if not nmiss(AESTDY, AEENDY) then aedur = AEENDY - AESTDY + 1;
   run;

   %if %nrbquote(&highlight_updates) = Y %then %do;
      %m_add_update_vars(dsetin_curr = aefinal,
                         dsetin_prev = PREVPDAT.PP_AE,
                         dsetout     = aefinal,
                         keyvarlist  = USUBJID _aeterm,
                         othvarlist  = aestart aeend _aeser aedur _aesev _aerel _aeout _aeacn _aetrtem);
   %end;

%mend m_getdata_ae;
