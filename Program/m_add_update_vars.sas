%macro m_add_update_vars(
	dsetin_curr=,
	dsetin_prev=,
	dsetout=,
	keyvarlist=,
	othvarlist=
);

%local _prefix _i;
%let _prefix = _m_add_update_vars;

proc sort data=&dsetin_prev out=&_prefix._prev;
	by &keyvarlist;
run;

proc sort data=&dsetin_curr out=&_prefix._curr;
	by &keyvarlist;
run;

data &dsetout;
	merge &_prefix._curr ( in = incurr)
	      &_prefix._prev ( in = inprev
			keep = &keyvarlist &othvarlist
			rename = ( 
				%do _i=1 %to %sysfunc(countw(&othvarlist,%str( )));
					%scan(&othvarlist,&_i) = _%scan(&othvarlist,&_i)
				%end;
			));
	by &keyvarlist;
	if incurr;
	length modcols $200;
	call missing(modcols);
	if not(inprev) then newflag=1;
	else do;
		%do _i=1 %to %sysfunc(countw(&othvarlist,%str( )));
			if %scan(&othvarlist,&_i) ne _%scan(&othvarlist,&_i) then modcols = catx(' ',modcols,"%upcase(%scan(&othvarlist,&_i))");
		%end;
	end;
	drop %do _i=1 %to %sysfunc(countw(&othvarlist,%str( ))); _%scan(&othvarlist,&_i) %end;;
run;

%mend m_add_update_vars;
