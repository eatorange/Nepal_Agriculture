/*****************************************************************
PROJECT: 	NEPAL AGRICULTURE - ICIMOD
PURPOSE: 	CREATING EDGE LIST TO STORE NETWORK INFORMATION 
			
AUTHORS: 	SAMPADA KC (YALE)
			DEREK WOLFSON (IPA)
			
NOTES: 		
*******************************************************************/
clear all
set more off
	*USER SPECIFIC LOG + DATA LOAD*
	if "`c(username)'"=="sampadakc"{
	local GITHUBDIR "/Users/sampadakc/Documents/GITHub/Nepal_Agriculture"
	local DB "/Users/sampadakc/Dropbox"
	}
	
	if "`c(username)'"=="dwolfson"{
	local GITHUBDIR "Y:/Nepal_Agriculture"
	local DB X:	
	}
	
	local DATA "`DB'/Agriculture Extension Worker Project/Analysis/data/SN_data.dta"
	use "`DATA'", clear
	
	local DATAOUT "`DB'/Agriculture Extension Worker Project/Analysis/data"
	local RESULTS "`DB'/Agriculture Extension Worker Project/Analysis/output"


*************************************************
*  DATA ANALYSIS CREATING AN EDGE LIST	*
*************************************************

foreach VAR in m01 m10Y{
	levelsof ward_id,local(WARDS)
	foreach WID of local WARDS{
		
		use "`DATA'", clear
		keep if ward_id == `WID'
		duplicates drop hhid, force
		sort hhid
		keep ward_id hhid
		tempfile temp_head
		save "`temp_head'"
			
		
	*OUTDEGREE*
		di "OUTDEGREE - `WID'"
		use "`DATA'", clear
		//CREATE OUTDEGREE DENOMINATOR
		keep if ward_id ==`WID'
		drop if SN_hhid==.
		drop if SN_hhid == hhid // REMOVING PARALLEL EDGES
		duplicates drop hhid SN_hhid, force // REMOVING SELF-LOOPS
		
		bys hhid: egen `VAR'_outdegree_denom=count(SN_hhid)
		la var `VAR'_outdegree_denom "Baseline Outdegree Denominator"
		note `VAR'_outdegree_denom: Number of households that we asked HHID if they know
		
		//CREATE OUTDEGREE NUMERATOR
		gen long SN_hhid2 = SN_hhid if `VAR'==01
		bys hhid : egen `VAR'_outdegree=count(SN_hhid2)
		la var `VAR'_outdegree "Baseline Outdegree"
		duplicates drop hhid, force
		gen `VAR'_outdegree_proportion= `VAR'_outdegree/`VAR'_outdegree_denom
				
		keep hhid `VAR'_outdegree*
		sort hhid
		tempfile temp_outd
		save "`temp_outd'"

	*INDEGREE*
		use "`DATA'", clear
		//COMPUTE INDEGREE DENOMINATOR
		di "INDEGREE - `WID'"
		keep if ward_id== `WID'
		drop if SN_hhid==.
		drop if SN_hhid == hhid //REMOVING SELF-LOOPS 
		duplicates drop hhid SN_hhid, force //REMOVING PARALLEL EDGES 
		
		duplicates tag SN_hhid, gen(`VAR'_indegree_denom)
		replace `VAR'_indegree_denom= `VAR'_indegree_denom+1
		la var `VAR'_indegree_denom "Baseline Indegree Denominator"
		note `VAR'_indegree_denom: Number that know the households
		
		//COMPUTE INDEGREE
		gen long SN_hhid2 = SN_hhid if `VAR'==01
		bys SN_hhid : egen `VAR'_indegree=count(SN_hhid2)
		la var `VAR'_indegree "Baseline Indegree"
		gen `VAR'_indegree_proportion= `VAR'_indegree/`VAR'_indegree_denom
		keep SN_hhid `VAR'_indegree*
		rename SN_hhid hhid
		la var hhid "HHID"
		duplicates drop hhid, force
		sort hhid
		tempfile temp_ind
		save "`temp_ind'"
		
	*TOTAL DEGREE*	
		use "`DATA'", clear
		keep if ward_id ==`WID'
		drop if SN_hhid==.
		drop if SN_hhid == hhid //REMOVING SELF-LOOPS 
		duplicates drop hhid SN_hhid, force //REMOVING PARALLEL EDGES
		sort hhid
		
		//COMPUTE TOTAL DEGREE DENOMINATOR
		netsis hhid SN_hhid, measure(adjacency) name(A,replace)
		netsummarize A, generate(degree) statistic(rowsum)
		rename degree_source `VAR'_total_denom_degree
		la var `VAR'_total_denom_degree "Total Denominator Degree"
		drop degree_target
		
		//COMPUTE TOTAL DEGREE
		di "TOTAL DEGREE"
		gen long SN_hhid2 = SN_hhid if `VAR'==01
		drop if SN_hhid2 == .
		if c(N) == 0 continue // STOPS ERRORS FROM REMOVING ALL OBSERVATIONS
		netsis hhid SN_hhid2, measure(adjacency) name(B,replace)
		netsummarize B , generate(`VAR'_degree) statistic(rowsum)
		rename `VAR'_degree_source `VAR'_total_degree
		la var `VAR'_total_degree "Total Degree"
		duplicates drop hhid, force
		gen `VAR'_Tdegree_proportion= `VAR'_total_degree/`VAR'_total_denom_degree
		keep hhid `VAR'_total_degree `VAR'_total_denom_degree `VAR'_Tdegree_proportion
		sort hhid
		tempfile temp_totald
		save "`temp_totald'"
		
	*EIGENVALUE CENTRALITY*
		use "`DATA'", clear
		keep if ward_id ==`WID'
		drop if SN_hhid==.
		drop if SN_hhid == hhid //REMOVING SELF-LOOPS 
		duplicates drop hhid SN_hhid, force //REMOVING PARALLEL EDGES
		sort hhid
		
		gen long SN_hhid2 = SN_hhid if `VAR'==01
		
		netsis hhid SN_hhid2, measure(eigenvector) name(EIGEN, replace)
		netsummarize EIGEN, gen(`VAR'_E) s(rowsum)
		
		keep hhid `VAR'_E_source
		rename `VAR'_E_source `VAR'_e_score
		la var `VAR'_e_score "Eigenvector Centrality Measure"
		tempfile EIGEN_`WID'
		save "`EIGEN_`WID''", replace
		
	*BETWEENESS CENTRALITY*	
		use "`DATA'", clear
		keep if ward_id ==`WID'
		drop if SN_hhid==.
		drop if SN_hhid == hhid //REMOVING SELF-LOOPS 
		duplicates drop hhid SN_hhid, force //REMOVING PARALLEL EDGES
		sort hhid
		gen long SN_hhid2 = SN_hhid if `VAR'==01
		drop if SN_hhid2 == .
		netsis hhid SN_hhid2, measure(betweenness) name(BETWEEN, replace)
		netsummarize BETWEEN, gen(`VAR'_betweenness) s(rowsum)
		
		keep hhid `VAR'_betweenness_source
		la var `VAR'_betweenness_source "Betweenness Centrality Measure"
		tempfile BETWEEN_`WID'
		save "`BETWEEN_`WID''", replace
			
		use "`temp_head'", clear
		sort hhid
		merge hhid using "`temp_outd'"
		drop _merge
		sort hhid
		
		merge hhid using "`temp_ind'"
		drop _merge
		sort hhid

		merge hhid using "`temp_totald'"
		drop _merge
		sort hhid

		merge hhid using "`EIGEN_`WID''"
		drop _merge
		sort hhid
		
		merge hhid using "`BETWEEN_`WID''"
		drop _merge
		

		if(`WID'==111){
			save "`DATAOUT'/`VAR'_centrality_measures.dta", replace
		} 
		else{
			append using "`DATAOUT'/`VAR'_centrality_measures.dta"
			save "`DATAOUT'/`VAR'_centrality_measures.dta", replace
		} 
	} //END WARDID
} //END VAR

use "`DATAOUT'/m01_centrality_measures.dta"
duplicates drop hhid, force
drop if ward_id==.
save "`DATAOUT'/m01_centrality_measures.dta", replace

use "`DATAOUT'/m10Y_centrality_measures.dta"
duplicates drop hhid, force
drop if ward_id==.
save "`DATAOUT'/m10Y_centrality_measures.dta", replace

merge 1:1 hhid using "`DATAOUT'/m01_centrality_measures.dta"

replace m10Y_outdegree_proportion=0 if  _merge==2
replace m10Y_indegree_proportion=0 if _merge==2 
replace m10Y_Tdegree_proportion=0 if _merge==2 

drop _merge
	
save "`DATAOUT'/centrality_measures.dta", replace
erase "`DATAOUT'/m01_centrality_measures.dta"
erase "`DATAOUT'/m10Y_centrality_measures.dta"

*************************************************
*  M01 CENTRALITY V. M10 CENTRALITY	*
*************************************************


pwcorr m10Y_outdegree_proportion m10Y_indegree_proportion m10Y_e_score m10Y_betweenness_source

twoway scatter m10Y_outdegree_proportion m01_outdegree_proportion
graph export "`RESULTS'/outdegree.png" , replace
 
twoway scatter m10Y_indegree_proportion m01_indegree_proportion
graph export "`RESULTS'/indegree.png" , replace
 
twoway scatter m10Y_e_score m01_e_score
graph export "`RESULTS'/e_score.png" , replace
 
twoway scatter m10Y_betweenness_source m01_betweenness_source
graph export "`RESULTS'/betweenness.png" , replace
 


 
