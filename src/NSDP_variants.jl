
##############################################################################
# Created by: Wesley DA SILVA COELHO
##############################################################################
#This file contains the main script for NSDP model execution
#: https://hal.archives-ouvertes.fr/hal-02448028


##############################################################################
#                   INCLUDE PACKAGES
##############################################################################
using NBInclude #Package to include personal files",
using JuMP #Mathematical programming package : allows us to define the MILP",
using LightGraphs #Package to construct simple graphs",
using MetaGraphs #Package to construct complex graphs",




# path to some folders
input_folder = "../inputs/"
include_folder = "../include/"
result_folder = "../Results/" 



#including files
include(joinpath(include_folder,"NSDP_instance_generator.jl"))# code creator for 5GNSD instances
include(joinpath(include_folder,"NSDP_structures.j")) # our data structures 
include(joinpath(include_folder,"NSDP_solver.jl")) # impementation of our model 
include(joinpath(include_folder,"NSDP_instance_reader.jl"))# file responsible for parseing new NSDP instances


#Defining instance size
number_DUs = 16 #for mandala topology, it means total size = 13/8*number_DUs     
number_request_per_slice=1
number_slices=32

#creating instances
physical_net_mandala(number_DUs,input_folder) 
slice_requests_generator(number_DUs, input_folder, number_request_per_slice, number_slices)





#creating files and their headres to store the final solutions
#see the header (on write function) to know the information on each file 
open(joinpath(result_folder,"load_on_nodes.csv"), "w") do finalNodeLoad
    write(finalNodeLoad,"test;nodeID;type;objFO;variant;topo;load\n")
end

open(joinpath(result_folder,"load_on_arcs.csv"), "w") do finalArcLoad
    write(finalArcLoad,"test;arcID;type;objFO;variant;topo;load\n") 
end

open(joinpath(result_folder,"final_statistics.csv"), "w") do finalStatistics 
    write(finalStatistics,"test;instance_name;objFO;variant;topology;Objective_value;NFSintalled;disNFS;centNFS;nodes;activeNodes;acitiveNodeRatio;totalNodeCapacity;totalNodeLoad;avNodeLoad;mostLoadedNode;arc;activeArcs;acitiveArcRatio;totalArcCapacity;totalArcLoad;avArcLoad;mostLoadedArc;avrLatency\n")
end

my_instance = 0
OFs = ["minLinkLoad","minNFS"]
variants = ["NSDP","NSDP-ISFS","NSDP-ISSC"]
toplogies = ["Tree","Sun","Mandala"]
splits = [7]
for test in 1:10, var in variants,  of in OFs, topo in toplogies
    #getting all proprities needed to represent the instance
    if var == "NSDP"
        my_instance = get_Instance(input_folder,topo,test,var)
    else
        my_instance = get_Instance_pre(input_folder,topo,test,var)
    end
    #creating model
    model = create_NSDP_variants_model(my_instance, var,of)
    #calling solver 
    solve_NSDP_model(model,"test$(test)_of$(of)_var$(var)_topo$(topo)")

    #getting and saving final solution and information
    get_solution(model,my_instance,result_folder,of,var,test,topo)
    my_instance = 0
    model = 0
    
end


