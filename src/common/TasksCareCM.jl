module TasksCareCM
    

using Utilities

using MaternityAM, TasksAM 


export socialCareDemandPerDay, weeklyCareSupply, initCareTasks!


function weeklyCareSupply(person, pars)
    if person.careNeedLevel > 0
        return 0
    end
    
    if isInMaternity(person)
        return pars.careSupplyMaternity
    end
    
    s = Int(person.status)
    
    pars.careSupplyByStatus[s+1]
end


socialCareDemandPerDay(person, pars) = pars.socialCareDemandPerDay[person.careNeedLevel + 1]
childCareDemandPerDay(person, pars) = 
    person.age < pars.stopChildCareAge ? 
        ( person.age < pars.stopBabyCareAge ? pars.babyCarePerDay : pars.childCarePerDay) :
        0

function initCareTasks!(person, pars)
    sc = socialCareDemandPerDay(person, pars)
    cc = childCareDemandPerDay(person, pars)
    
    # social care demand replaces childcare
    cc = max(cc-sc, 0)
    
    @assert 0 <= cc + sc <= 24
    
    freeHours = 24 - (sc + cc)
    @assert freeHours >= 0
    first = freeHours ÷ 2 + 1
    nSc1stHalf = sc ÷ 2
    nSc2ndHalf = sc - nSc1stHalf
    
    # TODO focus, urgency
    
    TType = taskType(person)
    
    for day in 1:7
        hour = first
        for h in 1:nSc1stHalf
            task = TType(2, person, undefined(person), 24*(day-1)+hour, 0.5, 0.5)
            push!(person.openTasks, task)
            hour += 1
        end
        for h in 1:cc
            task = TType(1, person, undefined(person), 24*(day-1)+hour, 0.5, 0.5)
            push!(person.openTasks, task)
            hour += 1
        end
        for h in 1:nSc2ndHalf
            task = TType(2, person, undefined(person), 24*(day-1)+hour, 0.5, 0.5)
            push!(person.openTasks, task)
            hour += 1
        end           
    end
end


end
