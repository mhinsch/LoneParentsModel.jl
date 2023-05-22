using Utilities

export selectBirth, birth! 

isFertileWoman(p, pars) = isFemale(p) && pars.minPregnancyAge <= age(p) <= pars.maxPregnancyAge
canBePregnant(p) = !isSingle(p) && ageYoungestAliveChild(p) > 1
isPotentialMother(p, pars) = isFertileWoman(p, pars) && canBePregnant(p)

mutable struct BirthCache{PERSON}
    potentialMothers :: Vector{PERSON}
    pPotentialMotherInFertWAndAge :: Vector{Float64}
    classBias :: Vector{Float64}
    nChBias :: Matrix{Float64}
end

BirthCache{T}() where {T} = BirthCache(T[], Float64[], Float64[], zeros(5, 5))

function birthPreCalc!(model, pars)
    pc = model.birthCache
    empty!(pc.potentialMothers)
    for a in model.pop
        if isPotentialMother(a, pars)
            push!(pc.potentialMothers, a)
        end
    end
    
    resize!(pc.pPotentialMotherInFertWAndAge, 150)
    fill!(pc.pPotentialMotherInFertWAndAge, 0)
    cbp = zeros(Int, 150)
    for a in model.pop
        if isFertileWoman(a, pars)
            years = yearsold(a)
            cbp[years] += 1
            if canBePregnant(a)
                pc.pPotentialMotherInFertWAndAge[years] += 1
            end
        end
    end
    for (i, n) in enumerate(cbp)
        pc.pPotentialMotherInFertWAndAge[i] /= n > 0 ? n : Inf 
    end
    
    nPerClass = zeros(5)
    for p in pc.potentialMothers
        nPerClass[classRank(p)+1] += 1
    end
    
    pcpm = copy(nPerClass)
    if length(pc.potentialMothers) > 0
        pcpm ./= length(pc.potentialMothers)
    end
    resize!(pc.classBias, 5)
    sumFertClassBias = sumClassBias(c->pcpm[c+1], 0:4, pars.fertilityBias)
    for c in 0:4
        pc.classBias[c+1] = pars.fertilityBias^c/sumFertClassBias
    end
    
    pncpmc = zeros(5, 5)
    for p in pc.potentialMothers
        c = classRank(p)
        nc = min(4, nChildren(p))
        pncpmc[c+1, nc+1] += 1
    end
    
    fill!(pc.nChBias, 0.0)
    for class in 0:4
        for n in 0:4
            pncpmc[class+1, n+1] /= nPerClass[class+1]
        end
        sumNChBias = sumClassBias(n -> pncpmc[class+1, n+1], 0:4, pars.prevChildFertBias)
        for n in 0:4
            pc.nChBias[class+1, n+1] = pars.prevChildFertBias^n/sumNChBias
        end
    end
end

"Proportion of women that can get pregnant in entire population."
function pPotentialMotherInAllPop(model, pars)
    n = length(model.birthCache.potentialMothers)
    
    n / length(model.pop)
end


function computeBirthProb(woman, parameters, model, currstep)
    (curryear,currmonth) = date2yearsmonths(currstep)
    currmonth = currmonth + 1   # adjusting 0:11 => 1:12 

    womanRank = classRank(woman)
    if status(woman) == WorkStatus.student
        womanRank = parentClassRank(woman)
    end
    
    ageYears = yearsold(woman)
    fertAge = ageYears-parameters.minPregnancyAge+1
    
    if curryear < 1951
        # number of children per uk resident and year
        rawRate = model.pre51Fertility[Int(curryear-parameters.startTime+1)] /
            # scale by number of women that can actually get pregnant
            pPotentialMotherInAllPop(model, parameters) * 
            # and multiply with age-specific fertility factor 
            model.fertFByAge51[fertAge]
    else
        # fertility rates are stored as P(pregnant) per year and age
        rawRate = model.fertility[fertAge, curryear-1950] /
            model.birthCache.pPotentialMotherInFertWAndAge[ageYears]
    end 
    
    # fertility bias by class
    birthProb = rawRate * model.birthCache.classBias[womanRank+1] 
        
    # fertility bias by number of previous children
    birthProb *= model.birthCache.nChBias[womanRank+1, min(4,nChildren(woman))+1]
        
    min(1.0, birthProb)
end # computeBirthProb


function effectsOfMaternity!(woman, pars)
    startMaternity!(woman)
    
    workingHours!(woman, 0)
    income!(woman, 0)
    potentialIncome!(woman, 0)
    availableWorkingHours!(woman, 0)
    # commented in sim.py:
    # woman.weeklyTime = [[0]*12+[1]*12, [0]*12+[1]*12, [0]*12+[1]*12, [0]*12+[1]*12, [0]*12+[1]*12, [0]*12+[1]*12, [0]*12+[1]*12]
    # sets all weeklyTime slots to 1
    # TODO copied from the python code, but does it make sense?
    setFullWeeklyTime!(woman)
    #= TODO
    woman.maxWeeklySupplies = [0, 0, 0, 0]
    woman.residualDailySupplies = [0]*7
    woman.residualWeeklySupplies = [x for x in woman.maxWeeklySupplies]
    =# 

    # TODO not necessarily true in many cases
    if provider(woman) == nothing
        setAsProviderProvidee!(partner(woman), woman)
    end

    nothing
end


selectBirth(person, parameters) = isFertileWoman(person, parameters) && !isSingle(person) && 
    ageYoungestAliveChild(person) > 1 


function birth!(woman, currstep, model, parameters, addBaby!)
    birthProb = computeBirthProb(woman, parameters, model, currstep)
                        
    assumption() do
        @assert isFemale(woman) 
        @assert ageYoungestAliveChild(woman) > 1 
        @assert !isSingle(woman)
        @assert age(woman) >= parameters.minPregnancyAge 
        @assert age(woman) <= parameters.maxPregnancyAge
        @assert birthProb >= 0 
    end
                        
    #=
    The following code is commented in the python code: 
    #baseRate = self.baseRate(self.socialClassShares, self.p['fertilityBias'], rawRate)
    #fertilityCorrector = (self.socialClassShares[woman.classRank] - self.p['initialClassShares'][woman.classRank])/self.p['initialClassShares'][woman.classRank]
    #baseRate *= 1/math.exp(self.p['fertilityCorrector']*fertilityCorrector)
    #birthProb = baseRate*math.pow(self.p['fertilityBias'], woman.classRank)
    =#
                        
    if rand() < p_yearly2monthly(limit(0.0, birthProb, 1.0)) 
                        
        baby = Person(pos=woman.pos,
                        father=partner(woman),mother=woman,
                        gender=rand([male,female]))

        # this goes first, so that we know material circumstances
        effectsOfMaternity!(woman, parameters)
        
        setAsGuardianDependent!(woman, baby)
        if !isSingle(woman) # currently not an option
            setAsGuardianDependent!(partner(woman), baby)
        end
        setAsProviderProvidee!(woman, baby)

        addBaby!(model, baby)
    end # if rand()

    nothing 
end

