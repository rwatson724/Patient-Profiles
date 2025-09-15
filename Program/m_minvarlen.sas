%*****************************************************************************;
%* Program: m_minvarlen.sas                                                  *;
%*                                                                           *;
%* Author : Joshua Horstman                                                  *;
%*                                                                           *;
%* Purpose: Minimize the lengths of the character variables in a dataset by  *;
%*          reducing each one to the length of its longest value.            *;
%*                                                                           *;
%* Parameters:                                                               *;
%*                                                                           *;
%*      INDSN     - Name of input SAS dataset (including library if needed)  *;
%*      OUTDSN    - Name of output SAS dataset (including library if needed) *;
%*      RMVFMTS   - Set to Y to remove all formats and informats from the    *;
%*                  dataset.  Otherwise, formats are added to character      *;
%*                  variables being modified corresponding to the new length *;
%*                  and all other formats are left alone (default=Y).        *;
%*                                                                           *;
%*      DEBUG     - Set to Y to add debugging information to the SAS log     *;
%*                  (default = N).                                           *;
%*                                                                           *;
%*****************************************************************************;

%macro m_minvarlen(
		indsn=,
		outdsn=,
		rmvfmts=Y,
		debug=N);

	%IF %UPCASE(&debug) = Y %THEN %DO;
		%PUT *****;
		%PUT m_minvarlen: Beginning macro execution;
		%PUT *****;
	%END;
	
	%* Local macro variables.;
	%local _i _numcharvars _lib _dsn ;

	%* If output dataset name not specified, use input dataset name;
	%IF &outdsn eq %THEN %LET outdsn = &indsn;

	%* Verify input dataset exists, then parse out library reference from actual ;
	%* dataset name.;
	%if %sysfunc(exist(&indsn)) = 0 %then %do;
		%put *****;
		%put m_minvarlen: Input dataset &indsn does not exist.  Terminating macro execution.;
		%put *****;
		%abort;
	%end;
	%else %if %index(&indsn,.) %then %do;
		%* Dataset name specified as a two-level name that includes a library reference.;
		%let _lib = %upcase(%scan(&indsn,1,.));
		%let _dsn = %upcase(%scan(&indsn,2,.));
	%end;
	%else %do;
		%* Dataset name specified as a one-level name with no library reference.;
		%let _lib = WORK;
		%let _dsn = %upcase(&indsn);
	%end;

	%* Get original value of VARLENCHK since we need to change it.;
	%let _varlenchk = %sysfunc(getoption(varlenchk));
	%IF %UPCASE(&debug) = Y %THEN %PUT Original value of VARLENCHK option: &_varlenchk;

	%*******************************************************************************;
	%* Put number of character variables into macro variable for use in control of *;
	%* subsequent logic.                                                           *;
	%*******************************************************************************;
	proc sql noprint;
		select count(*) into :_numcharvars trimmed
			from dictionary.columns
			where upcase(libname) = "&_lib" and upcase(memname) = "&_dsn" and type="char";
	quit;

	%IF %UPCASE(&debug) = Y %THEN %PUT Number of character variables found: &_numcharvars;

	%*******************************************************************************;
	%* Build length and format statements based on lengths of longest values for   *;
	%* each variable.                                                              *;
	%*******************************************************************************;

	%IF &_numcharvars ne 0 %THEN %DO;

		data _null_;
			set &indsn end=eof;
			array charvars(&_numcharvars) _character_;
			array maxlen(&_numcharvars);
			retain _all_;
			do _i = 1 to &_numcharvars;
				maxlen(_i) = max(maxlen(_i),length(charvars(_i)));
			end;
			if eof then do;
				do _i = 1 to &_numcharvars;
					%IF %UPCASE(&debug) = Y %THEN %DO;
						msg = ifc(vlength(charvars(_i))=maxlen(_i),
							catx(' ','Length for variable',vname(charvars(_i)),'is',vlength(charvars(_i)),'and cannot be reduced.'),
							catx(' ','Length for variable',vname(charvars(_i)),
						           'reduced from',vlength(charvars(_i)),'to',maxlen(_i)));
						put msg;
					%END;
					call symputx(
						cats('lenstmt',_i),
						catx(' ','length',vname(charvars(_i)),'$',maxlen(_i),';'));
					%IF %UPCASE(&rmvfmts) ne Y %THEN %DO;
						call symputx(
							cats('fmtstmt',_i),
							catx(' ','format',vname(charvars(_i)),cats('$',maxlen(_i),'.;')));
					%END;
				end;
			end;
		run;

	%END;

	%*******************************************************************************;
	%* Write output dataset, applying lengths and formats.                         *;
	%*******************************************************************************;

	* Set VARLENCHK option to NOWARN to suppress warnings about possible truncation ;
	* of character values.  We have already computed the longest value length for   ;
	* each variable and know that no truncation will occur.                         ;
	options varlenchk=NOWARN;

	data &outdsn;
		%IF &_numcharvars ne 0 %THEN %DO _i = 1 %TO &_numcharvars;
			&&lenstmt&_i
			%IF %UPCASE(&rmvfmts) ne Y %THEN
				&&fmtstmt&_i
			;
		%END;
		set &indsn;
		%IF %UPCASE(&rmvfmts) = Y %THEN %DO;
			format _all_;
			informat _all_;
		%END;
	run;

	*Set VARLENCHK option back to original value.;
	%IF %UPCASE(&debug) = Y %THEN %PUT Restoring original value of VARLENCHK option: &_varlenchk;
	options varlenchk=&_varlenchk;

	%IF %UPCASE(&debug) = Y %THEN %DO;
		%PUT *****;
		%PUT m_minvarlen: Ending macro execution;
		%PUT *****;
	%END;

%mend m_minvarlen;
