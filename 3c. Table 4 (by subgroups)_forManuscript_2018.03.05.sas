libname x 'F:\power\HRS\DerivedData\AD_Disparities_AlgorithmDev\Data 2018_0105'; /*derived hrs files*/
libname rand 'F:\power\HRS\RAND_HRS\sasdata';
options fmtsearch = (rand.formats);

/*********************************************************************************************
* Edited 2018.04.16 on github
*
***********************************************************************************************/
*set date for output label;
%let dt=2018_0416;
%let pdt=2018_0302;

*pull datasets from drive & create self-response dummy;
data HRSt; set x.HRSt_&pdt; 
	if proxy=0 then selfresp = 1;
	else if proxy = 1 then selfresp = 0;
run;
data HRSv; set x.HRSv_&pdt; 
	if proxy=0 then selfresp = 1;
	else if proxy = 1 then selfresp = 0;
run;

*create a macro to automatically spit out sensitivity, specificity, and mean accuracy for each algorithm. ;
%macro confusion_subs(test, data, sub, val);

proc sort data=&data; by &sub; run;

proc freq data=&data noprint; 
where &sub=&val;
tables &test*dement/out=looksee outpct;
run;

data row00; set looksee;
if &test=0 and dement=0 then do;
	spec=pct_col;
	npv=pct_row;
	acc00=percent;
	end;
algorithm = "&test";
sub = "&sub";
val = &val;
run;

data row00; set row00;
if &test=0 and dement=0;
keep algorithm spec npv acc00;
run;

data row11; set looksee;
if &test=1 and dement=1 then do;
	sens=pct_col;
	ppv=pct_row;
	acc11=percent;
	end;
algorithm = "&test";
sub = "&sub";
val = &val;
run;

data row11; set row11;
if &test=1 and dement=1;
keep algorithm sens ppv acc11;
run;

data &test._&sub._&data; merge row11 row00; by algorithm; 
acc=acc00+acc11;
run;

/*drop unnecessary vars; rearrange; rename for merging*/
data &test._&sub._&data (keep = algorithm sens spec acc); 
retain algorithm sens spec acc;
set &test._&sub._&data;
run;

data &test._&sub._&data._long; set &test._&sub._&data; run;

data &test._&sub._&data; set &test._&sub._&data;
rename sens= sens_&sub&val;
rename spec = spec_&sub&val;
rename acc = acc_&sub&val;
run;

/*proc print data=row00; run;*/
/*proc print data=row11; run;*/
/*proc print data=perf_&test; run;*/
/*proc print data=&test._&sub._&data; run;*/
%mend;

%macro loop_sub (data, sub, val);
%confusion_subs(hw_dem, &data, &sub, &val);
%confusion_subs(lkw_dem, &data, &sub, &val);
%confusion_subs(hurd_dem, &data, &sub, &val);
%confusion_subs(wu_dem, &data, &sub, &val);
%confusion_subs(crim_dem, &data, &sub, &val);
%confusion_subs()

data table_&data._&sub._&val; length algorithm $20;
set hw_dem_&sub._&data
	lkw_dem_&sub._&data
	hurd_dem_&sub._&data
	wu_dem_&sub._&data
	crim_dem_&sub._&data;

	if algorithm = "hw_dem" then algorithm = "1. hw_dem";
	if algorithm = "lkw_dem" then algorithm = "2. lkw_dem";
	if algorithm = "crim_dem" then algorithm = "3. crim_dem";
	if algorithm = "hurd_dem" then algorithm = "4. hurd_dem";
	if algorithm = "wu_dem" then algorithm = "5. wu_dem";
	proc sort; by algorithm;
run;

/*create long version*/
data table_&data._&sub._&val._long; length algorithm $20;
set hw_dem_&sub._&data._long
	lkw_dem_&sub._&data._long
	hurd_dem_&sub._&data._long
	wu_dem_&sub._&data._long
	crim_dem_&sub._&data._long;
run;

proc transpose data=table_&data._&sub._&val._long out = table_&data._&sub._&val._long name=metric;
ID algorithm;
var sens spec acc;
run;

%macro ext(alg, alg2);
	data &alg._l; set table_&data._&sub._&val._long (keep = Metric &alg);
		algorithm="&alg2";
		label metric = "metric";
		rename &alg = performance;
		
		subgroup = "&sub";

	run;
