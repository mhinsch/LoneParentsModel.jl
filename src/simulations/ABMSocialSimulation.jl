"""
Definition of a social simulation type. It resembles Agents.jl 
""" 

export ABMSocialSimulation 
using SocialABMs: AbstractSocialABM
using SocialABMs: errorstep 

mutable struct ABMSocialSimulation <: AbstractABMSimulation  
    model::AbstractSocialABM
    properties::Dict{Symbol,Any} 
    

    pre_model_steps::Vector{Function} 
    agent_steps::Vector{Function}       
    post_model_steps::Vector{Function} 

    function ABMSocialSimulation(abm::AbstractSocialABM,properties::Dict{Symbol};
                                 example::AbstractExample=DummyExample()) 
        abmsimulation = new(abm,properties,[errorstep],[errorstep],[errorstep])
        setup!(abmsimulation,example)
        abmsimulation 
    end

    ABMSocialSimulation(createABM::Function,properties::Dict{Symbol};
                        example::AbstractExample=DummyExample()) = 
                            ABMSocialSimulation(createABM(),properties,example=example)

#    ABMSocialSimulation(abm::AbstractSocialABM,properties::Dict{Symbol};
#                         agent_step=dummystep,model_step=dummystep) = new(abm,properties,agent_step,model_step)
end 

# default cors .

#
# function run! 
# run!(abm::ABMSocialSimulation,Simproperties) = run!(abm,...) 
# 


# Simulation setup phase 
# attaching simulations  end 
# attach_agent_step      end 
# attach_model_step      end 
# attach_premodel_step   end