comby -diff ':[fnname~\bage|\bgender|\balive|\bfather|\bmother|\bpartner|\bchildren|\bpTime|\bstatus|\boutOfTownStudent|\bnewEntrant|\binitialIncome|\bfinalIncome|\b wage|\bincome|\bpotentialIncome|\bjobTenure|\bschedule|\bworkingHours|\bweeklyTime|\b availableWorkingHours|\bworkingPeriods|\bworkExperience|\bpension|\bcareNeedLevel|\bsocialWork|\bchildWork|\bclassRank|\bparentClassRank|\bguardians|\bdependents|\bprovider|\bprovidees]!(:[ag], :[val])' ':[ag].:[fnname] = :[val]' .jl