%mend;
%ext(hw_dem, H-W) %ext(lkw_dem, L-K-W) %ext(crim_dem, Crimmins) %ext(hurd_dem, Hurd) %ext(wu_dem, Wu)

data table_&data._&sub._&val._long;
	retain algorithm subgroup metric performance;
	length algorithm $10;
	set hw_dem_l lkw_dem_l crim_dem_l hurd_dem_l wu_dem_l;
run;
%mend;

/*output confusion tables*/
ods listing close; 
ods html file = "F:\power\HRS\Projects\Ad_Disparities_AlgorithmDev\SAS Outputs\Manuscript tables\T4_AlgorithmBySociodmSubgroup_HRSt_HRSv_&dt..xls";
%macro out(dataset, d);
/*race/ethnicity*/
TITLE "HRS/ADAMS &dataset dataset, race/ethnicity frequencies";
proc freq data=HRS&d;
tables raceeth4;
run;

/*delete race/ethnic*/

TITLE "Confusion matrix for HRS/ADAMS training data, by race/ethnicity";
proc print data=table_HRS&d; run;

data table_HRS&d._long;
	set table_HRS&d._NH_white_1_long table_HRS&d._NH_black_1_long table_HRS&d._Hispanic_1_long;
run;

TITLE "Confusion matrix for HRS/ADAMS training data, by race/ethnicity - long";
proc print data=table_HRS&d._long; run;

/*education*/
TITLE "HRS/ADAMS &dataset dataset, education frequencies";
proc freq data=HRS&d;
tables ltHS geHS;
run;

%loop_sub (HRS&d, ltHS, 1);
%loop_sub (HRS&d, geHS, 1);

data table_HRS&d; 
	merge table_HRS&d._ltHS_1 table_HRS&d._geHS_1;
	by algorithm;
run;

TITLE "Confusion matrix for HRS/ADAMS training data, by education";
proc print data=table_HRS&d; run;

data table_HRS&d._long;
	set table_HRS&d._ltHS_1_long table_HRS&d._geHS_1_long ;
run;

TITLE "Confusion matrix for HRS/ADAMS training data, by education - long";
proc print data=table_HRS&d._long; run;

/*age*/
TITLE "HRS/ADAMS &dataset dataset, age frequencies";
proc freq data=HRS&d;
tables lt80 ge80;
run;

%loop_sub (HRS&d, lt80, 1);
%loop_sub (HRS&d, ge80, 1);

data table_HRS&d; 
	merge table_HRS&d._lt80_1 table_HRS&d._ge80_1;
	by algorithm;
run;

TITLE "Confusion matrix for HRS/ADAMS training data, by age";
proc print data=table_HRS&d; run;

data table_HRS&d._long;
	set table_HRS&d._lt80_1_long table_HRS&d._ge80_1_long ;
run;

TITLE "Confusion matrix for HRS/ADAMS training data, by age - long";
proc print data=table_HRS&d._long; run;

/*gender*/
TITLE "HRS/ADAMS &dataset dataset, gender frequencies";
proc freq data=HRS&d;
tables male female;
run;

%loop_sub (HRS&d, male, 1);
%loop_sub (HRS&d, female, 1);

data table_HRS&d; 
	merge table_HRS&d._male_1 table_HRS&d._female_1;
	by algorithm;
run;

TITLE "Confusion matrix for HRS/ADAMS training data, by gender";
proc print data=table_HRS&d; run;

data table_HRS&d._long;
	set table_HRS&d._male_1_long table_HRS&d._female_1_long ;
run;

TITLE "Confusion matrix for HRS/ADAMS training data, by gender - long";
proc print data=table_HRS&d._long; run;

/*proxy*/
TITLE "HRS/ADAMS &dataset dataset, proxy frequencies";
proc freq data=HRS&d;
tables proxy;
run;

%loop_sub (HRS&d, selfresp, 1);
%loop_sub (HRS&d, proxy, 1);

data table_HRS&d; 
	merge table_HRS&d._selfresp_1 table_HRS&d._proxy_1;
	by algorithm;
run;

/* TITLE "Confusion matrix for HRS/ADAMS training data, by proxy";
proc print data=table_HRS&d; run;
data table_HRS&d._long;
	set table_HRS&d._selfresp_1_long table_HRS&d._proxy_1_long ;
run;

TITLE "Confusion matrix for HRS/ADAMS training data, by proxy - long";
proc print data=table_HRS&d._long; run;
%mend;
%out(training, t) %out(validation, v)
 */
ods html close;
